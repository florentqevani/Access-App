import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:access_app/presentation/pages/users_commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final List<UserSummary> _users = [];
  bool _isLoadingUsers = false;
  String? _usersError;

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
    final canManageUsers =
        user.hasPermission('users', 'create') ||
        user.hasPermission('users', 'edit') ||
        user.hasPermission('users', 'delete') ||
        user.hasPermission('roles', 'manage');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Dashboard'),
        actions: [
          if (canManageUsers)
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
                _buildUsersCard(canManageUsers: canManageUsers),
              if (canManageUsers) const SizedBox(height: 12),
              if (canManageUsers)
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
                    label: const Text('Open User Management'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersCard({required bool canManageUsers}) {
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
                      onTap: canManageUsers
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

  void _openUserManagement({UserSummary? prefillUser}) {
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

    final response = await context.read<GetUsersUseCase>()(
      GetUsersParams(accessToken: widget.session.accessToken, limit: 200),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        setState(() {
          _usersError = failure.message;
        });
      },
      (users) {
        setState(() {
          _users
            ..clear()
            ..addAll(users);
        });
      },
    );

    setState(() {
      _isLoadingUsers = false;
    });
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
