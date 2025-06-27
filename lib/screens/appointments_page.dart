import 'package:flutter/material.dart';
class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: const Center(child: Text('Appointments Page (Placeholder)')),
    );
  }
} 