import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/state.dart';
import '../core/updates.dart';
import 'design.dart';

class AuthPage extends StatefulWidget {
  final RyhzeState state;
  final bool activation;
  final ValueChanged<String> onNavigate;
  const AuthPage({
    super.key,
    required this.state,
    required this.activation,
    required this.onNavigate,
  });
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(),
      password = TextEditingController(),
      invitation = TextEditingController();
  bool remember = true, visible = false, busy = false, done = false;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    invitation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.activation) {
        final input = invitation.text.trim();
        final url = Uri.tryParse(input);
        final token =
            url != null && url.host == 'ryhze.com' && url.path == '/activate'
            ? url.fragment
            : input;
        if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
          throw Exception(
            'Use the full invitation link from your administrator.',
          );
        }
        await widget.state.api.request(
          '/api/activate',
          body: {'token': token, 'password': password.text},
        );
        if (!mounted) return;
        password.clear();
        invitation.clear();
        if (mounted) setState(() => done = true);
      } else {
        await widget.state.login(username.text, password.text, remember);
        if (!mounted) return;
        password.clear();
        if (mounted) widget.onNavigate('games');
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final mobile = width <= 700;
      final panel = Glass(
        radius: surfaceRadius,
        padding: EdgeInsets.all(
          mobile
              ? 26
              : width <= 1000
              ? 28
              : 36,
        ),
        child: AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  widget.activation ? 'An invitation to Ryhze' : 'Welcome back',
                ),
                const SizedBox(height: 20),
                Text(
                  done
                      ? 'You’re all set.'
                      : widget.activation
                      ? 'Set your password.'
                      : 'Sign in.',
                  style: heading(36).copyWith(height: 1.1),
                ),
                const SizedBox(height: 28),
                if (done) ...[
                  const Text('Your password is ready. Sign in to continue.'),
                  const SizedBox(height: 20),
                  Pill(
                    'Continue to sign in',
                    primary: true,
                    onPressed: () => widget.onNavigate('login'),
                  ),
                ] else ...[
                  if (widget.activation)
                    TextFormField(
                      controller: invitation,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Invitation link',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Enter your invitation link.'
                          : null,
                    )
                  else
                    TextFormField(
                      controller: username,
                      autofillHints: const [AutofillHints.username],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        counterText: '',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter your user ID.'
                          : null,
                    ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: password,
                    obscureText: !visible,
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLength: 256,
                    autofillHints: [
                      widget.activation
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!busy) submit();
                    },
                    decoration: InputDecoration(
                      labelText: widget.activation
                          ? 'New password'
                          : 'Password',
                      counterText: '',
                      suffixIcon: IconButton(
                        tooltip: visible ? 'Hide password' : 'Show password',
                        onPressed: () => setState(() => visible = !visible),
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Enter your password.'
                        : widget.activation && v.length < 12
                        ? 'Use at least 12 characters.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (!widget.activation)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: remember,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Remember me for 30 days',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (v) => setState(() => remember = v ?? false),
                    )
                  else
                    const Text(
                      'Use at least 12 characters. Your invitation works once.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xffffb4bb),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Pill(
                      busy
                          ? 'One moment…'
                          : widget.activation
                          ? 'Set password'
                          : 'Sign in',
                      primary: true,
                      icon: Icons.arrow_forward,
                      onPressed: busy ? null : submit,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!widget.activation) ...[
                    const Text(
                      'Access is currently by invitation. For help, contact support@ryhze.com.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigate('activate'),
                      child: const Text(
                        'I have an invitation',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                const Text(
                  'Your session is protected by your device’s secure storage when you choose Remember me.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate('privacy'),
                  child: const Text('Privacy', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      );
      final intro = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Your space in Ryhze'),
          const SizedBox(height: 24),
          Text(
            'Make yourself\nat home.',
            style: heading(
              mobile
                  ? 48
                  : width <= 1000
                  ? 52
                  : (width * .06).clamp(46, 90),
            ).copyWith(height: 1.01),
          ),
          const SizedBox(height: 24),
          const Text('Stories to discover. Worlds to return to.'),
        ],
      );
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 22 : (width * .045).clamp(20, 88),
          vertical: mobile ? 45 : 70,
        ),
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.65, .1),
            radius: 1.1,
            colors: [Color(0x335500ff), canvas],
          ),
        ),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  intro,
                  const SizedBox(height: 30),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: panel,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: intro),
                  SizedBox(width: width <= 1000 ? 30 : width * .08),
                  SizedBox(width: width <= 1000 ? 390 : 440, child: panel),
                ],
              ),
      );
    },
  );
}

