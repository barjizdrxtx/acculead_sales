import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

Widget StatusDistributon(
  List<double> percentages,
  List<String> labels,
  List<Color> colors,
  List<int> counts,
) {
  final totalLeads = counts.fold<int>(0, (sum, c) => sum + c);
  if (totalLeads == 0) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          "No data available",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  // Build PieChart sections
  final sections = List<PieChartSectionData>.generate(labels.length, (i) {
    final value = counts[i].toDouble();
    final pct = (value / totalLeads) * 100;
    return PieChartSectionData(
      color: colors[i],
      value: value,
      title: '${pct.toStringAsFixed(1)}%',
      radius: 60,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 40,
            sectionsSpace: 4,
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Legend
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: List.generate(labels.length, (i) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${labels[i]} (${counts[i]})',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          );
        }),
      ),
    ],
  );
}
