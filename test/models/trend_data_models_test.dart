import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/models/trend_data_models.dart';

void main() {
  group('TrendAnalysisData', () {
    test('should parse from Firestore data correctly', () {
      final firestoreData = <String, dynamic>{
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

      final trendData = TrendAnalysisData.fromFirestore(firestoreData);

      expect(trendData.labReportType, equals('Blood Sugar'));
      expect(trendData.reportCount, equals(5));
      expect(trendData.vitals.length, equals(1));
      expect(trendData.vitals['glucose']?.currentValue, equals(110.0));
      expect(trendData.hasSignificantTrends, isTrue);
    });

    test('should calculate health summary correctly', () {
      final trendData = _createSampleTrendData();
      final summary = trendData.summary;

      expect(summary.totalVitals, equals(1));
      expect(summary.healthScore, greaterThan(0));
      expect(summary.healthScore, lessThanOrEqualTo(100));
    });

    test('should handle empty vitals data', () {
      final trendData = TrendAnalysisData(
        labReportType: 'Empty Test',
        reportCount: 0,
        timespan: TimeSpanData(
          days: 0,
          months: 0,
          startDate: DateTime.now(),
          endDate: DateTime.now(),
        ),
        vitals: {},
        predictions: {},
        generatedAt: DateTime.now(),
      );

      expect(trendData.hasSignificantTrends, isFalse);
      expect(trendData.summary.totalVitals, equals(0));
    });
  });

  group('VitalTrendData', () {
    test('should identify concerning trends', () {
      final vitalData = VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'increasing',
        trendSlope: 2.0,
        trendSignificance: 0.85, // High significance
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      expect(vitalData.isConcerning, isTrue);
      expect(vitalData.trendStrength, equals(TrendStrength.strong));
    });

    test('should identify stable trends', () {
      final vitalData = VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 105.0,
        meanValue: 105.0,
        standardDeviation: 2.0,
        trendDirection: 'stable',
        trendSlope: 0.1,
        trendSignificance: 0.2, // Very low significance
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      expect(vitalData.isConcerning, isFalse);
      expect(
        vitalData.trendStrength,
        equals(TrendStrength.none),
      ); // Changed to none for very low significance
    });

    test('should handle anomalies correctly', () {
      final anomaly = AnomalyData(
        index: 3,
        value: 180.0,
        severity: 'high',
        zScore: 3.2,
      );

      final vitalData = VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'stable',
        trendSlope: 0.1,
        trendSignificance: 0.3,
        anomalies: [anomaly],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      );

      expect(vitalData.anomalies.isNotEmpty, isTrue);
      expect(vitalData.anomalies.length, equals(1));
      expect(vitalData.anomalies.first.severity, equals('high'));
    });
  });

  group('DataPointData', () {
    test('should create from Map correctly', () {
      final json = {
        'date': '2024-01-01T00:00:00.000Z',
        'value': 105.0,
        'unit': 'mg/dL',
        'status': 'normal',
        'reportId': 'report123',
      };

      final dataPoint = DataPointData.fromMap(json);

      expect(dataPoint.value, equals(105.0));
      expect(dataPoint.unit, equals('mg/dL'));
      expect(dataPoint.status, equals('normal'));
      expect(dataPoint.reportId, equals('report123'));
    });

    test('should handle missing optional fields', () {
      final json = {'date': '2024-01-01T00:00:00.000Z', 'value': 105.0};

      final dataPoint = DataPointData.fromMap(json);

      expect(dataPoint.value, equals(105.0));
      expect(dataPoint.unit, equals(''));
      expect(dataPoint.status, equals('normal')); // Default from fromMap
      expect(dataPoint.reportId, equals(''));
    });
  });

  group('PredictionData', () {
    test('should create prediction with confidence interval', () {
      final prediction = PredictionData(
        date: DateTime(2024, 9, 1),
        predictedValue: 115.0,
        confidenceInterval: ConfidenceIntervalData(lower: 110.0, upper: 120.0),
        confidence: 0.85,
        monthsAhead: 3,
      );

      expect(prediction.predictedValue, equals(115.0));
      expect(prediction.confidence, equals(0.85));
      expect(prediction.monthsAhead, equals(3));
      expect(prediction.confidenceInterval.lower, equals(110.0));
      expect(prediction.confidenceInterval.upper, equals(120.0));
    });

    test('should identify high confidence predictions', () {
      final highConfidence = PredictionData(
        date: DateTime(2024, 9, 1),
        predictedValue: 115.0,
        confidenceInterval: ConfidenceIntervalData(lower: 110.0, upper: 120.0),
        confidence: 0.9,
        monthsAhead: 3,
      );

      final lowConfidence = PredictionData(
        date: DateTime(2024, 9, 1),
        predictedValue: 115.0,
        confidenceInterval: ConfidenceIntervalData(lower: 100.0, upper: 130.0),
        confidence: 0.6,
        monthsAhead: 3,
      );

      expect(highConfidence.confidenceLevel, equals(ConfidenceLevel.high));
      expect(lowConfidence.confidenceLevel, equals(ConfidenceLevel.medium));
    });
  });
}

TrendAnalysisData _createSampleTrendData() {
  return TrendAnalysisData(
    labReportType: 'Blood Sugar',
    reportCount: 5,
    timespan: TimeSpanData(
      days: 150,
      months: 5,
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2024, 6, 1),
    ),
    vitals: {
      'glucose': VitalTrendData(
        vitalName: 'glucose',
        dataCount: 5,
        currentValue: 110.0,
        meanValue: 105.0,
        standardDeviation: 8.5,
        trendDirection: 'stable',
        trendSlope: 0.1,
        trendSignificance: 0.3,
        anomalies: [],
        dataPoints: [],
        unit: 'mg/dL',
        dateRange: DateRangeData(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 6, 1),
        ),
      ),
    },
    predictions: {},
    generatedAt: DateTime.now(),
  );
}
