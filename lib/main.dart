import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import 'src/core/api_client.dart';
import 'src/core/staff_session.dart';

const _primary = Color(0xFFD97757);
const _bgDark = Color(0xFF1A1C1E);
const _success = Color(0xFF10B981);
const _gold = Color(0xFFB89A6A);
const _red = Color(0xFFB42318);

// Aliases for seamless integration
const _burgundy = _primary;
const _oxblood = Color(0xFF260A11);
const _charcoal = _bgDark;
const _ivory = Color(0xFFF9F7F2);
const _green = _success;

void main() => runApp(const ScannerApp());

class ScannerApp extends StatefulWidget {
  const ScannerApp({super.key});

  @override
  State<ScannerApp> createState() => _ScannerAppState();
}

class _ScannerAppState extends State<ScannerApp> {
  final _api = ApiClient();
  final _store = StaffSessionStore();
  StaffSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await _store.restore();
    if (session != null) {
      _api.setToken(session.token);
      try {
        final response = await _api.get('/mobile/staff/me');
        final user = Map<String, dynamic>.from(response['data'] as Map);
        _session = StaffSession(session.token, user);
        await _store.save(_session!);
      } catch (_) {
        await _store.clear();
        _api.setToken(null);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _signedIn(StaffSession session) async {
    _api.setToken(session.token);
    await _store.save(session);
    if (mounted) setState(() => _session = session);
  }

  Future<void> _signOut() async {
    try {
      await _api.post('/mobile/staff/logout');
    } catch (_) {
      // A local logout must still succeed if the device is offline.
    }
    _api.setToken(null);
    await _store.clear();
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TKTSAPP Scanner',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _loading
          ? const _BrandLoading()
          : _session == null
          ? StaffLoginScreen(api: _api, onSignedIn: _signedIn)
          : StaffShell(
              api: _api,
              session: _session!,
              onSignOut: _signOut,
              onSessionUpdated: _signedIn,
            ),
    ),
  );
}

ThemeData _theme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _primary,
    brightness: Brightness.light,
    surface: _ivory,
  ).copyWith(primary: _primary, secondary: _gold, onPrimary: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _ivory,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _ivory,
      foregroundColor: _charcoal,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFECE7E1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: _ivory,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x22A6492C)),
      ),
    ),
  );
}

