/**
 * Test Enhanced Clinical Feature Engine - Stage 1
 * 
 * This test demonstrates the enhanced clinical intelligence
 * compared to simple linear regression.
 */

const SharedPatientContext = require('./SharedPatientContext');
const ClinicalFeatureEngine = require('./ClinicalFeatureEngine');

/**
 * Test the enhanced clinical feature engine with sample data
 */
async function testEnhancedFeatures() {
    console.log('🧪 Testing Enhanced Clinical Feature Engine - Stage 1');
    console.log('====================================================\n');
    
    try {
        // Create test patient context with realistic lab data
        const testPatientId = 'TEST-ENHANCED-001';
        const context = new SharedPatientContext(testPatientId);
        
        // Add realistic glucose progression data (pre-diabetic pattern)
        const glucoseData = [
            { 
                timestamp: new Date('2024-01-15'), 
                normalizedValues: { glucose: 95, fasting_glucose: 95 },
                labReportType: 'Blood Sugar'
            },
            { 
                timestamp: new Date('2024-02-15'), 
                normalizedValues: { glucose: 105, fasting_glucose: 105 },
                labReportType: 'Blood Sugar'
            },
            { 
                timestamp: new Date('2024-03-15'), 
                normalizedValues: { glucose: 115, fasting_glucose: 115 },
                labReportType: 'Blood Sugar'
            },
            { 
                timestamp: new Date('2024-04-15'), 
                normalizedValues: { glucose: 125, fasting_glucose: 125 },
                labReportType: 'Blood Sugar'
            },
            { 
                timestamp: new Date('2024-05-15'), 
                normalizedValues: { glucose: 130, fasting_glucose: 130 },
                labReportType: 'Blood Sugar'
            },
            { 
                timestamp: new Date('2024-06-15'), 
                normalizedValues: { glucose: 135, fasting_glucose: 135 },
                labReportType: 'Blood Sugar'
            }
        ];
        
        // Add cholesterol data (stable)
        const cholesterolData = [
            { 
                timestamp: new Date('2024-01-15'), 
                normalizedValues: { total_cholesterol: 180, ldl: 110, hdl: 45, triglycerides: 120 },
                labReportType: 'Lipid Panel'
            },
            { 
                timestamp: new Date('2024-03-15'), 
                normalizedValues: { total_cholesterol: 185, ldl: 115, hdl: 42, triglycerides: 140 },
                labReportType: 'Lipid Panel'
            },
            { 
                timestamp: new Date('2024-06-15'), 
                normalizedValues: { total_cholesterol: 190, ldl: 120, hdl: 40, triglycerides: 160 },
                labReportType: 'Lipid Panel'
            }
        ];
        
        // Add kidney function data (slight decline)
        const kidneyData = [
            { 
                timestamp: new Date('2024-01-15'), 
                normalizedValues: { creatinine: 0.9, gfr: 95 },
                labReportType: 'Kidney Function'
            },
            { 
                timestamp: new Date('2024-03-15'), 
                normalizedValues: { creatinine: 1.0, gfr: 90 },
                labReportType: 'Kidney Function'
            },
            { 
                timestamp: new Date('2024-06-15'), 
                normalizedValues: { creatinine: 1.1, gfr: 85 },
                labReportType: 'Kidney Function'
            }
        ];
        
        // Add to context
        context.addRawData('lab_results', {
            'Blood Sugar': glucoseData,
            'Lipid Panel': cholesterolData,
            'Kidney Function': kidneyData
        });
        
        // Add some existing trends (simulating your current system)
        context.addEngineeredFeature('trends', 'Blood Sugar_slope', 6.67); // mg/dL per month
        context.addEngineeredFeature('trends', 'Blood Sugar_correlation', 0.92);
        context.addEngineeredFeature('trends', 'Lipid Panel_slope', 2.0);
        context.addEngineeredFeature('trends', 'Lipid Panel_correlation', 0.85);
        
        console.log('📊 Test data loaded:');
        console.log(`   - Glucose: 95 → 135 mg/dL (6 data points over 5 months)`);
        console.log(`   - Cholesterol: 180 → 190 mg/dL (3 data points)`);
        console.log(`   - Creatinine: 0.9 → 1.1 mg/dL (3 data points)`);
        
        // Test the enhanced feature engine
        console.log('\n🔬 Running Enhanced Clinical Feature Analysis...');
        const featureEngine = new ClinicalFeatureEngine();
        const enhancedFeatures = await featureEngine.extractClinicalFeatures(context);
        
        // Display results
        console.log('\n📈 ENHANCED ANALYSIS RESULTS');
        console.log('============================');
        
        // Overall assessment
        const metadata = enhancedFeatures.analysis_metadata;
        console.log(`🎯 Overall Confidence: ${(metadata.confidence_score * 100).toFixed(1)}%`);
        console.log(`⚠️ Clinical Significance: ${metadata.clinical_significance.toUpperCase()}`);
        
        // Statistical analysis results
        const stats = enhancedFeatures.statistical_analysis;
        console.log(`\n📊 Statistical Analysis Summary:`);
        console.log(`   - Parameters analyzed: ${stats.summary.parameters_analyzed}`);
        console.log(`   - Significant trends: ${stats.summary.significant_trends}`);
        console.log(`   - Concerning trends: ${stats.summary.concerning_trends}`);
        
        // Detailed analysis for each parameter
        console.log('\n🔍 DETAILED PARAMETER ANALYSIS');
        console.log('==============================');
        
        Object.entries(stats.enhanced_trends).forEach(([paramType, analysis]) => {
            console.log(`\n📋 ${paramType.toUpperCase()}:`);
            
            const clinical = analysis.clinical_interpretation;
            const enhanced = analysis.enhanced_statistics;
            
            console.log(`   📈 Trend: ${clinical.trend_direction} (${clinical.trend_magnitude})`);
            console.log(`   🎯 Clinical Significance: ${clinical.clinical_significance}`);
            console.log(`   ⚠️ Concern Level: ${clinical.concern_level}`);
            console.log(`   💬 Interpretation: ${clinical.interpretation}`);
            
            if (clinical.time_to_concern) {
                console.log(`   ⏰ Time to concern: ${clinical.time_to_concern.months} months`);
            }
            
            console.log(`   📊 Statistics:`);
            console.log(`      - Current Value: ${enhanced.mean?.toFixed(1) || 'N/A'}`);
            console.log(`      - Trend Slope: ${enhanced.slope?.toFixed(2) || 'N/A'}`);
            console.log(`      - Correlation: ${enhanced.correlation?.toFixed(2) || 'N/A'}`);
            console.log(`      - P-value: ${enhanced.p_value?.toFixed(3) || 'N/A'}`);
            console.log(`      - Trend Consistency: ${enhanced.trend_consistency ? (enhanced.trend_consistency * 100).toFixed(1) : 'N/A'}%`);
            console.log(`      - Data Quality: ${analysis.data_quality?.quality_rating || 'N/A'}`);
            
            if (analysis.data_quality?.recommendations?.length > 0) {
                console.log(`      - Recommendations: ${analysis.data_quality.recommendations.join(', ')}`);
            }
        });
        
        // Compare with simple linear regression
        console.log('\n🔄 COMPARISON: Enhanced vs Simple Linear Regression');
        console.log('==================================================');
        
        console.log('\n📊 SIMPLE LINEAR REGRESSION (Your Current System):');
        console.log('   - Blood Sugar slope: +6.67 mg/dL per month');
        console.log('   - Blood Sugar correlation: 0.92');
        console.log('   - Conclusion: "Strong upward trend"');
        
        console.log('\n🧠 ENHANCED CLINICAL ANALYSIS (New System):');
        const glucoseAnalysis = stats.enhanced_trends['Blood Sugar'];
        if (glucoseAnalysis) {
            console.log(`   - Clinical Pattern: ${glucoseAnalysis.clinical_interpretation.parameter_type}`);
            console.log(`   - Clinical Significance: ${glucoseAnalysis.clinical_interpretation.clinical_significance}`);
            console.log(`   - Concern Level: ${glucoseAnalysis.clinical_interpretation.concern_level}`);
            console.log(`   - Interpretation: ${glucoseAnalysis.clinical_interpretation.interpretation}`);
            console.log(`   - Data Quality: ${glucoseAnalysis.data_quality.quality_rating} (${(glucoseAnalysis.data_quality.confidence_level * 100).toFixed(1)}% confidence)`);
            
            if (glucoseAnalysis.clinical_interpretation.time_to_concern) {
                console.log(`   - Projected Timeline: Abnormal range in ${glucoseAnalysis.clinical_interpretation.time_to_concern.months} months`);
            }
        }
        
        console.log('\n✨ KEY IMPROVEMENTS:');
        console.log('   ✅ Clinical context and interpretation');
        console.log('   ✅ Parameter-specific thresholds and ranges');
        console.log('   ✅ Data quality assessment');
        console.log('   ✅ Trend consistency analysis');
        console.log('   ✅ Time-to-concern predictions');
        console.log('   ✅ Statistical significance testing');
        console.log('   ✅ Concern level stratification');
        
        console.log('\n🎯 NEXT STEPS:');
        console.log('   📝 Stage 2: Multi-parameter relationship analysis');
        console.log('   🔍 Stage 3: Clinical pattern recognition');
        console.log('   🤖 Stage 4: AI-powered specialist agents');
        console.log('   🎪 Stage 5: Integration and testing');
        
        return {
            success: true,
            enhancedFeatures: enhancedFeatures,
            improvements: [
                'Clinical interpretation added',
                'Data quality assessment implemented',
                'Parameter-specific analysis',
                'Time-to-concern predictions',
                'Statistical significance testing'
            ]
        };
        
    } catch (error) {
        console.error('❌ Enhanced feature test failed:', error);
        throw error;
    }
}

// Export for use in other modules
module.exports = { testEnhancedFeatures };

// Run test if this file is executed directly
if (require.main === module) {
    testEnhancedFeatures()
        .then(() => {
            console.log('\n🎉 Stage 1 Enhanced Feature Engine Test Complete!');
            console.log('Ready to proceed to Stage 2: Multi-Parameter Analysis');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n💥 Test failed:', error);
            process.exit(1);
        });
}
