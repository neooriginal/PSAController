import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/app_models.dart';
import 'services/api_client.dart';
import 'services/app_controller.dart';
import 'widgets/glass_panel.dart';
import 'widgets/metric_card.dart';

void main() {
  runApp(const PsaControllerApp());
}

class PsaControllerApp extends StatefulWidget {
  const PsaControllerApp({super.key});

  @override
  State<PsaControllerApp> createState() => _PsaControllerAppState();
}

class _PsaControllerAppState extends State<PsaControllerApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(ApiClient())..initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF204A3A),
        brightness: Brightness.light,
        surface: const Color(0xFFFBF7F0),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5EFE5),
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PSA Controller',
      theme: theme,
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => AppShell(controller: controller),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final body = !controller.initialized
        ? const Center(child: CircularProgressIndicator())
        : controller.bootstrapRequired
        ? BootstrapScreen(controller: controller)
        : controller.session == null
        ? LoginScreen(controller: controller)
        : DashboardScreen(controller: controller);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9F2E7), Color(0xFFE6EFE7), Color(0xFFF5EFE5)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -40,
              child: _Orb(color: const Color(0x55D7B36A), size: 240),
            ),
            Positioned(
              bottom: -80,
              right: -20,
              child: _Orb(color: const Color(0x553A806A), size: 220),
            ),
            SafeArea(
              child: Padding(padding: const EdgeInsets.all(20), child: body),
            ),
          ],
        ),
      ),
    );
  }
}

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Text(
                  'Create the first secure operator account.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'This account owns browser access, PSA connection setup, remote commands, and MCP key management.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.controller.loading
                        ? null
                        : () => widget.controller.bootstrap(
                            emailController.text.trim(),
                            passwordController.text,
                          ),
                    child: const Text('Create admin account'),
                  ),
                ),
                if (widget.controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.controller.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: GlassPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Text(
                  'PSA Controller',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign in to the control room for onboarding, remote actions, analytics, and audited AI access.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.controller.loading
                        ? null
                        : () => widget.controller.login(
                            emailController.text.trim(),
                            passwordController.text,
                          ),
                    child: const Text('Sign in'),
                  ),
                ),
                if (widget.controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.controller.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int index = 0;

  static const tabs = [
    'Overview',
    'Trips',
    'Charge',
    'Map',
    'Control',
    'Stats',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.controller.selectedVehicle;
    final setupStatus = widget.controller.setupState?.status ?? 'not_started';
    final needsSetup = setupStatus != 'synced';

    return Column(
      children: [
        _TopBar(controller: widget.controller),
        if (widget.controller.bannerMessage != null) ...[
          const SizedBox(height: 12),
          _Banner(message: widget.controller.bannerMessage!, isError: false),
        ],
        if (widget.controller.errorMessage != null) ...[
          const SizedBox(height: 12),
          _Banner(message: widget.controller.errorMessage!, isError: true),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: needsSetup
              ? SetupScreen(controller: widget.controller)
              : Column(
                  children: [
                    _DashboardTabBar(
                      tabs: tabs,
                      index: index,
                      onSelected: (tabIndex) =>
                          setState(() => index = tabIndex),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildPage(context, vehicle)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, VehicleSummary? vehicle) {
    switch (index) {
      case 0:
        return OverviewPage(controller: widget.controller, vehicle: vehicle);
      case 1:
        return TripsPage(vehicle: vehicle);
      case 2:
        return ChargePage(vehicle: vehicle);
      case 3:
        return MapPage(vehicle: vehicle);
      case 4:
        return ControlPage(controller: widget.controller, vehicle: vehicle);
      case 5:
        return StatsPage(vehicle: vehicle);
      default:
        return SettingsPage(controller: widget.controller);
    }
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  static const brandOptions = <String, String>{
    'Peugeot': 'com.psa.mym.mypeugeot',
    'Opel': 'com.psa.mym.myopel',
    'Citroën': 'com.psa.mym.mycitroen',
    'DS': 'com.psa.mym.myds',
    'Vauxhall': 'com.psa.mym.myvauxhall',
  };

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final countryController = TextEditingController(text: 'DE');
  final authCodeController = TextEditingController();
  final otpController = TextEditingController();
  final pinController = TextEditingController();
  String brand = 'Peugeot';

  int get stepIndex {
    final status = widget.controller.setupState?.status ?? 'not_started';
    final hasRedirectUrl =
        (widget.controller.setupState?.redirectUrl ?? '').isNotEmpty;
    if (status == 'reauth_required' && hasRedirectUrl) return 1;
    if (status == 'credentials_saved') return 1;
    if (status == 'connected') return 2;
    if (status == 'otp_requested') return 3;
    if (status == 'ready_to_sync') return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;
        final mainPanel = GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PSA setup',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'A compact staged flow with explicit blockers and degraded-mode messaging.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              _SetupStepper(stepIndex: stepIndex),
              const SizedBox(height: 22),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  child: SingleChildScrollView(
                    key: ValueKey(stepIndex),
                    child: _buildStepCard(context),
                  ),
                ),
              ),
            ],
          ),
        );
        final statusPanel = GlassPanel(
          child: _SetupStatusPanel(
            stepIndex: stepIndex,
            setupState: widget.controller.setupState,
          ),
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: mainPanel),
              const SizedBox(height: 16),
              SizedBox(height: 220, child: statusPanel),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: mainPanel),
            const SizedBox(width: 18),
            SizedBox(width: 320, child: statusPanel),
          ],
        );
      },
    );
  }

  Future<void> _copyRedirectUrl(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard.')),
      );
    } catch (error) {
      authCodeController.text = url;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard access is blocked in this browser context. URL was placed in the field below for manual copy.',
          ),
        ),
      );
    }
  }

  Widget _buildStepCard(BuildContext context) {
    switch (stepIndex) {
      case 0:
        return Column(
          key: const ValueKey('credentials'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Account & region',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: brand,
              items: const ['Peugeot', 'Opel', 'Citroën', 'DS', 'Vauxhall']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => brand = value ?? brand),
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'PSA email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PSA password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countryController,
              decoration: const InputDecoration(labelText: 'Country code'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.controller.loading
                  ? null
                  : () => widget.controller.saveCredentials(
                      brand: brandOptions[brand] ?? brand,
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      countryCode: countryController.text.trim(),
                    ),
              child: const Text('Save connection details'),
            ),
          ],
        );
      case 1:
        final redirectUrl = widget.controller.setupState?.redirectUrl;
        return Column(
          key: const ValueKey('connect'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Authentication handoff',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              widget.controller.setupState?.syncMessage ??
                  'Open the PSA login page in a second tab, finish the flow, then paste the final redirect URL or just the code value.',
            ),
            if ((widget.controller.setupState?.status ?? '') ==
                'reauth_required') ...[
              const SizedBox(height: 10),
              Text(
                'The previous PSA session expired. Complete this step again to restore live sync without resetting the rest of the app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (redirectUrl != null && redirectUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFE6EEF2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open this PSA URL in a separate browser tab. When the brand page finishes, copy the final redirect URL or the `code=` value and paste it below.',
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      redirectUrl,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _copyRedirectUrl(redirectUrl);
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Link'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(redirectUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open link directly. Please copy it instead.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open Link'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: authCodeController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Redirect URL or authorization code',
                hintText:
                    'Paste the full mym...://oauth2redirect/... URL or just the code value',
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: widget.controller.loading
                      ? null
                      : () => widget.controller.connectSetup(
                          authCodeController.text.trim(),
                        ),
                  child: const Text('Complete authentication'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.loading
                      ? null
                      : widget.controller.connectSetupAuto,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Try browser automation'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Browser automation is experimental and often breaks on CAPTCHA, MFA, or PSA page changes. The manual paste flow above is the reliable path.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case 2:
        return Column(
          key: const ValueKey('otp-request'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. SMS verification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              widget.controller.setupState?.syncMessage ??
                  'Request an OTP by SMS to unlock remote actions.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.controller.loading
                  ? null
                  : widget.controller.requestOtp,
              child: const Text('Request SMS code'),
            ),
          ],
        );
      case 3:
        return Column(
          key: const ValueKey('otp-confirm'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. OTP and PIN',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: const InputDecoration(labelText: 'SMS code'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Vehicle PIN'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.controller.loading
                  ? null
                  : () => widget.controller.confirmOtp(
                      otpController.text.trim(),
                      pinController.text.trim(),
                    ),
              child: const Text('Confirm and prepare sync'),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey('sync'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5. Vehicle sync',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              widget.controller.setupState?.syncMessage ??
                  'Finalize the first sync. If the provider is unavailable, the app stays reachable and reports degraded mode.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.controller.loading
                  ? null
                  : widget.controller.syncVehicles,
              child: const Text('Sync vehicles now'),
            ),
          ],
        );
    }
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.controller,
    required this.vehicle,
  });

  final AppController controller;
  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    if (vehicle == null) {
      return const GlassPanel(
        child: Center(child: Text('No vehicles available yet.')),
      );
    }

    final stats = vehicle!.stats;
    final snapshot = vehicle!.snapshot;
    final metricCards = [
      MetricCard(
        label: 'Battery',
        value: '${(snapshot['batteryLevel'] ?? 0).round()}%',
        footnote: 'Live state of charge',
      ),
      MetricCard(
        label: 'Mileage',
        value: '${(snapshot['mileage'] ?? 0).round()} km',
        footnote: 'Last synced odometer',
      ),
      MetricCard(
        label: 'Battery SOH',
        value: stats?.lastChargeEfficiency == null
            ? '${(snapshot['batterySoh'] ?? 0).round()}%'
            : '${((snapshot['batterySoh'] ?? 0) as num?)?.round() ?? 0}%',
        footnote: 'Latest observed health',
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F3D33), Color(0xFF8B6A37)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 960;
                final headline = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle!.brand} ${vehicle!.model}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'VIN: ${vehicle!.vin} • ${vehicle!.type.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFEDE5D8),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatusPill(
                          label: 'Charge',
                          value: '${snapshot['chargeStatus'] ?? 'unknown'}',
                        ),
                        _StatusPill(
                          label: 'Climate',
                          value:
                              '${snapshot['preconditioningStatus'] ?? 'unknown'}',
                        ),
                        _StatusPill(
                          label: 'Doors',
                          value: (snapshot['locked'] == true)
                              ? 'locked'
                              : 'unlocked',
                        ),
                      ],
                    ),
                  ],
                );
                final controlBlock = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: compact ? double.infinity : 280,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: controller.selectedVin,
                        dropdownColor: Colors.white,
                        items: controller.vehicles
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.vin,
                                child: Text('${item.brand} ${item.model}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectVehicle(value);
                            controller.refreshDashboard();
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Vehicle'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${(snapshot['batteryLevel'] ?? 0).round()}%',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'battery now',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFEDE5D8),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headline,
                      const SizedBox(height: 24),
                      controlBlock,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: headline),
                    const SizedBox(width: 24),
                    controlBlock,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1100;
              final chartPanel = Expanded(
                flex: compact ? 0 : 8,
                child: GlassPanel(
                  child: SizedBox(
                    height: 300,
                    child: stats == null || vehicle!.trips.isEmpty
                        ? const Center(
                            child: Text(
                              'Import or sync trip data to unlock the trip-distance trace.',
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: vehicle!.trips
                                      .take(12)
                                      .toList()
                                      .reversed
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => FlSpot(
                                          entry.key.toDouble(),
                                          entry.value.distanceKm,
                                        ),
                                      )
                                      .toList(),
                                  isCurved: true,
                                  color: const Color(0xFF275F49),
                                  barWidth: 4,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0x33275F49),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
              final metricsPanel = Expanded(
                flex: compact ? 0 : 5,
                child: GridView.count(
                  crossAxisCount: compact ? 2 : 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: compact ? 1.35 : 1.12,
                  children: metricCards,
                ),
              );

              if (compact) {
                return Column(
                  children: [
                    chartPanel,
                    const SizedBox(height: 18),
                    metricsPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [chartPanel, const SizedBox(width: 18), metricsPanel],
              );
            },
          ),
        ],
      ),
    );
  }
}

