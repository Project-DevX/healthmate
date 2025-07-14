# Backend Integration - Automatic Trigger System

## Overview

This document covers integrating the trend detection system with the existing lab report classification workflow to automatically trigger trend analysis when the threshold is reached.

## Implementation

### 1. Modify Existing Lab Report Function

Update your existing `extractLabReportContent` function in `/functions/index.js`:

```javascript
// In extractLabReportContent function, after storing the lab report:
exports.extractLabReportContent = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    // ...existing extraction logic...
    
    // After successful classification and storage:
    if (labReportType && labReportType !== 'other_lab_tests') {
      try {
        // Check if this triggers trend analysis threshold
        await checkTrendAnalysisTrigger(auth.uid, labReportType);
      } catch (error) {
        console.log('Trend analysis check failed:', error);
        // Don't fail the main operation
      }
    }
    
    return result;
  }
);
```

### 2. Automatic Trigger Function

Add this function to automatically check and trigger trend analysis:

```javascript
async function checkTrendAnalysisTrigger(userId, labReportType) {
  const db = admin.firestore();
  
  // Count reports of this type
  const countSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('lab_report_content')
    .where('labReportType', '==', labReportType)
    .get();
  
  const reportCount = countSnapshot.size;
  
  console.log(`📊 User ${userId} has ${reportCount} reports of type ${labReportType}`);
  
  // Trigger trend analysis if threshold reached
  if (reportCount >= 5) {
    // Check if trend analysis was already done recently
    const lastTrendRef = db
      .collection('users')
      .doc(userId)
      .collection('latest_trends')
      .doc(labReportType);
    
    const lastTrend = await lastTrendRef.get();
    const shouldUpdate = !lastTrend.exists || 
      (lastTrend.data()?.reportCount || 0) < reportCount;
    
    if (shouldUpdate) {
      console.log(`🎯 Triggering trend analysis for ${labReportType}`);
      
      // Call trend detection function
      const trendAnalysis = await analyzeLabTrends(userId, labReportType);
      if (trendAnalysis.shouldGenerateGraphs) {
        const trendData = await generateTrendData(userId, labReportType, trendAnalysis);
        await storeTrendAnalysis(userId, labReportType, trendData);
        
        // Send notification about new trends
        await sendTrendNotification(userId, labReportType, trendData);
      }
    }
  }
}
```

### 3. Notification System

Add notification functionality for trend detection:

```javascript
async function sendTrendNotification(userId, labReportType, trendData) {
  // Store notification for user
  const db = admin.firestore();
  
  const notification = {
    type: 'trend_analysis',
    title: 'New Health Trends Detected',
    message: `We've analyzed your ${labReportType} reports and found interesting trends.`,
    labReportType: labReportType,
    vitalsAnalyzed: Object.keys(trendData.vitals).length,
    hasAnomalies: Object.values(trendData.vitals).some(v => v.anomalies.length > 0),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false
  };
  
  await db
    .collection('users')
    .doc(userId)
    .collection('notifications')
    .add(notification);
  
  console.log(`🔔 Trend notification sent to user ${userId}`);
}
```

### 4. Manual Trigger Endpoint

Create an additional endpoint for manual trend analysis requests:

```javascript
/**
 * Manually trigger trend analysis for testing or user request
 */
exports.triggerTrendAnalysisManual = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    const {auth, data} = request;
    const {labReportType} = data;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    try {
      await checkTrendAnalysisTrigger(auth.uid, labReportType);
      return {
        success: true,
        message: `Manual trend analysis triggered for ${labReportType}`
      };
    } catch (error) {
      console.error('Manual trend analysis failed:', error);
      throw new HttpsError("internal", "Failed to trigger trend analysis");
    }
  }
);
```

### 5. Batch Processing Function

For existing users with many reports, create a batch processing function:

```javascript
/**
 * Batch process trend analysis for existing users (admin function)
 */
