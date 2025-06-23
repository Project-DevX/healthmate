import 'package:flutter/material.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;

  // List of pages to display
  final List<Widget> _pages = [
    const DashboardContent(),
    const UserProfileContent(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthMate'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showEmergencyOptions(context);
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.add_alert),
      ),
    );
  }

  void _showEmergencyOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Emergency Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildEmergencyOption(
                context,
                Icons.emergency,
                'Emergency',
                Colors.red,
                () {
                  Navigator.pop(context);
                  // TODO: Navigate to emergency page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Emergency option selected')),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildEmergencyOption(
                context,
                Icons.medical_services,
                'Find Doctor',
                Colors.blue,
                () {
                  Navigator.pop(context);
                  // TODO: Navigate to find doctor page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Find Doctor option selected')),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildEmergencyOption(
                context,
                Icons.people,
                'Find Caregiver',
                Colors.green,
                () {
                  Navigator.pop(context);
                  // TODO: Navigate to find caregiver page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Find Caregiver option selected')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmergencyOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 24,
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// Dashboard Content Widget
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting and summary
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Patient Name',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Health Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHealthMetric(context, '120/80', 'Blood Pressure', Icons.favorite),
                      _buildHealthMetric(context, '72 bpm', 'Heart Rate', Icons.monitor_heart),
                      _buildHealthMetric(context, '98.6°F', 'Temperature', Icons.thermostat),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Upcoming appointments
          const Text(
            'Upcoming Appointments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 2,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.medical_services),
                  ),
                  title: Text(
                    index == 0 ? 'Dr. Smith - Cardiology' : 'Dr. Johnson - General',
                  ),
                  subtitle: Text(
                    index == 0 ? 'Tomorrow, 10:00 AM' : 'Jun 30, 2:30 PM',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to appointment details
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Medications
          const Text(
            'Your Medications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                List<String> medications = [
                  'Aspirin - 1 tablet daily',
                  'Vitamin D - 1 capsule daily',
                  'Metformin - 2 tablets daily'
                ];
                List<String> times = ['8:00 AM', '8:00 AM', '8:00 AM, 8:00 PM'];
                
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.medication),
                  ),
                  title: Text(medications[index]),
                  subtitle: Text(times[index]),
                  trailing: Checkbox(
                    value: false,
                    onChanged: (_) {
                      // TODO: Mark medication as taken
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          radius: 24,
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

// User Profile Content Widget
class UserProfileContent extends StatelessWidget {
  const UserProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 48,
                    backgroundImage: NetworkImage(
                      'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Patient Name',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'patient@example.com',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Edit profile
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Profile details
          const Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildProfileDetail(Icons.calendar_today, 'Date of Birth', 'January 1, 1990'),
                const Divider(height: 1),
                _buildProfileDetail(Icons.phone, 'Phone', '+1 123-456-7890'),
                const Divider(height: 1),
                _buildProfileDetail(Icons.people, 'Gender', 'Male'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Account settings
          const Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildSettingsOption(
                  context,
                  Icons.privacy_tip,
                  'Privacy Settings',
                  () {
                    // TODO: Navigate to privacy settings
                  },
                ),
                const Divider(height: 1),
                _buildSettingsOption(
                  context,
                  Icons.notifications,
                  'Notification Preferences',
                  () {
                    // TODO: Navigate to notification settings
                  },
                ),
                const Divider(height: 1),
                _buildSettingsOption(
                  context,
                  Icons.help,
                  'Help & Support',
                  () {
                    // TODO: Navigate to help & support
                  },
                ),
                const Divider(height: 1),
                _buildSettingsOption(
                  context,
                  Icons.logout,
                  'Logout',
                  () {
                    // TODO: Implement logout
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logging out...')),
                    );
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.black,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}