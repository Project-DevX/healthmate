import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({Key? key}) : super(key: key);

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  List<Map<String, dynamic>> appointments = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user.uid)
          .orderBy('date', descending: false)
          .get();

      appointments = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error loading appointments: $e');
      // Add some sample data for demonstration
      appointments = [
        {
          'id': '1',
          'patientName': 'John Doe',
          'patientId': 'pat1',
          'date': '2025-07-02',
          'time': '10:00 AM',
          'status': 'Scheduled',
          'type': 'Consultation',
          'notes': 'Regular checkup',
        },
        {
          'id': '2',
          'patientName': 'Jane Smith',
          'patientId': 'pat2',
          'date': '2025-07-02',
          'time': '2:00 PM',
          'status': 'Confirmed',
          'type': 'Follow-up',
          'notes': 'Follow-up for previous treatment',
        },
        {
          'id': '3',
          'patientName': 'Mike Johnson',
          'patientId': 'pat3',
          'date': '2025-07-03',
          'time': '9:00 AM',
          'status': 'Pending',
          'type': 'Emergency',
          'notes': 'Urgent consultation required',
        },
      ];
    }

    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get filteredAppointments {
    if (_selectedFilter == 'All') return appointments;
    return appointments
        .where((apt) => apt['status'] == _selectedFilter)
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Appointment Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Patient', appointment['patientName'] ?? 'Unknown'),
            _buildDetailRow('Date', appointment['date'] ?? 'Not set'),
            _buildDetailRow('Time', appointment['time'] ?? 'Not set'),
            _buildDetailRow('Type', appointment['type'] ?? 'Consultation'),
            _buildDetailRow('Status', appointment['status'] ?? 'Unknown'),
            _buildDetailRow('Notes', appointment['notes'] ?? 'No notes'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _updateAppointmentStatus(appointment['id'], 'Confirmed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _updateAppointmentStatus(appointment['id'], 'Cancelled');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _updateAppointmentStatus(String appointmentId, String newStatus) {
    setState(() {
      final index = appointments.indexWhere(
        (apt) => apt['id'] == appointmentId,
      );
      if (index != -1) {
        appointments[index]['status'] = newStatus;
      }
    });

    // Here you would typically update the Firestore document
    // FirebaseFirestore.instance
    //     .collection('appointments')
    //     .doc(appointmentId)
    //     .update({'status': newStatus});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Appointment $newStatus')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: const Color(0xFF7B61FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter chips
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                                'All',
                                'Scheduled',
                                'Confirmed',
                                'Pending',
                                'Completed',
                                'Cancelled',
                              ]
                              .map(
                                (filter) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    selected: _selectedFilter == filter,
                                    label: Text(filter),
                                    onSelected: (selected) {
                                      setState(() => _selectedFilter = filter);
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
                // Appointments list
                Expanded(
                  child: filteredAppointments.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No appointments found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAppointments.length,
                          itemBuilder: (context, index) {
                            final appointment = filteredAppointments[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(
                                    appointment['status'] ?? '',
                                  ),
                                  child: Text(
                                    appointment['patientName']
                                            ?.substring(0, 1)
                                            .toUpperCase() ??
                                        'P',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  appointment['patientName'] ??
                                      'Unknown Patient',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${appointment['date']} at ${appointment['time']}',
                                    ),
                                    Text(
                                      appointment['type'] ?? 'Consultation',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      appointment['status'] ?? '',
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getStatusColor(
                                        appointment['status'] ?? '',
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    appointment['status'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: _getStatusColor(
                                        appointment['status'] ?? '',
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onTap: () =>
                                    _showAppointmentDetails(appointment),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new appointment functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add appointment feature coming soon!'),
            ),
          );
        },
        backgroundColor: const Color(0xFF7B61FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
