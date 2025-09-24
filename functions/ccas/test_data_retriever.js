/**
 * Test script for DataRetriever
 * 
 * This script tests the DataRetriever component to ensure it properly
 * integrates with the existing HealthMate Firebase structure.
 */

const DataRetriever = require('./DataRetriever');

/**
 * Test function to verify DataRetriever functionality
 */
async function testDataRetriever() {
    console.log('🧪 Testing DataRetriever component...\n');
    
    try {
        const dataRetriever = new DataRetriever();
        
        // Test with a synthetic patient ID (you can replace with real test data)
        const testUserId = 'SYNTH-PATIENT-001';
        
        console.log(`📋 Creating patient context for: ${testUserId}`);
        
        // Create patient context
        const context = await dataRetriever.createPatientContext(testUserId);
        
        // Display context summary
        console.log('\n📊 Patient Context Summary:');
        console.log('================================');
        const summary = context.getSummary();
        console.log(`Case ID: ${summary.case_id}`);
        console.log(`Patient ID: ${summary.patient_id}`);
        console.log(`Analysis Stage: ${summary.stage}`);
        console.log(`Data Types: ${summary.data_types.join(', ')}`);
        console.log(`Feature Types: ${summary.feature_types.join(', ')}`);
        console.log(`Last Updated: ${summary.last_updated}`);
        
        // Display raw data overview
        console.log('\n🔍 Raw Data Overview:');
        console.log('=====================');
        const rawData = context.raw_data;
        
        console.log(`Demographics: ${rawData.demographics ? 'Present' : 'Missing'}`);
        console.log(`Lab Results: ${Object.keys(rawData.lab_results).length} types`);
        console.log(`Medical Records: ${rawData.reports.length} records`);
        console.log(`Conditions: ${rawData.conditions.length} documented`);
        console.log(`Medications: ${rawData.medications.length} documented`);
        
        // Test trend analysis enrichment
        console.log('\n📈 Testing trend analysis enrichment...');
        await dataRetriever.enrichWithTrendAnalysis(context);
        
        const updatedSummary = context.getSummary();
        console.log(`Feature Types after enrichment: ${updatedSummary.feature_types.join(', ')}`);
        
        // Display engineered features
        if (Object.keys(context.engineered_features.trends || {}).length > 0) {
            console.log('\n📊 Engineered Features (Trends):');
            console.log('================================');
            for (const [feature, value] of Object.entries(context.engineered_features.trends)) {
                console.log(`${feature}: ${value}`);
            }
        }
        
        console.log('\n✅ DataRetriever test completed successfully!');
        
        return context;
        
    } catch (error) {
        console.error('❌ DataRetriever test failed:', error);
        throw error;
    }
}

// Export for use in other modules
module.exports = { testDataRetriever };

// Run test if this file is executed directly
if (require.main === module) {
    testDataRetriever()
        .then(() => {
            console.log('\n🎉 All tests passed!');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n💥 Test failed:', error);
            process.exit(1);
        });
}
