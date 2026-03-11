import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/core/network/auth_server_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class UsersCommandsPage extends StatefulWidget {
  final AuthSession session;
  final VoidCallback? onDataChanged;
  final String? initialUserId;
  final String? initialUserEmail;
  final String? initialUserDisplayName;
  final bool focusEditSection;

  const UsersCommandsPage({
    super.key,
    required this.session,
    this.onDataChanged,
    this.initialUserId,
    this.initialUserEmail,
    this.initialUserDisplayName,
    this.focusEditSection = false,
  });

  static MaterialPageRoute<dynamic> route({
    required AuthSession session,
    VoidCallback? onDataChanged,
    String? initialUserId,
    String? initialUserEmail,
    String? initialUserDisplayName,
    bool focusEditSection = false,
  }) {
    return MaterialPageRoute(
      builder: (context) => UsersCommandsPage(
        session: session,
        onDataChanged: onDataChanged,
        initialUserId: initialUserId,
        initialUserEmail: initialUserEmail,
        initialUserDisplayName: initialUserDisplayName,
        focusEditSection: focusEditSection,
      ),
    );
  }

  @override
  State<UsersCommandsPage> createState() => _UsersCommandsPageState();
}

class _UsersCommandsPageState extends State<UsersCommandsPage> {
  final Dio _dio = Dio();
  final GlobalKey _editSectionKey = GlobalKey();

  final TextEditingController _createEmailController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();

  final TextEditingController _editUserIdController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();

  final TextEditingController _deleteUserIdController = TextEditingController();

  final TextEditingController _roleUserIdController = TextEditingController();
  final TextEditingController _resetUserIdController = TextEditingController();

  List<_RoleOption> _roles = const [];
  String? _selectedCreateRole;
  String? _selectedManageRole;
  bool _isLoadingRoles = false;

