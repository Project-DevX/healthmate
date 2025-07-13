import 'package:flutter/material.dart';
import '../models/trend_data_models.dart';

class TrendChartWidget extends StatefulWidget {
  final VitalTrendData vitalData;
  final List<PredictionData> predictions;

  const TrendChartWidget({
    Key? key,
    required this.vitalData,
    required this.predictions,
  }) : super(key: key);

  @override
  State<TrendChartWidget> createState() => _TrendChartWidgetState();
}

class _TrendChartWidgetState extends State<TrendChartWidget> {
  bool _showPredictions = true;
  bool _showAnomalies = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVitalInfo(),
        const SizedBox(height: 16),
        _buildChartControls(),
        const SizedBox(height: 16),
        Expanded(child: _buildSimpleChart()),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildVitalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatVitalName(widget.vitalData.vitalName),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildVitalStat(
                  'Current',
                  widget.vitalData.formattedCurrentValue,
                ),
                const SizedBox(width: 24),
                _buildVitalStat('Average', widget.vitalData.formattedMeanValue),
                const SizedBox(width: 24),
                _buildVitalStat('Trend', widget.vitalData.trendInterpretation),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChartControls() {
    return Row(
      children: [
        if (widget.predictions.isNotEmpty)
          Row(
            children: [
              Checkbox(
                value: _showPredictions,
                onChanged: (value) =>
                    setState(() => _showPredictions = value ?? true),
              ),
              const Text('Show Predictions'),
            ],
          ),
        const SizedBox(width: 16),
        if (widget.vitalData.anomalies.isNotEmpty)
          Row(
            children: [
              Checkbox(
                value: _showAnomalies,
                onChanged: (value) =>
                    setState(() => _showAnomalies = value ?? true),
              ),
              const Text('Show Anomalies'),
            ],
          ),
      ],
    );
  }

  Widget _buildSimpleChart() {
    final dataPoints = widget.vitalData.dataPoints;

    if (dataPoints.isEmpty) {
      return const Center(child: Text('No data available for chart'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trend Visualization',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount:
                    dataPoints.length +
                    (_showPredictions ? widget.predictions.length : 0),
                itemBuilder: (context, index) {
                  if (index < dataPoints.length) {
                    final dataPoint = dataPoints[index];
                    final isAnomaly =
                        _showAnomalies &&
                        widget.vitalData.anomalies.any((a) => a.index == index);

                    return _buildDataPointRow(
                      date: dataPoint.formattedDate,
                      value: dataPoint.formattedValue,
                      isHistorical: true,
                      isAnomaly: isAnomaly,
                    );
                  } else {
                    final predictionIndex = index - dataPoints.length;
                    final prediction = widget.predictions[predictionIndex];

                    return _buildDataPointRow(
                      date: prediction.formattedDate,
                      value: prediction.formattedPredictedValue(
                        widget.vitalData.unit,
                      ),
                      isHistorical: false,
                      confidence: prediction.confidencePercentage,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPointRow({
    required String date,
    required String value,
    required bool isHistorical,
    bool isAnomaly = false,
    String? confidence,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHistorical
            ? (isAnomaly ? Colors.red[50] : Colors.blue[50])
            : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHistorical
              ? (isAnomaly ? Colors.red[200]! : Colors.blue[200]!)
              : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHistorical
                  ? (isAnomaly ? Colors.red : Theme.of(context).primaryColor)
                  : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (!isHistorical && confidence != null)
                  Text(
                    'Confidence: $confidence',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                if (isAnomaly)
                  Text(
                    'Anomaly detected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: [
        _buildLegendItem('Historical Data', Theme.of(context).primaryColor),
        if (_showPredictions && widget.predictions.isNotEmpty)
          _buildLegendItem('Predictions', Colors.orange),
        if (_showAnomalies && widget.vitalData.anomalies.isNotEmpty)
          _buildLegendItem('Anomalies', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _formatVitalName(String vital) {
    return vital
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
