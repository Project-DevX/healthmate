const {onCall} = require("firebase-functions/v2/https");
const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

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
 * Analyze lab trends to determine if enough data exists for trend generation
 */
async function analyzeLabTrends(userId, labReportType) {
  try {
    const reportsRef = db.collection('users').doc(userId).collection('lab_reports');
    const snapshot = await reportsRef
      .where('reportType', '==', labReportType)
      .orderBy('date', 'desc')
      .get();
    
    const reportCount = snapshot.size;
    const shouldGenerateGraphs = reportCount >= 5;
    
    const reports = [];
    snapshot.forEach(doc => {
      reports.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return {
      reportCount,
      shouldGenerateGraphs,
      reports,
      latestReportDate: reports.length > 0 ? reports[0].date : null
    };
    
  } catch (error) {
    console.error('Error analyzing lab trends:', error);
    throw error;
  }
}

/**
 * Generate trend data and predictions based on lab reports
 */
async function generateTrendData(userId, labReportType, trendAnalysis) {
  try {
    const reports = trendAnalysis.reports;
    
    // Extract vital signs data from reports
    const vitalsData = extractVitalsData(reports);
    
    // Calculate trends and predictions
    const trends = calculateTrends(vitalsData);
    const predictions = generatePredictions(vitalsData);
    
    const trendData = {
      labReportType,
      reportCount: trendAnalysis.reportCount,
      dateRange: {
        from: reports[reports.length - 1].date,
        to: reports[0].date
      },
      vitals: vitalsData,
      trends,
      predictions,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastAnalyzedReport: reports[0].id
    };
    
    return trendData;
    
  } catch (error) {
    console.error('Error generating trend data:', error);
    throw error;
  }
}

/**
 * Store trend analysis results in Firestore
 */
async function storeTrendAnalysis(userId, labReportType, trendData) {
  try {
    const batch = db.batch();
    
    // Store in trend_analysis collection with timestamp-based ID
    const trendAnalysisRef = db.collection('users')
      .doc(userId)
      .collection('trend_analysis')
      .doc();
    
    batch.set(trendAnalysisRef, trendData);
    
    // Store latest trends for quick access
    const latestTrendsRef = db.collection('users')
      .doc(userId)
      .collection('latest_trends')
      .doc(labReportType.replace(/\s+/g, '_').toLowerCase());
    
    batch.set(latestTrendsRef, {
      ...trendData,
      trendAnalysisId: trendAnalysisRef.id
    });
    
    await batch.commit();
    
    console.log(`Trend analysis stored for user ${userId}, lab type: ${labReportType}`);
    
  } catch (error) {
    console.error('Error storing trend analysis:', error);
    throw error;
  }
}

/**
 * Extract vital signs data from lab reports
 */
function extractVitalsData(reports) {
  const vitalsData = {};
  
  reports.forEach(report => {
    const date = report.date;
    
    // Extract common vital signs
    if (report.vitals) {
      Object.keys(report.vitals).forEach(vitalType => {
        if (!vitalsData[vitalType]) {
          vitalsData[vitalType] = [];
        }
        
        vitalsData[vitalType].push({
          date: date,
          value: report.vitals[vitalType],
          reportId: report.id
        });
      });
    }
  });
  
  // Sort each vital type by date
  Object.keys(vitalsData).forEach(vitalType => {
    vitalsData[vitalType].sort((a, b) => new Date(a.date) - new Date(b.date));
  });
  
  return vitalsData;
}

/**
 * Calculate trends for each vital sign
 */
function calculateTrends(vitalsData) {
  const trends = {};
  
  Object.keys(vitalsData).forEach(vitalType => {
    const data = vitalsData[vitalType];
    
    if (data.length >= 2) {
      const values = data.map(d => d.value);
      const trend = calculateLinearTrend(values);
      
      trends[vitalType] = {
        direction: trend > 0 ? 'increasing' : trend < 0 ? 'decreasing' : 'stable',
        slope: trend,
        correlation: calculateCorrelation(data),
        average: values.reduce((sum, val) => sum + val, 0) / values.length,
        min: Math.min(...values),
        max: Math.max(...values)
      };
    }
  });
  
  return trends;
}

/**
 * Generate predictions for vital signs
 */
function generatePredictions(vitalsData) {
  const predictions = {};
  
  Object.keys(vitalsData).forEach(vitalType => {
    const data = vitalsData[vitalType];
    
    if (data.length >= 3) {
      const values = data.map(d => d.value);
      const trend = calculateLinearTrend(values);
      const lastValue = values[values.length - 1];
      
      // Simple linear prediction for next 30, 60, 90 days
      predictions[vitalType] = {
        next30Days: lastValue + (trend * 30),
        next60Days: lastValue + (trend * 60),
        next90Days: lastValue + (trend * 90),
        confidence: calculatePredictionConfidence(values)
      };
    }
  });
  
  return predictions;
}

/**
 * Calculate linear trend (slope) for a series of values
 */
function calculateLinearTrend(values) {
  const n = values.length;
  const sumX = (n * (n - 1)) / 2; // 0 + 1 + 2 + ... + (n-1)
  const sumY = values.reduce((sum, val) => sum + val, 0);
  const sumXY = values.reduce((sum, val, index) => sum + (index * val), 0);
  const sumX2 = (n * (n - 1) * (2 * n - 1)) / 6; // 0² + 1² + 2² + ... + (n-1)²
  
  const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  return isNaN(slope) ? 0 : slope;
}

/**
 * Calculate correlation coefficient for data points
 */
function calculateCorrelation(data) {
  if (data.length < 2) return 0;
  
  const values = data.map(d => d.value);
  const indices = data.map((_, index) => index);
  
  const n = values.length;
  const sumX = indices.reduce((sum, val) => sum + val, 0);
  const sumY = values.reduce((sum, val) => sum + val, 0);
  const sumXY = indices.reduce((sum, val, index) => sum + (val * values[index]), 0);
  const sumX2 = indices.reduce((sum, val) => sum + val * val, 0);
  const sumY2 = values.reduce((sum, val) => sum + val * val, 0);
  
  const numerator = n * sumXY - sumX * sumY;
  const denominator = Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
  
  return denominator === 0 ? 0 : numerator / denominator;
}

/**
 * Calculate prediction confidence based on data consistency
 */
function calculatePredictionConfidence(values) {
  if (values.length < 3) return 0;
  
  const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
  const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
  const standardDeviation = Math.sqrt(variance);
  
  // Lower standard deviation = higher confidence
  const coefficientOfVariation = standardDeviation / mean;
  const confidence = Math.max(0, Math.min(1, 1 - coefficientOfVariation));
  
  return Math.round(confidence * 100) / 100; // Round to 2 decimal places
}