# Navigation Setup
This document outlines the steps to integrate navigation for the trend analysis feature in the HealthMate app. It includes updates to the main app structure, patient dashboard, and theme settings.
It also covers quick access methods, error handling, performance optimizations, and testing setup.

## Navigation Integration

### 1. Update Main App Structure

**File:** `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthMate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      // Add routes for trend analysis
      routes: {
        '/trends': (context) => const TrendAnalysisScreen(),
        '/trends/lab-type': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return TrendAnalysisScreen(labReportType: args['labReportType']);
        },
      },
    );
  }
}
```

### 2. Update Patient Dashboard

**File:** `lib/patientDashboard.dart` (or your main dashboard file)

Add trend analysis navigation to your existing dashboard:

```dart
// Add this import at the top
import 'screens/trend_analysis_screen.dart';
import 'services/trend_analysis_service.dart';

// Add this method to your dashboard class
class _PatientDashboardState extends State<PatientDashboard> {
  // ...existing code...

  Widget _buildTrendAnalysisCard() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _navigateToTrends(),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Health Trends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View patterns in your lab reports',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTrends() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrendAnalysisScreen(),
      ),
    );
  }

  // Add this to your existing build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...existing scaffold code...
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ...existing widgets...
            _buildTrendAnalysisCard(),
            // ...rest of existing widgets...
          ],
        ),
      ),
    );
  }
}
```

### 3. Update Bottom Navigation (if using)

If you're using bottom navigation, add trend analysis as a tab:

```dart
// In your main navigation widget
class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const PatientDashboard(),
    const MedicalRecordsScreen(),
    const TrendAnalysisScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Trends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
```

### 4. Add Drawer Menu Item

If you're using a drawer menu, add trend analysis:

```dart
// In your drawer widget
Widget _buildDrawer() {
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        // ...existing drawer items...
        ListTile(
          leading: const Icon(Icons.trending_up),
          title: const Text('Health Trends'),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TrendAnalysisScreen(),
              ),
            );
          },
        ),
        // ...rest of existing items...
      ],
    ),
  );
}
```

## Theme Updates

### Create App Theme

**File:** `lib/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[700],
      scaffoldBackgroundColor: Colors.grey[50],
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      
      // Card theme
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      
      // Chart colors for fl_chart
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[300],
      scaffoldBackgroundColor: Colors.grey[900],
      brightness: Brightness.dark,
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      
      cardTheme: CardTheme(
        elevation: 2,
        color: Colors.grey[800],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    );
  }

  // Chart colors for different trend types
  static const Map<String, Color> trendColors = {
    'increasing': Colors.red,
    'decreasing': Colors.orange,
    'stable': Colors.green,
    'prediction': Colors.blue,
    'anomaly': Colors.deepOrange,
  };

  // Health status colors
  static const Map<String, Color> healthStatusColors = {
    'excellent': Colors.green,
    'good': Colors.lightGreen,
    'fair': Colors.orange,
    'concerning': Colors.red,
  };
}
```

## Quick Access Methods

### 1. Floating Action Button

Add quick access to trend analysis from lab reports screen:

```dart
// In medical_records_screen.dart or similar
FloatingActionButton.extended(
  onPressed: () => _navigateToTrends(),
  icon: const Icon(Icons.trending_up),
  label: const Text('View Trends'),
),
```

### 2. Lab Report Type Cards

Show trend availability on lab report type cards:

```dart
// In lab reports listing
Widget _buildLabReportTypeCard(String labType, int count) {
  return FutureBuilder<bool>(
    future: TrendAnalysisService.isTrendAnalysisAvailable(labType),
    builder: (context, snapshot) {
      final hasTrends = snapshot.data ?? false;
      
      return Card(
        child: ListTile(
          title: Text(labType),
          subtitle: Text('$count reports'),
          trailing: hasTrends
              ? IconButton(
                  icon: const Icon(Icons.trending_up, color: Colors.green),
                  onPressed: () => _navigateToSpecificTrend(labType),
                )
              : Text(
                  'Need ${5 - count} more',
                  style: const TextStyle(fontSize: 12),
                ),
        ),
      );
    },
  );
}

void _navigateToSpecificTrend(String labType) {
  Navigator.pushNamed(
    context,
    '/trends/lab-type',
    arguments: {'labReportType': labType},
  );
}
```

### 3. Dashboard Notifications

Show trend notifications on dashboard:

```dart
// In dashboard
Widget _buildTrendNotifications() {
  return FutureBuilder<List<TrendNotification>>(
    future: TrendAnalysisService.getTrendNotifications(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const SizedBox.shrink();
      }
      
      final unreadNotifications = snapshot.data!
          .where((notification) => !notification.read)
          .toList();
      
      if (unreadNotifications.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return Card(
        color: Colors.blue[50],
        child: ListTile(
          leading: Icon(Icons.notifications, color: Colors.blue[700]),
          title: Text('New Health Trends Available'),
          subtitle: Text('${unreadNotifications.length} new analysis'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _navigateToTrends(),
        ),
      );
    },
  );
}
```

## Error Handling

### Global Error Handler

```dart
// In main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ...existing config...
      
      // Global error handling
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return CustomErrorWidget(errorDetails: errorDetails);
        };
        return widget!;
      },
    );
  }
}

class CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;
  
  const CustomErrorWidget({Key? key, required this.errorDetails}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.red[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 48, color: Colors.red[700]),
              const SizedBox(height: 16),
              const Text('Something went wrong'),
              const SizedBox(height: 8),
              Text(
                'Please try again later',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Performance Optimization

### 1. Lazy Loading

```dart
// Use lazy loading for trend analysis data
class TrendAnalysisScreen extends StatefulWidget {
  // ...existing code...
}

class _TrendAnalysisScreenState extends State<TrendAnalysisScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs
  
  // ...rest of implementation...
}
```

### 2. Caching

```dart
// Add caching for trend data
class TrendAnalysisService {
  static final Map<String, TrendAnalysisData> _cache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);
  
  static Future<TrendAnalysisData?> getTrendAnalysis(String labReportType) async {
    // Check cache first
    if (_cache.containsKey(labReportType)) {
      final timestamp = _cacheTimestamp[labReportType];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _cache[labReportType];
      }
    }
    
    // Fetch from server
    final data = await _fetchTrendAnalysis(labReportType);
    if (data != null) {
      _cache[labReportType] = data;
      _cacheTimestamp[labReportType] = DateTime.now();
    }
    
    return data;
  }
  
  // ...rest of service methods...
}
```

## Testing Setup

### Unit Tests

```dart
// test/services/trend_analysis_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/services/trend_analysis_service.dart';

void main() {
  group('TrendAnalysisService', () {
    test('should return null when user not authenticated', () async {
      // Test implementation
    });
    
    test('should parse trend data correctly', () async {
      // Test implementation
    });
  });
}
```

### Widget Tests

```dart
// test/widgets/trend_chart_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/widgets/trend_chart_widget.dart';

void main() {
  group('TrendChartWidget', () {
    testWidgets('should display chart with data points', (tester) async {
      // Test implementation
    });
  });
}
```

## Next Steps

Continue to **09_TESTING_DEPLOYMENT.md** for comprehensive testing strategies and deployment instructions.
