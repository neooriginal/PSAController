import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import 'api_client.dart';

class AppController extends ChangeNotifier {
  AppController(this._apiClient);

  final ApiClient _apiClient;

  bool loading = false;
  bool initialized = false;
  bool bootstrapRequired = true;
  String? errorMessage;
  String? bannerMessage;
  AppSession? session;
  SetupState? setupState;
  List<VehicleSummary> vehicles = const [];
  List<McpKeyRecord> mcpKeys = const [];
  List<AuditEventRecord> auditEvents = const [];
  Map<String, String> settings = const {};
  String? selectedVin;
  DateTime? lastRefreshedAt;

  VehicleSummary? get selectedVehicle {
    if (vehicles.isEmpty) {
      return null;
    }
    return vehicles.firstWhere(
      (vehicle) => vehicle.vin == selectedVin,
      orElse: () => vehicles.first,
    );
  }

  Future<void> initialize() async {
    await _run(() async {
      final bootstrap =
          await _apiClient.getJson('/api/bootstrap-state')
              as Map<String, dynamic>;
      bootstrapRequired = (bootstrap['requiresBootstrap'] ?? false) as bool;

      if (!bootstrapRequired) {
        try {
          final sessionJson =
              await _apiClient.getJson('/api/auth/session')
                  as Map<String, dynamic>;
          session = AppSession.fromJson(sessionJson);
          await _loadPrivateData();
        } on ApiException {
          session = null;
        }
      }
      initialized = true;
    });
  }

  Future<void> bootstrap(String email, String password) async {
    await _run(() async {
      final response =
          await _apiClient.postJson('/api/bootstrap/admin', {
                'email': email,
                'password': password,
              })
              as Map<String, dynamic>;
      bootstrapRequired = false;
      session = AppSession(
        authenticated: true,
        csrfToken: response['csrfToken'] as String,
        userEmail: email,
      );
      await _loadPrivateData();
    });
  }

  Future<void> login(String email, String password) async {
    await _run(() async {
      final response =
          await _apiClient.postJson('/api/auth/login', {
                'email': email,
                'password': password,
              })
              as Map<String, dynamic>;
      session = AppSession(
        authenticated: true,
        csrfToken: response['csrfToken'] as String,
        userEmail: email,
      );
      await _loadPrivateData();
    });
  }

  Future<void> logout() async {
    await _run(() async {
      await _apiClient.postJson(
        '/api/auth/logout',
        {},
        csrfToken: session?.csrfToken,
      );
      _clearPrivateState();
    });
  }

  Future<void> refreshDashboard() async {
    await _run(() async {
      await _loadPrivateData();
      bannerMessage = 'Dashboard refreshed.';
    }, preserveMessage: false);
  }

  Future<void> saveCredentials({
    required String brand,
    required String email,
    required String password,
    required String countryCode,
  }) async {
    await _run(() async {
      final response =
          await _apiClient.postJson('/api/setup/session', {
                'brand': brand,
                'email': email,
                'password': password,
                'countryCode': countryCode,
              }, csrfToken: session?.csrfToken)
              as Map<String, dynamic>;
      setupState = SetupState.fromJson(response);
      bannerMessage = setupState?.syncMessage ?? 'Credentials saved.';
    }, preserveMessage: false);
  }

  Future<void> connectSetup(String code) async {
    await _run(() async {
      final response =
          await _apiClient.postJson('/api/setup/connect', {
                'code': code,
              }, csrfToken: session?.csrfToken)
              as Map<String, dynamic>;
      setupState = SetupState.fromJson(response);
      bannerMessage = setupState?.syncMessage;
    }, preserveMessage: false);
  }

  Future<void> connectSetupAuto() async {
    await _run(() async {
      final response =
          await _apiClient.postJson(
                '/api/setup/connect/auto',
                {},
                csrfToken: session?.csrfToken,
              )
              as Map<String, dynamic>;
      setupState = SetupState.fromJson(response);
      bannerMessage = setupState?.syncMessage;
    }, preserveMessage: false);
  }

  Future<void> requestOtp() async {
    await _run(() async {
      final response =
          await _apiClient.postJson(
                '/api/setup/otp/request',
                {},
                csrfToken: session?.csrfToken,
              )
              as Map<String, dynamic>;
      setupState = SetupState.fromJson(response);
      bannerMessage = setupState?.syncMessage;
    }, preserveMessage: false);
  }

  Future<void> confirmOtp(String smsCode, String pin) async {
    await _run(() async {
      final response =
          await _apiClient.postJson('/api/setup/otp/confirm', {
                'smsCode': smsCode,
                'pin': pin,
              }, csrfToken: session?.csrfToken)
              as Map<String, dynamic>;
      setupState = SetupState.fromJson(response);
      bannerMessage = setupState?.syncMessage;
    }, preserveMessage: false);
  }

  Future<void> syncVehicles() async {
    await _run(() async {
      await _apiClient.postJson(
        '/api/setup/sync',
        {},
        csrfToken: session?.csrfToken,
      );
      await _loadPrivateData();
      bannerMessage = setupState?.syncMessage ?? 'Vehicle sync finished.';
    }, preserveMessage: false);
  }

  Future<void> resetOnboarding() async {
    await _run(() async {
      final response =
          await _apiClient.postJson(
                '/api/setup/reset',
                {},
                csrfToken: session?.csrfToken,
              )
              as Map<String, dynamic>;
      setupState = SetupState.fromJson(response);
      vehicles = const [];
      selectedVin = null;
      bannerMessage = 'Onboarding reset. Reconnect your PSA account.';
    }, preserveMessage: false);
  }

