import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/core/network/auth_server_config.dart';
import 'package:access_app/presentation/pages/users_commands.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class UsersDashboardPage extends StatefulWidget {
  final AuthSession session;

  const UsersDashboardPage({super.key, required this.session});

  static MaterialPageRoute<dynamic> route({required AuthSession session}) {
    return MaterialPageRoute(
      builder: (context) => UsersDashboardPage(session: session),
    );
  }

  @override
  State<UsersDashboardPage> createState() => _UsersDashboardPageState();
}

class _UsersDashboardPageState extends State<UsersDashboardPage> {
  final Dio _dio = Dio();

  final List<_UserRow> _users = [];
  bool _isLoadingUsers = false;
  String? _usersError;

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
    if (widget.session.user.hasPermission('users', 'read')) {
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final canRead = user.hasPermission('users', 'read');
    final canOpenManagement =
        canRead ||
        user.hasPermission('users', 'create') ||
        user.hasPermission('users', 'edit') ||
        user.hasPermission('users', 'delete') ||
        user.hasPermission('roles', 'manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Dashboard'),
        actions: [
          if (canOpenManagement)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  UsersCommandsPage.route(
                    session: widget.session,
                    onDataChanged: _loadUsers,
                  ),
                );
              },
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Open User Management',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Database Users',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Role: ${user.role}'),
              const SizedBox(height: 16),
              if (!canRead)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No permission to read users.'),
                  ),
                )
              else
                _buildUsersCard(canOpenManagement: canOpenManagement),
              if (canOpenManagement) const SizedBox(height: 12),
              if (canOpenManagement)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        UsersCommandsPage.route(
                          session: widget.session,
                          onDataChanged: _loadUsers,
                        ),
                      );
                    },
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Open CRUD & Role Management'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersCard({required bool canOpenManagement}) {
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
                    'All Users',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _isLoadingUsers ? null : _loadUsers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh users',
                ),
              ],
            ),
            if (_isLoadingUsers) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_usersError != null) ...[
              const SizedBox(height: 8),
              Text(
                _usersError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            if (!_isLoadingUsers && _usersError == null) ...[
              const SizedBox(height: 8),
              if (_users.isEmpty)
                const Text('No users found.')
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _users.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final row = _users[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onTap: canOpenManagement
                          ? () => _openUserManagement(prefillUser: row)
                          : null,
                      title: Text(row.displayName ?? row.email ?? '(no name)'),
                      subtitle: Text(
                        'Email: ${row.email ?? '-'}\nRole: ${row.role} • ID: ${row.id}',
                      ),
                      trailing: Text(_formatDate(row.createdAt)),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openUserManagement({_UserRow? prefillUser}) {
    Navigator.push(
      context,
      UsersCommandsPage.route(
        session: widget.session,
        onDataChanged: _loadUsers,
        initialUserId: prefillUser?.id,
        initialUserEmail: prefillUser?.email,
        initialUserDisplayName: prefillUser?.displayName,
        focusEditSection: prefillUser != null,
      ),
    );
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      final response = await _dio.get(
        _usersEndpoint(''),
        queryParameters: {'limit': 200},
        options: _authorizedOptions(),
      );
      final payload = _readPayload(response.data);
      final rawUsers = payload['users'];

      if (rawUsers is! List) {
        throw const FormatException('Invalid users payload.');
      }

      final users = rawUsers
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_UserRow.fromMap)
          .toList(growable: false);

      setState(() {
        _users
          ..clear()
          ..addAll(users);
      });
    } on DioException catch (error) {
      setState(() {
        _usersError = _dioErrorMessage(
          error,
          fallback: 'Failed to load users.',
        );
      });
    } catch (_) {
      setState(() {
        _usersError = 'Failed to load users.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
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
    final normalizedPath = path.trim();
    if (trimmed.endsWith('/users')) {
      if (normalizedPath.isEmpty) return trimmed;
      return '$trimmed/$normalizedPath';
    }
    if (normalizedPath.isEmpty) {
      return '$trimmed/users';
    }
    return '$trimmed/users/$normalizedPath';
  }
}

class _UserRow {
  final String id;
  final String? email;
  final String? displayName;
  final String role;
  final DateTime? createdAt;

  const _UserRow({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  factory _UserRow.fromMap(Map<String, dynamic> map) {
    final rawCreated = map['createdAt'] ?? map['created_at'];
    return _UserRow(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      displayName: map['displayName']?.toString(),
      role: map['role']?.toString() ?? 'unknown',
      createdAt: rawCreated is String ? DateTime.tryParse(rawCreated) : null,
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
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

String _dioErrorMessage(DioException error, {required String fallback}) {
  final data = error.response?.data;
  if (data is Map) {
    final message = data['error'] ?? data['message'];
    if (message != null) {
      return message.toString();
    }
  }
  return error.message ?? fallback;
}
