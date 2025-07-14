# Backend Trend Detection Engine - Core Functions

## Overview

This document covers the implementation of the main Firebase Cloud Function for trend detection. This is the entry point that triggers when lab reports reach the threshold of 5 reports.

## Implementation

### Main Trend Detection Function

**File:** `/functions/index.js`

Add this Cloud Function to your existing `index.js` file:

```javascript
/**
 * Detect trends and generate analytics when lab report count threshold is reached
 */
exports.detectLabTrends = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    const {auth, data} = request;
    const {userId, labReportType} = data;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    try {
      // Check if user has enough reports for trend analysis
      const trendAnalysis = await analyzeLabTrends(userId, labReportType);
      
      if (trendAnalysis.shouldGenerateGraphs) {
        // Generate trend data and predictions
        const trendData = await generateTrendData(userId, labReportType, trendAnalysis);
        
        // Store trend analysis results
        await storeTrendAnalysis(userId, labReportType, trendData);
        
        return {
          success: true,
          trendsDetected: true,
          trendData: trendData,
          message: `Trend analysis generated for ${labReportType}`
        };
      }
      
      return {
        success: true,
        trendsDetected: false,
        reportCount: trendAnalysis.reportCount,
        requiredCount: 5
      };
      
    } catch (error) {
      console.error('Error in detectLabTrends:', error);
      throw new HttpsError("internal", "Failed to detect lab trends");
    }
  }
);
```

### Required Imports

Add these imports to the top of your `functions/index.js` file:

```javascript
// Add these imports if not already present
const {onCall} = require("firebase-functions/v2/https");
const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}
```

### Function Parameters

- **userId**: The authenticated user's ID
- **labReportType**: The type of lab report to analyze (e.g., "Blood Sugar", "Cholesterol Panel")

### Return Values

**Success Response (Trends Detected):**
```json
{
  "success": true,
  "trendsDetected": true,
  "trendData": {
    "labReportType": "Blood Sugar",
    "reportCount": 6,
    "vitals": { ... },
    "predictions": { ... }
  },
  "message": "Trend analysis generated for Blood Sugar"
}
```

**Success Response (Insufficient Data):**
```json
{
  "success": true,
  "trendsDetected": false,
  "reportCount": 3,
  "requiredCount": 5
}
```

### Error Handling

The function includes comprehensive error handling for:
- Unauthenticated users
- Database connection issues
- Data processing errors
- Invalid parameters

### Testing the Function

After deployment, you can test this function using:

```javascript
// Frontend call example
const result = await httpsCallable(functions, 'detectLabTrends')({
  userId: 'user123',
  labReportType: 'Blood Sugar'
});
```

### Firestore Security Rules

Ensure your Firestore rules allow trend analysis data:

```javascript
// Add to firestore.rules
match /users/{userId}/trend_analysis/{trendId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

match /users/{userId}/latest_trends/{labType} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Next Steps

After implementing this core function:
1. Continue to **03_BACKEND_HELPER_FUNCTIONS.md** for the supporting analysis functions
2. The helper functions (`analyzeLabTrends`, `generateTrendData`, `storeTrendAnalysis`) will be implemented next
3. Test the function deployment before proceeding

## Deployment

Deploy this function using:

```bash
cd functions
npm install
firebase deploy --only functions:detectLabTrends
```

## Monitoring

Monitor function execution in the Firebase Console:
- Check function logs for errors
- Monitor execution time and memory usage
- Verify successful trend data generation
