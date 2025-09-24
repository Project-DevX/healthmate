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
          child: isCompact
              ? _buildCompactLayout(context)
              : _buildFullLayout(context),
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
              child: _buildStatColumn(
                'Current',
                vitalData.formattedCurrentValue,
              ),
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTrendIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getTrendColor(vitalData.trendDirection).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getTrendColor(vitalData.trendDirection).withValues(alpha: 0.3),
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
            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
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
          valueColor: AlwaysStoppedAnimation(
            _getTrendColor(vitalData.trendDirection),
          ),
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
