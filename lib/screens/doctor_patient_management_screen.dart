import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class DoctorPatientManagementScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const DoctorPatientManagementScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<DoctorPatientManagementScreen> createState() =>
      _DoctorPatientManagementScreenState();
}

class _DoctorPatientManagementScreenState
    extends State<DoctorPatientManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      // Get all appointments for this doctor to find patients
      final appointments = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      final patientIds = appointments.docs
          .map((doc) => doc.data()['patientId'] as String)
          .toSet()
          .toList();

      final List<Map<String, dynamic>> patients = [];

      // Get patient details and their latest appointment info
      for (String patientId in patientIds) {
        try {
          final patientDoc = await _firestore
              .collection('users')
              .doc(patientId)
              .get();
          if (patientDoc.exists) {
            final patientData = patientDoc.data()!;
            patientData['id'] = patientId;

            // Get latest appointment (without orderBy to avoid index requirement)
            final latestAppointment = await _firestore
                .collection('appointments')
                .where('patientId', isEqualTo: patientId)
                .where('doctorId', isEqualTo: widget.doctorId)
                .get();

            if (latestAppointment.docs.isNotEmpty) {
              // Sort in memory to find latest appointment
              final sortedAppointments =
                  latestAppointment.docs.map((doc) => doc.data()).toList()
                    ..sort(
                      (a, b) => (b['appointmentDate'] as Timestamp).compareTo(
                        a['appointmentDate'] as Timestamp,
                      ),
                    );

              if (sortedAppointments.isNotEmpty) {
                patientData['lastVisit'] =
                    sortedAppointments.first['appointmentDate'];
                patientData['appointmentStatus'] =
                    sortedAppointments.first['status'];
              }
            }

            // Get prescription count
            final prescriptions = await _firestore
                .collection('prescriptions')
                .where('patientId', isEqualTo: patientId)
                .where('doctorId', isEqualTo: widget.doctorId)
                .get();
            patientData['prescriptionCount'] = prescriptions.docs.length;

            // Get lab report count
            final labReports = await _firestore
                .collection('labReports')
                .where('patientId', isEqualTo: patientId)
                .where('doctorId', isEqualTo: widget.doctorId)
                .get();
            patientData['labReportCount'] = labReports.docs.length;

            patients.add(patientData);
          }
        } catch (e) {
          print('Error loading patient $patientId: $e');
        }
      }

      // Add sample patients if no real patients found
      if (patients.isEmpty) {
        patients.addAll(await _getSamplePatients());
      }

      setState(() {
        _allPatients = patients;
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading patients: $e');
      final samplePatients = await _getSamplePatients();
      setState(() {
        _allPatients = samplePatients;
        _filteredPatients = _allPatients;
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getSamplePatients() async {
    return [
      {
        'id': 'patient_1',
        'firstName': 'John',
        'lastName': 'Smith',
        'email': 'john.smith@email.com',
        'phoneNumber': '+94 77 123 4567',
        'age': 45,
        'gender': 'Male',
        'bloodType': 'O+',
        'lastVisit': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 7)),
        ),
        'appointmentStatus': 'completed',
        'prescriptionCount': 3,
        'labReportCount': 2,
        'condition': 'Hypertension',
      },
      {
        'id': 'patient_2',
        'firstName': 'Jane',
        'lastName': 'Doe',
        'email': 'jane.doe@email.com',
        'phoneNumber': '+94 77 234 5678',
        'age': 32,
        'gender': 'Female',
        'bloodType': 'A+',
        'lastVisit': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 3)),
        ),
        'appointmentStatus': 'completed',
        'prescriptionCount': 1,
        'labReportCount': 1,
        'condition': 'Diabetes',
      },
      {
        'id': 'patient_3',
        'firstName': 'Robert',
        'lastName': 'Johnson',
        'email': 'robert.johnson@email.com',
        'phoneNumber': '+94 77 345 6789',
        'age': 28,
        'gender': 'Male',
        'bloodType': 'B+',
        'lastVisit': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'appointmentStatus': 'completed',
        'prescriptionCount': 2,
        'labReportCount': 3,
        'condition': 'Allergies',
      },
      {
        'id': 'patient_4',
        'firstName': 'Emily',
        'lastName': 'Davis',
        'email': 'emily.davis@email.com',
        'phoneNumber': '+94 77 456 7890',
        'age': 55,
        'gender': 'Female',
        'bloodType': 'AB+',
        'lastVisit': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 14)),
        ),
        'appointmentStatus': 'completed',
        'prescriptionCount': 5,
        'labReportCount': 4,
        'condition': 'Arthritis',
      },
    ];
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _allPatients.where((patient) {
        final name = '${patient['firstName']} ${patient['lastName']}'
            .toLowerCase();
        final email = (patient['email'] ?? '').toLowerCase();
        final condition = (patient['condition'] ?? '').toLowerCase();

        final matchesSearch =
            query.isEmpty ||
            name.contains(query) ||
            email.contains(query) ||
            condition.contains(query);

        final matchesFilter =
            _selectedFilter == 'All' ||
            (_selectedFilter == 'Recent' && _isRecentPatient(patient)) ||
            (_selectedFilter == 'Chronic' && _isChronicPatient(patient)) ||
            (_selectedFilter == 'Follow-up' && _needsFollowUp(patient));

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  bool _isRecentPatient(Map<String, dynamic> patient) {
    if (patient['lastVisit'] == null) return false;
    final lastVisit = (patient['lastVisit'] as Timestamp).toDate();
    return DateTime.now().difference(lastVisit).inDays <= 7;
  }

  bool _isChronicPatient(Map<String, dynamic> patient) {
    final condition = patient['condition']?.toLowerCase() ?? '';
    return condition.contains('diabetes') ||
        condition.contains('hypertension') ||
        condition.contains('arthritis') ||
        (patient['prescriptionCount'] ?? 0) >= 3;
  }

  bool _needsFollowUp(Map<String, dynamic> patient) {
    if (patient['lastVisit'] == null) return false;
    final lastVisit = (patient['lastVisit'] as Timestamp).toDate();
    return DateTime.now().difference(lastVisit).inDays >= 30;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'All Patients'),
            Tab(icon: Icon(Icons.schedule), text: 'Recent'),
            Tab(icon: Icon(Icons.favorite), text: 'Chronic'),
            Tab(icon: Icon(Icons.follow_the_signs), text: 'Follow-up'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search patients by name, email, or condition...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => _filterPatients(),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Recent', 'Chronic', 'Follow-up']
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: _selectedFilter == filter,
                              onSelected: (selected) {
                                setState(() => _selectedFilter = filter);
                                _filterPatients();
                              },
                              selectedColor: AppTheme.doctorColor.withOpacity(
                                0.2,
                              ),
                              checkmarkColor: AppTheme.doctorColor,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Patients List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPatientsList(_filteredPatients),
                _buildPatientsList(
                  _allPatients.where(_isRecentPatient).toList(),
                ),
                _buildPatientsList(
                  _allPatients.where(_isChronicPatient).toList(),
                ),
                _buildPatientsList(_allPatients.where(_needsFollowUp).toList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPatientDialog,
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildPatientsList(List<Map<String, dynamic>> patients) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No patients found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Patients who book appointments with you will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final lastVisit = patient['lastVisit'] != null
        ? DateFormat(
            'MMM dd, yyyy',
          ).format((patient['lastVisit'] as Timestamp).toDate())
        : 'No visits';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showPatientDetails(patient),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppTheme.doctorColor.withOpacity(0.2),
                    child: Text(
                      '${patient['firstName']?[0] ?? ''}${patient['lastName']?[0] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.doctorColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${patient['firstName']} ${patient['lastName']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${patient['age']} years • ${patient['gender']} • ${patient['bloodType'] ?? 'Unknown'}',
                          style: AppTheme.bodySmall,
                        ),
                        if (patient['condition'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.infoBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              patient['condition'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.infoBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showPatientActions(patient),
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip('Last Visit: $lastVisit', Icons.schedule),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    'Prescriptions: ${patient['prescriptionCount'] ?? 0}',
                    Icons.medication,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    'Lab Reports: ${patient['labReportCount'] ?? 0}',
                    Icons.science,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _showPatientDetails(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.doctorColor.withOpacity(0.2),
                    child: Text(
                      '${patient['firstName']?[0] ?? ''}${patient['lastName']?[0] ?? ''}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.doctorColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${patient['firstName']} ${patient['lastName']}',
                          style: AppTheme.headingLarge,
                        ),
                        Text(
                          patient['email'] ?? 'No email',
                          style: AppTheme.bodySmall,
                        ),
                        Text(
                          patient['phoneNumber'] ?? 'No phone',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _scheduleAppointment(patient),
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Schedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.doctorColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _createPrescription(patient),
                      icon: const Icon(Icons.medication),
                      label: const Text('Prescribe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Patient Information
              _buildDetailSection('Personal Information', [
                _buildDetailRow('Age', '${patient['age']} years'),
                _buildDetailRow('Gender', patient['gender'] ?? 'Not specified'),
                _buildDetailRow(
                  'Blood Type',
                  patient['bloodType'] ?? 'Unknown',
                ),
                _buildDetailRow(
                  'Condition',
                  patient['condition'] ?? 'None specified',
                ),
              ]),

              const SizedBox(height: 16),

              _buildDetailSection('Medical Summary', [
                _buildDetailRow(
                  'Total Prescriptions',
                  '${patient['prescriptionCount'] ?? 0}',
                ),
                _buildDetailRow(
                  'Lab Reports',
                  '${patient['labReportCount'] ?? 0}',
                ),
                _buildDetailRow(
                  'Last Visit',
                  patient['lastVisit'] != null
                      ? DateFormat(
                          'MMM dd, yyyy',
                        ).format((patient['lastVisit'] as Timestamp).toDate())
                      : 'No visits',
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.headingMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: AppTheme.bodySmall)),
          Expanded(child: Text(value, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  void _showPatientActions(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Schedule Appointment'),
            onTap: () {
              Navigator.pop(context);
              _scheduleAppointment(patient);
            },
          ),
          ListTile(
            leading: const Icon(Icons.medication),
            title: const Text('Create Prescription'),
            onTap: () {
              Navigator.pop(context);
              _createPrescription(patient);
            },
          ),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Request Lab Test'),
            onTap: () {
              Navigator.pop(context);
              _requestLabTest(patient);
            },
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Call Patient'),
            onTap: () {
              Navigator.pop(context);
              _callPatient(patient);
            },
          ),
        ],
      ),
    );
  }

  void _scheduleAppointment(Map<String, dynamic> patient) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scheduling appointment for ${patient['firstName']} ${patient['lastName']}',
        ),
        backgroundColor: AppTheme.infoBlue,
      ),
    );
  }

  void _createPrescription(Map<String, dynamic> patient) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Creating prescription for ${patient['firstName']} ${patient['lastName']}',
        ),
        backgroundColor: AppTheme.accentPurple,
      ),
    );
  }

  void _requestLabTest(Map<String, dynamic> patient) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Requesting lab test for ${patient['firstName']} ${patient['lastName']}',
        ),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  void _callPatient(Map<String, dynamic> patient) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Calling ${patient['firstName']} ${patient['lastName']} at ${patient['phoneNumber']}',
        ),
        backgroundColor: AppTheme.warningOrange,
      ),
    );
  }

  void _showAddPatientDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Manual patient addition feature coming soon. Patients are automatically added when they book appointments.',
        ),
        backgroundColor: AppTheme.infoBlue,
      ),
    );
  }
}
