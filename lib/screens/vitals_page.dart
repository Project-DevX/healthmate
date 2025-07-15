import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VitalsPage extends StatelessWidget {
  const VitalsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Vitals')),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('vitals')
                  .where('patientId', isEqualTo: user.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No vitals found.'));
                }
                final vitals = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: vitals.length,
                  itemBuilder: (context, index) {
                    final data = vitals[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          'BP: ${data['bpSystolic'] ?? '--'}/${data['bpDiastolic'] ?? '--'}',
                        ),
                        subtitle: Text(
                          'Glucose: ${data['glucose'] ?? '--'} | Temp: ${data['temperature'] ?? '--'} | HR: ${data['heartRate'] ?? '--'}',
                        ),
                        trailing: Text(
                          data['timestamp'] != null
                              ? (data['timestamp'] as Timestamp)
                                    .toDate()
                                    .toLocal()
                                    .toString()
                                    .split('.')[0]
                              : '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