  Future<void> updateSettings(Map<String, String> nextSettings) async {
    await _run(() async {
      final response =
          await _apiClient.putJson(
                '/api/settings',
                nextSettings,
                csrfToken: session?.csrfToken,
              )
              as Map<String, dynamic>;
      settings = response.map((key, value) => MapEntry(key, '$value'));
      bannerMessage = 'Settings saved.';
    }, preserveMessage: false);
  }

  Future<void> changePassword(String password) async {
    await _run(() async {
      await _apiClient.postJson('/api/auth/password', {
        'password': password,
      }, csrfToken: session?.csrfToken);
      bannerMessage = 'Password updated.';
    }, preserveMessage: false);
  }

  Future<void> createMcpKey(String label, List<String> scopes) async {
    await _run(() async {
      final response =
          await _apiClient.postJson('/api/settings/mcp-keys', {
                'label': label,
                'scopes': scopes,
              }, csrfToken: session?.csrfToken)
              as Map<String, dynamic>;
      mcpKeys = [McpKeyRecord.fromJson(response), ...mcpKeys];
      bannerMessage = 'MCP key created. Copy it now; it is shown once.';
    }, preserveMessage: false);
  }

  Future<void> revokeMcpKey(String id) async {
    await _run(() async {
      await _apiClient.delete(
        '/api/settings/mcp-keys/$id',
        csrfToken: session?.csrfToken,
      );
      await _loadAdminData();
      bannerMessage = 'MCP key revoked.';
    }, preserveMessage: false);
  }

  Future<void> runVehicleAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final vin = selectedVehicle?.vin;
    if (vin == null) {
      return;
    }

    await _run(() async {
      final response =
          await _apiClient.postJson(
                '/api/vehicles/$vin/actions/$action',
                payload,
                csrfToken: session?.csrfToken,
              )
              as Map<String, dynamic>;
      bannerMessage = response['message']?.toString() ?? 'Action queued.';
      await _loadVehicles();
    }, preserveMessage: false);
  }

  void selectVehicle(String vin) {
    selectedVin = vin;
    notifyListeners();
  }

  Future<void> _loadPrivateData() async {
    await Future.wait([
      _loadSetupState(),
      _loadVehicles(),
      _loadAdminData(),
      _loadSettings(),
    ]);
    lastRefreshedAt = DateTime.now();
  }

  Future<void> _loadSetupState() async {
    final setupJson =
        await _apiClient.getJson('/api/setup/state') as Map<String, dynamic>;
    setupState = SetupState.fromJson(setupJson);
  }

  Future<void> _loadVehicles() async {
    final vehicleJson =
        await _apiClient.getJson('/api/vehicles') as List<dynamic>;
    final summaries = vehicleJson
        .map((item) => VehicleSummary.fromJson(item as Map<String, dynamic>))
        .toList();
    vehicles = summaries;
    if (summaries.isNotEmpty) {
      selectedVin ??= summaries.first.vin;
      final detailJson =
          await _apiClient.getJson('/api/vehicles/$selectedVin')
              as Map<String, dynamic>;
      final detail = VehicleSummary.fromJson(detailJson);
      vehicles = [
        detail,
        ...summaries.where((vehicle) => vehicle.vin != detail.vin),
      ];
    }
  }

  Future<void> _loadAdminData() async {
    final keysJson =
        await _apiClient.getJson('/api/settings/mcp-keys') as List<dynamic>;
    final auditJson = [] as List<dynamic>;
    mcpKeys = keysJson
        .map((item) => McpKeyRecord.fromJson(item as Map<String, dynamic>))
        .toList();
    auditEvents = auditJson
        .map((item) => AuditEventRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadSettings() async {
    final settingsJson =
        await _apiClient.getJson('/api/settings') as Map<String, dynamic>;
    settings = settingsJson.map((key, value) => MapEntry(key, '$value'));
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool preserveMessage = true,
  }) async {
    loading = true;
    errorMessage = null;
    if (!preserveMessage) {
      bannerMessage = null;
    }
    notifyListeners();
    try {
      await operation();
    } on ApiException catch (error) {
      if (_isReauthError(error.message)) {
        _markOnboardingRequired(error.message);
      } else if (error.statusCode == 401) {
        _clearPrivateState();
        errorMessage = 'Authentication required. Restarted the session flow.';
      } else {
        errorMessage = error.message;
      }
    } catch (error) {
      final text = error.toString();
      if (_isReauthError(text)) {
        _markOnboardingRequired(text);
      } else {
        errorMessage = text;
      }
    } finally {
      loading = false;
      initialized = true;
      notifyListeners();
    }
  }

  bool _isReauthError(String message) {
    final lowered = message.toLowerCase();
    return lowered.contains('invalid_grant') ||
        lowered.contains('grant is invalid') ||
        lowered.contains('reauth_required') ||
        lowered.contains('psa session expired');
  }

  void _markOnboardingRequired(String message) {
    setupState = SetupState(
      status: 'reauth_required',
      brand: setupState?.brand,
      email: setupState?.email,
      countryCode: setupState?.countryCode,
      redirectUrl: null,
      syncMessage:
          'PSA authorization expired. Please redo onboarding in setup or settings.',
      updatedAt: DateTime.now().toIso8601String(),
    );
    errorMessage = message;
    bannerMessage = 'PSA authorization expired. Please reconnect your account.';
  }

  void _clearPrivateState() {
    session = null;
    vehicles = const [];
    mcpKeys = const [];
    auditEvents = const [];
    settings = const {};
    setupState = null;
    selectedVin = null;
    lastRefreshedAt = null;
  }
}
