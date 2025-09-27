import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/shared_models.dart';
import 'medical_records_screen.dart';
import 'prescriptions_screen.dart';

class DoctorAppointmentDetailsScreen extends StatefulWidget {
  final QueryDocumentSnapshot appointment;
  final String doctorId;

  const DoctorAppointmentDetailsScreen({
    Key? key,
    required this.appointment,
    required this.doctorId,
  }) : super(key: key);

  @override
  State<DoctorAppointmentDetailsScreen> createState() =>
      _DoctorAppointmentDetailsScreenState();
}

class _DoctorAppointmentDetailsScreenState
    extends State<DoctorAppointmentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final DocumentService _documentService = DocumentService();
  // final GeminiService _geminiService = GeminiService();

  MedicalRecordPermission? _permission;
  bool _isLoadingPermission = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    setState(() {
      _isLoadingPermission = true;
    });

    try {
      final permissionDoc = await _firestore
          .collection('medical_permissions')
          .where('appointmentId', isEqualTo: widget.appointment.id)
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      if (permissionDoc.docs.isNotEmpty) {
        _permission = MedicalRecordPermission.fromFirestore(
          permissionDoc.docs.first,
        );
      }
    } catch (e) {
      print('Error loading permission: $e');
    }

    setState(() {
      _isLoadingPermission = false;
    });
  }

  Future<void> _requestPermission() async {
    final data = widget.appointment.data() as Map<String, dynamic>;
    final patientId = data['patientId'];

    try {
      // Create permission request
      await _firestore.collection('medical_permissions').add({
        'patientId': patientId,
        'doctorId': widget.doctorId,
        'appointmentId': widget.appointment.id,
        'canViewRecords': true,
        'canViewAnalysis': true,
        'canWritePrescriptions': true,
        'grantedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission granted for this appointment'),
        ),
      );

      _loadPermission();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting permission: $e')),
      );
    }
  }

  Future<void> _writePrescription() async {
    if (_permission == null || !_permission!.canWritePrescriptions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need patient permission to write prescriptions'),
        ),
      );
      return;
    }

    final data = widget.appointment.data() as Map<String, dynamic>;
    final patientId = data['patientId'];
    final patientName = data['patientName'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionsScreen(
          doctorId: widget.doctorId,
          patientId: patientId,
          patientName: patientName,
          appointmentId: widget.appointment.id,
        ),
      ),
    );
  }

  Future<void> _referToLab() async {
    final data = widget.appointment.data() as Map<String, dynamic>;
    final patientId = data['patientId'];
    final patientName = data['patientName'];

    // Show lab selection dialog
    showDialog(
      context: context,
      builder: (context) => _LabReferralDialog(
        patientId: patientId,
        patientName: patientName,
        doctorId: widget.doctorId,
        appointmentId: widget.appointment.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.appointment.data() as Map<String, dynamic>;
    final appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final patientId = data['patientId'] ?? '';
    final status = data['status'] ?? 'scheduled';

    return Scaffold(
      appBar: AppBar(
        title: Text('Appointment: $patientName'),
        backgroundColor: Theme.of(context).primaryColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Details', icon: Icon(Icons.info)),
            Tab(text: 'Medical Records', icon: Icon(Icons.medical_services)),
            Tab(text: 'Analysis', icon: Icon(Icons.analytics)),
            Tab(text: 'Actions', icon: Icon(Icons.build)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Details Tab
          _buildDetailsTab(data, appointmentDate),

          // Medical Records Tab
          _buildMedicalRecordsTab(patientId),

          // Analysis Tab
          _buildAnalysisTab(patientId),

          // Actions Tab
          _buildActionsTab(data, status),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> data, DateTime appointmentDate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Name', data['patientName'] ?? 'Unknown'),
                  _buildDetailRow('Email', data['patientEmail'] ?? 'N/A'),
                  _buildDetailRow('Phone', data['patientPhone'] ?? 'N/A'),
                  if (data['patientAge'] != null)
                    _buildDetailRow('Age', '${data['patientAge']}'),
                  if (data['patientGender'] != null)
                    _buildDetailRow('Gender', data['patientGender']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointment Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Type',
                    data['appointmentType'] ?? 'Consultation',
                  ),
                  _buildDetailRow(
                    'Date',
                    DateFormat('MMMM dd, yyyy').format(appointmentDate),
                  ),
                  _buildDetailRow(
                    'Time',
                    DateFormat('hh:mm a').format(appointmentDate),
                  ),
                  _buildDetailRow('Duration', data['duration'] ?? '30 min'),
                  _buildDetailRow(
                    'Status',
                    (data['status'] ?? 'scheduled').toUpperCase(),
                  ),
                  if (data['symptoms'] != null && data['symptoms'].isNotEmpty)
                    _buildDetailRow('Symptoms', data['symptoms']),
                  if (data['notes'] != null && data['notes'].isNotEmpty)
                    _buildDetailRow('Notes', data['notes']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permission Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingPermission)
                    const Center(child: CircularProgressIndicator())
                  else if (_permission == null)
                    Column(
                      children: [
                        const Text(
                          'No permission granted for accessing patient medical records.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _requestPermission,
                          child: const Text('Request Permission'),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildPermissionRow(
                          'View Medical Records',
                          _permission!.canViewRecords,
                        ),
                        _buildPermissionRow(
                          'View Analysis',
                          _permission!.canViewAnalysis,
                        ),
                        _buildPermissionRow(
                          'Write Prescriptions',
                          _permission!.canWritePrescriptions,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Granted: ${DateFormat('MMM dd, yyyy').format(_permission!.grantedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalRecordsTab(String patientId) {
    if (_permission == null || !_permission!.canViewRecords) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Medical records access requires patient permission'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Request Permission'),
            ),
          ],
        ),
      );
    }

    return MedicalRecordsScreen(userId: patientId);
  }

  Widget _buildAnalysisTab(String patientId) {
    if (_permission == null || !_permission!.canViewAnalysis) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Analysis access requires patient permission'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestPermission,
              child: const Text('Request Permission'),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Text('Analysis features will be implemented here'),
    );
  }

  Widget _buildActionsTab(Map<String, dynamic> data, String status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.edit_document),
                    title: const Text('Write Prescription'),
                    subtitle: const Text(
                      'Create a new prescription for the patient',
                    ),
                    onTap: _writePrescription,
                    enabled: _permission?.canWritePrescriptions ?? false,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.science),
                    title: const Text('Refer to Lab'),
                    subtitle: const Text('Send patient for laboratory tests'),
                    onTap: _referToLab,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.chat),
                    title: const Text('Chat with Patient'),
                    subtitle: const Text(
                      'Start a conversation with the patient',
                    ),
                    onTap: () {
                      // Navigate to chat
                      // This will be implemented when integrating chat
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appointment Actions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (status != 'completed' && status != 'cancelled')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _updateAppointmentStatus('completed'),
                            icon: const Icon(Icons.check),
                            label: const Text('Mark Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _updateAppointmentStatus('cancelled'),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel Appointment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
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

  Widget _buildPermissionRow(String permission, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(permission),
        ],
      ),
    );
  }

  Future<void> _updateAppointmentStatus(String newStatus) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(widget.appointment.id)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as $newStatus'),
          backgroundColor: newStatus == 'completed' ? Colors.green : Colors.red,
        ),
      );

      Navigator.pop(context); // Go back to appointments list
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating appointment: $e')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _LabReferralDialog extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String appointmentId;

  const _LabReferralDialog({
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.appointmentId,
  });

  @override
  State<_LabReferralDialog> createState() => _LabReferralDialogState();
}

