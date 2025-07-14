import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/models/trend_data_models.dart';

void main() {
  test('Simple TrendAnalysisData creation test', () {
    final simple = TrendAnalysisData(
      labReportType: 'Blood Sugar',
      reportCount: 5,
      timespan: TimeSpanData(
        days: 150,
        months: 5,
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 6, 1),
      ),
      vitals: {},
      predictions: {},
      generatedAt: DateTime.now(),
    );

    expect(simple.labReportType, equals('Blood Sugar'));
    expect(simple.reportCount, equals(5));
  });
}
