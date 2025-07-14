const admin = require('firebase-admin');
const { initializeApp } = require('firebase-admin/app');

// Initialize admin (for testing only)
if (!admin.apps.length) {
  initializeApp();
}

const db = admin.firestore();

async function createTestLabReports(userId, labReportType, count = 5) {
  const testReports = [];
  
  for (let i = 0; i < count; i++) {
    const testDate = new Date();
    testDate.setMonth(testDate.getMonth() - i);
    
    const report = {
      labReportType: labReportType,
      testDate: testDate.toISOString(),
      testResults: [
        {
          testName: 'Glucose',
          value: 90 + (Math.random() * 40), // Random value between 90-130
          unit: 'mg/dL',
          status: 'normal'
        }
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const docRef = await db
      .collection('users')
      .doc(userId)
      .collection('lab_report_content')
      .add(report);
    
    testReports.push({ id: docRef.id, ...report });
  }
  
  console.log(`Created ${count} test lab reports for ${labReportType}`);
  return testReports;
}

async function testTrendDetection() {
  const testUserId = 'test-user-123';
  const labReportType = 'Blood Sugar';
  
  try {
    // Create test data
    await createTestLabReports(testUserId, labReportType, 6);
    
    // Import and test trend functions
    const { analyzeLabTrends, generateTrendData, storeTrendAnalysis } = require('./index');
    
    // Test trend analysis
    const trendAnalysis = await analyzeLabTrends(testUserId, labReportType);
    console.log('Trend Analysis:', trendAnalysis);
    
    if (trendAnalysis.shouldGenerateGraphs) {
      const trendData = await generateTrendData(testUserId, labReportType, trendAnalysis);
      console.log('Generated Trend Data:', JSON.stringify(trendData, null, 2));
      
      await storeTrendAnalysis(testUserId, labReportType, trendData);
      console.log('✅ Trend analysis stored successfully');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

// Run tests
if (require.main === module) {
  testTrendDetection();
}

module.exports = { createTestLabReports, testTrendDetection };
