import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  final GlobalKey _editSectionKey = GlobalKey();

  final TextEditingController _createEmailController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();

  final TextEditingController _editUserIdController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();

  final TextEditingController _deleteUserIdController = TextEditingController();

  final TextEditingController _roleUserIdController = TextEditingController();
  final TextEditingController _resetUserIdController = TextEditingController();

  List<RoleSummary> _roles = const [];
  String? _selectedCreateRole;
  String? _selectedManageRole;
  bool _isLoadingRoles = false;

  bool _isCreating = false;
  bool _isUpdating = false;
  bool _isDeleting = false;
  bool _isUpdatingRole = false;
  bool _isResettingPassword = false;

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

    final response = await context.read<GetRolesUseCase>()(
      GetRolesParams(accessToken: widget.session.accessToken),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (roles) {
        setState(() {
          _roles = roles;
          _selectedCreateRole =
              _selectedCreateRole ??
              (roles.isNotEmpty ? roles.first.name : null);
          _selectedManageRole =
              _selectedManageRole ??
              (roles.isNotEmpty ? roles.first.name : null);
        });
      },
    );

    setState(() {
      _isLoadingRoles = false;
    });
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

    final response = await context.read<CreateUserUseCase>()(
      CreateUserParams(
        accessToken: widget.session.accessToken,
        email: email,
        displayName: displayName,
        role: _selectedCreateRole,
      ),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (result) {
        _showMessage(
          result.userId.isNotEmpty
              ? 'Created user ${result.userId}. Default password: ${result.defaultPassword ?? '(username)'}'
              : 'User created.',
        );
        widget.onDataChanged?.call();
      },
    );

    setState(() {
      _isCreating = false;
    });
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

    final response = await context.read<UpdateUserUseCase>()(
      UpdateUserParams(
        accessToken: widget.session.accessToken,
        userId: userId,
        email: email.isEmpty ? null : email,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (_) {
        _showMessage('User updated.');
        widget.onDataChanged?.call();
      },
    );

    setState(() {
      _isUpdating = false;
    });
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

    final response = await context.read<DeleteUserUseCase>()(
      DeleteUserParams(accessToken: widget.session.accessToken, userId: userId),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (_) {
        _showMessage('User deleted.');
        widget.onDataChanged?.call();
      },
    );

    setState(() {
      _isDeleting = false;
    });
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

    final response = await context.read<UpdateUserRoleUseCase>()(
      UpdateUserRoleParams(
        accessToken: widget.session.accessToken,
        userId: userId,
        role: role,
      ),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (_) {
        _showMessage('Role updated.');
        widget.onDataChanged?.call();
      },
    );

    setState(() {
      _isUpdatingRole = false;
    });
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

    final response = await context.read<ResetUserPasswordUseCase>()(
      ResetUserPasswordParams(
        accessToken: widget.session.accessToken,
        userId: userId,
      ),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        _showMessage(failure.message);
      },
      (defaultPassword) {
        _showMessage(
          defaultPassword == null
              ? 'Password reset.'
              : 'Password reset. Default password: $defaultPassword',
        );
      },
    );

    setState(() {
      _isResettingPassword = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
