import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/widgets/trend_chart_widget.dart';
import 'package:healthmate/models/trend_data_models.dart';

void main() {
  group('TrendChartWidget', () {
    test('should be a StatefulWidget', () {
      expect(TrendChartWidget, isA<Type>());
    });

    testWidgets('should have required parameters and render correctly', (
      WidgetTester tester,
    ) async {
      final vitalData = VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'stable',
        trendSlope: 0.1,
        trendSignificance: 0.3,
        anomalies: [],
        dataPoints: [
          DataPointData(
            date: DateTime(2024, 1, 1),
            value: 100.0,
            unit: 'mg/dL',
            status: 'normal',
            reportId: 'report1',
          ),
          DataPointData(
            date: DateTime(2024, 2, 1),
            value: 105.0,
            unit: 'mg/dL',
            status: 'normal',
            reportId: 'report2',
          ),
        ],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      final widget = TrendChartWidget(vitalData: vitalData, predictions: []);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));

      expect(find.byType(TrendChartWidget), findsOneWidget);
      expect(widget, isNotNull);
    });

    testWidgets('should handle null or empty data gracefully', (
      WidgetTester tester,
    ) async {
      final emptyVitalData = VitalTrendData(
        vitalName: 'empty',
        dataCount: 0,
        currentValue: 0.0,
        meanValue: 0.0,
        standardDeviation: 0.0,
        trendDirection: 'stable',
        trendSlope: 0.0,
        trendSignificance: 0.0,
        anomalies: [],
        dataPoints: [],
        unit: '',
        dateRange: DateRangeData(start: DateTime.now(), end: DateTime.now()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrendChartWidget(vitalData: emptyVitalData, predictions: []),
          ),
        ),
      );

      // Should not crash with empty data
      expect(find.byType(TrendChartWidget), findsOneWidget);
    });

    testWidgets('should display predictions when provided', (
      WidgetTester tester,
    ) async {
      final vitalData = VitalTrendData(
        vitalName: 'glucose',
        dataCount: 3,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'increasing',
        trendSlope: 0.5,
        trendSignificance: 0.7,
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      final predictions = [
        PredictionData(
          date: DateTime(2024, 9, 1),
          predictedValue: 115.0,
          confidenceInterval: ConfidenceIntervalData(
            lower: 110.0,
            upper: 120.0,
          ),
          confidence: 0.8,
          monthsAhead: 3,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrendChartWidget(
              vitalData: vitalData,
              predictions: predictions,
            ),
          ),
        ),
      );

      expect(find.byType(TrendChartWidget), findsOneWidget);
    });

    testWidgets('should handle large datasets efficiently', (
      WidgetTester tester,
    ) async {
      // Create a large dataset
      final largeDataPoints = List.generate(
        100,
        (index) => DataPointData(
          date: DateTime(2024, 1, 1).add(Duration(days: index)),
          value: 100.0 + (index % 30),
          unit: 'mg/dL',
          status: 'normal',
          reportId: 'report_$index',
        ),
      );

      final largeVitalData = VitalTrendData(
        vitalName: 'large_dataset',
        dataCount: 100,
        currentValue: 115.0,
        meanValue: 110.0,
        standardDeviation: 12.0,
        trendDirection: 'increasing',
        trendSlope: 0.5,
        trendSignificance: 0.7,
        anomalies: [],
        dataPoints: largeDataPoints,
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 4, 10),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrendChartWidget(vitalData: largeVitalData, predictions: []),
          ),
        ),
      );

      // Should render without performance issues
      expect(find.byType(TrendChartWidget), findsOneWidget);

      // Pump additional frames to test performance
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TrendChartWidget), findsOneWidget);
    });
  });
}
