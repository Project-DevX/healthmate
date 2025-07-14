const admin = require('firebase-admin');
const { performance } = require('perf_hooks');

// Initialize Firebase Admin
// Note: In production, use proper service account key
if (!admin.apps.length) {
  admin.initializeApp({
    // Configure with your Firebase project
  });
}

const db = admin.firestore();

async function performanceTest() {
  console.log('🚀 Starting performance test...');
  
  // Test 1: Create large dataset
  console.log('📊 Creating test dataset...');
  const startCreate = performance.now();
  const testUserId = 'performance-test-user';
  const labReportType = 'Blood Sugar';
  
  const batch = db.batch();
  
  for (let i = 0; i < 50; i++) {
    const testDate = new Date();
    testDate.setMonth(testDate.getMonth() - i);
    
    const docRef = db
      .collection('users')
      .doc(testUserId)
      .collection('lab_report_content')
      .doc();
    
    batch.set(docRef, {
      labReportType: labReportType,
      testDate: testDate.toISOString(),
      testResults: [
        {
          testName: 'Glucose',
          value: 90 + (Math.random() * 40),
          unit: 'mg/dL',
          status: 'normal'
        }
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  await batch.commit();
  const createTime = performance.now() - startCreate;
  console.log(`✅ Created 50 reports in ${createTime.toFixed(2)}ms`);
  
  // Test 2: Data retrieval performance
  console.log('🔍 Testing data retrieval performance...');
  const startRetrieval = performance.now();
  
  const snapshot = await db
    .collection('users')
    .doc(testUserId)
    .collection('lab_report_content')
    .where('labReportType', '==', labReportType)
    .orderBy('testDate', 'desc')
    .limit(20)
    .get();
  
  const retrievalTime = performance.now() - startRetrieval;
  console.log(`✅ Retrieved ${snapshot.size} documents in ${retrievalTime.toFixed(2)}ms`);
  
  // Test 3: Trend calculation simulation
  console.log('📈 Testing trend calculation performance...');
  const startCalculation = performance.now();
  
  const reports = snapshot.docs.map(doc => doc.data());
  
  // Simulate trend analysis calculations
  const values = reports.map(report => report.testResults[0].value);
  const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
  const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
  const stdDev = Math.sqrt(variance);
  
  // Simulate slope calculation
  const dates = reports.map(report => new Date(report.testDate).getTime());
  const n = values.length;
  const sumX = dates.reduce((sum, date) => sum + date, 0);
  const sumY = values.reduce((sum, val) => sum + val, 0);
  const sumXY = dates.reduce((sum, date, i) => sum + (date * values[i]), 0);
  const sumXX = dates.reduce((sum, date) => sum + (date * date), 0);
  
  const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  const trendDirection = slope > 0.1 ? 'increasing' : slope < -0.1 ? 'decreasing' : 'stable';
  
  const calculationTime = performance.now() - startCalculation;
  console.log(`✅ Trend calculation completed in ${calculationTime.toFixed(2)}ms`);
  console.log(`   Mean: ${mean.toFixed(2)}, Std Dev: ${stdDev.toFixed(2)}, Trend: ${trendDirection}`);
  
  // Test 4: Multiple concurrent requests simulation
  console.log('🔄 Testing concurrent requests...');
  const startConcurrent = performance.now();
  
  const concurrentPromises = [];
  for (let i = 0; i < 5; i++) {
    const promise = db
      .collection('users')
      .doc(`concurrent-user-${i}`)
      .collection('lab_report_content')
      .where('labReportType', '==', labReportType)
      .limit(10)
      .get();
    concurrentPromises.push(promise);
  }
  
  await Promise.all(concurrentPromises);
  const concurrentTime = performance.now() - startConcurrent;
  console.log(`✅ 5 concurrent queries completed in ${concurrentTime.toFixed(2)}ms`);
  
  // Test 5: Memory usage simulation
  console.log('💾 Testing memory efficiency...');
  const startMemory = performance.now();
  
  // Create large in-memory dataset
  const largeDataset = [];
  for (let i = 0; i < 1000; i++) {
    largeDataset.push({
      date: new Date(Date.now() - (i * 24 * 60 * 60 * 1000)),
      value: 100 + (Math.random() * 50),
      processed: false
    });
  }
  
  // Process the dataset
  const processedData = largeDataset.map(item => ({
    ...item,
    processed: true,
    zscore: (item.value - 125) / 15, // Simulate z-score calculation
    anomaly: Math.abs((item.value - 125) / 15) > 2
  }));
  
  const memoryTime = performance.now() - startMemory;
  const anomalies = processedData.filter(item => item.anomaly).length;
  console.log(`✅ Processed 1000 data points in ${memoryTime.toFixed(2)}ms`);
  console.log(`   Found ${anomalies} anomalies`);
  
  // Cleanup
  console.log('🧹 Cleaning up test data...');
  const cleanupBatch = db.batch();
  const cleanupSnapshot = await db
    .collection('users')
    .doc(testUserId)
    .collection('lab_report_content')
    .get();
  
  cleanupSnapshot.docs.forEach(doc => {
    cleanupBatch.delete(doc.ref);
  });
  
  await cleanupBatch.commit();
  console.log('✅ Test data cleaned up');
  
  // Summary
  console.log('\n📊 Performance Test Results:');
  console.log(`- Data Creation (50 docs): ${createTime.toFixed(2)}ms`);
  console.log(`- Data Retrieval (20 docs): ${retrievalTime.toFixed(2)}ms`);
  console.log(`- Trend Calculation: ${calculationTime.toFixed(2)}ms`);
  console.log(`- Concurrent Requests (5): ${concurrentTime.toFixed(2)}ms`);
  console.log(`- Memory Processing (1000 items): ${memoryTime.toFixed(2)}ms`);
  
  const totalTime = createTime + retrievalTime + calculationTime + concurrentTime + memoryTime;
  console.log(`- Total Test Time: ${totalTime.toFixed(2)}ms`);
  
  // Performance thresholds
  console.log('\n🎯 Performance Analysis:');
  console.log(`- Data Creation: ${createTime < 2000 ? '✅ GOOD' : '⚠️ SLOW'} (< 2s)`);
  console.log(`- Data Retrieval: ${retrievalTime < 500 ? '✅ GOOD' : '⚠️ SLOW'} (< 500ms)`);
  console.log(`- Trend Calculation: ${calculationTime < 100 ? '✅ GOOD' : '⚠️ SLOW'} (< 100ms)`);
  console.log(`- Concurrent Requests: ${concurrentTime < 1000 ? '✅ GOOD' : '⚠️ SLOW'} (< 1s)`);
  console.log(`- Memory Processing: ${memoryTime < 200 ? '✅ GOOD' : '⚠️ SLOW'} (< 200ms)`);
}

// Test Firestore connection
async function testConnection() {
  try {
    await db.collection('test').doc('connection').set({
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      test: true
    });
    
    await db.collection('test').doc('connection').delete();
    console.log('✅ Firestore connection successful');
    return true;
  } catch (error) {
    console.error('❌ Firestore connection failed:', error.message);
    return false;
  }
}

// Stress test with larger datasets
async function stressTest() {
  console.log('\n🔥 Starting stress test...');
  
  const stressTestUser = 'stress-test-user';
  const batchSize = 500;
  const startStress = performance.now();
  
  try {
    // Create large batch
    const stressBatch = db.batch();
    
    for (let i = 0; i < batchSize; i++) {
      const docRef = db
        .collection('users')
        .doc(stressTestUser)
        .collection('stress_test')
        .doc();
      
      stressBatch.set(docRef, {
        index: i,
        data: `stress_test_data_${i}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        randomValue: Math.random() * 1000
      });
    }
    
    await stressBatch.commit();
    const stressTime = performance.now() - startStress;
    
    console.log(`✅ Stress test completed: ${batchSize} documents in ${stressTime.toFixed(2)}ms`);
    console.log(`   Average: ${(stressTime / batchSize).toFixed(2)}ms per document`);
    
    // Cleanup stress test data
    const stressSnapshot = await db
      .collection('users')
      .doc(stressTestUser)
      .collection('stress_test')
      .get();
    
    const cleanupStressBatch = db.batch();
    stressSnapshot.docs.forEach(doc => {
      cleanupStressBatch.delete(doc.ref);
    });
    
    await cleanupStressBatch.commit();
    console.log('✅ Stress test data cleaned up');
    
  } catch (error) {
    console.error('❌ Stress test failed:', error.message);
  }
}

// Main execution
async function main() {
  console.log('🧪 Firebase Performance Testing Suite');
  console.log('=====================================\n');
  
  // Test connection first
  const connected = await testConnection();
  if (!connected) {
    console.log('❌ Cannot proceed without Firestore connection');
    return;
  }
  
  // Run performance tests
  await performanceTest();
  
  // Run stress test
  await stressTest();
  
  console.log('\n🎉 All tests completed!');
}

// Run tests if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  performanceTest,
  testConnection,
  stressTest
};