class EditorialPage extends StatelessWidget {
  final String page;
  final ValueChanged<String> navigate;
  const EditorialPage({super.key, required this.page, required this.navigate});
  Future<void> email(BuildContext context, String value) async {
    if (!await launchUrl(Uri(scheme: 'mailto', path: value)) &&
        context.mounted) {
      toast(context, 'Open your email app and write to $value.');
    }
  }

  Widget section(String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: heading(30)),
        const SizedBox(height: 16),
        Text(body),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width <= 700
          ? 22
          : (MediaQuery.sizeOf(context).width * .045).clamp(20, 88),
      vertical: MediaQuery.sizeOf(context).width <= 700 ? 60 : 80,
    ),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(
            page == 'about'
                ? 'Meet Ryhze'
                : page == 'contact'
                ? 'Start a conversation'
                : 'Your privacy',
          ),
          const SizedBox(height: 24),
          Text(
            page == 'about'
                ? 'Stories to watch.\nWorlds to play.'
                : page == 'contact'
                ? 'Let’s make\nsomething matter.'
                : 'Clear by design.',
            style: heading(
              MediaQuery.sizeOf(context).width <= 700
                  ? 50
                  : (MediaQuery.sizeOf(context).width * .055).clamp(42, 88),
            ).copyWith(height: 1.01),
          ),
          const SizedBox(height: 28),
          if (page == 'about') ...[
            const Text(
              'Ryhze brings films and games together through one recognizable identity, with room for every production to find its own voice.',
            ),
            LayoutBuilder(
              builder: (context, box) {
                final mobile = MediaQuery.sizeOf(context).width <= 700;
                final gap = MediaQuery.sizeOf(context).width <= 1000
                    ? 24.0
                    : 40.0;
                final columnWidth = mobile
                    ? box.maxWidth
                    : (box.maxWidth - gap * 2) / 3;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: mobile ? 45 : 80),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: 25,
                    children: [
                      for (final item in [
                        (
                          '01 / Film',
                          'Ryhze Studio',
                          'Stories told through moving images. A production label for Ryhze?s films.',
                        ),
                        (
                          '02 / Series',
                          'Ryhze Television',
                          'Stories with room to unfold. A production label for Ryhze?s series.',
                        ),
                        (
                          '03 / Games',
                          'Ryhze Games',
                          'Worlds experienced through play. A production label for Ryhze?s games.',
                        ),
                      ])
                        SizedBox(
                          width: columnWidth,
                          child: Container(
                            padding: EdgeInsets.only(top: mobile ? 20 : 25),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x25ffffff)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow(item.$1),
                                const SizedBox(height: 20),
                                Text(
                                  item.$2,
                                  style: heading(
                                    mobile
                                        ? 28
                                        : MediaQuery.sizeOf(context).width <=
                                              1000
                                        ? 24
                                        : 28,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  item.$3,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.75,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width <= 700 ? 30 : 60,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(surfaceRadius),
                border: Border.all(color: const Color(0x20ffffff)),
                gradient: const RadialGradient(
                  center: Alignment(.6, -.2),
                  radius: 1.2,
                  colors: [Color(0xff401580), Color(0xff181021)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('One identity. Many worlds.'),
                  const SizedBox(height: 24),
                  Text(
                    'Entertainment\nhas no limits.',
                    style: heading(
                      (MediaQuery.sizeOf(context).width * .05).clamp(38, 76),
                    ).copyWith(height: 1.1),
                  ),
                  const SizedBox(height: 30),
                  Pill(
                    'Explore Ryhze',
                    primary: true,
                    icon: Icons.arrow_forward,
                    onPressed: () => navigate('games'),
                  ),
                ],
              ),
            ),
          ] else if (page == 'contact') ...[
            const Text('The right conversation starts with the right people.'),
            const SizedBox(height: 32),
            for (final item in [
              ('General enquiries', 'contact@ryhze.com'),
              ('Member support', 'support@ryhze.com'),
              ('Games & publishing', 'devs@ryhze.com'),
              ('Film & licensing', 'studios@ryhze.com'),
              ('Press & brand', 'press@ryhze.com'),
              ('Security', 'security@ryhze.com'),
            ])
              InkWell(
                onTap: () => attempt(context, () => email(context, item.$2)),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.sizeOf(context).width <= 700 ? 22 : 28,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x1affffff))),
                  ),
                  child: MediaQuery.sizeOf(context).width <= 700
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.$2,
                                    style: heading(20).copyWith(
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.$2,
                                style:
                                    heading(
                                      (MediaQuery.sizeOf(context).width * .02)
                                          .clamp(16, 26),
                                    ).copyWith(
                                      letterSpacing: 0,
                                      fontWeight: FontWeight.w400,
                                    ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
          ] else ...[
            const Text(
              'The information Ryhze uses to keep your account and experience working.',
            ),
            section(
              'Account access',
              'Membership is invitation-only. We store your user ID, a salted password hash, account status, and session records in Cloudflare D1. Administrators can issue invitations and disable accounts. Passwords are not stored as readable text.',
            ),
            section(
              'Your sign-in',
              'Sessions last 12 hours, or up to 30 days when you choose Remember me. Remembered session tokens are stored using your operating system’s secure storage. Signing out revokes that session. Your password is not saved by Ryhze.',
            ),
            section(
              'Your preferences',
              'Saved titles, watch history, game availability requests, motion, and sound preferences stay on this device. Saved titles and watch history are separated by user ID. They do not sync between devices. Clear watch history from Continue watching. Ryhze does not add advertising trackers or collect precise location data.',
            ),
            section(
              'Games and downloads',
              'On Windows, Ryhze checks Riot’s installation record and standard installation folder to find Riot Client. This information stays on your device. Game installers are saved to Downloads/Ryhze and opened only when you choose Open installer.',
            ),
            section(
              'Hosting and security',
              'Cloudflare hosts account data and private media. Login attempts are rate-limited. Expired sessions, invitation links, and rate-limit records are removed daily.',
            ),
            section(
              'Contact',
              'For account access, correction, or deletion requests, contact support@ryhze.com. Report security concerns to security@ryhze.com.',
            ),
            const SizedBox(height: 24),
            Pill(
              'Contact support',
              icon: Icons.mail_outline,
              onPressed: () =>
                  attempt(context, () => email(context, 'support@ryhze.com')),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Ryhze',
                applicationVersion: appVersion,
              ),
              child: const Text('Open-source licences'),
            ),
          ],
        ],
      ),
    ),
  );
}

