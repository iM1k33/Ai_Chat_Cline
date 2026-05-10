import 'dart:convert';

import 'package:aichatcline/data/repositories/logs_repository.dart';
import 'package:aichatcline/features/export/services/share_service.dart';
import 'package:aichatcline/features/logs/models/app_log_entry.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({
    super.key,
    required this.logsRepository,
    required this.shareService,
  });

  final LogsRepository logsRepository;
  final ShareService shareService;

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  List<AppLogEntry> _logs = <AppLogEntry>[];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<AppLogEntry> logs = await widget.logsRepository.getLogs();
      if (!mounted) {
        return;
      }

      setState(() {
        _logs = logs;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Failed to load logs';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showClearLogsConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear logs?'),
          content: const Text(
            'This will delete saved debug logs. Chat history and statistics will not be deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _clearLogs() async {
    final bool confirmed = await _showClearLogsConfirmation();
    if (!confirmed) {
      return;
    }

    await widget.logsRepository.deleteAllLogs();
    await _loadLogs();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs cleared')));
  }

  Future<void> _exportLogs() async {
    if (_logs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logs to export')));
      return;
    }

    final String content = const JsonEncoder.withIndent('  ').convert(
      _logs.map((AppLogEntry entry) => entry.toJson()).toList(),
    );

    final String fileName =
        'logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

    final file = await widget.shareService.saveExportFileWithPicker(
      fileName: fileName,
      content: content,
    );

    if (!mounted) {
      return;
    }

    if (file == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export cancelled')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Logs exported: ${file.path}')));
  }

  String _compactMetadata(Map<String, dynamic> metadata) {
    final String value = jsonEncode(metadata);
    if (value.length <= 220) {
      return value;
    }

    return '${value.substring(0, 220)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadLogs,
          ),
          IconButton(
            tooltip: 'Export logs',
            icon: const Icon(Icons.download_outlined),
            onPressed: _isLoading ? null : _exportLogs,
          ),
          IconButton(
            tooltip: 'Clear logs',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _isLoading ? null : _clearLogs,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _logs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_logs.isEmpty)
                    const Text('No logs yet')
                  else
                    ..._logs.map((AppLogEntry entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _dateFormat.format(entry.createdAt),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.level.toUpperCase()} • ${entry.category}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(entry.message),
                              if (entry.metadata != null &&
                                  entry.metadata!.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  _compactMetadata(entry.metadata!),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}
