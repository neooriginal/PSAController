class AppSession {
  const AppSession({
    required this.authenticated,
    required this.csrfToken,
    required this.userEmail,
  });

  final bool authenticated;
  final String csrfToken;
  final String userEmail;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      authenticated: json['authenticated'] == true,
      csrfToken: (json['csrfToken'] ?? '') as String,
      userEmail: ((json['user'] ?? const {})['email'] ?? '') as String,
    );
  }
}

class SetupState {
  const SetupState({
    required this.status,
    this.brand,
    this.email,
    this.countryCode,
    this.redirectUrl,
    this.syncMessage,
    this.updatedAt,
  });

  final String status;
  final String? brand;
  final String? email;
  final String? countryCode;
  final String? redirectUrl;
  final String? syncMessage;
  final String? updatedAt;

  bool get needsAuthorizationCode => status == 'credentials_saved';
  bool get isDegraded => status == 'degraded';
  bool get requiresReauth => status == 'reauth_required';
  bool get canContinueToOtp =>
      status == 'connected' ||
      status == 'otp_requested' ||
      status == 'ready_to_sync' ||
      status == 'synced';

  factory SetupState.fromJson(Map<String, dynamic> json) {
    return SetupState(
      status: (json['status'] ?? 'not_started') as String,
      brand: json['brand'] as String?,
      email: json['email'] as String?,
      countryCode: json['countryCode'] as String?,
      redirectUrl: json['redirectUrl'] as String?,
      syncMessage: json['syncMessage'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class StatsOverview {
  const StatsOverview({
    required this.totalDistanceKm,
    required this.averageConsumption,
    required this.totalEnergyChargedKwh,
    required this.averageTripLengthKm,
    required this.tripCount,
    this.lastChargeEfficiency,
  });

  final double totalDistanceKm;
  final double averageConsumption;
  final double totalEnergyChargedKwh;
  final double averageTripLengthKm;
  final int tripCount;
  final double? lastChargeEfficiency;

  factory StatsOverview.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        value == null ? 0 : (value as num).toDouble();

    return StatsOverview(
      totalDistanceKm: toDouble(json['totalDistanceKm']),
      averageConsumption: toDouble(json['averageConsumption']),
      totalEnergyChargedKwh: toDouble(json['totalEnergyChargedKwh']),
      averageTripLengthKm: toDouble(json['averageTripLengthKm']),
      tripCount: (json['tripCount'] ?? 0) as int,
      lastChargeEfficiency: json['lastChargeEfficiency'] == null
          ? null
          : (json['lastChargeEfficiency'] as num).toDouble(),
    );
  }
}

class TripRecord {
  const TripRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.averageConsumption,
    required this.averageSpeed,
    required this.altitudeDiff,
  });

  final String id;
  final String startedAt;
  final String endedAt;
  final double distanceKm;
  final double averageConsumption;
  final double averageSpeed;
  final double altitudeDiff;

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        value == null ? 0 : (value as num).toDouble();

    return TripRecord(
      id: (json['id'] ?? '') as String,
      startedAt: (json['startedAt'] ?? '') as String,
      endedAt: (json['endedAt'] ?? '') as String,
      distanceKm: toDouble(json['distanceKm']),
      averageConsumption: toDouble(json['averageConsumption']),
      averageSpeed: toDouble(json['averageSpeed']),
      altitudeDiff: toDouble(json['altitudeDiff']),
    );
  }
}

class ChargingSessionRecord {
  const ChargingSessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.startLevel,
    required this.endLevel,
    required this.energyKwh,
    required this.cost,
    required this.averagePowerKw,
    required this.chargingMode,
  });

  final String id;
  final String startedAt;
  final String? endedAt;
  final double startLevel;
  final double endLevel;
  final double energyKwh;
  final double cost;
  final double averagePowerKw;
  final String chargingMode;

  factory ChargingSessionRecord.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        value == null ? 0 : (value as num).toDouble();

    return ChargingSessionRecord(
      id: (json['id'] ?? '') as String,
      startedAt: (json['startedAt'] ?? '') as String,
      endedAt: json['endedAt'] as String?,
      startLevel: toDouble(json['startLevel']),
      endLevel: toDouble(json['endLevel']),
      energyKwh: toDouble(json['energyKwh']),
      cost: toDouble(json['cost']),
      averagePowerKw: toDouble(json['averagePowerKw']),
      chargingMode: (json['chargingMode'] ?? 'unknown') as String,
    );
  }
}

