import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_texts.dart';
import '../providers/auth_provider.dart';
import '../theme/medi_go_theme.dart';
import 'advertisement_strip.dart';
import 'notification_bell.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';

/// Height of the advertisement strip shown at the bottom of dashboards.
const double kDashboardAdStripHeight = 92;

/// Consistent shell used by every role dashboard (doctor, patient, labo, pharmacy).
///
/// Provides a single, unified look:
///   * Same app bar (title/subtitle, notification bell, profile/refresh/logout)
///   * Same background, card spacing and bottom padding so content is never
///     hidden behind the advertisement strip
///   * Same advertisement strip at the bottom
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.extraActions,
    this.onRefresh,
    this.tabBar,
    this.toolbarHeight,
    required this.body,
    this.fab,
    this.placement,
  });

  /// Main dashboard title shown in the app bar.
  final String title;

  /// Optional subtitle shown under the title (e.g. the user's role).
  final String? subtitle;

  /// Optional custom app-bar actions. When provided, replaces the default
  /// profile/refresh/logout popup (the notification bell is always shown).
  final List<Widget>? actions;

  /// Extra app-bar actions appended after the standard ones.
  final List<Widget>? extraActions;

  /// Optional refresh callback wired to the default profile/refresh/logout popup.
  final VoidCallback? onRefresh;

  /// Optional tab bar shown under the app bar.
  final PreferredSizeWidget? tabBar;

  /// Optional toolbar height for dashboards whose app-bar content needs more
  /// room. Null keeps the Material default used by the other role dashboards.
  final double? toolbarHeight;

  /// The dashboard body content.
  final Widget body;

  /// Optional floating action button.
  final Widget? fab;

  /// Advertisement placement key (e.g. 'patient_dashboard').
  final String? placement;

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTexts.of(context, key);
    final auth = context.watch<AuthProvider>();
    final name = (auth.name ?? '').isNotEmpty ? auth.name! : t('dashboard');

    Widget defaultPopup = PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_rounded, size: 26),
      tooltip: t('dashboard_actions'),
      onSelected: (action) {
        if (action == 'logout') {
          _logout(context);
        } else if (action == 'refresh') {
          onRefresh?.call();
        } else if (action == 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
          );
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 10),
              Text(name.isEmpty ? t('profile') : name),
            ],
          ),
        ),
        if (onRefresh != null)
          PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                const Icon(Icons.refresh, size: 18),
                const SizedBox(width: 10),
                Text(t('refresh')),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18),
              const SizedBox(width: 10),
              Text(t('logout')),
            ],
          ),
        ),
      ],
    );

    final standardActions = <Widget>[
      const NotificationBell(iconColor: MediGoTheme.darkNavy),
      const SizedBox(width: 10),
      ...(actions ?? [defaultPopup]),
      if (extraActions != null) ...extraActions!,
    ];

    return SafeArea(
      bottom: false,
      child: Scaffold(
        backgroundColor: MediGoTheme.backgroundStart,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MediGoTheme.darkNavy,
                  letterSpacing: -0.4,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MediGoTheme.secondaryGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          backgroundColor: MediGoTheme.cardSurface,
          foregroundColor: MediGoTheme.darkNavy,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: MediGoTheme.darkNavy),
          toolbarHeight: toolbarHeight,
          bottom: tabBar,
          actions: standardActions,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: placement == null ? 16 : kDashboardAdStripHeight + 16,
            ),
            child: body,
          ),
        ),
        bottomNavigationBar: placement == null
            ? null
            : AdvertisementStrip(placement: placement!),
        floatingActionButton: fab,
      ),
    );
  }
}

class DashboardTabBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<Widget> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) => Container(
    height: preferredSize.height,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    color: MediGoTheme.cardSurface,
    child: TabBar(
      controller: controller,
      isScrollable: true,
      indicator: BoxDecoration(
        color: MediGoTheme.darkNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      labelColor: MediGoTheme.cardSurface,
      unselectedLabelColor: MediGoTheme.secondaryGrey,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      tabs: tabs,
    ),
  );
}

/// Consistent empty state used across dashboards.
class MediEmpty extends StatelessWidget {
  const MediEmpty({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: MediGoTheme.borderSoft),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MediGoTheme.secondaryGrey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent status chip used across dashboards.
class MediStatusChip extends StatelessWidget {
  const MediStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.toLowerCase()) {
      'completed' || 'dispensed' => (
        AppTexts.of(context, 'completed'),
        MediGoTheme.successGreen,
      ),
      'pending' => (AppTexts.of(context, 'pending'), MediGoTheme.warningOrange),
      _ => (status, MediGoTheme.secondaryGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Consistent section header used across dashboards.
class MediSectionHeader extends StatelessWidget {
  const MediSectionHeader({super.key, required this.title, this.action});

  final String title;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: MediGoTheme.darkNavy,
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(
              foregroundColor: MediGoTheme.primaryBlue,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
      ],
    );
  }
}

/// Consistent stat chip used across dashboards.
class MediStatChip extends StatelessWidget {
  const MediStatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: MediGoTheme.cardSurface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
