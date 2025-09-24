/**
 * Orchestrator - The central brain of CCAS
 * 
 * This is the "Chief Resident" that manages the entire workflow
 * from data retrieval to final synthesis. It coordinates all
 * specialist agents and manages the SharedPatientContext.
 */

const DataRetriever = require('./DataRetriever');
const SharedPatientContext = require('./SharedPatientContext');
const ClinicalFeatureEngine = require('./ClinicalFeatureEngine');

class Orchestrator {
    constructor() {
        this.dataRetriever = new DataRetriever();
        this.clinicalFeatureEngine = new ClinicalFeatureEngine();
        this.specialistAgents = new Map(); // Will be populated with specialist agents
        this.activeContexts = new Map(); // Store active patient contexts
    }

    /**
     * Main entry point - Start a new clinical assessment
     * @param {string} userId - Patient ID
     * @param {Array} requestedSpecialties - List of specialties to consult
     * @param {Object} options - Additional options (time period, etc.)
     */
    async startAssessment(userId, requestedSpecialties = [], options = {}) {
        console.log(`🎯 Starting CCAS assessment for patient: ${userId}`);
        console.log(`📋 Requested specialties: ${requestedSpecialties.join(', ')}`);
        
        try {
            // Phase 1: Context Generation
            const context = await this._phaseOneContextGeneration(userId, options.timePeriod);
            
            // Store active context
            this.activeContexts.set(context.case_id, context);
            
            // Phase 2: Virtual Case Conference (if specialists requested)
            if (requestedSpecialties.length > 0) {
                await this._phaseTwoVirtualCaseConference(context, requestedSpecialties);
            }
            
            // Phase 3: Synthesis (will be implemented next)
            const finalSummary = await this._phaseThreeSynthesis(context);
            
            console.log(`✅ CCAS assessment completed for case: ${context.case_id}`);
            
            return {
                success: true,
                case_id: context.case_id,
                summary: finalSummary,
                context: context.toJSON()
            };
            
        } catch (error) {
            console.error('❌ Error in CCAS assessment:', error);
            throw error;
        }
    }

    /**
     * Phase 1: Context Generation
     * - Fetch patient data
     * - Generate clinical features
     * - Prepare SharedPatientContext
     */
    async _phaseOneContextGeneration(userId, timePeriod = null) {
        console.log('\n🔍 Phase 1: Context Generation');
        console.log('===============================');
        
        // Tool A: Data Retriever
        console.log('📦 Using Tool A: Data Retriever...');
        const context = await this.dataRetriever.createPatientContext(userId, timePeriod);
        
        // Tool B: Clinical Feature Engine (integrate with existing trend analysis)
        console.log('⚙️ Using Tool B: Clinical Feature Engine...');
        await this._generateClinicalFeatures(context);
        
        context.setAnalysisStage('context_ready');
        
        const summary = context.getSummary();
        console.log(`✅ Context generated with ${summary.data_types.length} data types and ${summary.feature_types.length} feature types`);
        
        return context;
    }

    /**
     * Generate clinical features using the enhanced feature engine
     */
    async _generateClinicalFeatures(context) {
        try {
            console.log('🔬 Using Enhanced Clinical Feature Engine...');
            
            // Use the new enhanced feature engine
            const clinicalFeatures = await this.clinicalFeatureEngine.extractClinicalFeatures(context);
            
            // Add the enhanced features to the context
            Object.entries(clinicalFeatures).forEach(([featureType, featureData]) => {
                if (featureType !== 'analysis_metadata') {
                    context.addEngineeredFeature('enhanced_clinical', featureType, featureData);
                }
            });
            
            // Store metadata
            context.addEngineeredFeature('metadata', 'clinical_analysis', clinicalFeatures.analysis_metadata);
            
            console.log(`✅ Enhanced clinical features generated with confidence: ${clinicalFeatures.analysis_metadata.confidence_score.toFixed(2)}`);
            console.log(`📊 Clinical significance: ${clinicalFeatures.analysis_metadata.clinical_significance}`);
            
            // Also enrich with existing trend analysis for backward compatibility
            await this.dataRetriever.enrichWithTrendAnalysis(context);
            
            // Legacy risk scores (keep for now)
            this._calculateRiskScores(context);
            this._identifyAbnormalValues(context);
            this._detectPatterns(context);
            
        } catch (error) {
            console.error('❌ Error generating enhanced clinical features:', error);
            // Fallback to legacy feature generation
            console.log('🔄 Falling back to legacy feature generation...');
            await this.dataRetriever.enrichWithTrendAnalysis(context);
            this._calculateRiskScores(context);
            this._identifyAbnormalValues(context);
            this._detectPatterns(context);
        }
    }

