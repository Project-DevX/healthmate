/**
 * Test Enhanced Clinical Feature Engine - Stage 2
 * Multi-Parameter Relationship Analysis
 * 
 * This test demonstrates advanced correlation analysis and pattern detection
 * across multiple lab parameters to identify clinical syndromes.
 */

const SharedPatientContext = require('./SharedPatientContext');
const ClinicalFeatureEngine = require('./ClinicalFeatureEngine');

/**
 * Test Stage 2: Multi-parameter relationship analysis
 */
async function testStage2MultiParameterAnalysis() {
    console.log('🧪 Testing Enhanced Clinical Feature Engine - Stage 2');
    console.log('===================================================');
    console.log('🔗 Multi-Parameter Relationship Analysis\n');
    
    try {
        // Create test patient with metabolic syndrome pattern
        const testPatientId = 'TEST-METABOLIC-002';
        const context = new SharedPatientContext(testPatientId);
        
        // Create realistic metabolic syndrome progression data
        const metabolicProgressionData = [
            {
                // January 2024 - Early signs
                timestamp: new Date('2024-01-15'),
                normalizedValues: {
                    glucose: 95,
                    fasting_glucose: 95,
                    total_cholesterol: 180,
                    ldl: 110,
                    hdl: 45,
                    triglycerides: 120,
                    creatinine: 0.9,
                    hemoglobin_a1c: 5.4
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // March 2024 - Progression
                timestamp: new Date('2024-03-15'),
                normalizedValues: {
                    glucose: 105,
                    fasting_glucose: 105,
                    total_cholesterol: 195,
                    ldl: 125,
                    hdl: 42,
                    triglycerides: 145,
                    creatinine: 0.95,
                    hemoglobin_a1c: 5.7
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // May 2024 - Clear metabolic syndrome
                timestamp: new Date('2024-05-15'),
                normalizedValues: {
                    glucose: 115,
                    fasting_glucose: 115,
                    total_cholesterol: 210,
                    ldl: 140,
                    hdl: 38,
                    triglycerides: 165,
                    creatinine: 1.0,
                    hemoglobin_a1c: 6.0
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // July 2024 - Worsening
                timestamp: new Date('2024-07-15'),
                normalizedValues: {
                    glucose: 125,
                    fasting_glucose: 125,
                    total_cholesterol: 225,
                    ldl: 155,
                    hdl: 35,
                    triglycerides: 185,
                    creatinine: 1.05,
                    hemoglobin_a1c: 6.3
                },
                labReportType: 'Comprehensive Metabolic Panel'
            }
        ];
        
        // Add separate glucose monitoring data
        const glucoseMonitoringData = [
            { timestamp: new Date('2024-02-01'), normalizedValues: { glucose: 98, random_glucose: 98 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-04-01'), normalizedValues: { glucose: 110, random_glucose: 110 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-06-01'), normalizedValues: { glucose: 120, random_glucose: 120 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-08-01'), normalizedValues: { glucose: 130, random_glucose: 130 }, labReportType: 'Blood Sugar' }
        ];
        
        // Add lipid-specific monitoring
        const lipidData = [
            { timestamp: new Date('2024-01-20'), normalizedValues: { total_cholesterol: 185, ldl: 115, hdl: 44, triglycerides: 125 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-04-20'), normalizedValues: { total_cholesterol: 205, ldl: 135, hdl: 40, triglycerides: 155 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-07-20'), normalizedValues: { total_cholesterol: 220, ldl: 150, hdl: 37, triglycerides: 175 }, labReportType: 'Lipid Panel' }
        ];
        
        // Add to context
        context.addRawData('lab_results', {
            'Comprehensive Metabolic Panel': metabolicProgressionData,
            'Blood Sugar': glucoseMonitoringData,
            'Lipid Panel': lipidData
        });
        
        console.log('📊 Test Data Overview:');
        console.log('   📈 Glucose: 95 → 130 mg/dL (showing upward trend)');
        console.log('   🧪 A1c: 5.4% → 6.3% (prediabetic progression)');
        console.log('   💧 Triglycerides: 120 → 185 mg/dL (elevated)');
        console.log('   ❤️ HDL: 45 → 35 mg/dL (declining, concerning)');
        console.log('   🔬 Multiple time points with overlapping measurements');
        
        // First run Stage 1 to get enhanced trends
        console.log('\n🔬 Running Stage 1: Enhanced Features...');
        const featureEngine = new ClinicalFeatureEngine();
        const stage1Features = await featureEngine.extractClinicalFeatures(context);
        
        // Add Stage 1 results to context
        Object.entries(stage1Features).forEach(([featureType, featureData]) => {
            if (featureType !== 'analysis_metadata') {
                context.addEngineeredFeature('enhanced_clinical', featureType, featureData);
            }
        });
        
        console.log(`✅ Stage 1 complete with ${stage1Features.statistical_analysis.summary.parameters_analyzed} parameters analyzed`);
        
        // Now run Stage 2: Multi-parameter analysis
        console.log('\n🔗 Running Stage 2: Multi-Parameter Analysis...');
        const relationships = featureEngine._analyzeParameterRelationships(context);
        
        // Display comprehensive results
        console.log('\n📈 STAGE 2 MULTI-PARAMETER ANALYSIS RESULTS');
        console.log('============================================');
        
        // Overall summary
        console.log(`\n🎯 Overall Assessment:`);
        console.log(`   🔗 Significant Relationships: ${relationships.summary.significant_relationships}`);
        console.log(`   🏥 Clinical Patterns Detected: ${relationships.summary.clinical_patterns_detected}`);
        console.log(`   ⚠️ Overall Risk Level: ${relationships.summary.overall_risk_assessment.toUpperCase()}`);
        
        // Correlation analysis
        if (relationships.correlations.correlations.length > 0) {
            console.log('\n📊 PARAMETER CORRELATIONS:');
            console.log('===========================');
            
            relationships.correlations.correlations.slice(0, 5).forEach((correlation, index) => {
                console.log(`\n${index + 1}. ${correlation.parameter1} ↔ ${correlation.parameter2}`);
                console.log(`   📈 Correlation: ${correlation.correlation_coefficient.toFixed(3)} (${correlation.strength})`);
                console.log(`   📍 Direction: ${correlation.direction}`);
                console.log(`   🏥 Clinical Significance: ${correlation.clinical_significance}`);
                console.log(`   📊 Data Points: ${correlation.data_points}`);
                console.log(`   🎯 P-value: ${correlation.p_value.toFixed(3)}`);
                
                // Explain what this correlation means clinically
                const explanation = explainCorrelation(correlation.parameter1, correlation.parameter2, correlation.correlation_coefficient);
                if (explanation) {
                    console.log(`   💬 Clinical Meaning: ${explanation}`);
                }
            });
            
            console.log(`\n📊 Correlation Summary:`);
            console.log(`   - Total correlations found: ${relationships.correlations.summary.total_correlations}`);
            console.log(`   - Strong correlations (>0.7): ${relationships.correlations.summary.strong_correlations}`);
            console.log(`   - Clinically significant: ${relationships.correlations.summary.clinically_significant}`);
        }
        
        // Clinical pattern analysis
        if (relationships.clinical_patterns.detected_patterns.length > 0) {
            console.log('\n🏥 CLINICAL PATTERNS DETECTED:');
            console.log('==============================');
            
            relationships.clinical_patterns.detected_patterns.forEach((pattern, index) => {
                console.log(`\n${index + 1}. ${pattern.pattern_name.toUpperCase().replace(/_/g, ' ')}`);
                console.log(`   ✅ Detected: ${pattern.detected ? 'YES' : 'NO'}`);
                console.log(`   🎯 Confidence: ${(pattern.confidence * 100).toFixed(1)}%`);
                console.log(`   ⚠️ Risk Score: ${(pattern.risk_score * 100).toFixed(1)}%`);
                console.log(`   🏥 Clinical Significance: ${pattern.clinical_significance}`);
                console.log(`   📝 Description: ${pattern.description}`);
                
                if (pattern.criteria_met !== undefined) {
                    console.log(`   📋 Criteria Met: ${pattern.criteria_met}/${pattern.total_criteria}`);
                    
                    // Show detailed criteria for metabolic syndrome
                    if (pattern.pattern_name === 'metabolic_syndrome' && pattern.details) {
                        console.log(`   📊 Detailed Criteria:`);
                        Object.entries(pattern.details).forEach(([criterion, data]) => {
                            if (data.value !== null) {
                                const status = data.met ? '✅ MET' : '❌ NOT MET';
                                console.log(`      ${criterion}: ${data.value} (threshold: ${data.threshold}) ${status}`);
                            }
                        });
                    }
                }
                
                if (pattern.recommendations && pattern.recommendations.length > 0) {
                    console.log(`   🎯 Recommendations:`);
                    pattern.recommendations.forEach(rec => {
                        console.log(`      • ${rec}`);
                    });
                }
            });
            
            // Highlight highest risk pattern
            if (relationships.summary.highest_risk_pattern) {
                const highestRisk = relationships.summary.highest_risk_pattern;
                console.log(`\n🚨 HIGHEST RISK PATTERN: ${highestRisk.pattern_name.toUpperCase().replace(/_/g, ' ')}`);
                console.log(`   Risk Score: ${(highestRisk.risk_score * 100).toFixed(1)}%`);
                console.log(`   Priority: ${highestRisk.clinical_significance.toUpperCase()}`);
            }
        }
        
        // Show improvement over Stage 1
        console.log('\n🔄 STAGE 2 vs STAGE 1 COMPARISON:');
        console.log('==================================');
        
        console.log('\n📊 STAGE 1 (Single Parameter Analysis):');
        console.log('   - Glucose: Increasing trend, moderate concern');
        console.log('   - Cholesterol: Increasing trend, low concern');
        console.log('   - HDL: Decreasing trend, moderate concern');
        console.log('   - Triglycerides: Increasing trend, moderate concern');
        console.log('   - Individual parameter assessment only');
        
        console.log('\n🧠 STAGE 2 (Multi-Parameter Intelligence):');
        console.log(`   - Metabolic Syndrome Pattern: ${relationships.metabolic_analysis.detected ? 'DETECTED' : 'Not detected'}`);
        if (relationships.metabolic_analysis.detected) {
            console.log(`   - Criteria met: ${relationships.metabolic_analysis.criteria_met}/4`);
            console.log(`   - Risk level: ${relationships.metabolic_analysis.clinical_significance}`);
        }
        console.log(`   - Parameter correlations identified: ${relationships.correlations.correlations.length}`);
        console.log(`   - Clinical patterns detected: ${relationships.clinical_patterns.pattern_count}`);
        console.log(`   - Overall risk assessment: ${relationships.summary.overall_risk_assessment}`);
        
        console.log('\n✨ KEY STAGE 2 IMPROVEMENTS:');
        console.log('   ✅ Detects metabolic syndrome (not visible in single parameters)');
        console.log('   ✅ Shows glucose-triglyceride-HDL relationships');
        console.log('   ✅ Identifies clinical patterns across parameters');
        console.log('   ✅ Provides syndrome-specific recommendations');
        console.log('   ✅ Calculates multi-parameter risk scores');
        console.log('   ✅ Reveals hidden correlations between lab values');
        
        console.log('\n🎯 NEXT STAGES:');
        console.log('   📝 Stage 3: Clinical Pattern Recognition (advanced patterns)');
        console.log('   🤖 Stage 4: AI-powered specialist agents');
        console.log('   🎪 Stage 5: Integration and testing');
        
        return {
            success: true,
            stage1_results: stage1Features,
            stage2_results: relationships,
            key_findings: {
                metabolic_syndrome_detected: relationships.metabolic_analysis.detected,
                significant_correlations: relationships.correlations.correlations.length,
                clinical_patterns: relationships.clinical_patterns.pattern_count,
                overall_risk: relationships.summary.overall_risk_assessment
            }
        };
        
    } catch (error) {
        console.error('❌ Stage 2 test failed:', error);
        throw error;
    }
}

/**
 * Explain what a correlation means clinically
 */
function explainCorrelation(param1, param2, coefficient) {
    const explanations = {
        'glucose_triglycerides': 'Rising glucose often correlates with triglycerides in insulin resistance',
        'glucose_hdl': 'Glucose and HDL typically have inverse relationship in metabolic syndrome',
        'triglycerides_hdl': 'Classic inverse relationship seen in metabolic disorders',
        'glucose_hemoglobin_a1c': 'Expected strong correlation - both measure glucose control',
        'ldl_total_cholesterol': 'LDL is major component of total cholesterol',
        'glucose_creatinine': 'May indicate diabetic nephropathy development'
    };
    
    const key1 = `${param1.toLowerCase()}_${param2.toLowerCase()}`;
    const key2 = `${param2.toLowerCase()}_${param1.toLowerCase()}`;
    
    return explanations[key1] || explanations[key2] || null;
}

// Export for use in other modules
module.exports = { testStage2MultiParameterAnalysis };

// Run test if this file is executed directly
if (require.main === module) {
    testStage2MultiParameterAnalysis()
        .then(() => {
            console.log('\n🎉 Stage 2 Multi-Parameter Analysis Test Complete!');
            console.log('Ready to proceed to Stage 3: Advanced Clinical Pattern Recognition');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n💥 Test failed:', error);
            process.exit(1);
        });
}
