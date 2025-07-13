import 'package:cloud_firestore/cloud_firestore.dart';

/// Main trend analysis data model
class TrendAnalysisData {
  final String labReportType;
  final int reportCount;
  final TimeSpanData timespan;
  final Map<String, VitalTrendData> vitals;
  final Map<String, List<PredictionData>> predictions;
  final DateTime generatedAt;

  TrendAnalysisData({
    required this.labReportType,
    required this.reportCount,
    required this.timespan,
    required this.vitals,
    required this.predictions,
    required this.generatedAt,
  });

  factory TrendAnalysisData.fromFirestore(Map<String, dynamic> data) {
    final vitalsMap = <String, VitalTrendData>{};
    final vitalsData = data['vitals'] as Map<String, dynamic>? ?? {};

    vitalsData.forEach((key, value) {
      vitalsMap[key] = VitalTrendData.fromMap(Map<String, dynamic>.from(value));
    });

    final predictionsMap = <String, List<PredictionData>>{};
    final predictionsData = data['predictions'] as Map<String, dynamic>? ?? {};

    predictionsData.forEach((key, value) {
      final predictionsList = (value as List<dynamic>)
          .map(
            (item) => PredictionData.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
      predictionsMap[key] = predictionsList;
    });

    return TrendAnalysisData(
      labReportType: data['labReportType'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      timespan: TimeSpanData.fromMap(
        Map<String, dynamic>.from(data['timespan'] ?? {}),
      ),
      vitals: vitalsMap,
      predictions: predictionsMap,
      generatedAt: data['generatedAt'] is String
          ? DateTime.parse(data['generatedAt'])
          : (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Check if this analysis has significant trends
  bool get hasSignificantTrends {
    return vitals.values.any((vital) => vital.trendSignificance > 0.6);
  }

  /// Check if any vitals have anomalies
  bool get hasAnomalies {
    return vitals.values.any((vital) => vital.anomalies.isNotEmpty);
  }

  /// Get list of concerning vital trends
  List<String> get concerningTrends {
    return vitals.entries
        .where((entry) => entry.value.isConcerning)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get the most recent vital values
  Map<String, double> get latestVitalValues {
    final values = <String, double>{};
    vitals.forEach((key, vital) {
      values[key] = vital.currentValue;
    });
    return values;
  }

  /// Get summary statistics
  TrendSummary get summary {
    return TrendSummary(
      totalVitals: vitals.length,
      significantTrends: vitals.values
          .where((v) => v.trendSignificance > 0.6)
          .length,
      anomaliesDetected: vitals.values.fold(
        0,
        (sum, v) => sum + v.anomalies.length,
      ),
      predictionsAvailable: predictions.values.fold(
        0,
        (sum, p) => sum + p.length,
      ),
      timeSpanMonths: timespan.months,
    );
  }

  /// Convert to JSON for storage or transmission
  Map<String, dynamic> toJson() {
    final vitalsJson = <String, dynamic>{};
    vitals.forEach((key, value) {
      vitalsJson[key] = value.toJson();
    });

    final predictionsJson = <String, dynamic>{};
    predictions.forEach((key, value) {
      predictionsJson[key] = value.map((p) => p.toJson()).toList();
    });

    return {
      'labReportType': labReportType,
      'reportCount': reportCount,
      'timespan': timespan.toJson(),
      'vitals': vitalsJson,
      'predictions': predictionsJson,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

/// Individual vital parameter trend data
class VitalTrendData {
  final String vitalName;
  final int dataCount;
  final double currentValue;
  final double meanValue;
  final double standardDeviation;
  final String trendDirection;
  final double trendSlope;
  final double trendSignificance;
  final List<AnomalyData> anomalies;
  final List<DataPointData> dataPoints;
  final String unit;
  final DateRangeData dateRange;

  VitalTrendData({
    required this.vitalName,
    required this.dataCount,
    required this.currentValue,
    required this.meanValue,
    required this.standardDeviation,
    required this.trendDirection,
    required this.trendSlope,
    required this.trendSignificance,
    required this.anomalies,
    required this.dataPoints,
    required this.unit,
    required this.dateRange,
  });

  factory VitalTrendData.fromMap(Map<String, dynamic> data) {
    return VitalTrendData(
      vitalName: data['vitalName'] ?? '',
      dataCount: data['dataCount'] ?? 0,
      currentValue: (data['currentValue'] ?? 0).toDouble(),
      meanValue: (data['meanValue'] ?? 0).toDouble(),
      standardDeviation: (data['standardDeviation'] ?? 0).toDouble(),
      trendDirection: data['trendDirection'] ?? 'stable',
      trendSlope: (data['trendSlope'] ?? 0).toDouble(),
      trendSignificance: (data['trendSignificance'] ?? 0).toDouble(),
      anomalies: (data['anomalies'] as List<dynamic>? ?? [])
          .map((item) => AnomalyData.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      dataPoints: (data['dataPoints'] as List<dynamic>? ?? [])
          .map((item) => DataPointData.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      unit: data['unit'] ?? '',
      dateRange: DateRangeData.fromMap(
        Map<String, dynamic>.from(data['dateRange'] ?? {}),
      ),
    );
  }

  /// Check if this vital trend is concerning
  bool get isConcerning {
    return trendSignificance > 0.7 &&
            (trendDirection == 'increasing' ||
                trendDirection == 'decreasing') ||
        anomalies.any((anomaly) => anomaly.severity == 'high');
  }

  /// Get formatted trend direction with emoji
  String get formattedTrendDirection {
    switch (trendDirection) {
      case 'increasing':
        return 'Trending Up ↗️';
      case 'decreasing':
        return 'Trending Down ↘️';
      case 'stable':
        return 'Stable ➡️';
      default:
        return trendDirection;
    }
  }

  /// Get human-readable trend interpretation
  String get trendInterpretation {
    if (trendSignificance < 0.3) {
      return 'No clear trend detected';
    } else if (trendSignificance < 0.6) {
      return 'Mild $trendDirection trend';
    } else if (trendSignificance < 0.8) {
      return 'Moderate $trendDirection trend';
    } else {
      return 'Strong $trendDirection trend';
    }
  }

  /// Get formatted current value
  String get formattedCurrentValue {
    return '${currentValue.toStringAsFixed(1)} $unit';
  }

  /// Get formatted mean value
  String get formattedMeanValue {
    return '${meanValue.toStringAsFixed(1)} $unit';
  }

  /// Get coefficient of variation (relative variability)
  double get coefficientOfVariation {
    return meanValue != 0 ? (standardDeviation / meanValue) * 100 : 0;
  }

  /// Get trend strength category
  TrendStrength get trendStrength {
    if (trendSignificance < 0.3) return TrendStrength.none;
    if (trendSignificance < 0.6) return TrendStrength.weak;
    if (trendSignificance < 0.8) return TrendStrength.moderate;
    return TrendStrength.strong;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'vitalName': vitalName,
      'dataCount': dataCount,
      'currentValue': currentValue,
      'meanValue': meanValue,
      'standardDeviation': standardDeviation,
      'trendDirection': trendDirection,
      'trendSlope': trendSlope,
      'trendSignificance': trendSignificance,
      'anomalies': anomalies.map((a) => a.toJson()).toList(),
      'dataPoints': dataPoints.map((d) => d.toJson()).toList(),
      'unit': unit,
      'dateRange': dateRange.toJson(),
    };
  }
}

/// Prediction data for future values
class PredictionData {
  final DateTime date;
  final double predictedValue;
  final ConfidenceIntervalData confidenceInterval;
  final double confidence;
  final int monthsAhead;

  PredictionData({
    required this.date,
    required this.predictedValue,
    required this.confidenceInterval,
    required this.confidence,
    required this.monthsAhead,
  });

  factory PredictionData.fromMap(Map<String, dynamic> data) {
    return PredictionData(
      date: DateTime.parse(data['date']),
      predictedValue: (data['predictedValue'] ?? 0).toDouble(),
      confidenceInterval: ConfidenceIntervalData.fromMap(
        Map<String, dynamic>.from(data['confidenceInterval'] ?? {}),
      ),
      confidence: (data['confidence'] ?? 0).toDouble(),
      monthsAhead: data['monthsAhead'] ?? 0,
    );
  }

  /// Get formatted date string
  String get formattedDate {
    return '${date.month}/${date.year}';
  }

  /// Get confidence as percentage
  String get confidencePercentage {
    return '${(confidence * 100).round()}%';
  }

  /// Get formatted predicted value with unit
  String formattedPredictedValue(String unit) {
    return '${predictedValue.toStringAsFixed(1)} $unit';
  }

  /// Get confidence level category
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.8) return ConfidenceLevel.high;
    if (confidence >= 0.6) return ConfidenceLevel.medium;
    if (confidence >= 0.4) return ConfidenceLevel.low;
    return ConfidenceLevel.veryLow;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'predictedValue': predictedValue,
      'confidenceInterval': confidenceInterval.toJson(),
      'confidence': confidence,
      'monthsAhead': monthsAhead,
    };
  }
}

/// Time span data
class TimeSpanData {
  final int days;
  final int months;
  final DateTime startDate;
  final DateTime endDate;

  TimeSpanData({
    required this.days,
    required this.months,
    required this.startDate,
    required this.endDate,
  });

  factory TimeSpanData.fromMap(Map<String, dynamic> data) {
    return TimeSpanData(
      days: data['days'] ?? 0,
      months: data['months'] ?? 0,
      startDate: DateTime.parse(
        data['startDate'] ?? DateTime.now().toIso8601String(),
      ),
      endDate: DateTime.parse(
        data['endDate'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Get formatted time span
  String get formattedTimeSpan {
    if (months > 0) {
      return '$months month${months == 1 ? '' : 's'}';
    } else if (days > 0) {
      return '$days day${days == 1 ? '' : 's'}';
    } else {
      return 'Less than a day';
    }
  }

  /// Get date range string
  String get dateRangeString {
    final start = '${startDate.month}/${startDate.day}/${startDate.year}';
    final end = '${endDate.month}/${endDate.day}/${endDate.year}';
    return '$start - $end';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'days': days,
      'months': months,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }
}

/// Anomaly detection data
class AnomalyData {
  final int index;
  final double value;
  final double zScore;
  final String severity;

  AnomalyData({
    required this.index,
    required this.value,
    required this.zScore,
    required this.severity,
  });

  factory AnomalyData.fromMap(Map<String, dynamic> data) {
    return AnomalyData(
      index: data['index'] ?? 0,
      value: (data['value'] ?? 0).toDouble(),
      zScore: (data['zScore'] ?? 0).toDouble(),
      severity: data['severity'] ?? 'low',
    );
  }

  /// Get severity level
  AnomalySeverity get severityLevel {
    switch (severity.toLowerCase()) {
      case 'high':
        return AnomalySeverity.high;
      case 'moderate':
        return AnomalySeverity.moderate;
      case 'low':
        return AnomalySeverity.low;
      default:
        return AnomalySeverity.low;
    }
  }

  /// Get formatted z-score
  String get formattedZScore {
    return '${zScore.toStringAsFixed(2)}σ';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'value': value,
      'zScore': zScore,
      'severity': severity,
    };
  }
}

/// Individual data point
class DataPointData {
  final DateTime date;
  final double value;
  final String unit;
  final String status;
  final String reportId;

  DataPointData({
    required this.date,
    required this.value,
    required this.unit,
    required this.status,
    required this.reportId,
  });

  factory DataPointData.fromMap(Map<String, dynamic> data) {
    return DataPointData(
      date: DateTime.parse(data['date']),
      value: (data['value'] ?? 0).toDouble(),
      unit: data['unit'] ?? '',
      status: data['status'] ?? 'normal',
      reportId: data['reportId'] ?? '',
    );
  }

  /// Get formatted date
  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Get formatted value with unit
  String get formattedValue {
    return '${value.toStringAsFixed(1)} $unit';
  }

  /// Get status category
  TestStatus get statusCategory {
    switch (status.toLowerCase()) {
      case 'high':
        return TestStatus.high;
      case 'low':
        return TestStatus.low;
      case 'normal':
        return TestStatus.normal;
      case 'abnormal':
        return TestStatus.abnormal;
      default:
        return TestStatus.normal;
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'value': value,
      'unit': unit,
      'status': status,
      'reportId': reportId,
    };
  }
}

/// Date range data
class DateRangeData {
  final DateTime start;
  final DateTime end;

  DateRangeData({required this.start, required this.end});

  factory DateRangeData.fromMap(Map<String, dynamic> data) {
    return DateRangeData(
      start: DateTime.parse(data['start'] ?? DateTime.now().toIso8601String()),
      end: DateTime.parse(data['end'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Get duration in days
  int get durationInDays {
    return end.difference(start).inDays;
  }

  /// Get formatted range
  String get formattedRange {
    final startStr = '${start.month}/${start.day}/${start.year}';
    final endStr = '${end.month}/${end.day}/${end.year}';
    return '$startStr - $endStr';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {'start': start.toIso8601String(), 'end': end.toIso8601String()};
  }
}

/// Confidence interval data
class ConfidenceIntervalData {
  final double lower;
  final double upper;

  ConfidenceIntervalData({required this.lower, required this.upper});

  factory ConfidenceIntervalData.fromMap(Map<String, dynamic> data) {
    return ConfidenceIntervalData(
      lower: (data['lower'] ?? 0).toDouble(),
      upper: (data['upper'] ?? 0).toDouble(),
    );
  }

  /// Get interval width
  double get width {
    return upper - lower;
  }

  /// Get formatted interval
  String get formattedInterval {
    return '${lower.toStringAsFixed(1)} - ${upper.toStringAsFixed(1)}';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {'lower': lower, 'upper': upper};
  }
}

/// Trend summary statistics
class TrendSummary {
  final int totalVitals;
  final int significantTrends;
  final int anomaliesDetected;
  final int predictionsAvailable;
  final int timeSpanMonths;

  TrendSummary({
    required this.totalVitals,
    required this.significantTrends,
    required this.anomaliesDetected,
    required this.predictionsAvailable,
    required this.timeSpanMonths,
  });

  /// Get overall health score (0-100)
  int get healthScore {
    if (totalVitals == 0) return 0;

    // Base score
    int score = 70;

    // Reduce score for concerning trends
    if (significantTrends > 0) {
      score -= (significantTrends * 10);
    }

    // Reduce score for anomalies
    if (anomaliesDetected > 0) {
      score -= (anomaliesDetected * 5);
    }

    // Bonus for stable trends
    if (significantTrends == 0 && anomaliesDetected == 0) {
      score += 20;
    }

    return score.clamp(0, 100);
  }

  /// Get health status
  HealthStatus get healthStatus {
    final score = healthScore;
    if (score >= 80) return HealthStatus.excellent;
    if (score >= 60) return HealthStatus.good;
    if (score >= 40) return HealthStatus.fair;
    return HealthStatus.concerning;
  }
}

/// Enums for categorization
enum TrendStrength { none, weak, moderate, strong }

enum ConfidenceLevel { veryLow, low, medium, high }

enum AnomalySeverity { low, moderate, high }

enum TestStatus { normal, abnormal, high, low }

enum HealthStatus { excellent, good, fair, concerning }

/// Extension methods for enums
extension TrendStrengthExtension on TrendStrength {
  String get displayName {
    switch (this) {
      case TrendStrength.none:
        return 'No Trend';
      case TrendStrength.weak:
        return 'Weak Trend';
      case TrendStrength.moderate:
        return 'Moderate Trend';
      case TrendStrength.strong:
        return 'Strong Trend';
    }
  }
}

extension ConfidenceLevelExtension on ConfidenceLevel {
  String get displayName {
    switch (this) {
      case ConfidenceLevel.veryLow:
        return 'Very Low';
      case ConfidenceLevel.low:
        return 'Low';
      case ConfidenceLevel.medium:
        return 'Medium';
      case ConfidenceLevel.high:
        return 'High';
    }
  }
}

extension HealthStatusExtension on HealthStatus {
  String get displayName {
    switch (this) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.fair:
        return 'Fair';
      case HealthStatus.concerning:
        return 'Needs Attention';
    }
  }

  String get emoji {
    switch (this) {
      case HealthStatus.excellent:
        return '🟢';
      case HealthStatus.good:
        return '🟡';
      case HealthStatus.fair:
        return '🟠';
      case HealthStatus.concerning:
        return '🔴';
    }
  }
}
