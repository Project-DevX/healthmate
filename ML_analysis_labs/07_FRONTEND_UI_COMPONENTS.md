# Frontend UI Components - Trend Analysis Screens

## Overview

This document covers the implementation of user interface components for displaying trend analysis data, including interactive charts, trend summaries, and prediction visualizations.

## Implementation

### 1. Main Trend Analysis Screen

**File:** `lib/screens/trend_analysis_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/trend_analysis_service.dart';
import '../models/trend_data_models.dart';
import '../widgets/trend_chart_widget.dart';
import '../widgets/vital_info_card.dart';
import '../widgets/prediction_card.dart';

class TrendAnalysisScreen extends StatefulWidget {
  final String? labReportType;

  const TrendAnalysisScreen({Key? key, this.labReportType}) : super(key: key);

  @override
  State<TrendAnalysisScreen> createState() => _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends State<TrendAnalysisScreen> 
    with SingleTickerProviderStateMixin {
  List<TrendAnalysisData> _trendAnalyses = [];
  TrendAnalysisData? _selectedTrend;
  bool _isLoading = true;
  String? _selectedVital;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrendAnalyses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTrendAnalyses() async {
    try {
      setState(() => _isLoading = true);

      if (widget.labReportType != null) {
        final trend = await TrendAnalysisService.getTrendAnalysis(widget.labReportType!);
        if (trend != null) {
          setState(() {
            _trendAnalyses = [trend];
            _selectedTrend = trend;
          });
        }
      } else {
        final trends = await TrendAnalysisService.getAllTrendAnalyses();
        setState(() {
          _trendAnalyses = trends;
          if (trends.isNotEmpty) {
            _selectedTrend = trends.first;
          }
        });
      }

      if (_selectedTrend != null && _selectedTrend!.vitals.isNotEmpty) {
        _selectedVital = _selectedTrend!.vitals.keys.first;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trend analyses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshTrends() async {
    if (_selectedTrend != null) {
      try {
        await TrendAnalysisService.triggerManualAnalysis(_selectedTrend!.labReportType);
        await _loadTrendAnalyses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trends refreshed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to refresh trends: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Trends'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTrends,
          ),
        ],
        bottom: _selectedTrend != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                  Tab(text: 'Charts', icon: Icon(Icons.show_chart)),
                  Tab(text: 'Predictions', icon: Icon(Icons.trending_up)),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trendAnalyses.isEmpty
              ? _buildEmptyState()
              : _buildTrendAnalysisView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Trend Analysis Available',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload at least 5 lab reports of the same type\nto generate trend analysis',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Lab Reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisView() {
    return Column(
      children: [
        if (_trendAnalyses.length > 1) _buildTrendSelector(),
        if (_selectedTrend != null)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildChartsTab(),
                _buildPredictionsTab(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTrendSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: DropdownButtonFormField<TrendAnalysisData>(
        value: _selectedTrend,
        decoration: const InputDecoration(
          labelText: 'Select Lab Report Type',
          border: OutlineInputBorder(),
        ),
        items: _trendAnalyses.map((trend) {
          return DropdownMenuItem(
            value: trend,
            child: Text(trend.labReportType),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedTrend = value;
            if (value != null && value.vitals.isNotEmpty) {
              _selectedVital = value.vitals.keys.first;
            }
          });
        },
      ),
    );
  }

  Widget _buildOverviewTab() {
    final trend = _selectedTrend!;
    final summary = trend.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHealthScoreCard(summary),
          const SizedBox(height: 16),
          _buildTrendSummaryCard(trend),
          const SizedBox(height: 16),
          _buildVitalsOverview(trend),
          if (trend.hasAnomalies) ...[
            const SizedBox(height: 16),
            _buildAnomaliesCard(trend),
          ],
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    final trend = _selectedTrend!;
    if (trend.vitals.isEmpty) {
      return const Center(child: Text('No vital parameters available for charts'));
    }

    return Column(
      children: [
        if (trend.vitals.length > 1) _buildVitalSelector(),
        Expanded(child: _buildTrendChart()),
      ],
    );
  }

  Widget _buildPredictionsTab() {
    final trend = _selectedTrend!;
    final predictions = trend.predictions;

    if (predictions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crystal_ball, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No predictions available'),
            SizedBox(height: 8),
            Text(
              'Predictions require significant trends in the data',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: predictions.length,
      itemBuilder: (context, index) {
        final entry = predictions.entries.elementAt(index);
        return PredictionCard(
          vitalName: entry.key,
          predictions: entry.value,
          unit: trend.vitals[entry.key]?.unit ?? '',
        );
      },
    );
  }

  Widget _buildHealthScoreCard(TrendSummary summary) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  summary.healthStatus.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Score',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${summary.healthScore}/100',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(summary.healthScore),
                        ),
                      ),
                      Text(
                        summary.healthStatus.displayName,
                        style: TextStyle(
                          color: _getScoreColor(summary.healthScore),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: summary.healthScore / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(_getScoreColor(summary.healthScore)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSummaryCard(TrendAnalysisData trend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trend.labReportType,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Reports', '${trend.reportCount}', Icons.description),
                _buildSummaryItem('Timespan', trend.timespan.formattedTimeSpan, Icons.calendar_today),
                _buildSummaryItem('Vitals', '${trend.vitals.length}', Icons.favorite),
                _buildSummaryItem('Trends', '${trend.summary.significantTrends}', Icons.trending_up),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVitalsOverview(TrendAnalysisData trend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vital Parameters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...trend.vitals.entries.map((entry) => VitalInfoCard(
              vitalName: entry.key,
              vitalData: entry.value,
              isCompact: true,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesCard(TrendAnalysisData trend) {
    final allAnomalies = <String, List<AnomalyData>>{};
    
    for (final entry in trend.vitals.entries) {
      if (entry.value.anomalies.isNotEmpty) {
        allAnomalies[entry.key] = entry.value.anomalies;
      }
    }

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Anomalies Detected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...allAnomalies.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_formatVitalName(entry.key)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.value.length} anomal${entry.value.length == 1 ? 'y' : 'ies'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSelector() {
    final vitals = _selectedTrend!.vitals.keys.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        value: _selectedVital,
        decoration: const InputDecoration(
          labelText: 'Select Vital Parameter',
          border: OutlineInputBorder(),
        ),
        items: vitals.map((vital) {
          final vitalData = _selectedTrend!.vitals[vital]!;
          return DropdownMenuItem(
            value: vital,
            child: Row(
              children: [
                Expanded(child: Text(_formatVitalName(vital))),
                Text(
                  vitalData.formattedTrendDirection,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getTrendColor(vitalData.trendDirection),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedVital = value);
        },
      ),
    );
  }

  Widget _buildTrendChart() {
    if (_selectedVital == null) {
      return const Center(child: Text('Select a vital parameter to view chart'));
    }

    final vitalData = _selectedTrend!.vitals[_selectedVital]!;
    final predictions = _selectedTrend!.predictions[_selectedVital] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TrendChartWidget(
        vitalData: vitalData,
        predictions: predictions,
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getTrendColor(String trendDirection) {
    switch (trendDirection) {
      case 'increasing':
        return Colors.red;
      case 'decreasing':
        return Colors.orange;
      case 'stable':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatVitalName(String vital) {
    return vital
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
```

