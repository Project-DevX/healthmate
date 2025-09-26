// lib/widgets/patient_medical_history_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/shared_models.dart';
import '../services/interconnect_service.dart';

class PatientMedicalHistoryWidget extends StatefulWidget {
  final String doctorId;
  final String doctorName;

  const PatientMedicalHistoryWidget({
    Key? key,
    required this.doctorId,
    required this.doctorName,
  }) : super(key: key);

  @override
  State<PatientMedicalHistoryWidget> createState() =>
      _PatientMedicalHistoryWidgetState();
}

class _PatientMedicalHistoryWidgetState
    extends State<PatientMedicalHistoryWidget> {
  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _medicalHistory;
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchPatients('');
  }

  Future<void> _searchPatients(String query) async {
    setState(() => _isLoading = true);
    try {
      final patients = await InterconnectService.searchPatients(query);
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search patients: $e')),
        );
      }
    }
  }

  Future<void> _loadPatientHistory(String patientId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await InterconnectService.getPatientMedicalHistory(
        patientId,
      );
      setState(() {
        _medicalHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patient history: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Medical History'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Patients List
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search patients...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        _searchPatients(value);
                      },
                    ),
                  ),
                  // Patients List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _patients.length,
                            itemBuilder: (context, index) {
                              final patient = _patients[index];
                              final isSelected =
                                  _selectedPatient?['id'] == patient['id'];

                              return Container(

                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.1)
                                    : null,

                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      (patient['name'] ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(patient['name'] ?? 'Unknown'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(patient['email'] ?? ''),
                                      if (patient['dateOfBirth'] != null)
                                        Text('DOB: ${patient['dateOfBirth']}'),
                                      if (patient['phone'] != null)
                                        Text('Phone: ${patient['phone']}'),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedPatient = patient;
                                    });
                                    _loadPatientHistory(patient['id']);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Medical History Panel
          Expanded(
            flex: 2,
            child: _selectedPatient == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Select a patient to view medical history'),
                      ],
                    ),
                  )
                : _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _buildMedicalHistoryPanel(),
          ),
        ],
      ),
      floatingActionButton: _selectedPatient != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: "prescription",
                  onPressed: () => _showCreatePrescriptionDialog(),
                  icon: const Icon(Icons.medication),
                  label: const Text('New Prescription'),
                  backgroundColor: Colors.orange,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: "lab",
                  onPressed: () => _showRequestLabTestDialog(),
                  icon: const Icon(Icons.science),
                  label: const Text('Request Lab Test'),
                  backgroundColor: Colors.blue,
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildMedicalHistoryPanel() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Patient Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(
                    (_selectedPatient!['name'] ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPatient!['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_selectedPatient!['email'] ?? ''),
                      if (_selectedPatient!['dateOfBirth'] != null)
                        Text('DOB: ${_selectedPatient!['dateOfBirth']}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          const TabBar(
            tabs: [
              Tab(text: 'Appointments'),
              Tab(text: 'Lab Reports'),
              Tab(text: 'Prescriptions'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _buildAppointmentsTab(),
                _buildLabReportsTab(),
                _buildPrescriptionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_medicalHistory == null) return const SizedBox();

    final appointments =
        _medicalHistory!['appointments'] as List<Appointment>? ?? [];

    if (appointments.isEmpty) {
      return const Center(child: Text('No appointments found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(appointment.status),
              child: Icon(Icons.calendar_today, color: Colors.white, size: 20),
            ),
            title: Text(
              '${DateFormat('MMM dd, yyyy').format(appointment.appointmentDate)} at ${appointment.timeSlot}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${appointment.status.toUpperCase()}'),
                if (appointment.reason != null)
                  Text('Reason: ${appointment.reason}'),
                if (appointment.symptoms != null)
                  Text('Symptoms: ${appointment.symptoms}'),
                if (appointment.notes != null)
                  Text('Notes: ${appointment.notes}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabReportsTab() {
    if (_medicalHistory == null) return const SizedBox();

    final labReports = _medicalHistory!['labReports'] as List<LabReport>? ?? [];

    if (labReports.isEmpty) {
      return const Center(child: Text('No lab reports found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: labReports.length,
      itemBuilder: (context, index) {
        final report = labReports[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(report.status),
              child: Icon(Icons.science, color: Colors.white, size: 20),
            ),
            title: Text(
              report.testName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lab: ${report.labName}'),
                Text(
                  'Date: ${DateFormat('MMM dd, yyyy').format(report.testDate)}',
                ),
                Text('Status: ${report.status.toUpperCase()}'),
                if (report.notes != null) Text('Notes: ${report.notes}'),
              ],
            ),
            trailing: report.status == 'completed' && report.reportUrl != null
                ? IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      // Download report
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildPrescriptionsTab() {
    if (_medicalHistory == null) return const SizedBox();

    final prescriptions =
        _medicalHistory!['prescriptions'] as List<Prescription>? ?? [];

    if (prescriptions.isEmpty) {
      return const Center(child: Text('No prescriptions found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      itemBuilder: (context, index) {
        final prescription = prescriptions[index];
        return Card(
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(prescription.status),
              child: Icon(Icons.medication, color: Colors.white, size: 20),
            ),
            title: Text(
              'Prescribed: ${DateFormat('MMM dd, yyyy').format(prescription.prescribedDate)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${prescription.status.toUpperCase()}'),
                if (prescription.pharmacyName != null)
                  Text('Pharmacy: ${prescription.pharmacyName}'),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medications:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...prescription.medicines.map(
                      (medicine) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Dosage: ${medicine.dosage}'),
                              Text('Frequency: ${medicine.frequency}'),
                              Text('Duration: ${medicine.duration} days'),
                              if (medicine.instructions.isNotEmpty)
                                Text('Instructions: ${medicine.instructions}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (prescription.notes != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Notes: ${prescription.notes}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'requested':
      case 'prescribed':
        return Colors.blue;
      case 'confirmed':
      case 'in_progress':
        return Colors.orange;
      case 'completed':
      case 'filled':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showCreatePrescriptionDialog() {
    final medicinesController = <PrescriptionMedicine>[];
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('New Prescription for ${_selectedPatient!['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                // Add Medicine Button
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddMedicineDialog((medicine) {
                      setDialogState(() {
                        medicinesController.add(medicine);
                      });
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Medicine'),
                ),

                const SizedBox(height: 16),

                // Medicines List
                Expanded(
                  child: ListView.builder(
                    itemCount: medicinesController.length,
                    itemBuilder: (context, index) {
                      final medicine = medicinesController[index];
                      return Card(
                        child: ListTile(
                          title: Text(medicine.name),
                          subtitle: Text(
                            '${medicine.dosage} - ${medicine.frequency} - ${medicine.duration}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle),
                            onPressed: () {
                              setDialogState(() {
                                medicinesController.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: medicinesController.isNotEmpty
                  ? () async {
                      try {
                        final prescription = Prescription(
                          id: '',
                          patientId: _selectedPatient!['id'],
                          patientName: _selectedPatient!['name'],
                          doctorId: widget.doctorId,
                          doctorName: widget.doctorName,
                          pharmacyId: '', // Will be assigned when filled
                          medicines: medicinesController,
                          prescribedDate: DateTime.now(),
                          status: 'prescribed',
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );

                        await InterconnectService.createPrescription(
                          prescription,
                        );
                        Navigator.of(context).pop();
                        _loadPatientHistory(_selectedPatient!['id']);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Prescription created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to create prescription: $e'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Create Prescription'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedicineDialog(Function(PrescriptionMedicine) onAdd) {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    final durationController = TextEditingController();
    final instructionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medicine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage (e.g., 500mg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: frequencyController,
              decoration: const InputDecoration(
                labelText: 'Frequency (e.g., Twice daily)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (days)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  dosageController.text.trim().isNotEmpty &&
                  frequencyController.text.trim().isNotEmpty &&
                  durationController.text.trim().isNotEmpty) {
                final medicine = PrescriptionMedicine(
                  name: nameController.text.trim(),
                  dosage: dosageController.text.trim(),
                  frequency: frequencyController.text.trim(),
                  duration: int.tryParse(durationController.text.trim()) ?? 1,
                  instructions: instructionsController.text.trim(),
                );
                onAdd(medicine);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showRequestLabTestDialog() {
    final testTypes = [
      'Blood Test',
      'Urine Test',
      'X-Ray',
      'CT Scan',
      'MRI',
      'ECG',
      'Ultrasound',
      'Biopsy',
      'Other',
    ];

    String selectedTestType = testTypes[0];
    final testNameController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Request Lab Test for ${_selectedPatient!['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedTestType,
                decoration: const InputDecoration(
                  labelText: 'Test Type',
                  border: OutlineInputBorder(),
                ),
                items: testTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedTestType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: testNameController,
                decoration: const InputDecoration(
                  labelText: 'Specific Test Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: testNameController.text.trim().isNotEmpty
                  ? () async {
                      try {
                        final labReport = LabReport(
                          id: '',
                          patientId: _selectedPatient!['id'],
                          patientName: _selectedPatient!['name'],
                          labId: '', // Will be assigned by lab
                          labName: 'Pending Assignment',
                          doctorId: widget.doctorId,
                          doctorName: widget.doctorName,
                          testType: selectedTestType,
                          testName: testNameController.text.trim(),
                          testDate: DateTime.now().add(
                            const Duration(days: 1),
                          ), // Default to tomorrow
                          status: 'requested',
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                          createdAt: DateTime.now(),
                        );

                        await InterconnectService.requestLabTest(labReport);
                        Navigator.of(context).pop();
                        _loadPatientHistory(_selectedPatient!['id']);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lab test requested successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to request lab test: $e'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Request Test'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
