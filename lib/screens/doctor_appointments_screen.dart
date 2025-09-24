import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorAppointmentsScreen({super.key, required this.doctorId});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper function to sort appointments by date without requiring Firebase indexes
  List<QueryDocumentSnapshot> _sortAppointments(
    List<QueryDocumentSnapshot> appointments, {
    bool descending = false,
  }) {
    appointments.sort((a, b) {
      final aDate =
          (a.data() as Map<String, dynamic>)['appointmentDate'] as Timestamp?;
      final bDate =
          (b.data() as Map<String, dynamic>)['appointmentDate'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return descending ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return appointments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppWidgets.buildAppBar(title: 'Appointments', userType: 'doctor'),
      body: Column(
        children: [
          Container(
            color: AppTheme.doctorColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.today), text: 'Today'),
                Tab(icon: Icon(Icons.upcoming), text: 'Upcoming'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayAppointments(),
                _buildUpcomingAppointments(),
                _buildAppointmentHistory(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAppointmentDialog(),
        backgroundColor: AppTheme.doctorColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodayAppointments() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allAppointments = snapshot.data?.docs ?? [];

        // Filter for today's appointments in memory
        final todaysAppointments = allAppointments.where((doc) {
          final appointmentDate =
              (doc.data() as Map<String, dynamic>)['appointmentDate']
                  as Timestamp?;
          if (appointmentDate == null) return false;
          final date = appointmentDate.toDate();
          return date.isAfter(startOfDay) && date.isBefore(endOfDay);
        }).toList();

        final appointments = _sortAppointments(todaysAppointments);

        if (appointments.isEmpty) {
          return _buildEmptyState(
            'No appointments today',
            'You have no scheduled appointments for today.',
            Icons.event_available,
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
      },
    );
  }

  Widget _buildUpcomingAppointments() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startOfTomorrow = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
    );

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allAppointments = snapshot.data?.docs ?? [];

        // Filter for upcoming appointments in memory
        final upcomingAppointments = allAppointments.where((doc) {
          final appointmentDate =
              (doc.data() as Map<String, dynamic>)['appointmentDate']
                  as Timestamp?;
          if (appointmentDate == null) return false;
          final date = appointmentDate.toDate();
          return date.isAfter(startOfTomorrow);
        }).toList();

        final appointments = _sortAppointments(
          upcomingAppointments.take(50).toList(),
        );

        if (appointments.isEmpty) {
          return _buildEmptyState(
            'No upcoming appointments',
            'You have no scheduled appointments coming up.',
            Icons.event_note,
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
      },
    );
  }

  Widget _buildAppointmentHistory() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final endOfYesterday = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      59,
      59,
    );

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allAppointments = snapshot.data?.docs ?? [];

        // Filter for past appointments in memory
        final pastAppointments = allAppointments.where((doc) {
          final appointmentDate =
              (doc.data() as Map<String, dynamic>)['appointmentDate']
                  as Timestamp?;
          if (appointmentDate == null) return false;
          final date = appointmentDate.toDate();
          return date.isBefore(endOfYesterday);
        }).toList();

        final appointments = _sortAppointments(
          pastAppointments.take(50).toList(),
          descending: true,
        );

        if (appointments.isEmpty) {
          return _buildEmptyState(
            'No appointment history',
            'Your completed appointments will appear here.',
            Icons.history,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            return _buildAppointmentCard(appointment, showHistory: true);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textLight),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.headingMedium.copyWith(color: AppTheme.textMedium),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
    QueryDocumentSnapshot appointment, {
    bool showHistory = false,
  }) {
    final data = appointment.data() as Map<String, dynamic>;
    final appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final appointmentType = data['appointmentType'] ?? 'Consultation';
    final status = data['status'] ?? 'scheduled';
    final duration = data['duration'] ?? '30 min';
    final notes = data['notes'] ?? '';

    Color statusColor = AppTheme.infoBlue;
    IconData statusIcon = Icons.schedule;

    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.cancel;
        break;
      case 'in-progress':
        statusColor = AppTheme.warningOrange;
        statusIcon = Icons.hourglass_top;
        break;
      case 'no-show':
        statusColor = AppTheme.textMedium;
        statusIcon = Icons.person_off;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAppointmentDetails(appointment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.doctorColor.withValues(alpha: 0.1),
                    child: Text(
                      patientName.isNotEmpty
                          ? patientName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: AppTheme.doctorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(appointmentType, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
                  Icon(Icons.access_time, size: 16, color: AppTheme.textMedium),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(
                      'MMM dd, yyyy • hh:mm a',
                    ).format(appointmentDate),
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.timer, size: 16, color: AppTheme.textMedium),
                  const SizedBox(width: 4),
                  Text(duration, style: AppTheme.bodySmall),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: AppTheme.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (!showHistory &&
                  status != 'completed' &&
                  status != 'cancelled') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateAppointmentStatus(
                          appointment.id,
                          'completed',
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Complete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successGreen,
                          side: const BorderSide(color: AppTheme.successGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateAppointmentStatus(
                          appointment.id,
                          'cancelled',
                        ),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          side: const BorderSide(color: AppTheme.errorRed),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetails(QueryDocumentSnapshot appointment) {
    final data = appointment.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Appointment Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Patient', data['patientName'] ?? 'Unknown'),
            _buildDetailRow('Type', data['appointmentType'] ?? 'Consultation'),
            _buildDetailRow(
              'Date',
              DateFormat(
                'MMMM dd, yyyy',
              ).format((data['appointmentDate'] as Timestamp).toDate()),
            ),
            _buildDetailRow(
              'Time',
              DateFormat(
                'hh:mm a',
              ).format((data['appointmentDate'] as Timestamp).toDate()),
            ),
            _buildDetailRow('Duration', data['duration'] ?? '30 min'),
            _buildDetailRow('Status', data['status'] ?? 'scheduled'),
            if (data['notes'] != null && data['notes'].isNotEmpty)
              _buildDetailRow('Notes', data['notes']),
            if (data['patientPhone'] != null)
              _buildDetailRow('Phone', data['patientPhone']),
          ],
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

  void _showAddAppointmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Appointment'),
        content: const Text(
          'Appointment scheduling feature will be available soon. Patients can book appointments through the patient portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAppointmentStatus(
    String appointmentId,
    String newStatus,
  ) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment ${newStatus == 'completed' ? 'completed' : 'cancelled'} successfully',
            ),
            backgroundColor: newStatus == 'completed'
                ? AppTheme.successGreen
                : AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating appointment: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
