import 'package:flutter/material.dart';
import '../services/trend_analysis_service.dart' hide TrendSummary;
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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<TrendAnalysisData> _trendAnalyses = [];
  TrendAnalysisData? _selectedTrend;
  bool _isLoading = true;
  String? _selectedVital;
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

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
        final trend = await TrendAnalysisService.getTrendAnalysis(
          widget.labReportType!,
        );
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
        await TrendAnalysisService.triggerManualAnalysis(
          _selectedTrend!.labReportType,
        );
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
    super.build(context); // Required by AutomaticKeepAliveClientMixin
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
      return const Center(
        child: Text('No vital parameters available for charts'),
      );
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
            Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
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
              valueColor: AlwaysStoppedAnimation(
                _getScoreColor(summary.healthScore),
              ),
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
                _buildSummaryItem(
                  'Reports',
                  '${trend.reportCount}',
                  Icons.description,
                ),
                _buildSummaryItem(
                  'Timespan',
                  trend.timespan.formattedTimeSpan,
                  Icons.calendar_today,
                ),
                _buildSummaryItem(
                  'Vitals',
                  '${trend.vitals.length}',
                  Icons.favorite,
                ),
                _buildSummaryItem(
                  'Trends',
                  '${trend.summary.significantTrends}',
                  Icons.trending_up,
                ),
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
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
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
            ...trend.vitals.entries.map(
              (entry) => VitalInfoCard(
                vitalName: entry.key,
                vitalData: entry.value,
                isCompact: true,
              ),
            ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.orange[700]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...allAnomalies.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(_formatVitalName(entry.key))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
              ),
            ),
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
      return const Center(
        child: Text('Select a vital parameter to view chart'),
      );
    }

    final vitalData = _selectedTrend!.vitals[_selectedVital]!;
    final predictions = _selectedTrend!.predictions[_selectedVital] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TrendChartWidget(vitalData: vitalData, predictions: predictions),
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
