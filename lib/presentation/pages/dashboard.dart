import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/auth_user.dart';
import 'package:access_app/presentation/pages/login_page.dart';
import 'package:access_app/presentation/pages/logs_page.dart';
import 'package:access_app/presentation/pages/reports.dart';
import 'package:access_app/presentation/pages/settings.dart';
import 'package:access_app/presentation/pages/users_dashboard.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  final AuthSession session;

  const DashboardPage({super.key, required this.session});

  static MaterialPageRoute<dynamic> route({required AuthSession session}) {
    return MaterialPageRoute(
      builder: (context) => DashboardPage(session: session),
    );
  }

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _updatedDisplayName;

  static const List<_DashboardAction> _actions = [
    _DashboardAction.navigate(
      title: 'Users',
      subtitle: 'User and role management',
      destination: _DashboardDestination.users,
      icon: Icons.people_outline,
    ),
    _DashboardAction.navigate(
      title: 'Reports',
      subtitle: 'Read and export reports',
      destination: _DashboardDestination.reports,
      icon: Icons.insert_chart_outlined,
    ),
    _DashboardAction.navigate(
      title: 'Settings',
      subtitle: 'Profile and account settings',
      destination: _DashboardDestination.settings,
      icon: Icons.settings_outlined,
    ),
    _DashboardAction.navigate(
      title: 'Logs',
      subtitle: 'Review logs',
      destination: _DashboardDestination.logs,
      icon: Icons.history_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final displayName = _updatedDisplayName?.trim().isNotEmpty == true
        ? _updatedDisplayName!.trim()
        : user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email ?? 'Unknown user';
    final hasUsersDashboardAccess =
        user.hasPermission('users', 'read') ||
        user.hasPermission('users', 'create') ||
        user.hasPermission('users', 'edit') ||
        user.hasPermission('users', 'delete') ||
        user.hasPermission('roles', 'manage');
    final hasReportsAccess =
        user.hasPermission('reports', 'read') ||
        user.hasPermission('reports', 'export');
    final visibleActions = _actions
        .where((action) => _canAccessAction(user, action))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (hasUsersDashboardAccess)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  UsersDashboardPage.route(session: widget.session),
                );
              },
              icon: const Icon(Icons.people_outline),
              tooltip: 'Users Dashboard',
            ),
          if (hasReportsAccess)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  ReportsPage.route(session: widget.session),
                );
              },
              icon: const Icon(Icons.insert_chart_outlined),
              tooltip: 'Reports',
            ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                UserSettingsPage.route(
                  session: widget.session,
                  onDisplayNameUpdated: _handleDisplayNameUpdated,
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'User Settings',
          ),
          IconButton(
            onPressed: () async {
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  LoginPage.route(),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $displayName',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: visibleActions.isEmpty
                    ? const Center(
                        child: Text('No actions available for your role.'),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 720;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isNarrow ? 1 : 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: isNarrow ? 2.0 : 1.45,
                                ),
                            itemCount: visibleActions.length,
                            itemBuilder: (context, index) {
                              final action = visibleActions[index];

                              return _ActionCard(
                                action: action,
                                onPressed: () =>
                                    _openDestination(action.destination),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canAccessAction(AuthUser user, _DashboardAction action) {
    switch (action.destination) {
      case _DashboardDestination.users:
        return user.hasPermission('users', 'read') ||
            user.hasPermission('users', 'create') ||
            user.hasPermission('users', 'edit') ||
            user.hasPermission('users', 'delete') ||
            user.hasPermission('roles', 'manage');
      case _DashboardDestination.reports:
        return user.hasPermission('reports', 'read') ||
            user.hasPermission('reports', 'export');
      case _DashboardDestination.settings:
        return true;
      case _DashboardDestination.logs:
        final role = user.role.trim().toLowerCase();
        return role == 'admin' || role == 'manager';
    }
  }

  void _openDestination(_DashboardDestination destination) {
    switch (destination) {
      case _DashboardDestination.users:
        Navigator.push(
          context,
          UsersDashboardPage.route(session: widget.session),
        );
        break;
      case _DashboardDestination.reports:
        Navigator.push(context, ReportsPage.route(session: widget.session));
        break;
      case _DashboardDestination.settings:
        Navigator.push(
          context,
          UserSettingsPage.route(
            session: widget.session,
            onDisplayNameUpdated: _handleDisplayNameUpdated,
          ),
        );
        break;
      case _DashboardDestination.logs:
        Navigator.push(context, LogsPage.route(session: widget.session));
        break;
    }
  }

  void _handleDisplayNameUpdated(String newDisplayName) {
    setState(() {
      _updatedDisplayName = newDisplayName;
    });
  }
}

enum _DashboardDestination { users, reports, settings, logs }

class _DashboardAction {
  final String title;
  final String subtitle;
  final _DashboardDestination destination;
  final IconData icon;

  const _DashboardAction.navigate({
    required this.title,
    required this.subtitle,
    required this.destination,
    required this.icon,
  });
}

class _ActionCard extends StatelessWidget {
  final _DashboardAction action;
  final VoidCallback? onPressed;

  const _ActionCard({required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(action.icon),
                  const SizedBox(height: 8),
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onPressed,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