    /**
     * Calculate basic risk scores from available data
     */
    _calculateRiskScores(context) {
        const labResults = context.raw_data.lab_results;
        
        // Simple risk scoring based on available lab results
        Object.keys(labResults).forEach(labType => {
            const results = labResults[labType];
            if (results.length > 0) {
                const latestResult = results[0]; // Most recent
                
                // Basic risk assessment (this would be more sophisticated in production)
                let riskScore = 'normal';
                
                if (labType.toLowerCase().includes('glucose') || labType.toLowerCase().includes('diabetes')) {
                    riskScore = this._assessDiabeticRisk(results);
                } else if (labType.toLowerCase().includes('kidney') || labType.toLowerCase().includes('creatinine')) {
                    riskScore = this._assessKidneyRisk(results);
                } else if (labType.toLowerCase().includes('lipid') || labType.toLowerCase().includes('cholesterol')) {
                    riskScore = this._assessCardiovascularRisk(results);
                }
                
                context.addEngineeredFeature('risk_scores', `${labType}_risk`, riskScore);
            }
        });
    }

    /**
     * Simple diabetic risk assessment
     */
    _assessDiabeticRisk(glucoseResults) {
        // This is a simplified example - real implementation would be more sophisticated
        const latestValues = glucoseResults[0]?.normalizedValues || {};
        const glucose = latestValues.glucose || latestValues.random_glucose;
        
        if (glucose > 200) return 'high';
        if (glucose > 140) return 'moderate';
        return 'normal';
    }

    /**
     * Simple kidney function risk assessment
     */
    _assessKidneyRisk(kidneyResults) {
        const latestValues = kidneyResults[0]?.normalizedValues || {};
        const creatinine = latestValues.creatinine;
        
        if (creatinine > 1.5) return 'high';
        if (creatinine > 1.2) return 'moderate';
        return 'normal';
    }

    /**
     * Simple cardiovascular risk assessment
     */
    _assessCardiovascularRisk(lipidResults) {
        const latestValues = lipidResults[0]?.normalizedValues || {};
        const totalCholesterol = latestValues.total_cholesterol;
        
        if (totalCholesterol > 240) return 'high';
        if (totalCholesterol > 200) return 'moderate';
        return 'normal';
    }

    /**
     * Identify abnormal values across all lab results
     */
    _identifyAbnormalValues(context) {
        const abnormalFindings = [];
        const labResults = context.raw_data.lab_results;
        
        Object.entries(labResults).forEach(([labType, results]) => {
            if (results.length > 0) {
                const latest = results[0];
                const values = latest.normalizedValues || {};
                
                // Check for obvious abnormalities (simplified)
                Object.entries(values).forEach(([parameter, value]) => {
                    if (this._isAbnormalValue(parameter, value)) {
                        abnormalFindings.push({
                            labType,
                            parameter,
                            value,
                            date: latest.timestamp
                        });
                    }
                });
            }
        });
        
        context.addEngineeredFeature('clinical_indicators', 'abnormal_findings', abnormalFindings);
    }

    /**
     * Simple abnormal value detection
     */
    _isAbnormalValue(parameter, value) {
        const abnormalRanges = {
            glucose: { min: 70, max: 140 },
            creatinine: { min: 0.6, max: 1.2 },
            total_cholesterol: { min: 100, max: 200 },
            hemoglobin: { min: 12, max: 16 },
            white_blood_cells: { min: 4000, max: 11000 }
        };
        
        const range = abnormalRanges[parameter.toLowerCase()];
        if (range && typeof value === 'number') {
            return value < range.min || value > range.max;
        }
        
        return false;
    }

    /**
     * Detect temporal patterns in the data
     */
    _detectPatterns(context) {
        const patterns = {
            trending_up: [],
            trending_down: [],
            stable: [],
            fluctuating: []
        };
        
        const trends = context.engineered_features.trends || {};
        
        Object.entries(trends).forEach(([trendName, value]) => {
            if (trendName.includes('_slope')) {
                const labType = trendName.replace('_slope', '');
                if (value > 0.1) {
                    patterns.trending_up.push(labType);
                } else if (value < -0.1) {
                    patterns.trending_down.push(labType);
                } else {
                    patterns.stable.push(labType);
                }
            }
        });
        
        context.addEngineeredFeature('temporal_patterns', 'trend_patterns', patterns);
    }

