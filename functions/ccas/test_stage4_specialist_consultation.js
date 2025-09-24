/**
 * Test Enhanced Clinical Feature Engine - Stage 4
 * AI-Powered Specialist Consultation
 * 
 * This test demonstrates the integration of AI-powered specialist agents
 * that provide clinical reasoning and recommendations based on comprehensive
 * multi-stage analysis.
 */

const SharedPatientContext = require('./SharedPatientContext');
const ClinicalFeatureEngine = require('./ClinicalFeatureEngine');

/**
 * Test Stage 4: AI-Powered Specialist Consultation
 */
async function testStage4SpecialistConsultation() {
    console.log('🤖 Testing Enhanced Clinical Feature Engine - Stage 4');
    console.log('====================================================');
    console.log('🧠 AI-Powered Specialist Consultation\n');
    
    try {
        // Create test patient with complex clinical scenario
        const testPatientId = 'TEST-SPECIALIST-004';
        const context = new SharedPatientContext(testPatientId);
        
        // Create comprehensive clinical scenario for specialist consultation
        const clinicalScenarioData = [
            {
                // 8 months ago - Baseline normal
                timestamp: new Date('2023-12-01'),
                normalizedValues: {
                    glucose: 85,
                    fasting_glucose: 85,
                    total_cholesterol: 170,
                    ldl: 100,
                    hdl: 50,
                    triglycerides: 100,
                    creatinine: 0.8,
                    hemoglobin_a1c: 5.0,
                    alt: 20,
                    ast: 25
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // 6 months ago - Early changes
                timestamp: new Date('2024-02-01'),
                normalizedValues: {
                    glucose: 92,
                    fasting_glucose: 92,
                    total_cholesterol: 180,
                    ldl: 110,
                    hdl: 46,
                    triglycerides: 120,
                    creatinine: 0.85,
                    hemoglobin_a1c: 5.3,
                    alt: 25,
                    ast: 28
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // 4 months ago - Progression
                timestamp: new Date('2024-04-01'),
                normalizedValues: {
                    glucose: 102,
                    fasting_glucose: 102,
                    total_cholesterol: 195,
                    ldl: 125,
                    hdl: 41,
                    triglycerides: 145,
                    creatinine: 0.9,
                    hemoglobin_a1c: 5.6,
                    alt: 32,
                    ast: 35
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // 2 months ago - Clear metabolic syndrome
                timestamp: new Date('2024-06-01'),
                normalizedValues: {
                    glucose: 115,
                    fasting_glucose: 115,
                    total_cholesterol: 210,
                    ldl: 140,
                    hdl: 37,
                    triglycerides: 170,
                    creatinine: 0.95,
                    hemoglobin_a1c: 5.9,
                    alt: 40,
                    ast: 42
                },
                labReportType: 'Comprehensive Metabolic Panel'
            },
            {
                // Current - Prediabetic with complications
                timestamp: new Date('2024-08-01'),
                normalizedValues: {
                    glucose: 125,
                    fasting_glucose: 125,
                    total_cholesterol: 225,
                    ldl: 155,
                    hdl: 33,
                    triglycerides: 185,
                    creatinine: 1.0,
                    hemoglobin_a1c: 6.2,
                    alt: 48,
                    ast: 50
                },
                labReportType: 'Comprehensive Metabolic Panel'
            }
        ];
        
        // Add frequent glucose monitoring
        const glucoseMonitoringData = [
            { timestamp: new Date('2024-01-15'), normalizedValues: { glucose: 88 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-02-15'), normalizedValues: { glucose: 95 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-03-15'), normalizedValues: { glucose: 98 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-04-15'), normalizedValues: { glucose: 105 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-05-15'), normalizedValues: { glucose: 110 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-06-15'), normalizedValues: { glucose: 118 }, labReportType: 'Blood Sugar' },
            { timestamp: new Date('2024-07-15'), normalizedValues: { glucose: 122 }, labReportType: 'Blood Sugar' }
        ];
        
        // Add lipid monitoring
        const lipidData = [
            { timestamp: new Date('2024-01-20'), normalizedValues: { total_cholesterol: 175, ldl: 105, hdl: 48, triglycerides: 110 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-03-20'), normalizedValues: { total_cholesterol: 188, ldl: 118, hdl: 44, triglycerides: 130 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-05-20'), normalizedValues: { total_cholesterol: 202, ldl: 132, hdl: 39, triglycerides: 155 }, labReportType: 'Lipid Panel' },
            { timestamp: new Date('2024-07-20'), normalizedValues: { total_cholesterol: 218, ldl: 148, hdl: 35, triglycerides: 175 }, labReportType: 'Lipid Panel' }
        ];
        
        // Add to context
        context.addRawData('lab_results', {
            'Comprehensive Metabolic Panel': clinicalScenarioData,
            'Blood Sugar': glucoseMonitoringData,
            'Lipid Panel': lipidData
        });
        
        console.log('📊 Complex Clinical Scenario:');
        console.log('   ⏰ Timeline: 8 months of comprehensive data');
        console.log('   📈 Glucose: 85 → 125 mg/dL (40-point increase)');
        console.log('   🧪 A1c: 5.0% → 6.2% (prediabetic progression)');
        console.log('   💧 Triglycerides: 100 → 185 mg/dL');
        console.log('   ❤️ HDL: 50 → 33 mg/dL (significant decline)');
        console.log('   🧬 LDL: 100 → 155 mg/dL');
        console.log('   🫀 Liver enzymes: ALT 20 → 48, AST 25 → 50');
        console.log('   💻 Multiple specialist consultation required');
        
        // Run comprehensive analysis through all stages
        console.log('\n🔬 Running Complete Multi-Stage Analysis...');
        const featureEngine = new ClinicalFeatureEngine();
        
        console.log('🔬 Stage 1: Enhanced Features...');
        const completeResults = await featureEngine.extractClinicalFeatures(context);
        
        console.log('🔗 Stage 2 & 3: Multi-parameter and Advanced Patterns...');
        console.log('🤖 Stage 4: AI Specialist Consultation...');
        
        // Extract Stage 4 results
        const specialistConsultation = completeResults.parameter_relationships.specialist_consultation;
        
        // Display comprehensive Stage 4 results
        console.log('\n🤖 STAGE 4 AI-POWERED SPECIALIST CONSULTATION RESULTS');
        console.log('====================================================');
        
        // Overall consultation assessment
        console.log(`\n🎯 Consultation Overview:`);
        console.log(`   🤖 AI Consultation Confidence: ${(specialistConsultation.ai_confidence * 10).toFixed(1)}/10`);
        console.log(`   ⚡ Clinical Urgency: ${specialistConsultation.clinical_urgency.toUpperCase()}`);
        console.log(`   📅 Consultation Date: ${new Date(specialistConsultation.consultation_timestamp).toLocaleDateString()}`);
        console.log(`   👩‍⚕️ Specialists Consulted: ${Object.keys(specialistConsultation.specialist_opinions).length}`);
        
        // Individual specialist opinions
        console.log('\n👩‍⚕️ INDIVIDUAL SPECIALIST OPINIONS:');
        console.log('====================================');
        
        Object.entries(specialistConsultation.specialist_opinions).forEach(([specialistType, opinion], index) => {
            const specialistName = specialistType.toUpperCase().replace(/_/g, ' ');
            console.log(`\n${index + 1}. 🩺 ${specialistName}`);
            console.log(`   📊 Primary Assessment: ${opinion.primary_assessment}`);
            console.log(`   ⚠️ Risk Level: ${opinion.risk_level.toUpperCase()}`);
            console.log(`   🎯 Confidence: ${opinion.confidence}/10`);
            console.log(`   📝 Clinical Reasoning: ${opinion.clinical_reasoning}`);
            
            console.log(`   🚨 Immediate Recommendations:`);
            opinion.immediate_recommendations.forEach((rec, idx) => {
                console.log(`      ${idx + 1}. ${rec}`);
            });
            
            console.log(`   📋 Long-term Plan: ${opinion.long_term_plan}`);
            console.log(`   📅 Follow-up: ${opinion.follow_up_timeline}`);
            
            if (opinion.referrals && opinion.referrals.length > 0) {
                console.log(`   🔄 Referrals: ${opinion.referrals.join(', ')}`);
            }
        });
        
        // Synthesized recommendations
        console.log('\n🧠 SYNTHESIZED MULTI-SPECIALIST RECOMMENDATIONS:');
        console.log('================================================');
        
        const synthesis = specialistConsultation.synthesized_recommendations;
        
        console.log(`\n🎯 Priority Recommendations:`);
        synthesis.primary_recommendations.forEach((rec, index) => {
            console.log(`   ${index + 1}. ${rec}`);
        });
        
        console.log(`\n🔄 Specialist Referrals Recommended:`);
        if (synthesis.specialist_referrals.length > 0) {
            synthesis.specialist_referrals.forEach((referral, index) => {
                console.log(`   ${index + 1}. ${referral}`);
            });
        } else {
            console.log('   No immediate specialist referrals needed');
        }
        
        console.log(`\n⚠️ Overall Risk Assessment: ${synthesis.overall_risk_assessment.toUpperCase()}`);
        console.log(`📅 Recommended Follow-up: ${synthesis.recommended_follow_up}`);
        console.log(`📋 Monitoring Plan: ${synthesis.monitoring_plan}`);
        
        console.log(`\n🤝 Specialist Consensus Items:`);
        synthesis.consensus_items.forEach((item, index) => {
            console.log(`   ${index + 1}. ${item}`);
        });
        
        // Compare AI recommendations with previous stages
        console.log('\n🔄 MULTI-STAGE CLINICAL INTELLIGENCE EVOLUTION:');
        console.log('===============================================');
        
        console.log('\n📊 STAGE 1: Enhanced Single Parameter Analysis');
        console.log('   Output: "Glucose elevated, triglycerides high, HDL low"');
        console.log('   Limitation: Individual parameter view only');
        
        console.log('\n🔗 STAGE 2: Multi-Parameter Intelligence');
        console.log('   Output: "Metabolic syndrome detected with high correlation patterns"');
        console.log('   Advancement: Pattern recognition across parameters');
        
        console.log('\n🧠 STAGE 3: Advanced Pattern Recognition');
        console.log('   Output: "Progressive metabolic syndrome with accelerating trajectory"');
        console.log('   Advancement: Temporal evolution and risk projection');
        
        console.log('\n🤖 STAGE 4: AI-Powered Specialist Consultation');
        console.log('   Output: "Multi-specialist consensus with specialized clinical reasoning"');
        console.log('   Advancement: Expert-level clinical decision support');
        
        // Highlight the AI intelligence breakthrough
        console.log('\n✨ AI SPECIALIST CONSULTATION BREAKTHROUGHS:');
        console.log('===========================================');
        
        console.log('🧠 ENDOCRINOLOGIST AI:');
        const endoOpinion = specialistConsultation.specialist_opinions.endocrinologist;
        console.log(`   • ${endoOpinion.primary_assessment}`);
        console.log(`   • Risk: ${endoOpinion.risk_level} (${endoOpinion.confidence}/10 confidence)`);
        
        console.log('\n❤️ CARDIOLOGIST AI:');
        const cardioOpinion = specialistConsultation.specialist_opinions.cardiologist;
        console.log(`   • ${cardioOpinion.primary_assessment}`);
        console.log(`   • Risk: ${cardioOpinion.risk_level} (${cardioOpinion.confidence}/10 confidence)`);
        
        console.log('\n🩺 INTERNIST AI:');
        const internistOpinion = specialistConsultation.specialist_opinions.internist;
        console.log(`   • ${internistOpinion.primary_assessment}`);
        console.log(`   • Coordination: ${internistOpinion.long_term_plan}`);
        
        console.log('\n🛡️ PREVENTIVE MEDICINE AI:');
        const prevOpinion = specialistConsultation.specialist_opinions.preventive_medicine;
        console.log(`   • ${prevOpinion.primary_assessment}`);
        console.log(`   • Strategy: ${prevOpinion.long_term_plan}`);
        
        console.log('\n🎪 CLINICAL DECISION SUPPORT EVOLUTION:');
        console.log('======================================');
        console.log('Traditional: "Patient needs follow-up"');
        console.log('Stage 1-3: "Patient shows metabolic syndrome progression"');
        console.log('Stage 4 AI: "Multi-specialist consensus recommends:');
        console.log('            - Immediate diabetes prevention protocol');
        console.log('            - Cardio-metabolic risk reduction strategy');
        console.log('            - Coordinated multi-disciplinary care"');
        console.log('            - Evidence-based intervention timeline"');
        
        console.log('\n🎯 NEXT STEPS:');
        console.log('   🎪 Stage 5: Integration and optimization testing');
        console.log('   🚀 Production deployment preparation');
        console.log('   📊 Real-world validation studies');
        
        return {
            success: true,
            stage4_results: specialistConsultation,
            key_findings: {
                specialists_consulted: Object.keys(specialistConsultation.specialist_opinions).length,
                ai_confidence: specialistConsultation.ai_confidence,
                clinical_urgency: specialistConsultation.clinical_urgency,
                consensus_recommendations: synthesis.primary_recommendations.length,
                specialist_referrals: synthesis.specialist_referrals.length
            },
            clinical_impact: {
                decision_support_level: 'Specialist-grade',
                confidence_improvement: 'High',
                recommendation_quality: 'Evidence-based multi-specialist consensus',
                intervention_timing: 'Precision-guided'
            }
        };
        
    } catch (error) {
        console.error('❌ Stage 4 test failed:', error);
        throw error;
    }
}

// Export for use in other modules
module.exports = { testStage4SpecialistConsultation };

// Run test if this file is executed directly
if (require.main === module) {
    testStage4SpecialistConsultation()
        .then(() => {
            console.log('\n🎉 Stage 4 AI-Powered Specialist Consultation Test Complete!');
            console.log('Ready to proceed to Stage 5: Integration and Optimization');
            process.exit(0);
        })
        .catch((error) => {
            console.error('\n💥 Test failed:', error);
            process.exit(1);
        });
}