exports.batchProcessTrends = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    const {auth, data} = request;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    // Only allow for admin users or the user themselves
    const {userId, isAdmin} = data;
    if (!isAdmin && auth.uid !== userId) {
      throw new HttpsError("permission-denied", "Not authorized");
    }
    
    try {
      const db = admin.firestore();
      const results = [];
      
      // Get all lab report types for the user
      const reportsSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('lab_report_content')
        .get();
      
      // Group by lab report type
      const reportsByType = {};
      reportsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const type = data.labReportType;
        if (type && type !== 'other_lab_tests') {
          if (!reportsByType[type]) {
            reportsByType[type] = [];
          }
          reportsByType[type].push(data);
        }
      });
      
      // Process each type with sufficient reports
      for (const [labReportType, reports] of Object.entries(reportsByType)) {
        if (reports.length >= 5) {
          try {
            console.log(`Processing batch trend analysis for ${labReportType}`);
            const trendAnalysis = await analyzeLabTrends(userId, labReportType);
            
            if (trendAnalysis.shouldGenerateGraphs) {
              const trendData = await generateTrendData(userId, labReportType, trendAnalysis);
              await storeTrendAnalysis(userId, labReportType, trendData);
              
              results.push({
                labReportType: labReportType,
                success: true,
                reportCount: reports.length,
                vitalsAnalyzed: Object.keys(trendData.vitals).length
              });
            }
          } catch (error) {
            console.error(`Batch processing failed for ${labReportType}:`, error);
            results.push({
              labReportType: labReportType,
              success: false,
              error: error.message
            });
          }
        }
      }
      
      return {
        success: true,
        processedTypes: results.length,
        results: results
      };
      
    } catch (error) {
      console.error('Batch processing failed:', error);
      throw new HttpsError("internal", "Batch processing failed");
    }
  }
);
```

### 6. Firestore Triggers (Optional)

Add a Firestore trigger to automatically detect new lab reports:

```javascript
/**
 * Firestore trigger when new lab report is added
 */
exports.onLabReportAdded = onDocumentCreated(
  "users/{userId}/lab_report_content/{reportId}",
  async (event) => {
    const reportData = event.data?.data();
    const userId = event.params.userId;
    
    if (reportData && reportData.labReportType && reportData.labReportType !== 'other_lab_tests') {
      try {
        // Small delay to ensure document is fully written
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        await checkTrendAnalysisTrigger(userId, reportData.labReportType);
        console.log(`✅ Trend analysis check completed for ${reportData.labReportType}`);
      } catch (error) {
        console.error('Firestore trigger trend analysis failed:', error);
      }
    }
  }
);
```

### 7. Update Package Dependencies

Update your `functions/package.json` to include required dependencies:

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0",
    "firebase-functions/v1": "^5.0.0",
    "firebase-functions/v2": "^5.0.0"
  }
}
```

### 8. Error Recovery Function

Add a function to handle failed trend analyses:

```javascript
/**
 * Retry failed trend analysis
 */
exports.retryTrendAnalysis = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    const {auth, data} = request;
    const {labReportType, forceUpdate} = data;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    try {
      const db = admin.firestore();
      
      if (forceUpdate) {
        // Delete existing trend analysis to force regeneration
        await db
          .collection('users')
          .doc(auth.uid)
          .collection('latest_trends')
          .doc(labReportType)
          .delete();
      }
      
      await checkTrendAnalysisTrigger(auth.uid, labReportType);
      
      return {
        success: true,
        message: `Trend analysis retry completed for ${labReportType}`
      };
    } catch (error) {
      console.error('Retry trend analysis failed:', error);
      throw new HttpsError("internal", "Retry failed");
    }
  }
);
```

## Testing Integration

### 1. Test Automatic Triggers

1. Upload a 5th lab report of the same type
2. Check Firebase Function logs for trigger execution
3. Verify trend data appears in Firestore
4. Confirm notification is created

### 2. Test Manual Triggers

```javascript
// Frontend test call
const result = await httpsCallable(functions, 'triggerTrendAnalysisManual')({
  labReportType: 'Blood Sugar'
});
```

### 3. Test Batch Processing

```javascript
// Admin/user batch processing
const result = await httpsCallable(functions, 'batchProcessTrends')({
  userId: 'user123',
  isAdmin: false
});
```

## Monitoring and Debugging

### Function Logs

Monitor these log messages:
- `📊 Found X reports of type: [TYPE]`
- `🎯 Triggering trend analysis for [TYPE]`
- `📈 Trend analysis stored for [USER] - [TYPE]`
- `🔔 Trend notification sent to user [USER]`

### Error Handling

Common issues and solutions:
1. **Insufficient reports**: Ensure count check is accurate
2. **Data extraction fails**: Verify lab report structure
3. **Storage errors**: Check Firestore permissions
4. **Notification errors**: Verify notification collection structure

## Deployment

Deploy all new functions:

```bash
cd functions
firebase deploy --only functions
```

Or deploy specific functions:

```bash
firebase deploy --only functions:triggerTrendAnalysisManual,batchProcessTrends,retryTrendAnalysis
```

## Next Steps

Continue to **05_FRONTEND_SERVICES.md** to implement the Flutter service layer for accessing trend data.
