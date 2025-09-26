// lib/screens/patient_medical_records_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_models.dart';
import '../services/consent_service.dart';
import '../theme/app_theme.dart';

class PatientMedicalRecordsScreen extends StatefulWidget {
  final String doctorId;
  final String patientId;
  final String patientName;
  final String consentRequestId;
  final String purpose;

  const PatientMedicalRecordsScreen({
    super.key,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.consentRequestId,
    required this.purpose,
  });

  @override
  State<PatientMedicalRecordsScreen> createState() =>
      _PatientMedicalRecordsScreenState();
}

class _PatientMedicalRecordsScreenState
    extends State<PatientMedicalRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _medicalRecords;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMedicalRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalRecords() async {
    try {
      print(
        '📋 MEDICAL RECORDS: Loading for Dr. ${widget.doctorId} -> Patient ${widget.patientId}',
      );
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final records = await ConsentService.getAccessiblePatientRecords(
        widget.doctorId,
        widget.patientId,
        widget.consentRequestId,
        widget.purpose,
      );

      print('📋 MEDICAL RECORDS: Loaded successfully');
      print('   - Lab reports access: ${records['hasLabReportsAccess']}');
      print('   - Prescriptions access: ${records['hasPrescriptionsAccess']}');
      print('   - Full history access: ${records['hasFullHistoryAccess']}');
      print('   - Appointments: ${records['appointments']?.length ?? 0}');
      print('   - Lab reports: ${records['labReports']?.length ?? 0}');
      print('   - Prescriptions: ${records['prescriptions']?.length ?? 0}');

      setState(() {
        _medicalRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ MEDICAL RECORDS: Failed to load: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Medical Records', style: const TextStyle(fontSize: 18)),
            Text(
              widget.patientName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.calendar_today), text: 'Appointments'),
                  Tab(icon: Icon(Icons.science), text: 'Lab Reports'),
                  Tab(icon: Icon(Icons.medication), text: 'Prescriptions'),
                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading medical records...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.textMedium),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadMedicalRecords,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Access permissions info
        _buildAccessInfoBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentsTab(),
              _buildLabReportsTab(),
              _buildPrescriptionsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccessInfoBar() {
    final hasLabAccess = _medicalRecords?['hasLabReportsAccess'] ?? false;
    final hasPrescriptionAccess =
        _medicalRecords?['hasPrescriptionsAccess'] ?? false;
    final hasFullAccess = _medicalRecords?['hasFullHistoryAccess'] ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: AppTheme.infoBlue.withOpacity(0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 16, color: AppTheme.infoBlue),
              const SizedBox(width: 8),
              Text(
                'Access Permissions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.infoBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildAccessChip(
                'Appointments',
                true, // Always have access to appointments
                Icons.calendar_today,
              ),
              _buildAccessChip('Lab Reports', hasLabAccess, Icons.science),
              _buildAccessChip(
                'Prescriptions',
                hasPrescriptionAccess,
                Icons.medication,
              ),
              if (hasFullAccess)
                _buildAccessChip('Full History', true, Icons.history),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccessChip(String label, bool hasAccess, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasAccess
            ? AppTheme.successGreen.withOpacity(0.1)
            : AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAccess
              ? AppTheme.successGreen.withOpacity(0.3)
              : AppTheme.errorRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasAccess ? Icons.check_circle : Icons.block,
            size: 14,
            color: hasAccess ? AppTheme.successGreen : AppTheme.errorRed,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: hasAccess ? AppTheme.successGreen : AppTheme.errorRed,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final appointments =
        (_medicalRecords?['appointments'] as List<Appointment>?) ?? [];

    if (appointments.isEmpty) {
      return _buildEmptyState(
        'No Appointments Found',
        'No appointment history available for this patient.',
        Icons.calendar_today,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildLabReportsTab() {
    final hasAccess = _medicalRecords?['hasLabReportsAccess'] ?? false;

    if (!hasAccess) {
      return _buildNoAccessState(
        'Lab Reports Access Required',
        'You need patient consent to view lab reports.',
        Icons.science,
      );
    }

    final labReports =
        (_medicalRecords?['labReports'] as List<Map<String, dynamic>>?) ?? [];

    if (labReports.isEmpty) {
      return _buildEmptyState(
        'No Lab Reports Found',
        'No lab reports available for this patient.',
        Icons.science,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: labReports.length,
      itemBuilder: (context, index) {
        final report = labReports[index];
        return _buildLabReportDocumentCard(report);
      },
    );
  }

  Widget _buildPrescriptionsTab() {
    final hasAccess = _medicalRecords?['hasPrescriptionsAccess'] ?? false;

    if (!hasAccess) {
      return _buildNoAccessState(
        'Prescriptions Access Required',
        'You need patient consent to view prescriptions.',
        Icons.medication,
      );
    }

    final prescriptions =
        (_medicalRecords?['prescriptions'] as List<Map<String, dynamic>>?) ??
        [];

    if (prescriptions.isEmpty) {
      return _buildEmptyState(
        'No Prescriptions Found',
        'No prescriptions available for this patient.',
        Icons.medication,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = prescriptions[index];
        return _buildPrescriptionDocumentCard(prescription);
      },
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textMedium),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: AppTheme.textMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoAccessState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: TextStyle(fontSize: 16, color: AppTheme.textMedium),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'MMMM dd, yyyy',
                        ).format(appointment.appointmentDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${DateFormat('hh:mm a').format(appointment.appointmentDate)} • ${appointment.status}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (appointment.reason != null || appointment.symptoms != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (appointment.reason != null) ...[
                      Text(
                        'Reason: ${appointment.reason}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                    if (appointment.symptoms != null) ...[
                      if (appointment.reason != null) const SizedBox(height: 4),
                      Text(
                        'Symptoms: ${appointment.symptoms}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (appointment.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${appointment.notes}',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabReportDocumentCard(Map<String, dynamic> report) {
    final fileName = report['fileName'] as String? ?? 'Unknown File';
    final fileType = report['fileType'] as String? ?? 'unknown';
    final uploadDate = report['uploadDate'] as Timestamp?;
    final labReportType = report['labReportType'] as String? ?? 'General';
    final downloadUrl = report['downloadUrl'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${uploadDate != null ? DateFormat('MMM dd, yyyy').format(uploadDate.toDate()) : 'Unknown date'} • $labReportType',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'File Type: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  fileType.toUpperCase(),
                  style: TextStyle(color: AppTheme.textMedium),
                ),
              ],
            ),
            if (downloadUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement download/view functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabReportCard(LabReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.science,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.testName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM dd, yyyy').format(report.testDate)} • ${report.status}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (report.results != null && report.results!.isNotEmpty) ...[
              Text(
                'Results:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ...report.results!.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        entry.value.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (report.notes != null && report.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${report.notes}',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionDocumentCard(Map<String, dynamic> prescription) {
    final source = prescription['source'] as String;

    if (source == 'formal') {
      // Formal prescription from doctor/pharmacy
      final medicines = prescription['medicines'] as List<dynamic>? ?? [];
      final prescribedDate = prescription['prescribedDate'] as DateTime?;
      final doctorName =
          prescription['doctorName'] as String? ?? 'Unknown Doctor';
      final status = prescription['status'] as String? ?? 'Unknown';

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medication,
                      color: AppTheme.warningOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prescription',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${prescribedDate != null ? DateFormat('MMM dd, yyyy').format(prescribedDate) : 'Unknown date'} • Dr. $doctorName',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Status: $status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              if (medicines.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Medications:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                ...medicines
                    .map(
                      (med) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${med['name']} - ${med['dosage']} (${med['frequency']})',
                          style: TextStyle(color: AppTheme.textMedium),
                        ),
                      ),
                    )
                    .toList(),
              ],
            ],
          ),
        ),
      );
    } else {
      // Uploaded prescription document
      final fileName = prescription['fileName'] as String? ?? 'Unknown File';
      final fileType = prescription['fileType'] as String? ?? 'unknown';
      final uploadDate = prescription['uploadDate'] as Timestamp?;
      final downloadUrl = prescription['downloadUrl'] as String? ?? '';

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description,
                      color: AppTheme.warningOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${uploadDate != null ? DateFormat('MMM dd, yyyy').format(uploadDate.toDate()) : 'Unknown date'} • Uploaded Document',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'File Type: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  Text(
                    fileType.toUpperCase(),
                    style: TextStyle(color: AppTheme.textMedium),
                  ),
                ],
              ),
              if (downloadUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement download/view functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Download feature coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}