class AdminPage extends StatefulWidget {
  final RyhzeState state;
  const AdminPage({super.key, required this.state});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final username = TextEditingController();
  List<dynamic> members = [];
  String? error, link;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.state.user?.role == 'admin') refresh();
  }

  @override
  void dispose() {
    username.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final list = await widget.state.api.request('/api/admin/users') as List;
      if (mounted) {
        setState(() {
          members = list;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> invite() async {
    if (!RegExp(r'^[\w.@+\-]{2,80}$').hasMatch(username.text.trim())) {
      setState(() => error = 'Use 2–80 letters, numbers, or email characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      link = null;
    });
    try {
      final result = await widget.state.api.request(
        '/api/admin/invite',
        body: {'username': username.text.trim()},
      );
      if (mounted) setState(() => link = result['url']);
      await refresh();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disable(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disable ${member['username']}?'),
        content: const Text(
          'Their active sessions will end and they will no longer be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable access'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await attempt(context, () async {
        await widget.state.api.request(
          '/api/admin/disable',
          body: {'id': member['id']},
        );
        await refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.user?.role != 'admin') {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Text('Administrator access required.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Your Ryhze community'),
          const SizedBox(height: 24),
          Text('Approved members.', style: heading(44)),
          const SizedBox(height: 32),
          Glass(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite a member', style: heading(28)),
                const SizedBox(height: 22),
                TextField(
                  controller: username,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'User ID'),
                ),
                const SizedBox(height: 16),
                Pill(
                  busy ? 'Creating…' : 'Create invitation',
                  primary: true,
                  onPressed: busy ? null : invite,
                ),
                const SizedBox(height: 16),
                const Text(
                  'An invitation lasts 24 hours. For an existing member, it lets them set a new password.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                if (link != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Share this link privately with the intended member.',
                  ),
                  SelectableText(link!, style: const TextStyle(fontSize: 12)),
                  TextButton(
                    onPressed: () => attempt(context, () async {
                      await Clipboard.setData(ClipboardData(text: link!));
                      if (context.mounted) toast(context, 'Invitation copied.');
                    }),
                    child: const Text('Copy invitation'),
                  ),
                ],
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xffffb4bb)),
              ),
            ),
          const SizedBox(height: 32),
          for (final member in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(member['username']),
              subtitle: Text(
                '${member['role']} · ${member['disabled'] == 1 ? 'Disabled' : 'Active'}',
              ),
              trailing:
                  member['disabled'] == 1 ||
                      member['username'] == widget.state.user?.username
                  ? null
                  : TextButton(
                      onPressed: () => disable(member),
                      child: const Text('Disable'),
                    ),
            ),
          TextButton(onPressed: refresh, child: const Text('Refresh members')),
        ],
      ),
    );
  }
}
