import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:aichatcline/features/statistics/state/statistics_controller.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, required this.controller});

  final StatisticsController controller;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.load();
    });
  }

  String _formatDouble(double value) {
    return value.toStringAsFixed(6);
  }

  String _formatResponseTime(double value) {
    return value.toStringAsFixed(1);
  }

  Future<bool> _showClearStatisticsConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear statistics?'),
          content: const Text(
            'This will delete all saved usage and cost statistics. Chat conversations and messages will not be deleted. This action cannot be undone.',
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final StatisticsController controller = widget.controller;

        final Map<String, int> modelRequests = controller.requestCountByModel;
        final Map<String, int> modelTokens = controller.totalTokensByModel;
        final Map<String, double> modelCost = controller.estimatedCostByModel;
        final Map<String, int> providerTokens = controller.totalTokensByProvider;
        final List<String> modelIds = modelRequests.keys.toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Statistics'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: controller.isLoading ? null : controller.refresh,
              ),
              IconButton(
                tooltip: 'Delete all statistics',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: controller.isLoading
                    ? null
                    : () async {
                        final bool confirmed =
                            await _showClearStatisticsConfirmation();
                        if (!confirmed) {
                          return;
                        }

                        await controller.deleteAllStatistics();
                        if (context.mounted && controller.error == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Statistics deleted'),
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
          body: SafeArea(
            child: controller.isLoading && controller.records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            controller.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      _SectionCard(
                        title: 'Summary',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _StatRow(
                              label: 'Total requests',
                              value: '${controller.totalRequests}',
                            ),
                            _StatRow(
                              label: 'Total tokens',
                              value: '${controller.totalTokens}',
                            ),
                            _StatRow(
                              label: 'Prompt tokens',
                              value: '${controller.totalPromptTokens}',
                            ),
                            _StatRow(
                              label: 'Completion tokens',
                              value: '${controller.totalCompletionTokens}',
                            ),
                            _StatRow(
                              label: 'Error count',
                              value: '${controller.errorCount}',
                            ),
                            _StatRow(
                              label: 'Average response time (ms)',
                              value: _formatResponseTime(
                                controller.averageResponseTimeMs,
                              ),
                            ),
                            _StatRow(
                              label: 'Estimated cost USD',
                              value: _formatDouble(
                                controller.totalEstimatedCostUsd,
                              ),
                            ),
                            _StatRow(
                              label: 'Estimated cost RUB',
                              value: _formatDouble(
                                controller.totalEstimatedCostRub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'By model',
                        child: modelIds.isEmpty
                            ? const Text('No records')
                            : Column(
                                children: modelIds.map((String modelId) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLow,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            modelId,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Requests: ${modelRequests[modelId] ?? 0}',
                                          ),
                                          Text(
                                            'Total tokens: ${modelTokens[modelId] ?? 0}',
                                          ),
                                          Text(
                                            'Estimated cost: ${_formatDouble(modelCost[modelId] ?? 0)}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Tokens by provider',
                        child: providerTokens.isEmpty
                            ? const Text('No records')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: providerTokens.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${entry.key}: ${entry.value}',
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Recent records',
                        child: controller.records.isEmpty
                            ? const Text('No records')
                            : Column(
                                children: controller.records.map((UsageRecord record) {
                                  final String errorText = record.error ?? '-';
                                  final String responseTimeText =
                                      record.responseTimeMs?.toString() ?? '-';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLow,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            _dateFormat.format(record.createdAt),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                          ),
                                          const SizedBox(height: 6),
                                          Text('Provider: ${record.providerId}'),
                                          Text('Model: ${record.modelId}'),
                                          Text('Total tokens: ${record.totalTokens}'),
                                          Text(
                                            'Estimated cost: ${_formatDouble(record.estimatedCost)} ${record.currencyCode}',
                                          ),
                                          Text(
                                            'Response time (ms): $responseTimeText',
                                          ),
                                          Text('Error: $errorText'),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}