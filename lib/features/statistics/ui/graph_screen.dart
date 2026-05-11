import 'dart:math' as math;

import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:aichatcline/features/statistics/state/statistics_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key, required this.controller});

  final StatisticsController controller;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final StatisticsController controller = widget.controller;
        final List<UsageRecord> records = List<UsageRecord>.from(
          controller.records,
        )..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Graphs'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: controller.isLoading ? null : controller.refresh,
              ),
            ],
          ),
          body: SafeArea(
            child: controller.isLoading && records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'No graph data yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Send a few messages first to collect usage statistics.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      _SummaryCards(controller: controller),
                      const SizedBox(height: 12),
                      _CardSection(
                        title: 'Token usage over time',
                        child: SizedBox(
                          height: 220,
                          child: _TokenLineChart(records: records),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardSection(
                        title: 'Estimated cost over time',
                        child: SizedBox(
                          height: 220,
                          child: _CostLineChart(records: records),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardSection(
                        title: 'Tokens by model',
                        child: SizedBox(
                          height: 260,
                          child: _TokensByModelBarChart(
                            data: controller.totalTokensByModel,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardSection(
                        title: 'Cost by model',
                        child: SizedBox(
                          height: 260,
                          child: _CostByModelBarChart(
                            data: controller.estimatedCostByModel,
                          ),
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

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final StatisticsController controller;

  String _money(double value) => value.toStringAsFixed(6);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _MiniCard(
          label: 'Total requests',
          value: '${controller.totalRequests}',
        ),
        _MiniCard(label: 'Total tokens', value: '${controller.totalTokens}'),
        _MiniCard(
          label: 'Total estimated USD',
          value: _money(controller.totalEstimatedCostUsd),
        ),
        _MiniCard(
          label: 'Total estimated RUB',
          value: _money(controller.totalEstimatedCostRub),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});
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
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _TokenLineChart extends StatelessWidget {
  const _TokenLineChart({required this.records});
  final List<UsageRecord> records;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> points = <FlSpot>[
      for (int i = 0; i < records.length; i++)
        FlSpot(i.toDouble(), records[i].totalTokens.toDouble()),
    ];
    final double maxY = math.max<double>(
      1,
      points.fold<double>(0, (p, e) => math.max(p, e.y)),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        titlesData: const FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: points,
            isCurved: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _CostLineChart extends StatelessWidget {
  const _CostLineChart({required this.records});
  final List<UsageRecord> records;

  @override
  Widget build(BuildContext context) {
    final List<UsageRecord> usd = records
        .where((r) => r.currencyCode == 'USD')
        .toList();
    final List<UsageRecord> rub = records
        .where((r) => r.currencyCode == 'RUB')
        .toList();

    final List<FlSpot> usdSpots = <FlSpot>[
      for (int i = 0; i < usd.length; i++)
        FlSpot(i.toDouble(), usd[i].estimatedCost),
    ];
    final List<FlSpot> rubSpots = <FlSpot>[
      for (int i = 0; i < rub.length; i++)
        FlSpot(i.toDouble(), rub[i].estimatedCost),
    ];

    final double usdMax = usdSpots.fold<double>(0, (p, e) => math.max(p, e.y));
    final double rubMax = rubSpots.fold<double>(0, (p, e) => math.max(p, e.y));
    final double maxY = math.max<double>(1, math.max(usdMax, rubMax));

    if (usdMax == 0 && rubMax == 0) {
      return const Center(child: Text('No cost data yet'));
    }

    final int longest = math.max(usdSpots.length, rubSpots.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          children: const <Widget>[
            _LegendDot(color: Colors.blue, label: 'USD'),
            _LegendDot(color: Colors.green, label: 'RUB'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (math.max(1, longest) - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              titlesData: const FlTitlesData(
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: usdSpots,
                  color: Colors.blue,
                  isCurved: true,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: rubSpots,
                  color: Colors.green,
                  isCurved: true,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _TokensByModelBarChart extends StatelessWidget {
  const _TokensByModelBarChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No statistics yet'));
    }
    final List<MapEntry<String, int>> items = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final double maxY = math.max<double>(1, items.first.value.toDouble());

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(toY: items[i].value.toDouble()),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                final String model = items[i].key;
                final String short = model.length > 12
                    ? '${model.substring(0, 12)}…'
                    : model;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Tooltip(
                    message: model,
                    child: Text(short, style: const TextStyle(fontSize: 10)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CostByModelBarChart extends StatelessWidget {
  const _CostByModelBarChart({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No statistics yet'));
    }

    final List<MapEntry<String, double>> items = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final double maxY = math.max<double>(1, items.first.value);

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(toY: items[i].value, color: Colors.deepPurple),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                final String model = items[i].key;
                final String short = model.length > 12
                    ? '${model.substring(0, 12)}…'
                    : model;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Tooltip(
                    message: model,
                    child: Text(short, style: const TextStyle(fontSize: 10)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