  bool _isCreating = false;
  bool _isUpdating = false;
  bool _isDeleting = false;
  bool _isUpdatingRole = false;
  bool _isResettingPassword = false;

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
    _applyInitialUserPrefill();
    if (widget.session.user.hasPermission('roles', 'manage')) {
      _loadRoles();
    }
    if (widget.focusEditSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEditSection();
      });
    }
  }

  void _applyInitialUserPrefill() {
    if (widget.initialUserId?.trim().isNotEmpty == true) {
      _editUserIdController.text = widget.initialUserId!.trim();
    }
    if (widget.initialUserEmail?.trim().isNotEmpty == true) {
      _editEmailController.text = widget.initialUserEmail!.trim();
    }
    if (widget.initialUserDisplayName?.trim().isNotEmpty == true) {
      _editNameController.text = widget.initialUserDisplayName!.trim();
    }
  }

  @override
  void dispose() {
    _createEmailController.dispose();
    _createNameController.dispose();
    _editUserIdController.dispose();
    _editEmailController.dispose();
    _editNameController.dispose();
    _deleteUserIdController.dispose();
    _roleUserIdController.dispose();
    _resetUserIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final canCreate = user.hasPermission('users', 'create');
    final canEdit = user.hasPermission('users', 'edit');
    final canDelete = user.hasPermission('users', 'delete');
    final canManageRoles = user.hasPermission('roles', 'manage');
    final isAdmin = user.role.toLowerCase() == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canCreate) _buildCreateUserCard(canManageRoles),
            if (canCreate) const SizedBox(height: 12),
            if (canEdit) _buildEditUserCard(),
            if (canEdit) const SizedBox(height: 12),
            if (canDelete) _buildDeleteUserCard(),
            if (canDelete) const SizedBox(height: 12),
            if (canManageRoles) _buildRoleCard(),
            if (isAdmin) const SizedBox(height: 12),
            if (isAdmin) _buildResetPasswordCard(),
            if (!canCreate && !canEdit && !canDelete && !canManageRoles)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No user management permissions for your role.'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateUserCard(bool canManageRoles) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create User Record',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _createEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _createNameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Default password will be set to the same value as username.',
              style: TextStyle(fontSize: 12),
            ),
            if (canManageRoles) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCreateRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role.name,
                        child: Text(role.name),
                      ),
                    )
                    .toList(),
                onChanged: _isLoadingRoles
                    ? null
                    : (value) {
                        setState(() {
                          _selectedCreateRole = value;
                        });
                      },
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createUser,
                child: Text(_isCreating ? 'Creating...' : 'Create User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditUserCard() {
    return Card(
      key: _editSectionKey,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update User', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _editUserIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editEmailController,
              decoration: const InputDecoration(
                labelText: 'New Email (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editNameController,
              decoration: const InputDecoration(
                labelText: 'New Display Name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateUser,
                child: Text(_isUpdating ? 'Updating...' : 'Update User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToEditSection() {
    final context = _editSectionKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.08,
    );
  }

  Widget _buildDeleteUserCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete User', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _deleteUserIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _deleteUser,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(_isDeleting ? 'Deleting...' : 'Delete User'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    final isBusy = _isLoadingRoles || _isUpdatingRole;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role Management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _roleUserIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedManageRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: _roles
                  .map(
                    (role) => DropdownMenuItem<String>(
                      value: role.name,
                      child: Text(role.name),
                    ),
                  )
                  .toList(),
              onChanged: isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedManageRole = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isBusy ? null : _updateRole,
                child: Text(_isUpdatingRole ? 'Updating...' : 'Update Role'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetPasswordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset User Password',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Resets selected user password to their username.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _resetUserIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResettingPassword ? null : _resetUserPassword,
                child: Text(
                  _isResettingPassword ? 'Resetting...' : 'Reset To Default',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoadingRoles = true;
    });
    try {
      final response = await _dio.get(
        _usersEndpoint('roles'),
        options: _authorizedOptions(),
      );
      final payload = _readPayload(response.data);
      final raw = payload['roles'];
      if (raw is! List) {
        throw const FormatException('Invalid roles payload.');
      }
      final roles = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(
            (item) => _RoleOption(
              name: item['name']?.toString() ?? '',
              description: item['description']?.toString(),
            ),
          )
          .where((role) => role.name.isNotEmpty)
          .toList(growable: false);
      setState(() {
        _roles = roles;
        _selectedCreateRole =
            _selectedCreateRole ?? (roles.isNotEmpty ? roles.first.name : null);
        _selectedManageRole =
            _selectedManageRole ?? (roles.isNotEmpty ? roles.first.name : null);
      });
    } on DioException catch (error) {
      _showMessage(_dioErrorMessage(error, fallback: 'Failed to load roles.'));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoles = false;
        });
      }
    }
  }

  Future<void> _createUser() async {
    final email = _createEmailController.text.trim();
    final displayName = _createNameController.text.trim();
    if (email.isEmpty || displayName.isEmpty) {
      _showMessage('Email and username are required.');
      return;
    }
    if (displayName.length < 6) {
      _showMessage(
        'Username must be at least 6 characters (default password = username).',
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });
    try {
      final body = <String, dynamic>{};
      body['email'] = email;
      body['displayName'] = displayName;
      if (_selectedCreateRole != null) body['role'] = _selectedCreateRole;

      final response = await _dio.post(
        _usersEndpoint(''),
        data: body,
        options: _authorizedOptions(),
      );
      final payload = _readPayload(response.data);
      final createdUser = payload['user'];
      final defaultPassword = payload['defaultPassword']?.toString();
      _showMessage(
        createdUser is Map
            ? 'Created user ${createdUser['id'] ?? ''}. '
                  'Default password: ${defaultPassword ?? '(username)'}'
            : 'User created.',
      );
      widget.onDataChanged?.call();
    } on DioException catch (error) {
      _showMessage(_dioErrorMessage(error, fallback: 'Failed to create user.'));
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _updateUser() async {
    final userId = _editUserIdController.text.trim();
    final email = _editEmailController.text.trim();
    final displayName = _editNameController.text.trim();
    if (userId.isEmpty) {
      _showMessage('User ID is required.');
      return;
    }
    if (email.isEmpty && displayName.isEmpty) {
      _showMessage('Provide email or display name.');
      return;
    }

    setState(() {
      _isUpdating = true;
    });
    try {
      final body = <String, dynamic>{};
      if (email.isNotEmpty) body['email'] = email;
      if (displayName.isNotEmpty) body['displayName'] = displayName;

      await _dio.patch(
        _usersEndpoint(userId),
        data: body,
        options: _authorizedOptions(),
      );
      _showMessage('User updated.');
      widget.onDataChanged?.call();
    } on DioException catch (error) {
      _showMessage(_dioErrorMessage(error, fallback: 'Failed to update user.'));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteUser() async {
    final userId = _deleteUserIdController.text.trim();
    if (userId.isEmpty) {
      _showMessage('User ID is required.');
      return;
    }

    setState(() {
      _isDeleting = true;
    });
    try {
      await _dio.delete(_usersEndpoint(userId), options: _authorizedOptions());
      _showMessage('User deleted.');
      widget.onDataChanged?.call();
    } on DioException catch (error) {
      _showMessage(_dioErrorMessage(error, fallback: 'Failed to delete user.'));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _updateRole() async {
    final userId = _roleUserIdController.text.trim();
    final role = _selectedManageRole?.trim();
    if (userId.isEmpty || role == null || role.isEmpty) {
      _showMessage('User ID and role are required.');
      return;
    }

    setState(() {
      _isUpdatingRole = true;
    });
    try {
      await _dio.patch(
        _usersEndpoint('$userId/role'),
        data: {'role': role},
        options: _authorizedOptions(),
      );
      _showMessage('Role updated.');
      widget.onDataChanged?.call();
    } on DioException catch (error) {
      _showMessage(_dioErrorMessage(error, fallback: 'Failed to update role.'));
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingRole = false;
        });
      }
    }
  }

  Future<void> _resetUserPassword() async {
    final userId = _resetUserIdController.text.trim();
    if (userId.isEmpty) {
      _showMessage('User ID is required.');
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });
    try {
      final response = await _dio.post(
        _usersEndpoint('$userId/password/reset'),
        options: _authorizedOptions(),
      );
      final payload = _readPayload(response.data);
      final defaultPassword = payload['defaultPassword']?.toString();
      _showMessage(
        defaultPassword == null
            ? 'Password reset.'
            : 'Password reset. Default password: $defaultPassword',
      );
    } on DioException catch (error) {
      _showMessage(
        _dioErrorMessage(error, fallback: 'Failed to reset password.'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _RoleOption {
  final String name;
  final String? description;

  const _RoleOption({required this.name, required this.description});
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