### 2. Trend Chart Widget

**File:** `lib/widgets/trend_chart_widget.dart`

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
        Expanded(child: _buildChart()),
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
                _buildVitalStat('Current', widget.vitalData.formattedCurrentValue),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
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
                onChanged: (value) => setState(() => _showPredictions = value ?? true),
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
                onChanged: (value) => setState(() => _showAnomalies = value ?? true),
              ),
              const Text('Show Anomalies'),
            ],
          ),
      ],
    );
  }

  Widget _buildChart() {
    final dataPoints = widget.vitalData.dataPoints;
    
    // Historical data points
    final spots = dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    // Prediction points
    final predictionSpots = _showPredictions
        ? widget.predictions.asMap().entries.map((entry) {
            return FlSpot(
              (dataPoints.length + entry.key).toDouble(),
              entry.value.predictedValue,
            );
          }).toList()
        : <FlSpot>[];

    // Anomaly spots
    final anomalySpots = _showAnomalies
        ? widget.vitalData.anomalies.map((anomaly) {
            if (anomaly.index < dataPoints.length) {
              return FlSpot(
                anomaly.index.toDouble(),
                dataPoints[anomaly.index].value,
              );
            }
            return null;
          }).where((spot) => spot != null).cast<FlSpot>().toList()
        : <FlSpot>[];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _calculateInterval(spots),
          verticalInterval: 1,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                
                if (index < dataPoints.length) {
                  final date = dataPoints[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.year.toString().substring(2)}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                } else if (_showPredictions && widget.predictions.isNotEmpty) {
                  final predIndex = index - dataPoints.length;
                  if (predIndex < widget.predictions.length) {
                    final date = widget.predictions[predIndex].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${date.month}/${date.year.toString().substring(2)}',
                        style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                      ),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          // Historical data line
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                // Highlight anomalies
                if (_showAnomalies && anomalySpots.any((anomaly) => 
                    anomaly.x == spot.x && anomaly.y == spot.y)) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.red,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                }
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).primaryColor,
                );
              },
            ),
          ),
          // Prediction line
          if (_showPredictions && predictionSpots.isNotEmpty)
            LineChartBarData(
              spots: predictionSpots,
              isCurved: true,
              color: Colors.blue[300],
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blue[300]!,
                  );
                },
              ),
              dashArray: [5, 5], // Dashed line for predictions
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final isHistorical = barSpot.x < dataPoints.length;
                final prefix = isHistorical ? 'Actual: ' : 'Predicted: ';
                
                String dateInfo = '';
                if (isHistorical && barSpot.x.toInt() < dataPoints.length) {
                  final date = dataPoints[barSpot.x.toInt()].date;
                  dateInfo = '\n${date.month}/${date.day}/${date.year}';
                } else if (!isHistorical && widget.predictions.isNotEmpty) {
                  final predIndex = barSpot.x.toInt() - dataPoints.length;
                  if (predIndex < widget.predictions.length) {
                    final prediction = widget.predictions[predIndex];
                    dateInfo = '\n${prediction.formattedDate} (${prediction.confidencePercentage})';
                  }
                }
                
                return LineTooltipItem(
                  '$prefix${barSpot.y.toStringAsFixed(1)} ${widget.vitalData.unit}$dateInfo',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: [
        _buildLegendItem('Historical Data', Theme.of(context).primaryColor, false),
        if (_showPredictions && widget.predictions.isNotEmpty)
          _buildLegendItem('Predictions', Colors.blue[300]!, true),
        if (_showAnomalies && widget.vitalData.anomalies.isNotEmpty)
          _buildLegendItem('Anomalies', Colors.red, false, isAnomaly: true),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDashed, {bool isAnomaly = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: isAnomaly ? 8 : 3,
          decoration: BoxDecoration(
            color: color,
            shape: isAnomaly ? BoxShape.circle : BoxShape.rectangle,
            border: isDashed ? Border.all(color: color, width: 1) : null,
          ),
          child: isDashed
              ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: color),
                  ),
                  child: CustomPaint(
                    painter: DashedLinePainter(color: color),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  double _calculateInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    
    final values = spots.map((spot) => spot.y).toList()..sort();
    final range = values.last - values.first;
    
    // Calculate a reasonable interval based on range
    if (range <= 10) return 1;
    if (range <= 50) return 5;
    if (range <= 100) return 10;
    if (range <= 500) return 50;
    return 100;
  }

  String _formatVitalName(String vital) {
    return vital
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### 3. Vital Info Card Widget

**File:** `lib/widgets/vital_info_card.dart`

```dart
import 'package:flutter/material.dart';
import '../models/trend_data_models.dart';

class VitalInfoCard extends StatelessWidget {
  final String vitalName;
  final VitalTrendData vitalData;
  final bool isCompact;
  final VoidCallback? onTap;

  const VitalInfoCard({
    Key? key,
    required this.vitalName,
    required this.vitalData,
    this.isCompact = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: isCompact ? 8 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: isCompact ? _buildCompactLayout(context) : _buildFullLayout(context),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatVitalName(vitalName),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                vitalData.formattedCurrentValue,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTrendIndicator(),
            const SizedBox(height: 4),
            Text(
              vitalData.trendDirection,
              style: TextStyle(
                fontSize: 12,
                color: _getTrendColor(vitalData.trendDirection),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _formatVitalName(vitalName),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _buildTrendIndicator(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatColumn('Current', vitalData.formattedCurrentValue),
            ),
            Expanded(
              child: _buildStatColumn('Average', vitalData.formattedMeanValue),
            ),
            Expanded(
              child: _buildStatColumn('Trend', vitalData.trendInterpretation),
            ),
          ],
        ),
        if (vitalData.anomalies.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAnomaliesIndicator(),
        ],
        const SizedBox(height: 8),
        _buildTrendBar(),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTrendIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTrendColor(vitalData.trendDirection).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getTrendColor(vitalData.trendDirection).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getTrendIcon(vitalData.trendDirection),
            size: 16,
            color: _getTrendColor(vitalData.trendDirection),
          ),
          const SizedBox(width: 4),
          Text(
            '${(vitalData.trendSignificance * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              color: _getTrendColor(vitalData.trendDirection),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 4),
          Text(
            '${vitalData.anomalies.length} anomal${vitalData.anomalies.length == 1 ? 'y' : 'ies'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trend Strength',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              vitalData.trendStrength.displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: vitalData.trendSignificance,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(_getTrendColor(vitalData.trendDirection)),
        ),
      ],
    );
  }

  Color _getTrendColor(String trendDirection) {
    switch (trendDirection) {
      case 'increasing':
        return Colors.red;
      case 'decreasing':
        return Colors.orange;
      case 'stable':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getTrendIcon(String trendDirection) {
    switch (trendDirection) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.remove;
    }
  }

  String _formatVitalName(String vital) {
    return vital
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
```

### 4. Prediction Card Widget

**File:** `lib/widgets/prediction_card.dart`

```dart
import 'package:flutter/material.dart';
import '../models/trend_data_models.dart';

class PredictionCard extends StatelessWidget {
  final String vitalName;
  final List<PredictionData> predictions;
  final String unit;

  const PredictionCard({
    Key? key,
    required this.vitalName,
    required this.predictions,
    required this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatVitalName(vitalName),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...predictions.map((prediction) => _buildPredictionRow(prediction)),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionRow(PredictionData prediction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${prediction.monthsAhead}M',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prediction.formattedPredictedValue(unit),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Range: ${prediction.confidenceInterval.formattedInterval} $unit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getConfidenceColor(prediction.confidence).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getConfidenceColor(prediction.confidence).withOpacity(0.3),
              ),
            ),
            child: Text(
              prediction.confidencePercentage,
              style: TextStyle(
                fontSize: 12,
                color: _getConfidenceColor(prediction.confidence),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatVitalName(String vital) {
    return vital
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
```

## Usage Examples

### Navigate to Trend Analysis

```dart
// From main dashboard
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrendAnalysisScreen(),
      ),
    );
  },
  child: const Text('View Health Trends'),
);

// For specific lab type
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrendAnalysisScreen(
          labReportType: 'Blood Sugar',
        ),
      ),
    );
  },
  child: const Text('View Blood Sugar Trends'),
);
```

### Use Individual Widgets

```dart
// Use vital info card in other screens
VitalInfoCard(
  vitalName: 'glucose',
  vitalData: trendData.vitals['glucose']!,
  onTap: () {
    // Navigate to detailed view
  },
);

// Use trend chart widget
TrendChartWidget(
  vitalData: vitalData,
  predictions: predictions,
);
```

## Key Features

1. **Tabbed Interface** - Overview, Charts, Predictions
2. **Interactive Charts** - Touch tooltips, zoom, pan
3. **Anomaly Highlighting** - Visual indicators for outliers
4. **Prediction Visualization** - Dashed lines with confidence intervals
5. **Health Score** - Overall health assessment
6. **Responsive Design** - Works on different screen sizes
7. **Error Handling** - Graceful error states and loading indicators

## Next Steps

Continue to **08_DEPENDENCIES_NAVIGATION.md** to set up the required packages and navigation structure.
