#!/usr/bin/env python3
import json
import os
import shutil
import sys
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNTIME_HOME = Path(os.environ.get("PSA_BRIDGE_HOME", ROOT_DIR / "psa-runtime"))
SESSION_FILE = RUNTIME_HOME / "session.json"
FALLBACK_SESSION_FILE = (ROOT_DIR / "psa-runtime" / "session.json").resolve()
CONFIG_FILE = RUNTIME_HOME / "config.json"
FALLBACK_CONFIG_FILE = (ROOT_DIR / "psa-runtime" / "config.json").resolve()
CERTS_DIR = RUNTIME_HOME / "certs"
ASSET_CERTS_DIR = Path(__file__).resolve().parent / "certs"


class BridgeError(Exception):
    pass


BRAND_ALIASES = {
    "peugeot": "com.psa.mym.mypeugeot",
    "citroen": "com.psa.mym.mycitroen",
    "opel": "com.psa.mym.myopel",
    "vauxhall": "com.psa.mym.myvauxhall",
    "ds": "com.psa.mym.myds",
    "mypeugeot": "com.psa.mym.mypeugeot",
    "mycitroen": "com.psa.mym.mycitroen",
    "myopel": "com.psa.mym.myopel",
    "myvauxhall": "com.psa.mym.myvauxhall",
    "myds": "com.psa.mym.myds",
    "ap": "com.psa.mym.mypeugeot",
    "ac": "com.psa.mym.mycitroen",
    "op": "com.psa.mym.myopel",
    "vx": "com.psa.mym.myvauxhall",
}


def normalize_brand(raw_brand: str) -> str:
    if not raw_brand:
        raise BridgeError("Brand is required.")
    lowered = raw_brand.strip().lower()
    if lowered in BRAND_ALIASES:
        return BRAND_ALIASES[lowered]
    if lowered.startswith("com.psa.mym."):
        return lowered
    raise BridgeError(f"Unsupported brand: {raw_brand}")


def ensure_runtime_files():
    RUNTIME_HOME.mkdir(parents=True, exist_ok=True)
    CERTS_DIR.mkdir(parents=True, exist_ok=True)

    for cert_name in ("public.pem", "private.pem"):
        target = CERTS_DIR / cert_name
        source = ASSET_CERTS_DIR / cert_name
        if not target.exists() and source.exists():
            shutil.copy2(source, target)


