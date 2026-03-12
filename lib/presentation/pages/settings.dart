import 'package:access_app/core/network/auth_server_config.dart';
import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:access_app/presentation/pages/login_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserSettingsPage extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<String>? onDisplayNameUpdated;

  const UserSettingsPage({
    super.key,
    required this.session,
    this.onDisplayNameUpdated,
  });

  static MaterialPageRoute<dynamic> route({
    required AuthSession session,
    ValueChanged<String>? onDisplayNameUpdated,
  }) {
    return MaterialPageRoute(
      builder: (context) => UserSettingsPage(
        session: session,
        onDisplayNameUpdated: onDisplayNameUpdated,
      ),
    );
  }

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final Dio _dio = Dio();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSavingUsername = false;
  bool _isChangingPassword = false;
  String? _liveDisplayName;

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
    _usernameController.text = widget.session.user.displayName ?? '';
    _liveDisplayName = widget.session.user.displayName;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final canConfigureSystem = user.hasPermission('settings', 'configure');
    final displayName = _liveDisplayName?.trim().isNotEmpty == true
        ? _liveDisplayName!.trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'unknown');

    return Scaffold(
      appBar: AppBar(title: const Text('User Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Profile & Security',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Signed in as $displayName • ${user.email ?? 'unknown'} (${user.role}).',
              ),
              const SizedBox(height: 16),
              _buildUsernameCard(),
              const SizedBox(height: 16),
              _buildPasswordCard(),
              if (canConfigureSystem) const SizedBox(height: 16),
              if (canConfigureSystem)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Settings Permission',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        const Text('You can configure system settings.'),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _executeSystemSettingsAction,
                            child: const Text('Run Settings Configure Action'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change Username',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingUsername ? null : _changeUsername,
                child: Text(_isSavingUsername ? 'Saving...' : 'Save Username'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change Password',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChangingPassword ? null : _changePassword,
                child: Text(
                  _isChangingPassword ? 'Updating...' : 'Update Password',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isSavingUsername = true;
    });

    try {
      final response = await _dio.patch(
        _usersEndpoint('me/profile'),
        data: {'displayName': newName},
        options: _authorizedOptions(),
      );

      final payload = _readPayload(response.data);
      final message =
          payload['message']?.toString() ?? 'Username updated successfully.';

      setState(() {
        _liveDisplayName = newName;
      });
      widget.onDisplayNameUpdated?.call(newName);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _dioErrorMessage(error, fallback: 'Failed to update username.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update username.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUsername = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is required.')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters.'),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password confirmation does not match.')),
      );
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      final response = await _dio.patch(
        _authEndpoint('change-password'),
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        options: _authorizedOptions(),
      );

      final payload = _readPayload(response.data);
      final message =
          payload['message']?.toString() ??
          'Password updated successfully. Please sign in again.';

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      Navigator.pushAndRemoveUntil(
        context,
        LoginPage.route(),
        (route) => false,
      );
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _dioErrorMessage(error, fallback: 'Failed to update password.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update password.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _executeSystemSettingsAction() async {
    final response = await context.read<ExecuteUserActionUseCase>()(
      ExecuteUserActionParams(
        accessToken: widget.session.accessToken,
        resource: 'settings',
        action: 'configure',
      ),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (result) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      },
    );
  }

  Options _authorizedOptions() {
    return Options(
      headers: {'Authorization': 'Bearer ${widget.session.accessToken}'},
    );
  }

  String _authEndpoint(String path) {
    final base = _serviceBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    if (trimmed.endsWith('/auth')) {
      return '$trimmed/$path';
    }
    return '$trimmed/auth/$path';
  }

  String _usersEndpoint(String path) {
    final base = _serviceBaseUrl();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;

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

  String _serviceBaseUrl() {
    var base = _authServerBaseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    if (base.endsWith('/auth')) {
      return base.substring(0, base.length - '/auth'.length);
    }
    if (base.endsWith('/users')) {
      return base.substring(0, base.length - '/users'.length);
    }
    return base;
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
}