    /**
     * Phase 2: Virtual Case Conference
     * - Engage specialist agents
     * - Enable collaboration between agents
     */
    async _phaseTwoVirtualCaseConference(context, requestedSpecialties) {
        console.log('\n👥 Phase 2: Virtual Case Conference');
        console.log('===================================');
        
        context.setAnalysisStage('virtual_conference');
        
        // For now, we'll create a simple mock specialist opinion
        // (We'll implement real specialist agents in the next step)
        for (const specialty of requestedSpecialties) {
            console.log(`🩺 Consulting ${specialty} specialist...`);
            
            context.setAgentActive(specialty);
            
            // Mock initial opinion (will be replaced with real AI agents)
            const mockOpinion = this._generateMockSpecialistOpinion(specialty, context);
            context.addAgentOpinion(specialty, 'initial_opinion', mockOpinion);
            
            context.setAgentCompleted(specialty);
        }
        
        console.log(`✅ Virtual case conference completed with ${requestedSpecialties.length} specialists`);
    }

    /**
     * Generate mock specialist opinion (temporary - will be replaced with AI agents)
     */
    _generateMockSpecialistOpinion(specialty, context) {
        const riskScores = context.engineered_features.risk_scores || {};
        const abnormalFindings = context.engineered_features.clinical_indicators?.abnormal_findings || [];
        
        return {
            specialty: specialty,
            assessment: `Based on the available data, I note ${abnormalFindings.length} abnormal findings requiring attention.`,
            recommendations: [`Continue monitoring ${specialty.toLowerCase()} parameters`, "Follow up in 3 months"],
            urgency: abnormalFindings.length > 3 ? 'high' : 'routine',
            confidence: 0.8
        };
    }

    /**
     * Phase 3: Synthesis
     * - Combine all specialist opinions
     * - Generate final summary
     */
    async _phaseThreeSynthesis(context) {
        console.log('\n📝 Phase 3: Synthesis');
        console.log('======================');
        
        context.setAnalysisStage('synthesis');
        
        // Simple synthesis (will be enhanced with AI in next steps)
        const opinions = context.getAgentOpinions('initial_opinion');
        const summary = this._generateBasicSummary(context, opinions);
        
        context.setAnalysisStage('completed');
        
        console.log('✅ Synthesis completed');
        
        return summary;
    }

    /**
     * Generate basic summary from context and opinions
     */
    _generateBasicSummary(context, opinions) {
        const contextSummary = context.getSummary();
        const abnormalFindings = context.engineered_features.clinical_indicators?.abnormal_findings || [];
        const riskScores = context.engineered_features.risk_scores || {};
        
        return {
            case_id: context.case_id,
            patient_id: context.patient_id,
            assessment_date: new Date().toISOString(),
            data_summary: {
                lab_types: Object.keys(context.raw_data.lab_results).length,
                medical_records: context.raw_data.reports.length,
                conditions: context.raw_data.conditions.length,
                medications: context.raw_data.medications.length
            },
            clinical_findings: {
                abnormal_findings_count: abnormalFindings.length,
                risk_assessments: riskScores,
                specialist_consultations: Object.keys(opinions).length
            },
            recommendations: this._generateRecommendations(context, opinions),
            next_steps: this._generateNextSteps(context, opinions)
        };
    }

    /**
     * Generate recommendations based on findings
     */
    _generateRecommendations(context, opinions) {
        const recommendations = [];
        const abnormalFindings = context.engineered_features.clinical_indicators?.abnormal_findings || [];
        
        if (abnormalFindings.length > 0) {
            recommendations.push("Review abnormal lab values with primary care physician");
        }
        
        Object.values(opinions).forEach(opinion => {
            if (opinion.content && opinion.content.recommendations) {
                recommendations.push(...opinion.content.recommendations);
            }
        });
        
        return recommendations;
    }

    /**
     * Generate next steps
     */
    _generateNextSteps(context, opinions) {
        const steps = [];
        const highRiskItems = Object.entries(context.engineered_features.risk_scores || {})
            .filter(([key, value]) => value === 'high');
        
        if (highRiskItems.length > 0) {
            steps.push("Schedule follow-up for high-risk conditions");
        }
        
        steps.push("Continue regular monitoring");
        steps.push("Update medical records with new findings");
        
        return steps;
    }

    /**
     * Get status of an active assessment
     */
    getAssessmentStatus(caseId) {
        const context = this.activeContexts.get(caseId);
        if (!context) {
            return { error: 'Case not found' };
        }
        
        return context.getSummary();
    }

    /**
     * List all active assessments
     */
    getActiveAssessments() {
        return Array.from(this.activeContexts.keys());
    }
}

module.exports = Orchestrator;
