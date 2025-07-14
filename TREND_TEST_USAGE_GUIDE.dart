// HOW TO USE THE TREND TEST DATA GENERATOR
// =======================================

// OPTION 1: Add the test widget to your patient dashboard
// -------------------------------------------------------

// In your patientDashboard.dart or any screen, add this import:
import 'widgets/trend_test_data_widget.dart';

// Then add the widget to your screen:
class PatientDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Your existing widgets...
          
          // Add this for development/testing:
          if (kDebugMode) // Only show in debug mode
            const TrendTestDataWidget(),
          
          // Rest of your widgets...
        ],
      ),
    );
  }
}

// OPTION 2: Add a floating action button
// --------------------------------------

// In any screen, add a FAB for quick testing:
class SomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your existing content...
      floatingActionButton: kDebugMode 
          ? const TrendTestDataButton() 
          : null,
    );
  }
}

// OPTION 3: Call the service directly from code
// ----------------------------------------------

import 'services/test_data_service.dart';

// Generate all test data:
await TrendAnalysisTestData.generateTestData();

// Generate just blood sugar data (fastest):
await TrendAnalysisTestData.generateQuickBloodSugarData();

// Clear test data:
await TrendAnalysisTestData.clearTestData();

// OPTION 4: Add to developer settings screen
// ------------------------------------------

class DeveloperSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Settings')),
      body: const SingleChildScrollView(
        child: Column(
          children: [
            TrendTestDataWidget(),
            // Other developer options...
          ],
        ),
      ),
    );
  }
}

// WHAT THE TEST DATA GENERATES:
// ============================

/*
1. Random Blood Sugar Test (15 reports over 12 months):
   - Values start at ~85 mg/dl and gradually increase to ~140 mg/dl
   - Shows pre-diabetic progression trend
   - Includes 2 anomalous spikes (stress/illness simulation)
   - Perfect for testing upward trend detection

2. Hemoglobin A1c (6 reports over 6 months):
   - Values start high at 6.8% and improve to 5.6%
   - Shows treatment effectiveness
   - Plateaus in normal range
   - Great for testing downward trend detection

3. Complete Blood Count (8 reports over 8 months):
   - Hemoglobin: Slight decline trend (anemia development)
   - WBC: Normal with 2 infection spikes
   - Platelets: Stable with one temporary drop
   - Excellent for multi-parameter trend analysis

The data includes realistic:
- Date ranges spanning months
- Natural variation and noise
- Clinically relevant anomalies
- Multiple trend patterns (increasing, decreasing, stable)
- Proper medical units and reference ranges
*/

// TESTING WORKFLOW:
// ================

/*
1. Add TrendTestDataWidget to your dashboard
2. Tap "Generate Full Data" or "Quick Test"
3. Wait for confirmation message
4. Navigate to Health Trends screen
5. You should see:
   - Multiple lab report types in dropdown
   - Interactive trend charts with real data
   - Anomaly detection markers
   - Prediction algorithms working
   - Health score calculations

6. Test different features:
   - Switch between lab types
   - View different vital parameters
   - Check Overview, Charts, and Predictions tabs
   - Look for anomaly indicators
   - Verify trend direction detection

7. When done testing, use "Clear Test Data" to clean up
*/
