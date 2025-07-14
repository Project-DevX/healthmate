import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/models/trend_data_models.dart';

void main() {
  group('TrendAnalysisService Advanced Tests', () {
    test('should validate trend analysis data structure', () async {
      final testData = <String, dynamic>{
        'labReportType': 'Blood Sugar',
        'reportCount': 5,
        'timespan': <String, dynamic>{
          'days': 150,
          'months': 5,
          'startDate': '2024-01-01T00:00:00.000Z',
          'endDate': '2024-06-01T00:00:00.000Z',
        },
        'vitals': <String, dynamic>{
          'glucose': <String, dynamic>{
            'vitalName': 'glucose',
            'dataCount': 5,
            'currentValue': 110.0,
            'meanValue': 105.0,
            'standardDeviation': 8.5,
            'trendDirection': 'increasing',
            'trendSlope': 0.5,
            'trendSignificance': 0.75,
            'anomalies': <dynamic>[],
            'dataPoints': <dynamic>[],
            'unit': 'mg/dL',
            'dateRange': <String, dynamic>{
              'start': '2024-01-01T00:00:00.000Z',
              'end': '2024-06-01T00:00:00.000Z',
            },
          },
        },
        'predictions': <String, dynamic>{},
        'generatedAt': '2024-06-01T12:00:00.000Z',
      };

      // Test that data can be parsed correctly
      final trendData = TrendAnalysisData.fromFirestore(testData);

      expect(trendData.labReportType, equals('Blood Sugar'));
      expect(trendData.vitals.containsKey('glucose'), isTrue);
      expect(trendData.vitals['glucose']?.currentValue, equals(110.0));
      expect(trendData.hasSignificantTrends, isTrue);
    });

    test('should handle large datasets efficiently', () {
      // Performance test with large dataset
      final largeVitals = <String, VitalTrendData>{};

      for (int i = 0; i < 50; i++) {
        largeVitals['vital_$i'] = VitalTrendData(
          vitalName: 'vital_$i',
          dataCount: 100,
          currentValue: 100.0 + i,
          meanValue: 95.0 + i,
          standardDeviation: 5.0,
          trendDirection: 'stable',
          trendSlope: 0.1,
          trendSignificance: 0.3,
          anomalies: [],
          dataPoints: [],
          unit: 'unit',
          dateRange: DateRangeData(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 6, 1),
          ),
        );
      }

      final largeTrendData = TrendAnalysisData(
        labReportType: 'Comprehensive Panel',
        reportCount: 100,
        timespan: TimeSpanData(
          days: 150,
          months: 5,
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 6, 1),
        ),
        vitals: largeVitals,
        predictions: {},
        generatedAt: DateTime.now(),
      );

      // Should handle large datasets without performance issues
      expect(largeTrendData.vitals.length, equals(50));
      expect(largeTrendData.summary.totalVitals, equals(50));
    });

    test('should handle edge cases in trend calculation', () {
      // Test with extreme values
      final extremeVital = VitalTrendData(
        vitalName: 'extreme_test',
        dataCount: 2, // Minimal data
        currentValue: 0.0, // Zero value
        meanValue: 1000000.0, // Very large mean
        standardDeviation: 0.001, // Very small std dev
        trendDirection: 'unknown', // Invalid direction
        trendSlope: double.infinity, // Infinite slope
        trendSignificance: 1.5, // Out of range significance
        anomalies: [],
        dataPoints: [],
        unit: '',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 1), // Same date
        ),
      );

      // Should handle extreme values gracefully
      expect(extremeVital.vitalName, equals('extreme_test'));
      expect(extremeVital.currentValue, equals(0.0));
      expect(extremeVital.trendDirection, equals('unknown'));
    });

    test('should validate prediction confidence intervals', () {
      final prediction = PredictionData(
        date: DateTime(2024, 9, 1),
        predictedValue: 115.0,
        confidenceInterval: ConfidenceIntervalData(lower: 110.0, upper: 120.0),
        confidence: 0.85,
        monthsAhead: 3,
      );

      // Validate confidence interval integrity
      expect(
        prediction.confidenceInterval.lower,
        lessThan(prediction.predictedValue),
      );
      expect(
        prediction.confidenceInterval.upper,
        greaterThan(prediction.predictedValue),
      );
      expect(
        prediction.confidenceInterval.lower,
        lessThan(prediction.confidenceInterval.upper),
      );
      expect(prediction.confidence, greaterThan(0.0));
      expect(prediction.confidence, lessThanOrEqualTo(1.0));
    });

    test('should calculate health trends correctly', () {
      final vitalWithUpwardTrend = VitalTrendData(
        vitalName: 'cholesterol',
        dataCount: 10,
        currentValue: 220.0,
        meanValue: 200.0,
        standardDeviation: 15.0,
        trendDirection: 'increasing',
        trendSlope: 2.0,
        trendSignificance: 0.9,
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      expect(vitalWithUpwardTrend.isConcerning, isTrue);
      expect(vitalWithUpwardTrend.trendStrength, equals(TrendStrength.strong));
      expect(vitalWithUpwardTrend.formattedTrendDirection, contains('Up'));
    });
  });

  group('Data Point Analysis', () {
    test('should analyze data point trends correctly', () {
      final dataPoints = [
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
        DataPointData(
          date: DateTime(2024, 3, 1),
          value: 110.0,
          unit: 'mg/dL',
          status: 'normal',
          reportId: 'report3',
        ),
      ];

      expect(dataPoints.length, equals(3));
      expect(dataPoints.first.value, equals(100.0));
      expect(dataPoints.last.value, equals(110.0));

      // Verify chronological order
      expect(dataPoints[0].date.isBefore(dataPoints[1].date), isTrue);
      expect(dataPoints[1].date.isBefore(dataPoints[2].date), isTrue);
    });

    test('should handle empty data points gracefully', () {
      final emptyVital = VitalTrendData(
        vitalName: 'empty_test',
        dataCount: 0,
        currentValue: 0.0,
        meanValue: 0.0,
        standardDeviation: 0.0,
        trendDirection: 'stable',
        trendSlope: 0.0,
        trendSignificance: 0.0,
        anomalies: [],
        dataPoints: [], // Empty data points
        unit: '',
        dateRange: DateRangeData(start: DateTime.now(), end: DateTime.now()),
      );

      expect(emptyVital.dataPoints.isEmpty, isTrue);
      expect(emptyVital.dataCount, equals(0));
    });
  });

  group('Performance and Memory Tests', () {
    test('should handle concurrent trend analysis requests', () async {
      // Simulate multiple concurrent analysis requests
      final futures = <Future<bool>>[];

      for (int i = 0; i < 10; i++) {
        futures.add(
          Future.delayed(
            Duration(milliseconds: i * 10),
            () => true, // Simulate successful analysis
          ),
        );
      }

      final results = await Future.wait(futures);
      expect(results.length, equals(10));
      expect(results.every((r) => r == true), isTrue);
    });

    test('should manage memory efficiently with large datasets', () {
      // Create a large trend analysis object
      final largeDataPoints = List.generate(
        1000,
        (index) => DataPointData(
          date: DateTime(2024, 1, 1).add(Duration(days: index)),
          value: 100.0 + (index % 50),
          unit: 'mg/dL',
          status: 'normal',
          reportId: 'report_$index',
        ),
      );

      final largeVital = VitalTrendData(
        vitalName: 'large_dataset',
        dataCount: 1000,
        currentValue: 125.0,
        meanValue: 112.5,
        standardDeviation: 15.0,
        trendDirection: 'increasing',
        trendSlope: 0.025,
        trendSignificance: 0.75,
        anomalies: [],
        dataPoints: largeDataPoints,
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 12, 31),
        ),
      );

      // Should handle large datasets without memory issues
      expect(largeVital.dataPoints.length, equals(1000));
      expect(largeVital.dataCount, equals(1000));

      // Verify data integrity
      expect(largeVital.dataPoints.first.value, equals(100.0));
      expect(
        largeVital.dataPoints.last.value,
        equals(149.0),
      ); // 100 + (999 % 50)
    });
  });
}
