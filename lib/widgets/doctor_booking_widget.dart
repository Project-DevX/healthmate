// lib/widgets/doctor_booking_widget.dart
import 'package:flutter/material.dart';
import '../models/shared_models.dart';
import '../services/interconnect_service.dart';

class DoctorBookingWidget extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String? caregiverId;

  const DoctorBookingWidget({
    Key? key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    this.caregiverId,
  }) : super(key: key);

  @override
  State<DoctorBookingWidget> createState() => _DoctorBookingWidgetState();
}

class _DoctorBookingWidgetState extends State<DoctorBookingWidget> {
  List<DoctorProfile> _doctors = [];
  List<DoctorProfile> _filteredDoctors = [];
  bool _isLoading = true;
  String _selectedSpecialty = 'All';
  String _searchQuery = '';
  DoctorProfile? _selectedDoctor;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();

  final List<String> _specialties = [
    'All',
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'General Medicine',
    'Neurology',
    'Oncology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Pulmonology',
    'Radiology',
    'Surgery',
    'Urology',
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors = await InterconnectService.getAvailableDoctors();
      setState(() {
        _doctors = doctors;
        _filteredDoctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load doctors: $e')),
        );
      }
    }
  }

  void _filterDoctors() {
    setState(() {
      _filteredDoctors = _doctors.where((doctor) {
        final matchesSpecialty = _selectedSpecialty == 'All' || doctor.specialty == _selectedSpecialty;
        final matchesSearch = doctor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             doctor.hospitalName.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesSpecialty && matchesSearch;
      }).toList();
    });
  }

  Future<void> _loadAvailableTimeSlots() async {
    if (_selectedDoctor == null || _selectedDate == null) return;

    try {
      final timeSlots = await InterconnectService.getAvailableTimeSlots(
        _selectedDoctor!.id,
        _selectedDate!,
      );
      setState(() {
        _availableTimeSlots = timeSlots;
        _selectedTimeSlot = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load time slots: $e')),
        );
      }
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedDoctor == null || _selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      final appointment = Appointment(
        id: '',
        patientId: widget.patientId,
        patientName: widget.patientName,
        patientEmail: widget.patientEmail,
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.name,
        doctorSpecialty: _selectedDoctor!.specialty,
        hospitalId: _selectedDoctor!.hospitalId,
        hospitalName: _selectedDoctor!.hospitalName,
        appointmentDate: _selectedDate!,
        timeSlot: _selectedTimeSlot!,
        status: 'scheduled',
        reason: _reasonController.text.trim(),
        symptoms: _symptomsController.text.trim(),
        createdAt: DateTime.now(),
        caregiverId: widget.caregiverId,
      );

      await InterconnectService.bookAppointment(appointment);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book appointment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search doctors or hospitals...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _filterDoctors();
                        },
                      ),
                      const SizedBox(height: 12),
                      // Specialty Filter
                      DropdownButtonFormField<String>(
                        value: _selectedSpecialty,
                        decoration: InputDecoration(
                          labelText: 'Specialty',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _specialties.map((specialty) {
                          return DropdownMenuItem(
                            value: specialty,
                            child: Text(specialty),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedSpecialty = value!);
                          _filterDoctors();
                        },
                      ),
                    ],
                  ),
                ),
                // Doctors List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doctor = _filteredDoctors[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor,
                            child: Text(
                              doctor.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            doctor.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doctor.specialty),
                              Text(doctor.hospitalName),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 16, color: Colors.amber),
                                  Text(' ${doctor.rating.toStringAsFixed(1)}'),
                                  const SizedBox(width: 16),
                                  Text('${doctor.experienceYears} years exp.'),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '\$${doctor.consultationFee.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text('Consultation'),
                            ],
                          ),
                          onTap: () => _showBookingDialog(doctor),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showBookingDialog(DoctorProfile doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _availableTimeSlots = [];
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Book with Dr. ${doctor.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Doctor Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            doctor.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(doctor.specialty),
                              Text(doctor.hospitalName),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date Selection
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    _selectedDate == null
                        ? 'Select Date'
                        : 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setDialogState(() => _selectedDate = date);
                      await _loadAvailableTimeSlots();
                      setDialogState(() {});
                    }
                  },
                ),
                
                // Time Slot Selection
                if (_selectedDate != null) ...[
                  const SizedBox(height: 12),
                  const Text('Available Time Slots:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availableTimeSlots.map((slot) {
                      final isSelected = slot == _selectedTimeSlot;
                      return FilterChip(
                        label: Text(slot),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            _selectedTimeSlot = selected ? slot : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Reason
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for visit',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 12),
                
                // Symptoms
                TextField(
                  controller: _symptomsController,
                  decoration: const InputDecoration(
                    labelText: 'Symptoms (optional)',
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
              onPressed: (_selectedDate != null && _selectedTimeSlot != null)
                  ? () {
                      Navigator.of(context).pop();
                      _bookAppointment();
                    }
                  : null,
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }
}
