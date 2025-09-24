/**
 * SharedPatientContext - The central data structure for CCAS
 * 
 * This class represents the "case file" that gets passed between all agents
 * in the Collaborative Clinical Assessment System. It serves as the single
 * source of truth for a patient's case during analysis.
 */

class SharedPatientContext {
    constructor(patientId, timePeriod = null) {
        this.case_id = this._generateCaseId();
        this.patient_id = patientId;
        this.time_period = timePeriod || {
            start: null,
            end: new Date().toISOString()
        };
        this.created_at = new Date().toISOString();
        this.last_updated = new Date().toISOString();
        
        // Raw data from various sources
        this.raw_data = {
            conditions: [],
            medications: [],
            lab_results: {},
            vital_signs: {},
            reports: [],
            demographics: null
        };
        
        // Engineered features from clinical analysis
        this.engineered_features = {
            trends: {},
            risk_scores: {},
            clinical_indicators: {},
            temporal_patterns: {}
        };
        
        // Opinions from specialist agents
        this.agent_opinions = {};
        
        // Metadata for tracking the analysis process
        this.metadata = {
            analysis_stage: 'initialized',
            active_agents: [],
            completed_agents: [],
            collaboration_rounds: 0,
            confidence_scores: {}
        };
    }

    /**
     * Generate a unique case ID
     */
    _generateCaseId() {
        const timestamp = Date.now().toString(36);
        const random = Math.random().toString(36).substr(2, 5);
        return `CCAS-${timestamp}-${random}`.toUpperCase();
    }

    /**
     * Update the last modified timestamp
     */
    _updateTimestamp() {
        this.last_updated = new Date().toISOString();
    }

    /**
     * Add raw patient data
     */
    addRawData(dataType, data) {
        if (!this.raw_data[dataType]) {
            this.raw_data[dataType] = Array.isArray(data) ? [] : {};
        }
        
        if (Array.isArray(this.raw_data[dataType])) {
            this.raw_data[dataType].push(...(Array.isArray(data) ? data : [data]));
        } else {
            Object.assign(this.raw_data[dataType], data);
        }
        
        this._updateTimestamp();
    }

    /**
     * Add engineered features from clinical analysis
     */
    addEngineeredFeature(featureType, featureName, value) {
        if (!this.engineered_features[featureType]) {
            this.engineered_features[featureType] = {};
        }
        
        this.engineered_features[featureType][featureName] = value;
        this._updateTimestamp();
    }

    /**
     * Add or update an agent's opinion
     */
    addAgentOpinion(agentName, opinionType, opinion) {
        if (!this.agent_opinions[agentName]) {
            this.agent_opinions[agentName] = {
                agent_id: agentName,
                timestamp: new Date().toISOString(),
                status: 'active'
            };
        }
        
        this.agent_opinions[agentName][opinionType] = {
            content: opinion,
            timestamp: new Date().toISOString(),
            confidence: null // Can be added later
        };
        
        this._updateTimestamp();
    }

    /**
     * Mark an agent as active (currently analyzing)
     */
    setAgentActive(agentName) {
        if (!this.metadata.active_agents.includes(agentName)) {
            this.metadata.active_agents.push(agentName);
        }
        this._updateTimestamp();
    }

    /**
     * Mark an agent as completed
     */
    setAgentCompleted(agentName) {
        // Remove from active
        this.metadata.active_agents = this.metadata.active_agents.filter(
            agent => agent !== agentName
        );
        
        // Add to completed
        if (!this.metadata.completed_agents.includes(agentName)) {
            this.metadata.completed_agents.push(agentName);
        }
        
        this._updateTimestamp();
    }

    /**
     * Update the analysis stage
     */
    setAnalysisStage(stage) {
        this.metadata.analysis_stage = stage;
        this._updateTimestamp();
    }

    /**
     * Increment collaboration round
     */
    incrementCollaborationRound() {
        this.metadata.collaboration_rounds += 1;
        this._updateTimestamp();
    }

    /**
     * Get a summary of the current state
     */
    getSummary() {
        return {
            case_id: this.case_id,
            patient_id: this.patient_id,
            stage: this.metadata.analysis_stage,
            active_agents: this.metadata.active_agents,
            completed_agents: this.metadata.completed_agents,
            collaboration_rounds: this.metadata.collaboration_rounds,
            data_types: Object.keys(this.raw_data).filter(
                key => Array.isArray(this.raw_data[key]) ? 
                    this.raw_data[key].length > 0 : 
                    Object.keys(this.raw_data[key]).length > 0
            ),
            feature_types: Object.keys(this.engineered_features).filter(
                key => Object.keys(this.engineered_features[key]).length > 0
            ),
            agent_count: Object.keys(this.agent_opinions).length,
            last_updated: this.last_updated
        };
    }

    /**
     * Get all agent opinions for a specific round
     */
    getAgentOpinions(opinionType = 'initial_opinion') {
        const opinions = {};
        for (const [agentName, agentData] of Object.entries(this.agent_opinions)) {
            if (agentData[opinionType]) {
                opinions[agentName] = agentData[opinionType];
            }
        }
        return opinions;
    }

    /**
     * Check if all specified agents have completed their analysis
     */
    areAgentsCompleted(requiredAgents) {
        return requiredAgents.every(agent => 
            this.metadata.completed_agents.includes(agent)
        );
    }

    /**
     * Get the full context for serialization
     */
    toJSON() {
        return {
            case_id: this.case_id,
            patient_id: this.patient_id,
            time_period: this.time_period,
            created_at: this.created_at,
            last_updated: this.last_updated,
            raw_data: this.raw_data,
            engineered_features: this.engineered_features,
            agent_opinions: this.agent_opinions,
            metadata: this.metadata
        };
    }

    /**
     * Create instance from JSON (for persistence/restoration)
     */
    static fromJSON(jsonData) {
        const context = new SharedPatientContext(jsonData.patient_id, jsonData.time_period);
        
        // Restore all data
        context.case_id = jsonData.case_id;
        context.created_at = jsonData.created_at;
        context.last_updated = jsonData.last_updated;
        context.raw_data = jsonData.raw_data || context.raw_data;
        context.engineered_features = jsonData.engineered_features || context.engineered_features;
        context.agent_opinions = jsonData.agent_opinions || context.agent_opinions;
        context.metadata = { ...context.metadata, ...jsonData.metadata };
        
        return context;
    }

    /**
     * Validate the context structure
     */
    validate() {
        const errors = [];
        
        if (!this.patient_id) {
            errors.push('Patient ID is required');
        }
        
        if (!this.case_id) {
            errors.push('Case ID is required');
        }
        
        // Add more validation as needed
        
        return {
            isValid: errors.length === 0,
            errors: errors
        };
    }
}

module.exports = SharedPatientContext;