class _LabReferralDialogState extends State<_LabReferralDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _labs = [];
  String? _selectedLabId;
  final List<String> _selectedTests = [];
  final TextEditingController _notesController = TextEditingController();

  final List<String> _availableTests = [
    'Blood Test',
    'Urine Test',
    'X-Ray',
    'MRI',
    'CT Scan',
    'ECG',
    'Ultrasound',
    'Biopsy',
    'Endoscopy',
    'Colonoscopy',
  ];

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  Future<void> _loadLabs() async {
    try {
      final labsSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'lab')
          .get();

      setState(() {
        _labs = labsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['institutionName'] ?? data['name'] ?? 'Lab',
            'email': data['email'],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading labs: $e');
    }
  }

  Future<void> _submitReferral() async {
    if (_selectedLabId == null || _selectedTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lab and at least one test'),
        ),
      );
      return;
    }

    try {
      final selectedLab = _labs.firstWhere(
        (lab) => lab['id'] == _selectedLabId,
      );
      final currentUser = await _firestore
          .collection('users')
          .doc(widget.doctorId)
          .get();
      final doctorName = currentUser.data()?['fullName'] ?? 'Doctor';

      await _firestore.collection('lab_referrals').add({
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'doctorId': widget.doctorId,
        'doctorName': doctorName,
        'labId': _selectedLabId,
        'labName': selectedLab['name'],
        'appointmentId': widget.appointmentId,
        'testTypes': _selectedTests,
        'status': 'pending',
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lab referral sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending referral: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Refer to Lab'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Lab:'),
            DropdownButton<String>(
              value: _selectedLabId,
              hint: const Text('Choose a lab'),
              isExpanded: true,
              items: _labs.map((lab) {
                return DropdownMenuItem<String>(
                  value: lab['id'] as String,
                  child: Text(lab['name'] as String),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLabId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Select Tests:'),
            Wrap(
              spacing: 8,
              children: _availableTests.map((test) {
                final isSelected = _selectedTests.contains(test);
                return FilterChip(
                  label: Text(test),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTests.add(test);
                      } else {
                        _selectedTests.remove(test);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitReferral,
          child: const Text('Send Referral'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