class PositionPoint {
  const PositionPoint({
    required this.id,
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  final String id;
  final String recordedAt;
  final double? latitude;
  final double? longitude;
  final double? altitude;

  factory PositionPoint.fromJson(Map<String, dynamic> json) {
    double? toNullableDouble(dynamic value) =>
        value == null ? null : (value as num).toDouble();

    return PositionPoint(
      id: (json['id'] ?? '') as String,
      recordedAt: (json['recordedAt'] ?? '') as String,
      latitude: toNullableDouble(json['latitude']),
      longitude: toNullableDouble(json['longitude']),
      altitude: toNullableDouble(json['altitude']),
    );
  }
}

class VehicleSummary {
  const VehicleSummary({
    required this.vin,
    required this.label,
    required this.brand,
    required this.model,
    required this.type,
    required this.capabilities,
    required this.snapshot,
    this.trips = const [],
    this.chargings = const [],
    this.positions = const [],
    this.stats,
  });

  final String vin;
  final String label;
  final String brand;
  final String model;
  final String type;
  final List<String> capabilities;
  final Map<String, dynamic> snapshot;
  final List<TripRecord> trips;
  final List<ChargingSessionRecord> chargings;
  final List<PositionPoint> positions;
  final StatsOverview? stats;

  factory VehicleSummary.fromJson(Map<String, dynamic> json) {
    final tripsJson = (json['trips'] as List<dynamic>? ?? const []);
    final chargingsJson = (json['chargings'] as List<dynamic>? ?? const []);
    final positionsJson = (json['positions'] as List<dynamic>? ?? const []);

    return VehicleSummary(
      vin: (json['vin'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      brand: (json['brand'] ?? '') as String,
      model: (json['model'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      capabilities: ((json['capabilities'] as List<dynamic>? ?? const []))
          .cast<String>(),
      snapshot: (json['snapshot'] as Map<String, dynamic>? ?? const {}),
      trips: tripsJson
          .map((item) => TripRecord.fromJson(item as Map<String, dynamic>))
          .toList(),
      chargings: chargingsJson
          .map(
            (item) =>
                ChargingSessionRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      positions: positionsJson
          .map((item) => PositionPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      stats: json['stats'] == null
          ? null
          : StatsOverview.fromJson(json['stats'] as Map<String, dynamic>),
    );
  }
}

class AuditEventRecord {
  const AuditEventRecord({
    required this.eventType,
    required this.target,
    required this.createdAt,
  });

  final String eventType;
  final String? target;
  final String createdAt;

  factory AuditEventRecord.fromJson(Map<String, dynamic> json) {
    return AuditEventRecord(
      eventType: (json['eventType'] ?? '') as String,
      target: json['target'] as String?,
      createdAt: (json['createdAt'] ?? '') as String,
    );
  }
}

class McpKeyRecord {
  const McpKeyRecord({
    required this.id,
    required this.label,
    required this.scopes,
    required this.createdAt,
    this.key,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String label;
  final List<String> scopes;
  final String createdAt;
  final String? key;
  final String? lastUsedAt;
  final String? revokedAt;

  factory McpKeyRecord.fromJson(Map<String, dynamic> json) {
    return McpKeyRecord(
      id: (json['id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      scopes: ((json['scopes'] as List<dynamic>? ?? const [])).cast<String>(),
      createdAt: (json['createdAt'] ?? '') as String,
      key: json['key'] as String?,
      lastUsedAt: json['lastUsedAt'] as String?,
      revokedAt: json['revokedAt'] as String?,
    );
  }
}