class _BrandLoading extends StatelessWidget {
  const _BrandLoading();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: _oxblood,
    body: Center(child: _BrandMark(light: true, subtitle: 'SCANNER')),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.light = false, this.subtitle});
  final bool light;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = light ? _ivory : _charcoal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -2,
            ),
            children: const [
              TextSpan(text: 'TKTS'),
              TextSpan(
                text: '•',
                style: TextStyle(color: _gold),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              color: color.withValues(alpha: .64),
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({
    super.key,
    required this.api,
    required this.onSignedIn,
  });
  final ApiClient api;
  final Future<void> Function(StaffSession) onSignedIn;

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _working = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _working = true);
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/login',
        data: {
          'login': _email.text.trim().toLowerCase(),
          'password': _password.text,
          'device_name': 'TKTSAPP Scanner',
        },
      );
      if (!mounted) return;
      if (response['requires_two_factor'] == true) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TwoFactorScreen(
              api: widget.api,
              login: response,
              onSignedIn: widget.onSignedIn,
            ),
          ),
        );
        return;
      }
      await _complete(response);
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _complete(Map<String, dynamic> response) async {
    final token = response['access_token']?.toString();
    final rawUser = response['user'];
    if (token == null || rawUser is! Map)
      throw const ApiFailure('The server did not return a staff session.');
    await widget.onSignedIn(
      StaffSession(token, Map<String, dynamic>.from(rawUser)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 36),
                const _BrandMark(subtitle: 'SCANNER'),
                const SizedBox(height: 52),
                Text(
                  'Secure staff sign in',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'For organizers, administrators and event staff. Use your assigned work email.',
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Work email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) =>
                            value != null && value.contains('@')
                            ? null
                            : 'Enter your work email.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (value) => (value?.isNotEmpty ?? false)
                            ? null
                            : 'Enter your password.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _working ? null : _login,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: _burgundy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _working
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign in securely'),
                ),
                const SizedBox(height: 18),
                const _SecurityNote(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({
    super.key,
    required this.api,
    required this.login,
    required this.onSignedIn,
  });
  final ApiClient api;
  final Map<String, dynamic> login;
  final Future<void> Function(StaffSession) onSignedIn;
  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  bool _working = false;
  int _seconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else if (mounted)
        setState(() => _seconds--);
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 6 || _working) return;
    setState(() => _working = true);
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/two-factor/verify',
        data: {
          'challenge_token': widget.login['challenge_token'],
          'code': _code,
        },
      );
      final token = response['access_token']?.toString();
      final rawUser = response['user'];
      if (token == null || rawUser is! Map)
        throw const ApiFailure('The verification response was incomplete.');
      await widget.onSignedIn(
        StaffSession(token, Map<String, dynamic>.from(rawUser)),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiFailure catch (error) {
      for (final controller in _controllers) {
        controller.clear();
      }
      _focus.first.requestFocus();
      if (mounted) _message(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    try {
      final response = await widget.api.post(
        '/mobile/auth/staff/two-factor/resend',
        data: {'challenge_token': widget.login['challenge_token']},
      );
      _startTimer();
      if (mounted)
        _message(
          context,
          response['message']?.toString() ?? 'A new code was sent.',
        );
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.verified_user_outlined,
              size: 54,
              color: _burgundy,
            ),
            const SizedBox(height: 24),
            Text(
              'Verify it’s you',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.login['method'] == 'sms'
                  ? 'Enter the 6-digit code sent to ${widget.login['masked_destination'] ?? 'your phone'}.'
                  : 'Enter the current 6-digit code from your authenticator app.',
            ),
            const SizedBox(height: 34),
            Row(
              children: List.generate(
                6,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focus[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focus[index + 1].requestFocus();
                        }
                        if (_code.length == 6) _verify();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _working || _code.length != 6 ? null : _verify,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _burgundy,
              ),
              child: _working
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify and continue'),
            ),
            if (widget.login['method'] == 'sms') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _seconds == 0 ? _resend : null,
                child: Text(
                  _seconds == 0
                      ? 'Resend code'
                      : 'Resend available in ${_seconds}s',
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class StaffShell extends StatefulWidget {
  const StaffShell({
    super.key,
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onSessionUpdated,
  });
  final ApiClient api;
  final StaffSession session;
  final Future<void> Function() onSignOut;
  final Future<void> Function(StaffSession) onSessionUpdated;
  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      OverviewPage(api: widget.api, session: widget.session),
      EventsPage(api: widget.api, session: widget.session),
      if (widget.session.canScan)
        ScannerPage(api: widget.api, session: widget.session),
      if (widget.session.canManageTeam) TeamPage(api: widget.api),
      ProfilePage(
        api: widget.api,
        session: widget.session,
        onSignOut: widget.onSignOut,
        onSessionUpdated: widget.onSessionUpdated,
      ),
    ];
    final items = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Overview',
      ),
      const NavigationDestination(
        icon: Icon(Icons.event_note_outlined),
        selectedIcon: Icon(Icons.event_note_rounded),
        label: 'Events',
      ),
      if (widget.session.canScan)
        const NavigationDestination(
          icon: Icon(Icons.qr_code_scanner_outlined),
          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
          label: 'Scan',
        ),
      if (widget.session.canManageTeam)
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups_rounded),
          label: 'Team',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Account',
      ),
    ];
    if (_index >= pages.length) _index = 0;
    final scannerIndex = widget.session.canScan ? 2 : -1;
    final scannerIsOpen = _index == scannerIndex;
    return Scaffold(
      body: scannerIsOpen
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
            )
          : SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: pages[_index],
                ),
              ),
            ),
      bottomNavigationBar: scannerIsOpen
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: items,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0x24B89A6A),
            ),
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.api, required this.session});
  final ApiClient api;
  final StaffSession session;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: _greeting(session.user['name']?.toString()),
    subtitle: _roleLabel(session.role),
    child: FutureBuilder<Map<String, dynamic>>(
      future: api.get(
        session.isAdmin ? '/mobile/admin/dashboard' : '/mobile/staff/dashboard',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _Skeleton();
        if (snapshot.hasError)
          return _Retry(onRetry: () => (context as Element).markNeedsBuild());
        final data = Map<String, dynamic>.from(
          snapshot.data?['data'] as Map? ?? const {},
        );
        final rows = data.entries
            .where((entry) => entry.key != 'user' && entry.value != null)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SecurityBanner(role: session.role),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width > 640 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: rows
                  .map(
                    (row) => _Metric(label: row.key, value: _value(row.value)),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Today’s operating principle',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan only after selecting the right event and station. Every validation is checked live against the ticket, event and session rules.',
            ),
          ],
        );
      },
    ),
  );
}

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.api, required this.session});
  final ApiClient api;
  final StaffSession session;
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.api.get('/mobile/staff/events');
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Assigned events',
    subtitle: 'Only events your account is allowed to access.',
    action: IconButton(
      onPressed: () =>
          setState(() => _future = widget.api.get('/mobile/staff/events')),
      icon: const Icon(Icons.refresh_rounded),
    ),
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _Skeleton(count: 4);
        if (snapshot.hasError)
          return _Retry(
            onRetry: () => setState(
              () => _future = widget.api.get('/mobile/staff/events'),
            ),
          );
        final events = (snapshot.data?['data'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (events.isEmpty)
          return const _Empty(
            icon: Icons.event_busy_outlined,
            title: 'No event assignments',
            message:
                'An organizer owner can assign this account to its events.',
          );
        return Column(
          children: events
              .map(
                (event) => _EventCard(
                  api: widget.api,
                  event: event,
                  session: widget.session,
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.api,
    required this.event,
    required this.session,
  });
  final ApiClient api;
  final Map<String, dynamic> event;
  final StaffSession session;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              EventDetailPage(api: api, event: event, session: session),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0x12541627),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_rounded, color: _burgundy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name']?.toString() ?? 'Event',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event['venue']?['name'] ?? 'Venue TBA'} • ${_date(event['starts_at'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6E6863),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({
    super.key,
    required this.api,
    required this.event,
    required this.session,
  });
  final ApiClient api;
  final Map<String, dynamic> event;
  final StaffSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Event access')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: api.get('/mobile/staff/events/${event['id']}'),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Padding(
            padding: EdgeInsets.all(20),
            child: _Skeleton(count: 3),
          );
        if (snapshot.hasError)
          return const Center(
            child: _Empty(
              icon: Icons.lock_outline_rounded,
              title: 'Access unavailable',
              message: 'This event is no longer assigned to your account.',
            ),
          );
        final details = Map<String, dynamic>.from(
          snapshot.data?['data'] as Map? ?? event,
        );
        final permissions = Map<String, dynamic>.from(
          details['permissions'] as Map? ?? const {},
        );
        final sessions = details['sessions'] as List? ?? const [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              details['name']?.toString() ?? 'Event',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${details['venue']?['name'] ?? 'Venue TBA'} • ${_date(details['starts_at'])}',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: permissions.entries
                  .where((item) => item.value == true)
                  .map(
                    (item) =>
                        Chip(label: Text(item.key.toString().toUpperCase())),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sessions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ...sessions.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(item['name']?.toString() ?? 'Session'),
                  subtitle: Text(_date(item['starts_at'])),
                ),
              );
            }),
            if (details['analytics'] is Map) ...[
              const SizedBox(height: 18),
              const Text(
                'Attendance overview',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...Map<String, dynamic>.from(
                details['analytics'] as Map,
              ).entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key.replaceAll('_', ' ')),
                  trailing: Text(
                    _value(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.api, required this.session});
  final ApiClient api;
  final StaffSession session;
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _devices = const [];
  Map<String, dynamic>? _event;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _fallbackSession;
  Map<String, dynamic>? _device;
  String _action = 'checkin';
  bool _loading = true;
  bool _processing = false;
  bool _isScanning = false;

  List<Map<String, dynamic>> get _sessions {
    final raw = _event?['sessions'];
    final sessions = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    if (sessions.isNotEmpty) return sessions;
    final startsAt = _event?['starts_at']?.toString();
    return startsAt == null
        ? const []
        : [
            _fallbackSession ??= {
              'id': null,
              'name': 'Main session',
              'starts_at': startsAt,
            },
          ];
  }

  // Station is resolved automatically for the selected event/session.
  bool get _canStart => _event != null && _session != null;

  Map<String, dynamic>? get _selectedSessionValue {
    if (_session == null) return null;
    for (final item in _sessions) {
      if (item['id']?.toString() == _session!['id']?.toString() &&
          item['name']?.toString() == _session!['name']?.toString()) {
        return item;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final response = await widget.api.get('/mobile/staff/events');
      _events = (response['data'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      // A scanner must be deliberately scoped; never silently select an event.
      _event = null;
      _session = null;
      _fallbackSession = null;
      _device = null;
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDevices() async {
    if (_event == null) {
      _devices = const [];
      _device = null;
      return;
    }
    final response = await widget.api.get(
      '/mobile/staff/events/${_event!['id']}/scanners',
    );
    _devices = (response['data'] as List? ?? const [])
        .where(
          (item) =>
              item['active'] == true &&
              (_session == null ||
                  item['event_session_id']?.toString() ==
                      _session!['id']?.toString()),
        )
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    _device = _devices.isEmpty ? null : _devices.first;
  }

  Future<void> _chooseEvent(Map<String, dynamic>? value) async {
    if (value == null) return;
    if (_isScanning) await _camera.stop();
    setState(() {
      _event = value;
      _session = null;
      _fallbackSession = null;
      _device = null;
      _isScanning = false;
    });
    await _loadDevices();
  }

  Future<void> _chooseSession(Map<String, dynamic>? value) async {
    if (value == null) return;
    if (_isScanning) await _camera.stop();
    setState(() {
      _session = value;
      _device = null;
      _isScanning = false;
    });
    await _loadDevices();
  }

  Future<void> _startScanning() async {
    if (!_canStart) return;
    if (_device == null) {
      await _loadDevices();
      if (_device == null &&
          (widget.session.isAdmin ||
              widget.session.isOwner ||
              widget.session.role == 'manager')) {
        await _createStation();
      }
      if (_device == null) {
        if (mounted) {
          _message(
            context,
            'No active scanner station is assigned to this session.',
            error: true,
          );
        }
        return;
      }
    }
    setState(() => _isScanning = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await _camera.start();
  }

  String _sessionLabel(Map<String, dynamic> session) {
    final name = session['name']?.toString() ?? 'Session';
    final raw = session['starts_at']?.toString();
    final startsAt = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (startsAt == null) return name;
    final hour = startsAt.hour % 12 == 0 ? 12 : startsAt.hour % 12;
    final minute = startsAt.minute.toString().padLeft(2, '0');
    final period = startsAt.hour >= 12 ? 'PM' : 'AM';
    return '$name • ${startsAt.day}/${startsAt.month} $hour:$minute $period';
  }

  Future<void> _createStation() async {
    if (_event == null || _session == null) return;
    try {
      await widget.api.post(
        '/mobile/staff/events/${_event!['id']}/scanners',
        data: {'label': 'TKTSAPP Scanner', 'event_session_id': _session!['id']},
      );
      await _loadDevices();
      if (mounted) {
        setState(() {});
        _message(context, 'Scanner station is ready for this event.');
      }
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    }
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_processing ||
        _event == null ||
        _device == null ||
        capture.barcodes.isEmpty)
      return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    setState(() => _processing = true);
    await _camera.stop();
    try {
      final response = await widget.api.post(
        '/mobile/staff/events/${_event!['id']}/scan',
        data: {
          'scanner_device_id': _device!['id'],
          'action': _action,
          'qr_raw': value,
          'idempotency_key': const Uuid().v4(),
        },
      );
      if (!mounted) return;
      final result = Map<String, dynamic>.from(
        response['data'] as Map? ?? const {},
      );
      await _showResult(result);
    } on ApiFailure catch (error) {
      if (mounted) _message(context, error.message, error: true);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        await _camera.start();
      }
    }
  }

  Future<void> _showResult(Map<String, dynamic> result) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final valid = result['status'] == 'valid';
          final ticket = Map<String, dynamic>.from(
            result['ticket'] as Map? ?? const {},
          );
          return _ScanResultSheet(valid: valid, result: result, ticket: ticket);
        },
      );

  Future<void> _openSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: _ivory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33181416),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scanner settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Changing this pauses the camera so tickets cannot be scanned on the wrong session.',
                style: TextStyle(color: Color(0xFF6E6863)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Map<String, dynamic>>(
                key: ValueKey('scan-event-${_event?['id']}'),
                initialValue: _event,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _events
                    .map(
                      (event) => DropdownMenuItem(
                        value: event,
                        child: Text(
                          event['name']?.toString() ?? 'Event',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  await _chooseEvent(value);
                  setSheetState(() {});
                  if (mounted) {
                    setState(() {});
                    setSheetState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                key: ValueKey(
                  'scan-session-${_event?['id']}-${_session?['id']}',
                ),
                initialValue: _selectedSessionValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Date & time / session',
                ),
                hint: const Text('Choose the session you are working'),
                items: _sessions
                    .map(
                      (session) => DropdownMenuItem(
                        value: session,
                        child: Text(
                          _sessionLabel(session),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _event == null
                    ? null
                    : (value) async {
                        await _chooseSession(value);
                        setSheetState(() {});
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                key: ValueKey(
                  'scan-station-${_event?['id']}-${_device?['id']}',
                ),
                initialValue: _device,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Scanner station'),
                items: _devices
                    .map(
                      (device) => DropdownMenuItem(
                        value: device,
                        child: Text(
                          device['label']?.toString() ??
                              'Scanner ${device['id']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _session == null
                    ? null
                    : (value) {
                        setState(() => _device = value);
                        setSheetState(() {});
                      },
              ),
              if (_device == null && _event != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'No active station exists for this event.',
                  style: TextStyle(fontSize: 12, color: _red),
                ),
                if (widget.session.isAdmin ||
                    widget.session.isOwner ||
                    widget.session.role == 'manager')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        await _createStation();
                        setSheetState(() {});
                      },
                      child: const Text('Create station'),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Validation type',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'checkin',
                    icon: Icon(Icons.login_rounded),
                    label: Text('Entry'),
                  ),
                  ButtonSegment(
                    value: 'checkout',
                    icon: Icon(Icons.logout_rounded),
                    label: Text('Exit'),
                  ),
                  ButtonSegment(
                    value: 'validate',
                    icon: Icon(Icons.verified_outlined),
                    label: Text('Check only'),
                  ),
                ],
                selected: {_action},
                onSelectionChanged: (value) {
                  setState(() => _action = value.first);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: !_canStart
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        await _startScanning();
                      },
                child: const Text('Apply & resume camera'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _isScanning ? _charcoal : _ivory,
    body: !_isScanning
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 62,
                    color: _burgundy,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Set up your scanner',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.epilogue(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _charcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'First choose the exact event, date and session. Then choose what this scanner should do.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6E6863)),
                  ),
                  const SizedBox(height: 28),
                  _ScannerSetupSummary(
                    event: _event,
                    session: _session,
                    device: _device,
                    action: _action,
                    loading: _loading,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('scanner-settings'),
                    onPressed: _loading ? null : _openSettings,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Choose event & validation'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _canStart ? _startScanning : null,
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Open full-screen camera'),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              if (!_loading && _event != null && _device != null)
                MobileScanner(controller: _camera, onDetect: _detect)
              else
                const ColoredBox(color: _charcoal),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xAA000000),
                      Colors.transparent,
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live scanner',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Secure event validation',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            key: const Key('scanner-settings'),
                            tooltip: 'Scanner settings',
                            onPressed: _openSettings,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IgnorePointer(
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2.5),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ScannerStatus(
                        event: _event,
                        device: _device,
                        action: _action,
                        loading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
              if (_processing)
                const ColoredBox(
                  color: Color(0x99000000),
                  child: Center(child: CircularProgressIndicator(color: _gold)),
                ),
            ],
          ),
  );
}

class _ScannerSetupSummary extends StatelessWidget {
  const _ScannerSetupSummary({
    required this.event,
    required this.session,
    required this.device,
    required this.action,
    required this.loading,
  });
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? session;
  final Map<String, dynamic>? device;
  final String action;
  final bool loading;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: loading
          ? const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Loading your permitted events…'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _setupRow(
                  Icons.event_outlined,
                  'Event',
                  event?['name']?.toString() ?? 'Not selected',
                ),
                const Divider(height: 22),
                _setupRow(
                  Icons.schedule_rounded,
                  'Date & session',
                  session == null
                      ? 'Not selected'
                      : session!['name']?.toString() ?? 'Session',
                ),
                const Divider(height: 22),
                _setupRow(
                  Icons.verified_user_outlined,
                  'Validation',
                  action == 'checkin'
                      ? 'Entry — validate and check in'
                      : action == 'checkout'
                      ? 'Exit — check out'
                      : 'Check only — no attendance change',
                ),
                if (device != null) ...[
                  const Divider(height: 22),
                  _setupRow(
                    Icons.sensors_rounded,
                    'Station',
                    device!['label']?.toString() ?? 'Scanner station',
                  ),
                ],
              ],
            ),
    ),
  );

  Widget _setupRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 20, color: _burgundy),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6E6863)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ScannerStatus extends StatelessWidget {
  const _ScannerStatus({
    required this.event,
    required this.device,
    required this.action,
    required this.loading,
  });
  final Map<String, dynamic>? event;
  final Map<String, dynamic>? device;
  final String action;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xCC181416),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white24),
    ),
    child: loading
        ? const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
              ),
              SizedBox(width: 12),
              Text(
                'Loading scanner access…',
                style: TextStyle(color: Colors.white),
              ),
            ],
          )
        : event == null || device == null
        ? const Text(
            'Tap settings to select an event and scanner station.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event!['name']?.toString() ?? 'Event',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${device!['label'] ?? 'Scanner station'} • ${action == 'checkin'
                    ? 'Entry'
                    : action == 'checkout'
                    ? 'Exit'
                    : 'Validate'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
  );
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({
    required this.valid,
    required this.result,
    required this.ticket,
  });
  final bool valid;
  final Map<String, dynamic> result;
  final Map<String, dynamic> ticket;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
    decoration: const BoxDecoration(
      color: _ivory,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x33181416),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            child: Icon(
              valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: valid ? _green : _red,
              size: 62,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            valid ? 'Entry approved' : _sentence(result['status']),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            result['message']?.toString() ??
                (valid
                    ? 'This ticket is valid for the selected event and station.'
                    : 'The ticket cannot be accepted at this time.'),
            textAlign: TextAlign.center,
          ),
          if (ticket.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _ResultLine(
                    'Holder',
                    ticket['recipient_name']?.toString() ?? 'Ticket holder',
                  ),
                  _ResultLine(
                    'Ticket',
                    ticket['ticket_type']?['name']?.toString() ?? 'Ticket',
                  ),
                  _ResultLine(
                    'Gate',
                    ticket['ticket_type']?['gate_label']?.toString() ??
                        'Gate TBA',
                  ),
                  if (ticket['session'] != null)
                    _ResultLine(
                      'Session',
                      ticket['session']?['name']?.toString() ?? 'Session',
                    ),
                  if (ticket['seat_label'] != null)
                    _ResultLine('Seat', ticket['seat_label'].toString()),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: valid ? _green : _charcoal,
            ),
            child: const Text('Scan next ticket'),
          ),
        ],
      ),
    ),
  );
}