class TripsPage extends StatelessWidget {
  const TripsPage({super.key, required this.vehicle});

  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    final trips = vehicle?.trips ?? const <TripRecord>[];
    return GlassPanel(
      child: trips.isEmpty
          ? const Center(
              child: Text(
                'No trips recorded yet. Import or sync data to populate this view.',
              ),
            )
          : ListView.separated(
              itemBuilder: (context, index) {
                final trip = trips[index];
                return ListTile(
                  title: Text('${trip.distanceKm.toStringAsFixed(1)} km'),
                  subtitle: Text('${trip.startedAt} → ${trip.endedAt}'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip.averageConsumption.toStringAsFixed(1)} kWh/100',
                      ),
                      Text('${trip.averageSpeed.toStringAsFixed(0)} km/h'),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemCount: trips.length,
            ),
    );
  }
}

class ChargePage extends StatelessWidget {
  const ChargePage({super.key, required this.vehicle});

  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    final chargings = vehicle?.chargings ?? const <ChargingSessionRecord>[];
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GlassPanel(
            child: chargings.isEmpty
                ? const Center(
                    child: Text('No charging sessions available yet.'),
                  )
                : ListView.separated(
                    itemBuilder: (context, index) {
                      final charging = chargings[index];
                      return ListTile(
                        title: Text(
                          '${charging.energyKwh.toStringAsFixed(1)} kWh • ${charging.chargingMode}',
                        ),
                        subtitle: Text(charging.startedAt),
                        trailing: Text(charging.cost.toStringAsFixed(2)),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemCount: chargings.length,
                  ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 2,
          child: GlassPanel(
            child: SizedBox(
              height: double.infinity,
              child: chargings.isEmpty
                  ? const Center(
                      child: Text(
                        'Charging curve will appear after sync or import.',
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: chargings
                                .take(10)
                                .toList()
                                .reversed
                                .toList()
                                .asMap()
                                .entries
                                .map(
                                  (entry) => FlSpot(
                                    entry.key.toDouble(),
                                    entry.value.averagePowerKw,
                                  ),
                                )
                                .toList(),
                            isCurved: true,
                            color: const Color(0xFFB98A3B),
                            dotData: const FlDotData(show: false),
                            barWidth: 4,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key, required this.vehicle});

  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    final positions =
        vehicle?.positions
            .where((item) => item.latitude != null && item.longitude != null)
            .toList() ??
        const <PositionPoint>[];
    return GlassPanel(
      child: positions.isEmpty
          ? const Center(child: Text('No location history available yet.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route surface',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: CustomPaint(
                    painter: RoutePainter(points: positions),
                    child: Container(),
                  ),
                ),
              ],
            ),
    );
  }
}

class ControlPage extends StatelessWidget {
  const ControlPage({
    super.key,
    required this.controller,
    required this.vehicle,
  });

  final AppController controller;
  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    if (vehicle == null) {
      return const GlassPanel(
        child: Center(child: Text('Select a vehicle first.')),
      );
    }

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width < 1100 ? 2 : 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _ActionCard(
          title: 'Wake up vehicle',
          subtitle:
              'Ping the car and refresh state after a disconnection or stale session.',
          onPressed: () => controller.runVehicleAction('wakeup', {}),
        ),
        _ActionCard(
          title: 'Charge now',
          subtitle: 'Switch from delayed to immediate charging.',
          onPressed: () =>
              controller.runVehicleAction('charge_now', {'enable': true}),
        ),
        _ActionCard(
          title: 'Stop immediate charge',
          subtitle: 'Fall back to scheduled charging mode.',
          onPressed: () =>
              controller.runVehicleAction('charge_now', {'enable': false}),
        ),
        _ActionCard(
          title: 'Preconditioning on',
          subtitle: 'Trigger cabin preconditioning.',
          onPressed: () =>
              controller.runVehicleAction('preconditioning', {'enable': true}),
        ),
        _ActionCard(
          title: 'Lock doors',
          subtitle: 'Send a lock command.',
          onPressed: () =>
              controller.runVehicleAction('lock_doors', {'lock': true}),
        ),
        _ActionCard(
          title: 'Lights',
          subtitle: 'Flash exterior lights for 30 seconds.',
          onPressed: () =>
              controller.runVehicleAction('lights', {'duration': 30}),
        ),
      ],
    );
  }
}

class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.vehicle});

  final VehicleSummary? vehicle;

  @override
  Widget build(BuildContext context) {
    final stats = vehicle?.stats;
    if (stats == null) {
      return const GlassPanel(
        child: Center(
          child: Text(
            'Stats appear after trips and charging sessions are available.',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width < 1100 ? 2 : 3,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              MetricCard(
                label: 'Total distance',
                value: '${stats.totalDistanceKm.toStringAsFixed(0)} km',
                footnote: 'Selected history range',
              ),
              MetricCard(
                label: 'Average consumption',
                value: stats.averageConsumption.toStringAsFixed(1),
                footnote: 'Energy per 100 km',
              ),
              MetricCard(
                label: 'Energy charged',
                value: '${stats.totalEnergyChargedKwh.toStringAsFixed(1)} kWh',
                footnote: 'Across local charging records',
              ),
              MetricCard(
                label: 'Average trip',
                value: '${stats.averageTripLengthKm.toStringAsFixed(1)} km',
                footnote: '${stats.tripCount} trips in total',
              ),
              MetricCard(
                label: 'Charge efficiency',
                value: stats.lastChargeEfficiency?.toStringAsFixed(2) ?? 'n/a',
                footnote: 'Last completed charging efficiency estimate',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final passwordController = TextEditingController();
  final mcpLabelController = TextEditingController();
  bool controlScope = false;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    // Other sync logic can go here if needed in the future
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.controller.mcpKeys;
    final mcpEndpoint = Uri.base.replace(path: '/mcp', query: '').toString();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () =>
                      widget.controller.changePassword(passwordController.text),
                  child: const Text('Update password'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => widget.controller.resetOnboarding(),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Redo PSA onboarding'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this if PSA authorization expired (for example invalid_grant) or remote actions fail with token errors.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MCP keys', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Use the Model Context Protocol to control and query your vehicle directly from compatible AI clients (like Claude). The protocol URL detected for this page is:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  mcpEndpoint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mcpLabelController,
                  decoration: const InputDecoration(labelText: 'Key label'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: controlScope,
                  title: const Text('Enable vehicle control scope'),
                  onChanged: (value) => setState(() => controlScope = value),
                ),
                FilledButton(
                  onPressed: () => widget.controller.createMcpKey(
                    mcpLabelController.text.trim(),
                    ['vehicle:read', if (controlScope) 'vehicle:control'],
                  ),
                  child: const Text('Create MCP key'),
                ),
                const SizedBox(height: 16),
                for (final key in keys) ...[
                  ListTile(
                    title: Text(key.label),
                    subtitle: Text(
                      [
                        key.createdAt,
                        if (key.lastUsedAt != null)
                          'last used ${key.lastUsedAt}',
                        key.scopes.join(', '),
                      ].join(' • '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (key.key != null)
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Copy Key',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: key.key!),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'MCP Key copied to clipboard.',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        if (key.revokedAt == null)
                          TextButton(
                            onPressed: () =>
                                widget.controller.revokeMcpKey(key.id),
                            child: const Text('Revoke'),
                          )
                        else
                          const Text(
                            'Revoked',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final AppController controller;

  static bool _canSyncCars(String status) =>
      status == 'ready_to_sync' || status == 'synced';

  static String _statusLabel(String status, bool hasVehicles) {
    switch (status) {
      case 'synced':
        return 'ready';
      case 'ready_to_sync':
        return 'sync pending';
      case 'otp_requested':
        return 'otp pending';
      case 'connected':
        return 'pin setup';
      case 'credentials_saved':
        return 'auth required';
      case 'reauth_required':
        return 'reconnect';
      case 'degraded':
        return hasVehicles ? 'stale data' : 'attention';
      default:
        return 'setup';
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'synced':
        return const Color(0xFFD8E9DE);
      case 'reauth_required':
      case 'degraded':
        return const Color(0xFFFFE7D8);
      default:
        return const Color(0xFFE2D5C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupStatus = controller.setupState?.status ?? 'not_started';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFF1E8DA),
        border: Border.all(color: const Color(0xFFD9CCB7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final lastVehicleSyncAt = controller.setupState?.lastVehicleSyncAt;
          String lastCarSyncLabel = 'Last car sync: --';
          if (lastVehicleSyncAt != null) {
            final parsed = DateTime.tryParse(lastVehicleSyncAt);
            if (parsed != null) {
              final text = parsed
                  .toLocal()
                  .toIso8601String()
                  .replaceFirst('T', ' ')
                  .split('.')
                  .first;
              lastCarSyncLabel = 'Last car sync: $text';
            }
          }
          final info = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PSA Controller',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _statusColor(setupStatus),
                ),
                child: Text(
                  _statusLabel(setupStatus, controller.vehicles.isNotEmpty),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                lastCarSyncLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5E5A54),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFE0D4C1),
                ),
                child: Text(controller.session?.userEmail ?? ''),
              ),
              FilledButton.tonal(
                onPressed: controller.loading
                    ? null
                    : controller.refreshDashboard,
                child: const Text('Refresh'),
              ),
              FilledButton.tonal(
                onPressed: controller.loading || !_canSyncCars(setupStatus)
                    ? null
                    : controller.syncVehicles,
                child: const Text('Sync cars'),
              ),
              TextButton(
                onPressed: controller.loading ? null : controller.logout,
                child: const Text('Logout'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 10), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardTabBar extends StatelessWidget {
  const _DashboardTabBar({
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFF0E8DB),
        border: Border.all(color: const Color(0xFFD8CDBD)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var tabIndex = 0; tabIndex < tabs.length; tabIndex++) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: tabIndex == index
                      ? const Color(0xFF1F3D33)
                      : Colors.transparent,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(tabIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      tabs[tabIndex],
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: tabIndex == index
                            ? Colors.white
                            : const Color(0xFF5D584F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupStepper extends StatelessWidget {
  const _SetupStepper({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    const steps = ['Account', 'Auth', 'SMS', 'PIN', 'Sync'];
    return Row(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index <= stepIndex
                  ? const Color(0xFF1F3D33)
                  : const Color(0xFFE6DDCF),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: index <= stepIndex
                    ? Colors.white
                    : const Color(0xFF776F63),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (index < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: index < stepIndex
                    ? const Color(0xFF1F3D33)
                    : const Color(0xFFDACEBC),
              ),
            ),
        ],
      ],
    );
  }
}

class _SetupStatusPanel extends StatelessWidget {
  const _SetupStatusPanel({required this.stepIndex, required this.setupState});

  final int stepIndex;
  final SetupState? setupState;

  @override
  Widget build(BuildContext context) {
    final status = setupState?.status ?? 'not_started';
    final notes = <String>[
      'Saved credentials and region',
      'Requires PSA auth handoff',
      'SMS verification pending',
      'Vehicle PIN confirmation pending',
      'Ready to sync vehicles',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Setup status', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: setupState?.isDegraded == true
                ? const Color(0xFFFFE7D8)
                : const Color(0xFFE8F0E7),
          ),
          child: Text(status),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setupState?.syncMessage ?? 'Waiting for account details.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 18),
                for (var index = 0; index < notes.length; index++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= stepIndex
                              ? const Color(0xFF1F3D33)
                              : const Color(0xFFD8CDBD),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notes[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isError ? const Color(0xFFFFE2DE) : const Color(0xFFE4F1E7),
      ),
      child: Text(message),
    );
  }
}

class _SetupAnimation extends StatefulWidget {
  const _SetupAnimation({required this.stepIndex, required this.setupState});

  final int stepIndex;
  final SetupState? setupState;

  @override
  State<_SetupAnimation> createState() => _SetupAnimationState();
}

class _SetupAnimationState extends State<_SetupAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection pulse',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: SetupPulsePainter(
                  progress: animationController.value,
                  stepIndex: widget.stepIndex,
                ),
                child: Container(),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.setupState?.status ?? 'not_started'),
            const SizedBox(height: 8),
            Text(
              widget.setupState?.syncMessage ??
                  'Waiting for the next setup step.',
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(subtitle),
          const Spacer(),
          FilledButton(onPressed: onPressed, child: const Text('Run')),
        ],
      ),
    );
  }
}

class SetupPulsePainter extends CustomPainter {
  SetupPulsePainter({required this.progress, required this.stepIndex});

  final double progress;
  final int stepIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < 4; i++) {
      final radius = 26 + (i * 28) + (progress * 16);
      basePaint.color = const Color(
        0xFF275F49,
      ).withValues(alpha: math.max(0.08, 0.35 - i * 0.08));
      canvas.drawCircle(center, radius, basePaint);
    }

    final nodePaint = Paint()..color = const Color(0xFFB98A3B);
    for (var i = 0; i < 5; i++) {
      final angle = (-math.pi / 2) + (i * (math.pi / 4));
      final offset = Offset(
        center.dx + math.cos(angle) * 78,
        center.dy + math.sin(angle) * 78,
      );
      nodePaint.color = i <= stepIndex
          ? const Color(0xFFB98A3B)
          : const Color(0xFFD9D0C4);
      canvas.drawCircle(offset, 12, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant SetupPulsePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        stepIndex != oldDelegate.stepIndex;
  }
}

class RoutePainter extends CustomPainter {
  RoutePainter({required this.points});

  final List<PositionPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    final lats = points.map((point) => point.latitude!).toList();
    final lngs = points.map((point) => point.longitude!).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);

    Offset normalize(PositionPoint point) {
      final x =
          ((point.longitude! - minLng) / math.max(0.0001, maxLng - minLng)) *
              (size.width - 40) +
          20;
      final y =
          ((point.latitude! - minLat) / math.max(0.0001, maxLat - minLat)) *
              (size.height - 40) +
          20;
      return Offset(x, size.height - y);
    }

    final path = Path();
    path.moveTo(normalize(points.first).dx, normalize(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = normalize(point);
      path.lineTo(offset.dx, offset.dy);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF275F49);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFFB98A3B);
    for (final point in points) {
      final offset = normalize(point);
      canvas.drawCircle(offset, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
