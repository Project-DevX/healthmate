const {onCall} = require("firebase-functions/v2/https");
const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

// Don't initialize db here - wait until functions are called
let db;

// Function to get db instance (lazy initialization)
function getDb() {
  if (!db) {
    db = admin.firestore();
  }
  return db;
}

/**
 * Main trend detection function - triggers when lab report threshold is reached
 */
exports.detectLabTrends = onCall(
  {cors: true},
  async (request) => {
    const {auth, data} = request;
    const {userId, labReportType} = data;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    if (auth.uid !== userId) {
      throw new HttpsError("permission-denied", "User can only access their own data");
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

/**
 * Analyze lab reports to determine if trend detection should be triggered
 */
async function analyzeLabTrends(userId, labReportType) {
  const db = getDb();
  
  // Get all lab reports of this type for the user
  const reportsSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('lab_report_content')
    .where('labReportType', '==', labReportType)
    .orderBy('createdAt', 'desc')
    .get();
  
  const reports = reportsSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
  
  console.log(`📊 Found ${reports.length} reports of type: ${labReportType}`);
  
  const shouldGenerate = reports.length >= 5;
  
  if (shouldGenerate) {
    // Extract vital parameters from reports
    const vitalParameters = extractVitalParameters(reports, labReportType);
    
    return {
      shouldGenerateGraphs: true,
      reportCount: reports.length,
      reports: reports,
      vitalParameters: vitalParameters,
      timespan: calculateTimespan(reports)
    };
  }
  
  return {
    shouldGenerateGraphs: false,
    reportCount: reports.length,
    reports: reports
  };
}

/**
 * Extract vital parameters based on lab report type
 */
function extractVitalParameters(reports, labReportType) {
  const vitalMappings = {
    // Blood Sugar / Glucose
    'blood_sugar': ['glucose', 'blood_glucose', 'fasting_glucose', 'random_glucose'],
    'Blood Sugar': ['glucose', 'blood_glucose', 'fasting_glucose', 'random_glucose'],
    
    // Cholesterol / Lipid Panel
    'cholesterol': ['total_cholesterol', 'ldl', 'hdl', 'triglycerides'],
    'Cholesterol Panel': ['total_cholesterol', 'ldl', 'hdl', 'triglycerides'],
    'Lipid Panel': ['total_cholesterol', 'ldl', 'hdl', 'triglycerides'],
    
    // Complete Blood Count
    'complete_blood_count': ['hemoglobin', 'hematocrit', 'white_blood_cell', 'platelet_count'],
    'Complete Blood Count': ['hemoglobin', 'hematocrit', 'white_blood_cell', 'platelet_count'],
    
    // Liver Function Tests
    'liver_function': ['alt', 'ast', 'bilirubin', 'alkaline_phosphatase'],
    'Liver Function Tests': ['alt', 'ast', 'bilirubin', 'alkaline_phosphatase'],
    
    // Kidney Function Tests
    'kidney_function': ['creatinine', 'blood_urea_nitrogen', 'gfr'],
    'Kidney Function Tests': ['creatinine', 'blood_urea_nitrogen', 'gfr'],
    
    // Thyroid Function Tests
    'thyroid_function': ['tsh', 't3', 't4', 'free_t4'],
    'Thyroid Function Tests': ['tsh', 't3', 't4', 'free_t4'],
  };
  
  const relevantVitals = vitalMappings[labReportType] || [];
  const extractedData = {};
  
  // Initialize arrays for each vital parameter
  relevantVitals.forEach(vital => {
    extractedData[vital] = [];
  });
  
  // Extract values from each report
  reports.forEach(report => {
    const testDate = report.testDate || report.createdAt;
    const testResults = report.testResults || [];
    
    testResults.forEach(test => {
      const testName = test.testName || test.test_name || '';
      const value = parseFloat(test.value);
      const unit = test.unit || '';
      
      // Find matching vital parameter
      relevantVitals.forEach(vital => {
        if (isMatchingTest(testName, vital) && !isNaN(value)) {
          extractedData[vital].push({
            date: testDate,
            value: value,
            unit: unit,
            status: test.status || 'normal',
            reportId: report.id
          });
        }
      });
    });
  });
  
  // Filter out vitals with no data
  Object.keys(extractedData).forEach(vital => {
    if (extractedData[vital].length === 0) {
      delete extractedData[vital];
    } else {
      // Sort by date
      extractedData[vital].sort((a, b) => new Date(a.date) - new Date(b.date));
    }
  });
  
  return extractedData;
}

/**
 * Check if test name matches vital parameter
 */
function isMatchingTest(testName, vitalParameter) {
  const normalized = testName.toLowerCase().replace(/[^a-z0-9]/g, '');
  const vitalNormalized = vitalParameter.toLowerCase().replace(/_/g, '');
  
  const mappings = {
    'glucose': ['glucose', 'bloodglucose', 'fastingglucose', 'randomglucose'],
    'totalcholesterol': ['totalcholesterol', 'cholesterol'],
    'ldl': ['ldl', 'ldlcholesterol', 'lowdensity'],
    'hdl': ['hdl', 'hdlcholesterol', 'highdensity'],
    'triglycerides': ['triglycerides', 'triglyceride'],
    'hemoglobin': ['hemoglobin', 'hgb', 'hb'],
    'hematocrit': ['hematocrit', 'hct'],
    'whitebloodcell': ['wbc', 'whitebloodcell', 'leukocyte'],
    'plateletcount': ['platelet', 'plt'],
    'alt': ['alt', 'alanineaminotransferase'],
    'ast': ['ast', 'aspartateaminotransferase'],
    'bilirubin': ['bilirubin', 'totalbilirubin'],
    'alkalinephosphatase': ['alkalinephosphatase', 'alp'],
    'creatinine': ['creatinine', 'serumcreatinine'],
    'bloodureanitrogen': ['bun', 'bloodureanitrogen', 'urea'],
    'gfr': ['gfr', 'egfr', 'glomerularfiltration'],
    'tsh': ['tsh', 'thyroidstimulating'],
    't3': ['t3', 'triiodothyronine'],
    't4': ['t4', 'thyroxine'],
    'freet4': ['ft4', 'freet4', 'freethyroxine']
  };
  
  const possibleMatches = mappings[vitalNormalized] || [vitalNormalized];
  return possibleMatches.some(match => normalized.includes(match));
}

/**
 * Generate trend data with predictions
 */
async function generateTrendData(userId, labReportType, trendAnalysis) {
  const vitalParameters = trendAnalysis.vitalParameters;
  const trendData = {
    labReportType: labReportType,
    reportCount: trendAnalysis.reportCount,
    timespan: trendAnalysis.timespan,
    vitals: {},
    generatedAt: new Date().toISOString(),
    predictions: {}
  };
  
  // Analyze each vital parameter
  for (const [vitalName, dataPoints] of Object.entries(vitalParameters)) {
    if (dataPoints.length >= 3) { // Need at least 3 points for trend
      const analysis = analyzeVitalTrend(vitalName, dataPoints);
      trendData.vitals[vitalName] = analysis;
      
      // Generate predictions if trend is significant
      if (analysis.trendSignificance > 0.6) {
        const predictions = generatePredictions(vitalName, dataPoints, analysis);
        trendData.predictions[vitalName] = predictions;
      }
    }
  }
  
  return trendData;
}

/**
 * Analyze trend for a specific vital parameter
 */
function analyzeVitalTrend(vitalName, dataPoints) {
  const values = dataPoints.map(point => point.value);
  const dates = dataPoints.map(point => new Date(point.date));
  
  // Calculate basic statistics
  const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
  const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
  const stdDev = Math.sqrt(variance);
  
  // Calculate linear trend
  const trend = calculateLinearTrend(dates, values);
  
  // Determine trend direction and significance
  const trendDirection = trend.slope > 0.1 ? 'increasing' : 
                        trend.slope < -0.1 ? 'decreasing' : 'stable';
  
  const trendSignificance = Math.abs(trend.correlation);
  
  // Detect anomalies
  const anomalies = detectAnomalies(values, mean, stdDev);
  
  return {
    vitalName: vitalName,
    dataCount: dataPoints.length,
    currentValue: values[values.length - 1],
    meanValue: mean,
    standardDeviation: stdDev,
    trendDirection: trendDirection,
    trendSlope: trend.slope,
    trendSignificance: trendSignificance,
    correlation: trend.correlation,
    anomalies: anomalies,
    dataPoints: dataPoints,
    unit: dataPoints[0].unit,
    dateRange: {
      start: dates[0].toISOString(),
      end: dates[dates.length - 1].toISOString()
    }
  };
}

/**
 * Calculate linear trend using least squares regression
 */
function calculateLinearTrend(dates, values) {
  const n = dates.length;
  const x = dates.map((date, i) => i); // Use index as x-axis for simplicity
  const y = values;
  
  const sumX = x.reduce((sum, val) => sum + val, 0);
  const sumY = y.reduce((sum, val) => sum + val, 0);
  const sumXY = x.reduce((sum, val, i) => sum + val * y[i], 0);
  const sumXX = x.reduce((sum, val) => sum + val * val, 0);
  const sumYY = y.reduce((sum, val) => sum + val * val, 0);
  
  const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  const intercept = (sumY - slope * sumX) / n;
  
  // Calculate correlation coefficient
  const correlation = (n * sumXY - sumX * sumY) / 
    Math.sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY));
  
  return {
    slope: slope,
    intercept: intercept,
    correlation: correlation
  };
}

/**
 * Generate future predictions based on trend analysis
 */
function generatePredictions(vitalName, dataPoints, analysis) {
  const lastDate = new Date(dataPoints[dataPoints.length - 1].date);
  const predictions = [];
  
  // Generate predictions for next 3, 6, and 12 months
  const intervals = [3, 6, 12];
  
  intervals.forEach(months => {
    const futureDate = new Date(lastDate);
    futureDate.setMonth(futureDate.getMonth() + months);
    
    // Simple linear extrapolation (can be enhanced with ML models)
    const timeStep = months * 30; // Approximate days
    const predictedValue = analysis.currentValue + (analysis.trendSlope * timeStep);
    
    // Add confidence intervals based on standard deviation
    const confidenceInterval = analysis.standardDeviation * 1.96; // 95% confidence
    
    predictions.push({
      date: futureDate.toISOString(),
      predictedValue: predictedValue,
      confidenceInterval: {
        lower: predictedValue - confidenceInterval,
        upper: predictedValue + confidenceInterval
      },
      confidence: Math.max(0.3, 1 - (months / 12) * 0.7), // Decreasing confidence over time
      monthsAhead: months
    });
  });
  
  return predictions;
}

/**
 * Detect anomalies in vital values
 */
function detectAnomalies(values, mean, stdDev) {
  const threshold = 2; // Number of standard deviations for anomaly detection
  const anomalies = [];
  
  values.forEach((value, index) => {
    const zScore = Math.abs((value - mean) / stdDev);
    if (zScore > threshold) {
      anomalies.push({
        index: index,
        value: value,
        zScore: zScore,
        severity: zScore > 3 ? 'high' : 'moderate'
      });
    }
  });
  
  return anomalies;
}

/**
 * Calculate timespan of reports
 */
function calculateTimespan(reports) {
  if (reports.length < 2) return { days: 0, months: 0 };
  
  const dates = reports
    .map(r => new Date(r.testDate || r.createdAt))
    .sort((a, b) => a - b);
  
  const startDate = dates[0];
  const endDate = dates[dates.length - 1];
  const diffTime = Math.abs(endDate - startDate);
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  const diffMonths = Math.round(diffDays / 30.44); // Average days per month
  
  return {
    days: diffDays,
    months: diffMonths,
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString()
  };
}

/**
 * Store trend analysis results in Firestore
 */
async function storeTrendAnalysis(userId, labReportType, trendData) {
  const db = getDb();
  
  // Store in user's trend analysis collection
  const trendRef = db
    .collection('users')
    .doc(userId)
    .collection('trend_analysis')
    .doc(`${labReportType}_${Date.now()}`);
  
  await trendRef.set(trendData);
  
  // Update latest trend for quick access
  const latestTrendRef = db
    .collection('users')
    .doc(userId)
    .collection('latest_trends')
    .doc(labReportType);
  
  await latestTrendRef.set({
    ...trendData,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`📈 Trend analysis stored for ${userId} - ${labReportType}`);
}

/**
 * Helper function to check and trigger trend analysis (used by multiple functions)
 */
async function checkTrendAnalysisTrigger(userId, labReportType) {
  const db = getDb();
  
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

/**
 * Send notification for trend detection
 */
async function sendTrendNotification(userId, labReportType, trendData) {
  const db = getDb();
  
  // Store notification for user
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

/**
 * Manually trigger trend analysis for testing or user request
 */
exports.triggerTrendAnalysisManual = onCall(
  {cors: true},
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

/**
 * Batch process trend analysis for existing users (admin function)
 */
exports.batchProcessTrends = onCall(
  {cors: true},
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
      const db = getDb();
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

/**
 * Retry failed trend analysis
 */
exports.retryTrendAnalysis = onCall(
  {cors: true},
  async (request) => {
    const {auth, data} = request;
    const {labReportType, forceUpdate} = data;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    try {
      if (forceUpdate) {
        const db = getDb();
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

// Export helper functions for use in index.js
module.exports = {
  analyzeLabTrends,
  generateTrendData,
  storeTrendAnalysis,
  checkTrendAnalysisTrigger,
  sendTrendNotification
};