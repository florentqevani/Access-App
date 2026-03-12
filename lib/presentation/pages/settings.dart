import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSavingUsername = false;
  bool _isChangingPassword = false;
  bool _isSendingPasswordResetEmail = false;
  String? _liveDisplayName;

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
                hintText: 'Needed for re-auth in most cases',
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSendingPasswordResetEmail
                    ? null
                    : _sendPasswordResetEmail,
                child: Text(
                  _isSendingPasswordResetEmail
                      ? 'Sending...'
                      : 'Send Password Reset Email',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeUsername() async {
    final exchangeIdTokenUseCase = context.read<ExchangeIdTokenUseCase>();
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
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No active Firebase user.',
        );
      }

      await firebaseUser.updateDisplayName(newName);
      await firebaseUser.reload();

      String? backendSyncError;
      final refreshedUser = FirebaseAuth.instance.currentUser;
      final idToken = await refreshedUser?.getIdToken(true);
      if (idToken != null && idToken.isNotEmpty) {
        final syncResponse = await exchangeIdTokenUseCase(
          ExchangeIdTokenParams(idToken: idToken),
        );

        syncResponse.fold(
          (failure) => backendSyncError = failure.message,
          (_) => backendSyncError = null,
        );
      }

      setState(() {
        _liveDisplayName = newName;
      });
      widget.onDisplayNameUpdated?.call(newName);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backendSyncError == null
                ? 'Username updated successfully.'
                : 'Username updated in Firebase, but backend sync failed: $backendSyncError',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Failed to update username.')),
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
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No active Firebase user.',
        );
      }

      final hasPasswordProvider = firebaseUser.providerData.any(
        (provider) => provider.providerId == 'password',
      );

      if (hasPasswordProvider && currentPassword.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Current password is required to change your password.',
            ),
          ),
        );
        return;
      }

      if (hasPasswordProvider && firebaseUser.email != null) {
        final credential = EmailAuthProvider.credential(
          email: firebaseUser.email!,
          password: currentPassword,
        );
        await firebaseUser.reauthenticateWithCredential(credential);
      }

      await firebaseUser.updatePassword(newPassword);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = _firebasePasswordErrorMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _sendPasswordResetEmail() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = firebaseUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email is available for password reset.'),
        ),
      );
      return;
    }

    setState(() {
      _isSendingPasswordResetEmail = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Failed to send password reset email.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send password reset email.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingPasswordResetEmail = false;
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

  String _firebasePasswordErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'requires-recent-login':
        return 'Please re-login (or enter current password) before changing password.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak.';
      default:
        return error.message ?? 'Failed to update password.';
    }
  }
}
