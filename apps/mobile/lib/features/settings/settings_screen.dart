import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/alert_sound.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/telemetry.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_card.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/avatar.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../feedback/send_feedback_sheet.dart";
import "../install/install.dart";
import "../support/support_sheet.dart";

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _name;
  String? _photoUrl;
  bool _shareUsage = Telemetry.enabled;
  bool _soundOn = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSound();
  }

  Future<void> _loadSound() async {
    final stored = await ref.read(secureStorageProvider).readString(alertSoundStorageKey);
    if (mounted) setState(() => _soundOn = stored != "off");
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(apiClientProvider).get("/api/profile/me") as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name = profile["displayName"] as String?;
        _photoUrl = profile["profilePhotoUrl"] as String?;
      });
    } on ApiException {
      // The header just falls back to a generic avatar.
    }
  }

  Future<void> _editProfile() async {
    await context.push("/profile-setup");
    if (mounted) _loadProfile();
  }

  Future<void> _logOut() async {
    final confirmed = await confirmAction(
      context,
      title: "Log out?",
      message: "You'll need a fresh email code to sign back in.",
      confirmLabel: "Log out",
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go("/");
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final installKind = ref.watch(installKindProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      title: "Settings",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            onTap: _editProfile,
            child: Row(
              children: [
                AppAvatar(imageUrl: _photoUrl, name: _name, radius: 30),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name ?? "Your profile", style: textTheme.titleLarge),
                      Text("Edit profile", style: textTheme.bodyMedium?.copyWith(color: scheme.primary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SectionHeader("Notifications"),
          _Group(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text("Notification sound"),
                subtitle: const Text("A short sound when a match, like or message comes in while the app is open."),
                value: _soundOn,
                onChanged: (value) async {
                  setState(() => _soundOn = value);
                  await ref.read(secureStorageProvider).writeString(alertSoundStorageKey, value ? "on" : "off");
                  if (value) ref.read(alertSoundPlayerProvider)();
                },
              ),
            ],
          ),
          const SectionHeader("Rides and safety"),
          _Group(
            children: [
              _Row(icon: Icons.block, title: "Blocked users", onTap: () => _showBlockedUsers(context, api)),
            ],
          ),
          const SectionHeader("Help us improve"),
          _Group(
            children: [
              _Row(
                icon: Icons.forum_outlined,
                title: "Send feedback",
                onTap: () => showSendFeedbackSheet(context, api),
              ),
              _Row(icon: Icons.support_agent, title: "Contact support", onTap: () => showSupportSheet(context)),
            ],
          ),
          const SectionHeader("About"),
          _Group(
            children: [
              if (installKind != InstallKind.none)
                _Row(
                  icon: Icons.install_mobile_outlined,
                  title: "Add to home screen",
                  onTap: () => startInstall(context, installKind),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.insights_outlined),
                title: const Text("Share anonymous usage data"),
                subtitle: const Text(
                  "Crash reports and when the app is opened. Never your name, email, phone or messages.",
                ),
                value: _shareUsage,
                onChanged: (value) async {
                  setState(() => _shareUsage = value);
                  await Telemetry.setEnabled(value);
                },
              ),
              _Row(
                icon: Icons.privacy_tip_outlined,
                title: "Privacy policy",
                onTap: () => context.push("/privacy"),
              ),
              _Row(
                icon: Icons.description_outlined,
                title: "Terms of service",
                onTap: () => context.push("/terms"),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(label: "Log out", icon: Icons.logout, onPressed: _logOut),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_outline),
            label: const Text("Delete account"),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await confirmAction(
      context,
      title: "Delete your account?",
      message:
          "This permanently deletes your profile, photo, matches, chats, ratings and feedback. "
          "Anyone you're matched with loses that match. This can't be undone.",
      confirmLabel: "Delete account",
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(apiClientProvider).delete("/api/account");
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
      return;
    }
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go("/");
  }

  void _showBlockedUsers(BuildContext context, ApiClient api) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BlockedUsersSheet(api: api),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _BlockedUsersSheet extends StatefulWidget {
  const _BlockedUsersSheet({required this.api});

  final ApiClient api;

  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _blocks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.get("/api/blocks/mine") as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _blocks = (result["blocks"] as List).cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(Map<String, dynamic> block) async {
    final name = block["blockedDisplayName"] as String? ?? "this person";
    final confirmed = await confirmAction(
      context,
      title: "Unblock $name?",
      message: "They'll be able to show up as a possible match for you again.",
      confirmLabel: "Unblock",
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.api.delete("/api/blocks/${block["id"]}");
      if (!mounted) return;
      setState(() => _blocks.removeWhere((b) => b["id"] == block["id"]));
      showAppSnack(context, "Unblocked $name.");
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Widget content;
    if (_loading) {
      content = const SizedBox(height: 180, child: LoadingView());
    } else if (_error != null) {
      content = SizedBox(height: 300, child: ErrorState(message: _error, onRetry: _load));
    } else if (_blocks.isEmpty) {
      content = const SizedBox(
        height: 300,
        child: EmptyState(
          icon: Icons.verified_user_outlined,
          title: "Nobody blocked",
          message: "People you block won't be matched with you again.",
        ),
      );
    } else {
      content = ListView.separated(
        shrinkWrap: true,
        itemCount: _blocks.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, i) {
          final block = _blocks[i];
          final name = block["blockedDisplayName"] as String? ?? "Unknown traveler";
          return ListTile(
            leading: AppAvatar(imageUrl: block["blockedPhotoUrl"] as String?, name: name, radius: 22),
            title: Text(name),
            trailing: TextButton(onPressed: () => _unblock(block), child: const Text("Unblock")),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Blocked users", style: textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Flexible(child: content),
        ],
      ),
    );
  }
}
