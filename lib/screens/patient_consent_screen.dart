// lib/screens/patient_consent_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shared_models.dart';
import '../services/consent_service.dart';
import '../theme/app_theme.dart';

class PatientConsentScreen extends StatefulWidget {
  final String patientId;

  const PatientConsentScreen({super.key, required this.patientId});

  @override
  State<PatientConsentScreen> createState() => _PatientConsentScreenState();
}

class _PatientConsentScreenState extends State<PatientConsentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ConsentRequest> _pendingRequests = [];
  List<ConsentRequest> _allRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConsentRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConsentRequests() async {
    try {
      setState(() => _isLoading = true);

      final pendingRequests = 
          await ConsentService.getPatientPendingRequests(widget.patientId);
      final allRequests = 
          await ConsentService.getPatientConsentHistory(widget.patientId);

      setState(() {
        _pendingRequests = pendingRequests;
        _allRequests = allRequests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading consent requests: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records Consent'),
        backgroundColor: AppTheme.patientColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Stack(
                children: [
                  const Icon(Icons.pending_actions),
                  if (_pendingRequests.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              text: 'Pending',
            ),
            const Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingRequestsTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildPendingRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppTheme.successGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'No Pending Requests',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no pending medical record access requests.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConsentRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final request = _pendingRequests[index];
          return _buildConsentRequestCard(request, isPending: true);
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    final completedRequests = _allRequests
        .where((r) => r.status != 'pending')
        .toList();

    if (completedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: AppTheme.textMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'No History',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no consent request history.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textMedium,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConsentRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: completedRequests.length,
        itemBuilder: (context, index) {
          final request = completedRequests[index];
          return _buildConsentRequestCard(request, isPending: false);
        },
      ),
    );
  }

  Widget _buildConsentRequestCard(ConsentRequest request, {required bool isPending}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showConsentRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with doctor info and status
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.doctorColor.withOpacity(0.1),
                    child: Icon(
                      Icons.local_hospital,
                      color: AppTheme.doctorColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.doctorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          request.doctorSpecialty,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: request.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request.status.toUpperCase(),
                      style: TextStyle(
                        color: request.statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Request details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getRequestTypeIcon(request.requestType),
                          size: 16,
                          color: AppTheme.infoBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Requesting: ${request.requestTypeDisplayName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.infoBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Purpose: ${request.purpose}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${request.durationDays} days',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Date and actions
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textMedium,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Requested: ${DateFormat('MMM dd, yyyy').format(request.requestDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const Spacer(),
                  if (isPending) ...[
                    OutlinedButton(
                      onPressed: () => _respondToRequest(request, 'denied'),
                      child: const Text('Deny'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: BorderSide(color: AppTheme.errorRed),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _respondToRequest(request, 'approved'),
                      child: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ] else if (request.status == 'approved' && 
                           request.expiryDate != null && 
                           DateTime.now().isBefore(request.expiryDate!)) ...[
                    OutlinedButton(
                      onPressed: () => _revokeConsent(request),
                      child: const Text('Revoke'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningOrange,
                        side: BorderSide(color: AppTheme.warningOrange),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ],
              ),

              // Expiry info for approved requests
              if (request.status == 'approved' && request.expiryDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.successGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Expires: ${DateFormat('MMM dd, yyyy').format(request.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRequestTypeIcon(String requestType) {
    switch (requestType) {
      case 'lab_reports':
        return Icons.science;
      case 'prescriptions':
        return Icons.medication;
      case 'full_history':
        return Icons.history;
      default:
        return Icons.folder;
    }
  }

  void _showConsentRequestDetails(ConsentRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Consent Request Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Doctor', request.doctorName),
              _buildDetailRow('Specialty', request.doctorSpecialty),
              _buildDetailRow('Request Type', request.requestTypeDisplayName),
              _buildDetailRow('Purpose', request.purpose),
              _buildDetailRow('Duration', '${request.durationDays} days'),
              _buildDetailRow('Status', request.status.toUpperCase()),
              _buildDetailRow(
                'Requested On',
                DateFormat('MMMM dd, yyyy').format(request.requestDate),
              ),
              if (request.responseDate != null)
                _buildDetailRow(
                  'Responded On',
                  DateFormat('MMMM dd, yyyy').format(request.responseDate!),
                ),
              if (request.expiryDate != null)
                _buildDetailRow(
                  'Expires On',
                  DateFormat('MMMM dd, yyyy').format(request.expiryDate!),
                ),
              if (request.patientResponse != null)
                _buildDetailRow('Your Response', request.patientResponse!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _respondToRequest(ConsentRequest request, String response) {
    showDialog(
      context: context,
      builder: (context) {
        final noteController = TextEditingController();
        return AlertDialog(
          title: Text(
            response == 'approved' ? 'Approve Request' : 'Deny Request',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dr. ${request.doctorName} is requesting access to your ${request.requestTypeDisplayName.toLowerCase()}.',
              ),
              const SizedBox(height: 16),
              Text(
                'Purpose: ${request.purpose}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Optional note to doctor',
                  border: OutlineInputBorder(),
                  hintText: 'Add any comments or conditions...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitResponse(request, response, noteController.text.trim());
              },
              child: Text(response == 'approved' ? 'Approve' : 'Deny'),
              style: ElevatedButton.styleFrom(
                backgroundColor: response == 'approved' 
                    ? AppTheme.successGreen 
                    : AppTheme.errorRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitResponse(
    ConsentRequest request,
    String response,
    String? note,
  ) async {
    try {
      await ConsentService.respondToConsentRequest(
        request.id,
        response,
        note,
      );

      await _loadConsentRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'approved'
                  ? '✅ Medical record access approved'
                  : '❌ Medical record access denied',
            ),
            backgroundColor: response == 'approved'
                ? AppTheme.successGreen
                : AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to request: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _revokeConsent(ConsentRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Consent'),
        content: Text(
          'Are you sure you want to revoke Dr. ${request.doctorName}\'s access to your ${request.requestTypeDisplayName.toLowerCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ConsentService.revokeConsent(request.id);
        await _loadConsentRequests();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Consent revoked successfully'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error revoking consent: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }
}