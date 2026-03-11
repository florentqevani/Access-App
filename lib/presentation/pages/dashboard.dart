import 'package:access_app/core/network/auth_server_config.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/presentation/pages/login_page.dart';
import 'package:access_app/presentation/pages/reports.dart';
import 'package:access_app/presentation/pages/settings.dart';
import 'package:access_app/presentation/pages/users_dashboard.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final Dio _dio = Dio();
  String? _updatedDisplayName;

  static const List<_DashboardAction> _actions = [
    _DashboardAction.navigate(
      title: 'Users',
      subtitle: 'CRUD and role management',
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
    _DashboardAction.execute(
      title: 'Logs',
      subtitle: 'Review persisted logs',
      resource: 'audit_logs',
      action: 'view',
      icon: Icons.history_outlined,
    ),
  ];

  final List<_AuditLogEntry> _auditLogs = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  String? _runningActionKey;

  String get _authServerBaseUrl {
    const configuredAuthServerBaseUrl = String.fromEnvironment(
      'AUTH_SERVER_BASE_URL',
    );
    return resolveAuthServerBaseUrl(
      configuredBaseUrl: configuredAuthServerBaseUrl,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAuditHistory();
  }

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
    final canViewAuditLogs = user.hasPermission('audit_logs', 'view');
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
              try {
                await FirebaseAuth.instance.signOut();
              } finally {
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    LoginPage.route(),
                    (route) => false,
                  );
                }
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
              const SizedBox(height: 8),
              const Text(
                'Actions below open modules and run allowed operations.',
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 2,
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
                              final isRunning = _runningActionKey == action.key;

                              return _ActionCard(
                                action: action,
                                isRunning: isRunning,
                                onPressed: action.isNavigation
                                    ? () =>
                                          _openDestination(action.destination!)
                                    : (!isRunning
                                          ? () => _executeAction(action)
                                          : null),
                              );
                            },
                          );
                        },
                      ),
              ),
              if (canViewAuditLogs) const SizedBox(height: 12),
              if (canViewAuditLogs)
                Expanded(flex: 1, child: _buildAuditPanel(canViewAuditLogs)),
            ],
          ),
        ),
      ),
    );
  }

  bool _canAccessAction(dynamic user, _DashboardAction action) {
    if (action.isNavigation) {
      switch (action.destination!) {
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
      }
    }

    return user.hasPermission(action.resource!, action.action!);
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
    }
  }

  void _handleDisplayNameUpdated(String newDisplayName) {
    setState(() {
      _updatedDisplayName = newDisplayName;
    });
  }

  Widget _buildAuditPanel(bool canViewHistory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Logs',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: canViewHistory && !_isLoadingHistory
                      ? _loadAuditHistory
                      : null,
                  tooltip: 'Refresh history',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!canViewHistory) const SizedBox.shrink(),
            if (_historyError != null) ...[
              const SizedBox(height: 4),
              Text(
                _historyError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            if (_isLoadingHistory) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _auditLogs.isEmpty
                  ? const Center(child: Text('No logs yet.'))
                  : ListView.separated(
                      itemCount: _auditLogs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final log = _auditLogs[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(log.title),
                          subtitle: Text(
                            '${_formatTimestamp(log.createdAt)} • ip: ${log.ipAddress ?? '-'}',
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeAction(_DashboardAction action) async {
    final resource = action.resource;
    final actionName = action.action;
    if (resource == null || actionName == null) {
      return;
    }

    setState(() {
      _runningActionKey = action.key;
    });

    try {
      final response = await _dio.post(
        _usersEndpoint('actions/execute'),
        data: {'resource': resource, 'action': actionName},
        options: _authorizedOptions(),
      );

      final payload = _readPayload(response.data);
      final event = payload['event'];
      if (event is Map) {
        final entry = _AuditLogEntry.fromMap(Map<String, dynamic>.from(event));
        setState(() {
          _auditLogs.insert(0, entry);
          if (_auditLogs.length > 20) {
            _auditLogs.removeRange(20, _auditLogs.length);
          }
        });
      }

      if (mounted) {
        final message =
            payload['message']?.toString() ?? '${action.title} executed.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }

      if (widget.session.user.hasPermission('audit_logs', 'view')) {
        await _loadAuditHistory();
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final serverMessage = error.response?.data is Map
          ? (error.response?.data['error'] ?? error.response?.data['message'])
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            serverMessage?.toString() ??
                error.message ??
                'Failed to execute action.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _runningActionKey = null;
        });
      }
    }
  }

  Future<void> _loadAuditHistory() async {
    if (!widget.session.user.hasPermission('audit_logs', 'view')) {
      setState(() {
        _historyError = null;
      });
      return;
    }

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final response = await _dio.get(
        _usersEndpoint('logs'),
        queryParameters: {'limit': 20},
        options: _authorizedOptions(),
      );

      final payload = _readPayload(response.data);
      final logsValue = payload['logs'];
      if (logsValue is! List) {
        throw const FormatException('Invalid logs payload');
      }

      final logs = logsValue.whereType<Map>().map((raw) {
        return _AuditLogEntry.fromMap(Map<String, dynamic>.from(raw));
      }).toList();

      setState(() {
        _auditLogs
          ..clear()
          ..addAll(logs);
      });
    } on DioException catch (error) {
      setState(() {
        _historyError = error.response?.data is Map
            ? (error.response?.data['error'] ?? error.response?.data['message'])
                  ?.toString()
            : (error.message ?? 'Failed to load audit history.');
      });
    } catch (error) {
      setState(() {
        _historyError = 'Failed to load audit history.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Options _authorizedOptions() {
    return Options(
      headers: {'Authorization': 'Bearer ${widget.session.accessToken}'},
    );
  }

  String _usersEndpoint(String path) {
    final trimmed = _authServerBaseUrl.endsWith('/')
        ? _authServerBaseUrl.substring(0, _authServerBaseUrl.length - 1)
        : _authServerBaseUrl;
    if (trimmed.endsWith('/users')) {
      return '$trimmed/$path';
    }
    return '$trimmed/users/$path';
  }
}

enum _DashboardDestination { users, reports, settings }

class _DashboardAction {
  final String title;
  final String subtitle;
  final String? resource;
  final String? action;
  final _DashboardDestination? destination;
  final IconData icon;

  const _DashboardAction.execute({
    required this.title,
    required this.subtitle,
    required this.resource,
    required this.action,
    required this.icon,
  }) : destination = null;

  const _DashboardAction.navigate({
    required this.title,
    required this.subtitle,
    required this.destination,
    required this.icon,
  }) : resource = null,
       action = null;

  bool get isNavigation => destination != null;

  String get key =>
      isNavigation ? 'nav:${destination!.name}' : '$resource:$action';
}

class _ActionCard extends StatelessWidget {
  final _DashboardAction action;
  final bool isRunning;
  final VoidCallback? onPressed;

  const _ActionCard({
    required this.action,
    required this.isRunning,
    required this.onPressed,
  });

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
                        child: Text(
                          action.isNavigation
                              ? 'Open'
                              : (isRunning ? 'Running...' : 'Run Action'),
                        ),
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

class _AuditLogEntry {
  final String id;
  final String title;
  final String? ipAddress;
  final DateTime createdAt;

  const _AuditLogEntry({
    required this.id,
    required this.title,
    required this.ipAddress,
    required this.createdAt,
  });

  factory _AuditLogEntry.fromMap(Map<String, dynamic> map) {
    final eventType =
        map['eventType']?.toString() ??
        map['event_type']?.toString() ??
        'unknown';
    final metadata = map['metadata'];
    String title = eventType;
    if (metadata is Map) {
      final actionKey = metadata['actionKey'];
      if (actionKey is String && actionKey.isNotEmpty) {
        title = '$eventType ($actionKey)';
      }
    }
    final createdRaw = map['createdAt'] ?? map['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.now();

    return _AuditLogEntry(
      id: map['id']?.toString() ?? '',
      title: title,
      ipAddress: map['ipAddress']?.toString() ?? map['ip_address']?.toString(),
      createdAt: createdAt,
    );
  }
}

Map<String, dynamic> _readPayload(dynamic data) {
  if (data == null) return {};
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return {};
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
