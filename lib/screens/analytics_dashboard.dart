// lib/screens/analytics_dashboard.dart
import 'package:flutter/material.dart';
import '../services/enhanced_firebase_service.dart';
import '../theme/app_theme.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  Map<String, dynamic>? analyticsData;
  Map<String, dynamic>? healthTimeline;
  List<dynamic>? recommendations;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Load analytics, timeline, and recommendations in parallel
      final results = await Future.wait([
        EnhancedFirebaseService.getUserAnalytics(),
        EnhancedFirebaseService.generateHealthTimeline(),
        EnhancedFirebaseService.getHealthRecommendations(),
      ]);

      setState(() {
        analyticsData = results[0];
        healthTimeline = results[1];
        recommendations = results[2]['recommendations'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Analytics'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildErrorWidget()
          : _buildAnalyticsContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to load analytics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadAnalytics, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 24),
            _buildRecommendationsSection(),
            const SizedBox(height: 24),
            _buildTimelineSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final totalDocs = analyticsData?['totalDocuments'] ?? 0;
    final categories = analyticsData?['documentCategories'] ?? {};
    final recentUploads = analyticsData?['recentUploads'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Statistics',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Documents',
                totalDocs.toString(),
                Icons.description,
                AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Recent Uploads',
                recentUploads.toString(),
                Icons.upload,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            _buildCategoryCard(
              'Lab Reports',
              categories['lab_reports'] ?? 0,
              Icons.science,
            ),
            _buildCategoryCard(
              'Prescriptions',
              categories['prescriptions'] ?? 0,
              Icons.medication,
            ),
            _buildCategoryCard(
              'Doctor Notes',
              categories['doctor_notes'] ?? 0,
              Icons.note_alt,
            ),
            _buildCategoryCard('Other', categories['other'] ?? 0, Icons.folder),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  count.toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (recommendations == null || recommendations!.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Recommendations',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recommendations!.length,
          itemBuilder: (context, index) {
            final rec = recommendations![index];
            return _buildRecommendationCard(rec);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    final priority = recommendation['priority'] as String;
    final title = recommendation['title'] as String;
    final description = recommendation['description'] as String;

    Color priorityColor;
    IconData priorityIcon;

    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      default:
        priorityColor = Colors.blue;
        priorityIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(priorityIcon, color: priorityColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final timeline = healthTimeline?['timeline'] as List?;
    if (timeline == null || timeline.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: timeline.length > 5
              ? 5
              : timeline.length, // Show only 5 recent items
          itemBuilder: (context, index) {
            final event = timeline[index];
            return _buildTimelineItem(event);
          },
        ),
        if (timeline.length > 5)
          TextButton(
            onPressed: () {
              // Navigate to full timeline view
              // TODO: Implement full timeline screen
            },
            child: const Text('View Full Timeline'),
          ),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event) {
    final type = event['type'] as String;
    final title = event['title'] as String;
    final description = event['description'] as String;
    final date = DateTime.parse(event['date'] as String);

    IconData icon;
    Color color;

    switch (type) {
      case 'document_upload':
        icon = Icons.upload_file;
        color = Colors.blue;
        break;
      case 'ai_analysis':
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      default:
        icon = Icons.event;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  _formatDate(date),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
