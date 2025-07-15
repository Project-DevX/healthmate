import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  Future<Map<String, int>> _fetchAnalytics() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .get();
    final apptSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .get();
    final labSnap = await FirebaseFirestore.instance
        .collection('lab_reports')
        .get();
    return {
      'Total Users': usersSnap.size,
      'Total Appointments': apptSnap.size,
      'Total Lab Reports': labSnap.size,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: FutureBuilder<Map<String, int>>(
        future: _fetchAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          final data = snapshot.data ?? {};
          if (data.isEmpty) {
            return const Center(child: Text('No analytics data found.'));
          }
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(24),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: data.entries
                .map(
                  (entry) => Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}
