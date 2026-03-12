import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/user_access_models.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LogsPage extends StatefulWidget {
  final AuthSession session;

  const LogsPage({super.key, required this.session});

  static MaterialPageRoute<dynamic> route({required AuthSession session}) {
    return MaterialPageRoute(builder: (context) => LogsPage(session: session));
  }

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final List<AuditLogEntry> _logs = [];
  bool _isLoading = false;
  String? _error;

  String get _roleName => widget.session.user.role.trim().toLowerCase();
  bool get _canViewLogs => _roleName == 'admin' || _roleName == 'manager';

  @override
  void initState() {
    super.initState();
    if (_canViewLogs) {
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          if (_canViewLogs)
            IconButton(
              onPressed: _isLoading ? null : _loadLogs,
              tooltip: 'Refresh logs',
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: !_canViewLogs
              ? const Center(
                  child: Text('You do not have permission to view logs.'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Logs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: _logs.isEmpty
                          ? const Center(child: Text('No logs available.'))
                          : ListView.separated(
                              itemCount: _logs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(log.title),
                                  subtitle: Text(
                                    '${_formatTimestamp(log.createdAt)} • user: ${log.userId ?? '-'} • ip: ${log.ipAddress ?? '-'}',
                                  ),
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

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await context.read<GetAuditLogsUseCase>()(
      GetAuditLogsParams(accessToken: widget.session.accessToken, limit: 50),
    );

    if (!mounted) {
      return;
    }

    response.fold(
      (failure) {
        setState(() {
          _error = failure.message;
        });
      },
      (logs) {
        setState(() {
          _logs
            ..clear()
            ..addAll(logs);
        });
      },
    );

    setState(() {
      _isLoading = false;
    });
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
