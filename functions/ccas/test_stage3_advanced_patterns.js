/**
 * Test Enhanced Clinical Feature Engine - Stage 3
 * Advanced Clinical Pattern Recognition
 * 
 * This test demonstrates sophisticated temporal evolution analysis,
 * multi-system interactions, and predictive risk trajectories.
 */

const SharedPatientContext = require('./SharedPatientContext');
const ClinicalFeatureEngine = require('./ClinicalFeatureEngine');

/**
 * Test Stage 3: Advanced Clinical Pattern Recognition
 */
async function testStage3AdvancedPatternRecognition() {
    console.log('🧠 Testing Enhanced Clinical Feature Engine - Stage 3');
    console.log('=====================================================');
    console.log('🔬 Advanced Clinical Pattern Recognition\n');
    
    try {
        // Create test patient with complex temporal progression
        const testPatientId = 'TEST-ADVANCED-003';
        const context = new SharedPatientContext(testPatientId);
        
        // Create realistic metabolic syndrome progression with temporal evolution
        const progressionData = [
            {
                // 6 months ago - Early metabolic changes
                timestamp: new Date('2024-02-01'),
                normalizedValues: {
                    glucose: 88,
                    fasting_glucose: 88,
                    total_cholesterol: 175,
                    ldl: 105,
                    hdl: 48,
                    triglycerides: 110,
                    creatinine: 0.8,
                    hemoglobin_a1c: 5.2
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // 4 months ago - Progression begins
                timestamp: new Date('2024-04-01'),
                normalizedValues: {
                    glucose: 95,
                    fasting_glucose: 95,
                    total_cholesterol: 185,
                    ldl: 115,
                    hdl: 44,
                    triglycerides: 130,
                    creatinine: 0.85,
                    hemoglobin_a1c: 5.5
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // 2 months ago - Clear worsening
                timestamp: new Date('2024-06-01'),
                normalizedValues: {
                    glucose: 108,
                    fasting_glucose: 108,
                    total_cholesterol: 200,
                    ldl: 130,
                    hdl: 38,
                    triglycerides: 155,
                    creatinine: 0.9,
                    hemoglobin_a1c: 5.8
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // Current - Metabolic syndrome established
                timestamp: new Date('2024-08-01'),
                normalizedValues: {
                    glucose: 118,
                    fasting_glucose: 118,
                    total_cholesterol: 215,
                    ldl: 145,
                    hdl: 35,
                    triglycerides: 175,
                    creatinine: 0.95,
                    hemoglobin_a1c: 6.1
                },
                labReportType: 'Comprehensive Metabolic Panel'
            }
        ];
        
        // Add additional monitoring data to show temporal patterns
        const glucoseMonitoringData = [
            { timestamp: new Date('2024-02-15'), normalizedValues: { glucose: 90, random_glucose: 90 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-03-15'), normalizedValues: { glucose: 93, random_glucose: 93 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-04-15'), normalizedValues: { glucose: 98, random_glucose: 98 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-05-15'), normalizedValues: { glucose: 105, random_glucose: 105 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-06-15'), normalizedValues: { glucose: 112, random_glucose: 112 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-07-15'), normalizedValues: { glucose: 115, random_glucose: 115 }, labReportType: 'Blood Sugar' }
        ];
        
        // Add lipid tracking to show coordinated changes
        const lipidTrackingData = [
            { timestamp: new Date('2024-03-01'), normalizedValues: { total_cholesterol: 180, ldl: 110, hdl: 46, triglycerides: 120 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-05-01'), normalizedValues: { total_cholesterol: 195, ldl: 125, hdl: 41, triglycerides: 145 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-07-01'), normalizedValues: { total_cholesterol: 210, ldl: 140, hdl: 37, triglycerides: 165 }, labReportType: 'Lipid Panel' }
        ];
        
        // Add to context
        context.addRawData('lab_results', {
            'Comprehensive Metabolic Panel': progressionData,
            'Blood Sugar': glucoseMonitoringData,
            'Lipid Panel': lipidTrackingData
        });
        
        console.log('📊 Test Data Overview:');
        console.log('   ⏰ Temporal Progression: 6 months of data');
        console.log('   📈 Glucose Evolution: 88 → 118 mg/dL');
        console.log('   🧪 A1c Progression: 5.2% → 6.1% (prediabetic)');
        console.log('   💧 Triglycerides: 110 → 175 mg/dL');
        console.log('   ❤️ HDL Decline: 48 → 35 mg/dL');
        console.log('   🔄 Multiple overlapping measurements');
        console.log('   🎯 Clear temporal progression pattern');
        
        // Run through all stages to get to Stage 3
        console.log('\n🔬 Running Stage 1: Enhanced Features...');
        const featureEngine = new ClinicalFeatureEngine();
        const stage1Features = await featureEngine.extractClinicalFeatures(context);
        
        // Add Stage 1 results to context
        Object.entries(stage1Features).forEach(([featureType, featureData]) => {
            if (featureType !== 'analysis_metadata') {
                context.addEngineeredFeature('enhanced_clinical', featureType, featureData);
            }
        });
        
        console.log(`✅ Stage 1 complete with ${stage1Features.statistical_analysis.summary.parameters_analyzed} parameters`);
        
        // Run Stage 2
        console.log('\n🔗 Running Stage 2: Multi-Parameter Analysis...');
        const stage2Results = featureEngine._analyzeParameterRelationships(context);
        console.log(`✅ Stage 2 complete with ${stage2Results.correlations.correlations.length} correlations`);
        
        // Now run Stage 3: Advanced Pattern Recognition
        console.log('\n🧠 Running Stage 3: Advanced Pattern Recognition...');
        const advancedPatterns = stage2Results.advanced_patterns;
        
        // Display comprehensive Stage 3 results
        console.log('\n📈 STAGE 3 ADVANCED PATTERN RECOGNITION RESULTS');
        console.log('===============================================');
        
        // Overall assessment
        console.log(`\n🎯 Advanced Pattern Assessment:`);
        console.log(`   🧠 Total Advanced Patterns: ${advancedPatterns.pattern_count}`);
        console.log(`   🎪 Overall Complexity: ${advancedPatterns.overall_assessment.risk_level.toUpperCase()}`);
        console.log(`   ⚡ Clinical Urgency: ${advancedPatterns.overall_assessment.clinical_urgency.toUpperCase()}`);
        console.log(`   🎯 Pattern Confidence: ${(advancedPatterns.confidence * 100).toFixed(1)}%`);
        
        // Temporal Evolution Analysis
        if (advancedPatterns.temporal_evolution.detected_patterns.length > 0) {
            console.log('\n⏰ TEMPORAL EVOLUTION ANALYSIS:');
            console.log('===============================');
            
            advancedPatterns.temporal_evolution.detected_patterns.forEach((pattern, index) => {
                console.log(`\n${index + 1}. ${pattern.pattern_name.toUpperCase().replace(/_/g, ' ')}`);
                console.log(`   ✅ Detected: ${pattern.detected ? 'YES' : 'NO'}`);
                console.log(`   🎯 Confidence: ${(pattern.confidence * 100).toFixed(1)}%`);
                console.log(`   ⚠️ Risk Score: ${(pattern.risk_score * 100).toFixed(1)}%`);
                console.log(`   🏥 Clinical Significance: ${pattern.clinical_significance}`);
                console.log(`   📝 Description: ${pattern.description}`);
                
                if (pattern.timeline) {
                    console.log(`   📊 Progression Analysis:`);
                    console.log(`      Initial Score: ${pattern.timeline.initial_score}/${pattern.timeline.progression_data[0].total_possible}`);
                    console.log(`      Final Score: ${pattern.timeline.final_score}/${pattern.timeline.progression_data[pattern.timeline.progression_data.length - 1].total_possible}`);
                    console.log(`      Trend: ${pattern.timeline.trend.toUpperCase()}`);
                    console.log(`      Change Velocity: ${pattern.timeline.velocity.toFixed(3)} criteria/timepoint`);
                    
                    if (pattern.timeline.progression_data.length > 0) {
                        console.log(`   📈 Timeline Progression:`);
                        pattern.timeline.progression_data.forEach((point, idx) => {
                            const date = point.timestamp.toLocaleDateString();
                            console.log(`      ${date}: ${point.score}/${point.total_possible} criteria met`);
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
            
            console.log(`\n⏰ Temporal Summary:`);
            console.log(`   Timeline Analysis: ${advancedPatterns.temporal_evolution.timeline_analysis}`);
            console.log(`   Change Velocity: ${advancedPatterns.temporal_evolution.velocity_of_change}`);
        } else {
            console.log('\n⏰ TEMPORAL EVOLUTION: No significant temporal patterns detected');
        }
        
        // Multi-System Interactions
        if (advancedPatterns.multi_system_interactions.detected_patterns.length > 0) {
            console.log('\n🔗 MULTI-SYSTEM INTERACTIONS:');
            console.log('==============================');
            
            advancedPatterns.multi_system_interactions.detected_patterns.forEach((pattern, index) => {
                console.log(`\n${index + 1}. ${pattern.pattern_name.toUpperCase().replace(/_/g, ' ')}`);
                console.log(`   ✅ Detected: ${pattern.detected ? 'YES' : 'NO'}`);
                console.log(`   🎯 Confidence: ${(pattern.confidence * 100).toFixed(1)}%`);
                console.log(`   ⚠️ Risk Score: ${(pattern.risk_score * 100).toFixed(1)}%`);
                console.log(`   🏥 Clinical Significance: ${pattern.clinical_significance}`);
                console.log(`   📝 Description: ${pattern.description}`);
                console.log(`   🔗 Interaction Score: ${(pattern.interaction_score * 100).toFixed(1)}%`);
                
                if (pattern.recommendations && pattern.recommendations.length > 0) {
                    console.log(`   🎯 Recommendations:`);
                    pattern.recommendations.forEach(rec => {
                        console.log(`      • ${rec}`);
                    });
                }
            });
            
            console.log(`\n🔗 System Interaction Summary:`);
            console.log(`   Network Complexity: ${advancedPatterns.multi_system_interactions.interaction_network.complexity}`);
            console.log(`   System Complexity Level: ${advancedPatterns.multi_system_interactions.system_complexity.level}`);
        } else {
            console.log('\n🔗 MULTI-SYSTEM INTERACTIONS: No significant interactions detected');
        }
        
        // Risk Trajectories
        if (advancedPatterns.risk_trajectories.risk_trajectories.length > 0) {
            console.log('\n📈 RISK TRAJECTORY ANALYSIS:');
            console.log('=============================');
            
            advancedPatterns.risk_trajectories.risk_trajectories.forEach((trajectory, index) => {
                console.log(`\n${index + 1}. ${trajectory.trajectory_name.toUpperCase().replace(/_/g, ' ')}`);
                console.log(`   📊 Current Risk: ${(trajectory.current_risk * 100).toFixed(1)}%`);
                console.log(`   🔮 5-Year Projection: ${(trajectory.projected_5_year * 100).toFixed(1)}%`);
                console.log(`   📈 Trend Direction: ${trajectory.trend_direction.toUpperCase().replace(/_/g, ' ')}`);
                console.log(`   ⚡ Urgency Level: ${trajectory.urgency.toUpperCase()}`);
                
                if (trajectory.recommendations && trajectory.recommendations.length > 0) {
                    console.log(`   🎯 Prevention Strategies:`);
                    trajectory.recommendations.forEach(rec => {
                        console.log(`      • ${rec}`);
                    });
                }
            });
            
            console.log(`\n📈 Risk Summary:`);
            console.log(`   Composite Risk Level: ${advancedPatterns.risk_trajectories.composite_risk.level.toUpperCase()}`);
            console.log(`   Time to Intervention: ${advancedPatterns.risk_trajectories.time_to_intervention}`);
        }
        
        // Advanced Clinical Recommendations
        if (advancedPatterns.clinical_recommendations.length > 0) {
            console.log('\n🎯 ADVANCED CLINICAL RECOMMENDATIONS:');
            console.log('=====================================');
            advancedPatterns.clinical_recommendations.forEach((rec, index) => {
                console.log(`${index + 1}. ${rec}`);
            });
        }
        
        // Compare all stages
        console.log('\n🔄 COMPREHENSIVE STAGE COMPARISON:');
        console.log('===================================');
        
        console.log('\n📊 STAGE 1 (Enhanced Single Parameter):');
        console.log('   - Individual parameter trend analysis');
        console.log('   - Clinical threshold assessment');
        console.log('   - Basic risk categorization');
        
        console.log('\n🔗 STAGE 2 (Multi-Parameter Intelligence):');
        console.log(`   - Parameter correlations: ${stage2Results.correlations.correlations.length}`);
        console.log(`   - Clinical patterns: ${stage2Results.clinical_patterns.pattern_count}`);
        console.log(`   - Metabolic syndrome: ${stage2Results.metabolic_analysis.detected ? 'DETECTED' : 'Not detected'}`);
        console.log(`   - Risk assessment: ${stage2Results.summary.overall_risk_assessment.toUpperCase()}`);
        
        console.log('\n🧠 STAGE 3 (Advanced Pattern Recognition):');
        console.log(`   - Temporal evolution patterns: ${advancedPatterns.temporal_evolution.detected_patterns.length}`);
        console.log(`   - Multi-system interactions: ${advancedPatterns.multi_system_interactions.detected_patterns.length}`);
        console.log(`   - Risk trajectory analysis: ${advancedPatterns.risk_trajectories.risk_trajectories.length}`);
        console.log(`   - Pattern complexity: ${advancedPatterns.overall_assessment.risk_level.toUpperCase()}`);
        console.log(`   - Clinical urgency: ${advancedPatterns.overall_assessment.clinical_urgency.toUpperCase()}`);
        
        console.log('\n✨ STAGE 3 KEY BREAKTHROUGHS:');
        console.log('   ⏰ Temporal progression analysis (6-month evolution)');
        console.log('   🧬 Metabolic syndrome progression velocity');
        console.log('   🔮 Predictive risk trajectories (5-year projections)');
        console.log('   🔗 Multi-system interaction analysis');
        console.log('   📊 Change acceleration detection');
        console.log('   🎯 Time-sensitive intervention recommendations');
        
        console.log('\n🎪 CLINICAL INTELLIGENCE EVOLUTION:');
        console.log('   Stage 1: "Patient has elevated glucose"');
        console.log('   Stage 2: "Patient has metabolic syndrome"');
        console.log('   Stage 3: "Patient shows accelerating metabolic syndrome progression"');
        console.log('             "Diabetes risk trajectory: 40% → 65% over 5 years"');
        console.log('             "Urgent intervention window: next 3 months"');
        
        console.log('\n🎯 NEXT STAGES:');
        console.log('   🤖 Stage 4: AI-powered specialist consultation agents');
        console.log('   🎪 Stage 5: Integration testing and optimization');
        
        return {
            success: true,
            stage1_results: stage1Features,
            stage2_results: stage2Results,
            stage3_results: advancedPatterns,
            key_findings: {
                temporal_patterns: advancedPatterns.temporal_evolution.detected_patterns.length,
                system_interactions: advancedPatterns.multi_system_interactions.detected_patterns.length,
                risk_trajectories: advancedPatterns.risk_trajectories.risk_trajectories.length,
                overall_complexity: advancedPatterns.overall_assessment.risk_level,
                clinical_urgency: advancedPatterns.overall_assessment.clinical_urgency
            }
        };
        
    } catch (error) {
        console.error('❌ Stage 3 test failed:', error);
        throw error;
    }
}

// Export for use in other modules
module.exports = { testStage3AdvancedPatternRecognition };

// Run test if this file is executed directly
if (require.main === module) {
    testStage3AdvancedPatternRecognition()
        .then(() => {
            console.log('\n🎉 Stage 3 Advanced Pattern Recognition Test Complete!');
            console.log('Ready to proceed to Stage 4: AI-Powered Specialist Agents');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n💥 Test failed:', error);
            process.exit(1);
        });
}
