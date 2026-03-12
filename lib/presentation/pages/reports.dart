import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  String? _runningAction;

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

    final response = await context.read<ExecuteUserActionUseCase>()(
      ExecuteUserActionParams(
        accessToken: widget.session.accessToken,
        resource: 'reports',
        action: action,
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

    setState(() {
      _runningAction = null;
    });
  }
}