def load_session() -> dict:
    candidates = [SESSION_FILE]
    if FALLBACK_SESSION_FILE not in candidates:
        candidates.append(FALLBACK_SESSION_FILE)

    for candidate in candidates:
        if not candidate.exists():
            continue
        try:
            return json.loads(candidate.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise BridgeError(f"Corrupt session.json: {error}") from error
    return {}


def save_session(data: dict):
    SESSION_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
    if SESSION_FILE.resolve() != FALLBACK_SESSION_FILE:
        FALLBACK_SESSION_FILE.parent.mkdir(parents=True, exist_ok=True)
        FALLBACK_SESSION_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")


def load_saved_config() -> dict:
    candidates = [CONFIG_FILE]
    if FALLBACK_CONFIG_FILE not in candidates:
        candidates.append(FALLBACK_CONFIG_FILE)

    for candidate in candidates:
        if not candidate.exists():
            continue
        try:
            return json.loads(candidate.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise BridgeError(f"Corrupt config.json: {error}") from error
    return {}


def merge_session_with_config(session: dict) -> dict:
    config = load_saved_config()
    if not config:
        return session

    merged = dict(session)
    field_map = {
        "refresh_token": "refreshToken",
        "remote_refresh_token": "remoteRefreshToken",
        "client_id": "clientId",
        "client_secret": "clientSecret",
        "customer_id": "customerId",
        "realm": "realm",
        "country_code": "countryCode",
    }
    for config_key, session_key in field_map.items():
        if not merged.get(session_key) and config.get(config_key):
            merged[session_key] = config[config_key]
    return merged


def require_session_keys(session: dict, keys):
    missing = [key for key in keys if not session.get(key)]
    if missing:
        raise BridgeError(f"Missing session fields: {', '.join(missing)}")


def parse_code(raw_code: str) -> str:
    if not raw_code:
        raise BridgeError("Authorization code is required.")
    if "?" in raw_code and "code=" in raw_code:
        parsed = urlparse(raw_code)
        values = parse_qs(parsed.query).get("code", [])
        if values:
            return values[0]
    if "code=" in raw_code:
        values = parse_qs(raw_code).get("code", [])
        if values:
            return values[0]
    return raw_code.strip()


@contextmanager
def runtime_cwd():
    previous = os.getcwd()
    os.chdir(str(RUNTIME_HOME))
    try:
        yield
    finally:
        os.chdir(previous)


def iso(value):
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def create_psa_client(session: dict):
    from psa_car_controller.psacc.application.psa_client import PSAClient

    session = merge_session_with_config(session)

    require_session_keys(
        session,
        ["clientId", "clientSecret", "customerId", "realm", "countryCode"],
    )

    client = PSAClient(
        session.get("refreshToken"),
        session["clientId"],
        session["clientSecret"],
        session.get("remoteRefreshToken"),
        session["customerId"],
        session["realm"],
        session["countryCode"],
        session.get("brandCode"),
    )

    if session.get("codeVerifier"):
        client.manager.code_verifier = session["codeVerifier"]
    if session.get("redirectUri"):
        client.manager.redirect_uri = session["redirectUri"]
    if session.get("accessToken"):
        # oauth2-client stores the token on a private field.
        client.manager._access_token = session["accessToken"]
    client.config_file = str(CONFIG_FILE)
    client.manager.refresh_callbacks.append(
        lambda: client.save_config(name=str(CONFIG_FILE), force=True)
    )

    return client


def persist_client_state(session: dict, psa_client):
    session["refreshToken"] = psa_client.manager.refresh_token
    session["accessToken"] = psa_client.manager.access_token
    session["remoteRefreshToken"] = psa_client.remote_client.remoteCredentials.refresh_token
    session["remoteAccessToken"] = psa_client.remote_client.remoteCredentials.access_token
    session["codeVerifier"] = psa_client.manager.code_verifier
    session["redirectUri"] = psa_client.manager.redirect_uri

    with runtime_cwd():
        psa_client.save_config(name=str(CONFIG_FILE), force=True)

    save_session(session)
    return session


def extract_snapshot(status_obj):
    snapshot = {
        "batteryLevel": None,
        "batterySoh": None,
        "mileage": None,
        "chargeStatus": None,
        "preconditioningStatus": None,
        "locked": None,
        "latitude": None,
        "longitude": None,
    }

    if status_obj is None:
        return snapshot

    try:
        snapshot["mileage"] = getattr(getattr(status_obj, "timed_odometer", None), "mileage", None)
    except Exception:
        pass

    try:
        electric = status_obj.get_energy("Electric")
        snapshot["batteryLevel"] = getattr(electric, "level", None)
        charging = getattr(electric, "charging", None)
        snapshot["chargeStatus"] = getattr(charging, "status", None)
        battery = getattr(electric, "battery", None)
        health = getattr(battery, "health", None)
        snapshot["batterySoh"] = getattr(health, "resistance", None)
    except Exception:
        pass

    try:
        preconditioning = getattr(status_obj, "preconditionning", None)
        ac = getattr(preconditioning, "air_conditioning", None)
        snapshot["preconditioningStatus"] = getattr(ac, "status", None)
    except Exception:
        pass

    try:
        doors_state = getattr(status_obj, "doors_state", None)
        locked_state = getattr(doors_state, "locked_state", None)
        if isinstance(locked_state, str):
            snapshot["locked"] = locked_state.lower() == "locked"
    except Exception:
        pass

    try:
        coordinates = getattr(getattr(status_obj, "last_position", None), "geometry", None)
        values = getattr(coordinates, "coordinates", None) or []
        if len(values) >= 2:
            snapshot["longitude"] = values[0]
            snapshot["latitude"] = values[1]
    except Exception:
        pass

    return snapshot


def fetch_trips(psa_client, vehicle_id):
    trips = []
    try:
        from psa_car_controller.psa.connected_car_api.api.trips_api import TripsApi

        api = TripsApi(psa_client.api().api_client)
        response = api.get_trips_by_vehicle_1(vehicle_id, page_size=100)
        embedded = getattr(response, "embedded", None)
        raw_trips = getattr(embedded, "trips", None) or []
        for trip in raw_trips:
            avg_consumption = None
            avg_values = getattr(trip, "avg_consumption", None) or []
            if avg_values:
                avg_consumption = getattr(avg_values[0], "value", None)
            trips.append(
                {
                    "id": getattr(trip, "id", None),
                    "startedAt": iso(getattr(trip, "started_at", None) or getattr(trip, "created_at", None)),
                    "endedAt": iso(getattr(trip, "stopped_at", None) or getattr(trip, "created_at", None)),
                    "distanceKm": getattr(trip, "distance", 0) or 0,
                    "averageConsumption": avg_consumption,
                    "averageSpeed": None,
                    "startBatteryLevel": None,
                    "endBatteryLevel": None,
                    "altitudeDiff": None,
                }
            )
    except Exception as error:
        # PSA trip endpoint availability differs by vehicle/market and should not block sync.
        print(f"Trip fetch failed for {vehicle_id}: {error}", file=sys.stderr)
        return []
    return trips


def cmd_submit_credentials(payload: dict):
    import requests

    from psa_car_controller.psa.constants import BRAND
    from psa_car_controller.psa.setup.apk_parser import ApkParser
    from psa_car_controller.psa.setup.github import urlretrieve_from_github
    from psa_car_controller.psacc.application.psa_client import PSAClient

    brand_package = normalize_brand(payload.get("brand", ""))
    email = (payload.get("email") or "").strip()
    password = payload.get("password") or ""
    country_code = (payload.get("countryCode") or "").upper().strip()

    if not email or not password or not country_code:
        raise BridgeError("brand, email, password and countryCode are required.")

    app_version = "1.51.1"
    timeout_s = 10
    github_user = "flobz"
    github_repo = "psa_apk"

    with runtime_cwd():
        filename = brand_package.split(".")[-1] + ".apk"
        urlretrieve_from_github(github_user, github_repo, "", filename)

        apk_parser = ApkParser(filename, country_code)
        apk_parser.retrieve_content_from_apk()

        auth_payload = {
            "siteCode": apk_parser.site_code,
            "culture": "fr-FR",
            "action": "authenticate",
            "fields": {
                "USR_EMAIL": {"value": email},
                "USR_PASSWORD": {"value": password},
            },
        }

        auth_response = requests.post(
            apk_parser.host_brandid_prod + "/GetAccessToken",
            headers={
                "Connection": "Keep-Alive",
                "Content-Type": "application/json",
                "User-Agent": "okhttp/2.3.0",
            },
            params={"jsonRequest": json.dumps(auth_payload)},
            timeout=timeout_s,
        )
        auth_data = auth_response.json()
        ticket = auth_data.get("accessToken")
        if not ticket:
            raise BridgeError(f"Failed to authenticate PSA account: {auth_response.text}")

        brand_meta = BRAND[brand_package]
        user_response = requests.post(
            f"https://mw-{brand_meta['brand_code'].lower()}-m2c.mym.awsmpsa.com/api/v1/user",
            params={
                "culture": apk_parser.culture,
                "width": 1080,
                "version": app_version,
            },
            data=json.dumps({"site_code": apk_parser.site_code, "ticket": ticket}),
            headers={
                "Connection": "Keep-Alive",
                "Content-Type": "application/json;charset=UTF-8",
                "Source-Agent": "App-Android",
                "Token": ticket,
                "User-Agent": "okhttp/4.8.0",
                "Version": app_version,
            },
            cert=(str(CERTS_DIR / "public.pem"), str(CERTS_DIR / "private.pem")),
            timeout=timeout_s,
        )
        user_data = user_response.json().get("success")
        if not user_data:
            raise BridgeError(f"Failed to fetch user profile: {user_response.text}")

        customer_id = f"{brand_meta['brand_code']}-{user_data['id']}"
        psa_client = PSAClient(
            None,
            apk_parser.client_id,
            apk_parser.client_secret,
            None,
            customer_id,
            brand_meta["realm"],
            country_code,
            brand_meta["brand_code"],
        )
        redirect_url = psa_client.manager.generate_redirect_url()

    session = {
        "brand": brand_package,
        "brandLabel": BRAND[brand_package]["app_name"],
        "email": email,
        "countryCode": country_code,
        "clientId": apk_parser.client_id,
        "clientSecret": apk_parser.client_secret,
        "brandCode": BRAND[brand_package]["brand_code"],
        "realm": BRAND[brand_package]["realm"],
        "customerId": customer_id,
        "userInfo": user_data,
        "refreshToken": psa_client.manager.refresh_token,
        "remoteRefreshToken": psa_client.remote_client.remoteCredentials.refresh_token,
        "remoteAccessToken": psa_client.remote_client.remoteCredentials.access_token,
        "redirectUri": psa_client.manager.redirect_uri,
        "codeVerifier": psa_client.manager.code_verifier,
    }
    save_session(session)

    return {
        "status": "credentials_saved",
        "redirectUrl": redirect_url,
        "message": "Credentials accepted. Finish OAuth to connect your vehicle account.",
    }


def cmd_connect(payload: dict):
    session = load_session()
    code = parse_code(payload.get("code", ""))

    with runtime_cwd():
        psa_client = create_psa_client(session)
        psa_client.connect(code)
        cars = psa_client.get_vehicles()

    persist_client_state(session, psa_client)

    return {
        "status": "connected",
        "redirectUrl": None,
        "message": f"Connected successfully. Found {len(cars)} vehicle(s).",
    }


def cmd_request_otp(_payload: dict):
    session = load_session()
    with runtime_cwd():
        psa_client = create_psa_client(session)
        if not psa_client.manager.refresh_token:
            raise BridgeError(
                "Authentication handoff incomplete. Please complete step 2 and submit a fresh authorization code."
            )
        if not psa_client.manager.refresh_token_now():
            raise BridgeError("Failed to refresh token before requesting OTP.")
        response = psa_client.remote_client.get_sms_otp_code()
    persist_client_state(session, psa_client)
    if getattr(response, "status_code", 500) >= 400:
        raise BridgeError(f"SMS OTP request failed: HTTP {response.status_code}")
    return {
        "status": "otp_requested",
        "message": "SMS code requested. Enter the SMS code and your app PIN.",
    }


def cmd_confirm_otp(payload: dict):
    sms_code = (payload.get("smsCode") or payload.get("sms_code") or "").strip()
    pin = (payload.get("pin") or "").strip()
    if not sms_code or not pin:
        raise BridgeError("smsCode and pin are required.")

    from psa_car_controller.psa.otp.otp import new_otp_session, save_otp

    session = load_session()
    with runtime_cwd():
        psa_client = create_psa_client(session)
        otp_session = new_otp_session(sms_code, pin, psa_client.remote_client.otp)
        if otp_session is None:
            raise BridgeError("OTP setup failed. Verify SMS code and PIN.")
        psa_client.remote_client.otp = otp_session
        save_otp(otp_session, filename=str(RUNTIME_HOME / "otp.bin"))

    persist_client_state(session, psa_client)

    return {
        "status": "ready_to_sync",
        "message": "OTP accepted. You can now sync vehicles and send remote actions.",
    }


def cmd_sync_vehicles(_payload: dict):
    session = load_session()
    user_vehicle_map = {
        item.get("vin"): item
        for item in (session.get("userInfo", {}).get("vehicles") or [])
        if item.get("vin")
    }

    with runtime_cwd():
        psa_client = create_psa_client(session)
        has_refresh_token = bool(psa_client.manager.refresh_token)
        # Do not hard-fail on refresh here. Right after OAuth handoff, the current
        # access token can already be valid while refresh may transiently fail.
        if has_refresh_token:
            try:
                psa_client.manager.refresh_token_now()
            except Exception:
                pass
        try:
            cars = psa_client.get_vehicles()
        except TypeError as error:
            # Happens when OAuth access token is absent in a fresh bridge process.
            if "NoneType" in str(error):
                if not has_refresh_token:
                    raise BridgeError(
                        "Authentication handoff incomplete. Please complete step 2 and submit a fresh authorization code."
                    )
                if not psa_client.manager.refresh_token_now():
                    raise BridgeError(
                        "PSA access token unavailable for sync. Re-run authentication handoff."
                    )
                cars = psa_client.get_vehicles()
            else:
                raise

        vehicles = []
        for car in cars:
            status_obj = psa_client.get_vehicle_info(car.vin)
            snapshot = extract_snapshot(status_obj)
            user_vehicle = user_vehicle_map.get(car.vin, {})

            position = []
            if snapshot.get("latitude") is not None and snapshot.get("longitude") is not None:
                position = [
                    {
                        "recordedAt": iso(getattr(getattr(status_obj, "last_position", None), "properties", None) and getattr(getattr(status_obj.last_position, "properties", None), "updated_at", None)),
                        "latitude": snapshot["latitude"],
                        "longitude": snapshot["longitude"],
                        "altitude": None,
                        "mileage": snapshot.get("mileage"),
                        "batteryLevel": snapshot.get("batteryLevel"),
                        "fuelLevel": None,
                    }
                ]

            vehicles.append(
                {
                    "vin": car.vin,
                    "label": user_vehicle.get("short_label") or car.label or car.vin,
                    "brand": session.get("brandLabel") or car.brand or "PSA",
                    "model": user_vehicle.get("label") or car.label or "Unknown",
                    "type": "electric",
                    "capabilities": ["remote_control", "status", "trips"],
                    "snapshot": snapshot,
                    "trips": fetch_trips(psa_client, car.vehicle_id),
                    "chargings": [],
                    "positions": position,
                }
            )

    persist_client_state(session, psa_client)
    return vehicles


def cmd_run_action(payload: dict):
    vin = (payload.get("vin") or "").strip()
    action = (payload.get("action") or "").strip()
    body = payload.get("payload") or {}
    if not vin or not action:
        raise BridgeError("vin and action are required.")

    session = load_session()
    with runtime_cwd():
        psa_client = create_psa_client(session)
        if not psa_client.manager.refresh_token_now():
            raise BridgeError("Unable to refresh PSA token for remote action.")

        remote = psa_client.remote_client
        if remote.mqtt_client is None or not remote.mqtt_client.is_connected():
            try:
                started = remote.start()
            except ModuleNotFoundError:
                try:
                    (RUNTIME_HOME / "otp.bin").unlink(missing_ok=True)
                except Exception:
                    pass
                raise BridgeError("OTP data format is outdated. Request and confirm OTP again.")
            if not started:
                raise BridgeError("Remote control unavailable. Complete OTP setup first.")

        if action == "wakeup":
            result = remote.wakeup(vin)
        elif action == "charge_now":
            psa_client.get_vehicle_info(vin)
            result = remote.charge_now(vin, bool(body.get("enable", True)))
        elif action == "preconditioning":
            result = remote.preconditioning(vin, bool(body.get("enable", True)))
        elif action == "lock_doors":
            result = remote.lock_door(vin, bool(body.get("lock", True)))
        elif action == "lights":
            result = remote.lights(vin, int(body.get("duration", 30)))
        elif action == "horn":
            result = remote.horn(vin, int(body.get("count", 1)))
        else:
            raise BridgeError(f"Unsupported action: {action}")

        try:
            remote.stop()
        except Exception:
            pass

    persist_client_state(session, psa_client)

    return {
        "vin": vin,
        "action": action,
        "payload": body,
        "status": "success",
        "message": f"{action} request sent.",
        "result": result,
    }


COMMANDS = {
    "submit_credentials": cmd_submit_credentials,
    "connect": cmd_connect,
    "request_otp": cmd_request_otp,
    "confirm_otp": cmd_confirm_otp,
    "sync_vehicles": cmd_sync_vehicles,
    "run_action": cmd_run_action,
}


def main():
    ensure_runtime_files()

    if len(sys.argv) < 2:
        raise BridgeError("Missing command argument.")

    command = sys.argv[1]
    payload = {}
    if len(sys.argv) > 2 and sys.argv[2]:
        payload = json.loads(sys.argv[2])

    if command not in COMMANDS:
        raise BridgeError(f"Unknown command: {command}")

    result = COMMANDS[command](payload)
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except BridgeError as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
    except Exception as error:
        print(json.dumps({"error": f"Bridge failure: {error}"}))
        sys.exit(1)