class _ResultLine extends StatelessWidget {
  const _ResultLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF6E6863))),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.api.get('/mobile/staff/team');
  }

  void _reload() =>
      setState(() => _future = widget.api.get('/mobile/staff/team'));
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Event team',
    subtitle:
        'Create staff accounts and grant only the event access they need.',
    action: IconButton(
      onPressed: _reload,
      icon: const Icon(Icons.refresh_rounded),
    ),
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _Skeleton(count: 3);
        if (snapshot.hasError) return _Retry(onRetry: _reload);
        final members = (snapshot.data?['data'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CreateStaffPage(api: widget.api),
                  ),
                );
                if (changed == true) _reload();
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create staff account'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),
            if (members.isEmpty)
              const _Empty(
                icon: Icons.groups_outlined,
                title: 'No staff accounts yet',
                message:
                    'Add a manager, analyst or scanner and assign their exact event access.',
              ),
            ...members.map(
              (member) => _StaffMemberCard(
                member: member,
                api: widget.api,
                onChanged: _reload,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _StaffMemberCard extends StatelessWidget {
  const _StaffMemberCard({
    required this.member,
    required this.api,
    required this.onChanged,
  });
  final Map<String, dynamic> member;
  final ApiClient api;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(member['user'] as Map? ?? const {});
    final events = member['events'] as List? ?? const [];
    final active = member['active'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0x12541627),
                  foregroundColor: _burgundy,
                  child: Text(
                    (user['name']?.toString() ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name']?.toString() ?? 'Staff member',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        user['email']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6863),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  onChanged: (_) async {
                    try {
                      await api.post(
                        '/mobile/staff/team/${member['id']}/toggle',
                      );
                      onChanged();
                    } on ApiFailure catch (e) {
                      if (context.mounted)
                        _message(context, e.message, error: true);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    member['role']?.toString().toUpperCase() ?? 'STAFF',
                  ),
                ),
                Chip(
                  label: Text(
                    '${events.length} assigned event${events.length == 1 ? '' : 's'}',
                  ),
                ),
                if (!active) const Chip(label: Text('PAUSED')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CreateStaffPage extends StatefulWidget {
  const CreateStaffPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<CreateStaffPage> createState() => _CreateStaffPageState();
}

class _CreateStaffPageState extends State<CreateStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  List<Map<String, dynamic>> _events = const [];
  final Set<int> _selected = {};
  String _role = 'scanner';
  bool _loading = true;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await widget.api.get('/mobile/staff/events');
      _events = (response['data'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on ApiFailure catch (e) {
      if (mounted) _message(context, e.message, error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _selected.isEmpty) {
      if (_selected.isEmpty)
        _message(context, 'Assign at least one event.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.post(
        '/mobile/staff/team',
        data: {
          'name': _name.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'password': _password.text,
          'staff_role': _role,
          'event_ids': _selected.toList(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (mounted) _message(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create staff account')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'A staff member can only access the events selected below. Scanner accounts cannot see financial data or buyer contact details.',
                  style: TextStyle(color: Color(0xFF6E6863)),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Enter a name.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Work email',
                        ),
                        validator: (v) => v != null && v.contains('@')
                            ? null
                            : 'Enter a valid email.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporary password',
                        ),
                        validator: (v) => (v?.length ?? 0) >= 8
                            ? null
                            : 'Use at least 8 characters.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: 'scanner',
                            child: Text('Scanner — scan only'),
                          ),
                          DropdownMenuItem(
                            value: 'analyst',
                            child: Text('Analyst — read-only analytics'),
                          ),
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('Manager — operations'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _role = v ?? 'scanner'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Event access',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ..._events.map((event) {
                  final id = event['id'] as int;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    onChanged: (checked) => setState(
                      () => checked == true
                          ? _selected.add(id)
                          : _selected.remove(id),
                    ),
                    title: Text(event['name']?.toString() ?? 'Event'),
                    subtitle: Text(_date(event['starts_at'])),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _burgundy,
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create staff account'),
                ),
              ],
            ),
          ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onSessionUpdated,
  });
  final ApiClient api;
  final StaffSession session;
  final Future<void> Function() onSignOut;
  final Future<void> Function(StaffSession) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    final method = session.user['two_factor_method']?.toString();
    final twoFactor = session.user['two_factor_enabled'] == true
        ? 'Enabled${method == null ? '' : ' ($method)'}'
        : 'Not enabled';
    return _PageFrame(
      title: 'Account',
      subtitle: 'Your secure TKTSAPP staff identity.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: _charcoal,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.user['name']?.toString() ?? 'Staff member',
                    style: const TextStyle(
                      color: _ivory,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.user['email']?.toString() ?? '',
                    style: const TextStyle(color: Color(0xBDF4EFE8)),
                  ),
                  const SizedBox(height: 14),
                  Chip(
                    label: Text(_roleLabel(session.role).toUpperCase()),
                    backgroundColor: _gold,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Two-factor authentication'),
                  subtitle: Text(twoFactor),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.lock_reset_rounded),
                  title: Text('Password and sessions'),
                  subtitle: Text('Manage this from the secure web dashboard'),
                  trailing: Icon(Icons.open_in_new_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: _red,
              side: const BorderSide(color: Color(0x33B42318)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _charcoal,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF6E6863)),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: _burgundy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label.replaceAll('_', ' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6E6863)),
          ),
        ],
      ),
    ),
  );
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0x14541627),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.shield_outlined, color: _burgundy),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'This workspace is scoped to your role and assigned events. Activity is logged for operational security.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFF6E6863)),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'Staff access is protected by event-level permissions and optional two-factor authentication.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6E6863)),
        ),
      ),
    ],
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      count,
      (index) => Container(
        height: 88,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0x0D181416),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _Empty(
    icon: Icons.wifi_off_rounded,
    title: 'Could not load this page',
    message: 'Check your internet connection and retry.',
    action: FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 42, color: _burgundy),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6E6863)),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

void _message(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _red : _charcoal,
        content: Text(message),
      ),
    );
String _greeting(String? name) {
  final first = (name ?? '').trim().split(' ').first;
  return first.isEmpty ? 'Welcome back' : 'Welcome, $first';
}

String _roleLabel(String role) => switch (role) {
  'super_admin' => 'Super admin',
  'admin' => 'Administrator',
  'organizer' => 'Organizer owner',
  'manager' => 'Organizer manager',
  'analyst' => 'Analytics',
  'scanner' => 'Scanner staff',
  _ => 'Staff workspace',
};
String _value(Object? value) => value is num
    ? (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2))
    : value?.toString() ?? '—';
String _date(Object? raw) {
  if (raw == null) return 'Date TBA';
  final value = DateTime.tryParse(raw.toString());
  if (value == null) return raw.toString();
  return '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} • ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
String _sentence(Object? value) => (value?.toString() ?? 'Scan declined')
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
