import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/core/network/auth_server_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ReportsPage extends StatefulWidget {
  final AuthSession session;

  const ReportsPage({super.key, required this.session});

  static MaterialPageRoute<dynamic> route({required AuthSession session}) {
    return MaterialPageRoute(
      builder: (context) => ReportsPage(session: session),
    );
  }

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Dio _dio = Dio();
  String? _runningAction;

  String get _authServerBaseUrl {
    const configuredAuthServerBaseUrl = String.fromEnvironment(
      'AUTH_SERVER_BASE_URL',
    );
    return resolveAuthServerBaseUrl(
      configuredBaseUrl: configuredAuthServerBaseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final reportActions =
        <({String title, String subtitle, IconData icon, String action})>[
          if (user.hasPermission('reports', 'read'))
            (
              title: 'Read Reports',
              subtitle: 'Fetch and view report data',
              icon: Icons.insert_chart_outlined,
              action: 'read',
            ),
          if (user.hasPermission('reports', 'export'))
            (
              title: 'Export Reports',
              subtitle: 'Export reports to file/download',
              icon: Icons.file_download_outlined,
              action: 'export',
            ),
        ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Reports Access',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (reportActions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No report actions available for your role.'),
                  ),
                )
              else
                ...reportActions.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReportActionCard(
                      title: entry.title,
                      subtitle: entry.subtitle,
                      icon: entry.icon,
                      action: entry.action,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String action,
  }) {
    final isRunning = _runningAction == action;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: !isRunning
                    ? () => _executeReportAction(action)
                    : null,
                child: Text(isRunning ? 'Running...' : 'Execute'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeReportAction(String action) async {
    setState(() {
      _runningAction = action;
    });

    try {
      final response = await _dio.post(
        _usersEndpoint('actions/execute'),
        data: {'resource': 'reports', 'action': action},
        options: _authorizedOptions(),
      );
      final payload = _readPayload(response.data);
      final message = payload['message']?.toString() ?? 'Action executed.';

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on DioException catch (error) {
      if (!mounted) return;
      final message = _dioErrorMessage(
        error,
        fallback: 'Failed to execute report action.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _runningAction = null;
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
