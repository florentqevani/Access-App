import 'dart:io';

import 'package:access_app/domain/repository/auth_session.dart';
import 'package:access_app/domain/repository/auth_user.dart';
import 'package:access_app/domain/use_cases/user_access_use_cases.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    final isBasicUser = user.role.trim().toLowerCase() == 'user';
    final canReadReport =
        user.hasPermission('reports', 'read') ||
        user.hasPermission('reports', 'export');
    final canDownloadReport = user.hasPermission('reports', 'export');
    final report = _buildDummyReport(user, hidePermissions: isBasicUser);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Access Activity Report',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (!canReadReport)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No report actions available for your role.'),
                  ),
                )
              else
                _ReportCard(
                  report: report,
                  showDownloadPanel: !isBasicUser,
                  canDownload: canDownloadReport,
                  isDownloading: _isDownloading,
                  onDownload: canDownloadReport ? _downloadReport : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  _DummyReport _buildDummyReport(
    AuthUser user, {
    required bool hidePermissions,
  }) {
    final permissions = user.permissions
        .where((permission) => permission.scope != 'none')
        .map((permission) => permission.key)
        .toList(growable: false);
    final generatedAt = DateTime.now();

    return _DummyReport(
      title: 'Weekly Access Overview',
      generatedAt: generatedAt,
      summary:
          'This dummy report summarizes user access, permissions, and recent operational coverage for the current app session.',
      lines: [
        'Prepared for: ${user.displayName ?? user.email ?? 'Unknown user'}',
        'Primary role: ${user.role}',
        'Visible modules: Users, Reports, Settings, Logs',
        if (!hidePermissions)
          'Effective permissions: ${permissions.isEmpty ? 'No explicit permissions' : permissions.join(', ')}',
        'System status: Authentication backend online, RBAC active, audit logging enabled',
        'Recommended follow-up: review role scopes and export monthly access audits',
      ],
    );
  }

  Future<void> _downloadReport() async {
    setState(() {
      _isDownloading = true;
    });

    final response = await context.read<ExecuteUserActionUseCase>()(
      ExecuteUserActionParams(
        accessToken: widget.session.accessToken,
        resource: 'reports',
        action: 'export',
      ),
    );

    if (!mounted) {
      return;
    }

    await response.fold(
      (failure) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) async {
        final report = _buildDummyReport(
          widget.session.user,
          hidePermissions:
              widget.session.user.role.trim().toLowerCase() == 'user',
        );
        final reportText = _formatReport(report);

        if (kIsWeb) {
          await Clipboard.setData(ClipboardData(text: reportText));
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Download is not available on web here. Report copied to clipboard.',
              ),
            ),
          );
          return;
        }

        try {
          final file = File(
            '${Directory.systemTemp.path}${Platform.pathSeparator}access_app_report.txt',
          );
          await file.writeAsString(reportText);
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report saved to ${file.path}'),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (error) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save report: $error')),
          );
        }
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isDownloading = false;
    });
  }

  String _formatReport(_DummyReport report) {
    final buffer = StringBuffer()
      ..writeln(report.title)
      ..writeln('Generated: ${report.generatedAt.toLocal()}')
      ..writeln()
      ..writeln(report.summary)
      ..writeln();

    for (final line in report.lines) {
      buffer.writeln('- $line');
    }

    return buffer.toString();
  }
}

class _ReportCard extends StatelessWidget {
  final _DummyReport report;
  final bool showDownloadPanel;
  final bool canDownload;
  final bool isDownloading;
  final VoidCallback? onDownload;

  const _ReportCard({
    required this.report,
    required this.showDownloadPanel,
    required this.canDownload,
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: !showDownloadPanel
            ? _ReportContent(report: report)
            : compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReportContent(report: report),
                  const SizedBox(height: 16),
                  _DownloadButton(
                    canDownload: canDownload,
                    isDownloading: isDownloading,
                    onPressed: onDownload,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ReportContent(report: report)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 180,
                    child: _DownloadButton(
                      canDownload: canDownload,
                      isDownloading: isDownloading,
                      onPressed: onDownload,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final _DummyReport report;

  const _ReportContent({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(report.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Generated ${_formatTimestamp(report.generatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(report.summary),
        const SizedBox(height: 12),
        ...report.lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(line)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  final bool canDownload;
  final bool isDownloading;
  final VoidCallback? onPressed;

  const _DownloadButton({
    required this.canDownload,
    required this.isDownloading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: canDownload && !isDownloading ? onPressed : null,
          icon: const Icon(Icons.download_outlined),
          label: Text(isDownloading ? 'Saving...' : 'Download'),
        ),
        if (!canDownload) ...[
          const SizedBox(height: 8),
          Text(
            'Export permission is required to download this report.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _DummyReport {
  final String title;
  final DateTime generatedAt;
  final String summary;
  final List<String> lines;

  const _DummyReport({
    required this.title,
    required this.generatedAt,
    required this.summary,
    required this.lines,
  });
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
