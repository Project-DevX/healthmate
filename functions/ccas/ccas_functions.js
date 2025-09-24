/**
 * CCAS Firebase Functions
 * 
 * These functions expose the Collaborative Clinical Assessment System
 * to the HealthMate frontend through Firebase Callable Functions.
 */

const {onCall} = require("firebase-functions/v2/https");
const {HttpsError} = require("firebase-functions/v2/https");
const Orchestrator = require('./Orchestrator');

// Initialize the orchestrator
const orchestrator = new Orchestrator();

/**
 * Start a new CCAS assessment
 */
exports.startCCASAssessment = onCall(
    {cors: true},
    async (request) => {
        const {auth, data} = request;
        const {userId, specialties = [], timePeriod = null} = data;
        
        if (!auth) {
            throw new HttpsError("unauthenticated", "User must be logged in");
        }
        
        if (auth.uid !== userId) {
            throw new HttpsError("permission-denied", "User can only access their own data");
        }
        
        if (!userId) {
            throw new HttpsError("invalid-argument", "User ID is required");
        }
        
        try {
            console.log(`🎯 Starting CCAS assessment for user: ${userId}`);
            console.log(`📋 Requested specialties: ${specialties.join(', ')}`);
            
            const result = await orchestrator.startAssessment(userId, specialties, {
                timePeriod: timePeriod
            });
            
            return {
                success: true,
                case_id: result.case_id,
                summary: result.summary,
                message: `CCAS assessment completed for case ${result.case_id}`
            };
            
        } catch (error) {
            console.error('❌ Error in CCAS assessment:', error);
            throw new HttpsError("internal", `CCAS assessment failed: ${error.message}`);
        }
    }
);

/**
 * Get the status of an ongoing assessment
 */
exports.getCCASStatus = onCall(
    {cors: true},
    async (request) => {
        const {auth, data} = request;
        const {caseId} = data;
        
        if (!auth) {
            throw new HttpsError("unauthenticated", "User must be logged in");
        }
        
        if (!caseId) {
            throw new HttpsError("invalid-argument", "Case ID is required");
        }
        
        try {
            const status = orchestrator.getAssessmentStatus(caseId);
            
            if (status.error) {
                throw new HttpsError("not-found", status.error);
            }
            
            return {
                success: true,
                status: status
            };
            
        } catch (error) {
            console.error('❌ Error getting CCAS status:', error);
            throw new HttpsError("internal", `Failed to get status: ${error.message}`);
        }
    }
);

/**
 * Run a quick CCAS assessment with automatic specialty detection
 */
exports.quickCCASAssessment = onCall(
    {cors: true},
    async (request) => {
        const {auth, data} = request;
        const {userId, timePeriod = null} = data;
        
        if (!auth) {
            throw new HttpsError("unauthenticated", "User must be logged in");
        }
        
        if (auth.uid !== userId) {
            throw new HttpsError("permission-denied", "User can only access their own data");
        }
        
        try {
            console.log(`⚡ Starting quick CCAS assessment for user: ${userId}`);
            
            // Automatically detect relevant specialties based on available data
            const relevantSpecialties = await detectRelevantSpecialties(userId);
            
            console.log(`🔍 Auto-detected specialties: ${relevantSpecialties.join(', ')}`);
            
            const result = await orchestrator.startAssessment(userId, relevantSpecialties, {
                timePeriod: timePeriod
            });
            
            return {
                success: true,
                case_id: result.case_id,
                summary: result.summary,
                detected_specialties: relevantSpecialties,
                message: `Quick CCAS assessment completed with ${relevantSpecialties.length} specialties`
            };
            
        } catch (error) {
            console.error('❌ Error in quick CCAS assessment:', error);
            throw new HttpsError("internal", `Quick assessment failed: ${error.message}`);
        }
    }
);

/**
 * Detect relevant medical specialties based on patient data
 */
async function detectRelevantSpecialties(userId) {
    try {
        const dataRetriever = new (require('./DataRetriever'))();
        
        // Create a temporary context to analyze available data
        const context = await dataRetriever.createPatientContext(userId);
        
        const specialties = new Set();
        const labResults = context.raw_data.lab_results;
        const conditions = context.raw_data.conditions;
        
        // Detect specialties based on lab types
        Object.keys(labResults).forEach(labType => {
            const lowerLabType = labType.toLowerCase();
            
            if (lowerLabType.includes('glucose') || lowerLabType.includes('diabetes') || lowerLabType.includes('hba1c')) {
                specialties.add('Endocrinology');
            }
            
            if (lowerLabType.includes('kidney') || lowerLabType.includes('creatinine') || lowerLabType.includes('urea')) {
                specialties.add('Nephrology');
            }
            
            if (lowerLabType.includes('lipid') || lowerLabType.includes('cholesterol') || lowerLabType.includes('cardiac')) {
                specialties.add('Cardiology');
            }
            
            if (lowerLabType.includes('liver') || lowerLabType.includes('hepatic') || lowerLabType.includes('alt') || lowerLabType.includes('ast')) {
                specialties.add('Gastroenterology');
            }
            
            if (lowerLabType.includes('blood') || lowerLabType.includes('hemoglobin') || lowerLabType.includes('hematology')) {
                specialties.add('Hematology');
            }
        });
        
        // Detect specialties based on conditions
        conditions.forEach(condition => {
            const conditionText = JSON.stringify(condition).toLowerCase();
            
            if (conditionText.includes('diabetes') || conditionText.includes('thyroid')) {
                specialties.add('Endocrinology');
            }
            
            if (conditionText.includes('heart') || conditionText.includes('cardiac') || conditionText.includes('hypertension')) {
                specialties.add('Cardiology');
            }
            
            if (conditionText.includes('kidney') || conditionText.includes('renal')) {
                specialties.add('Nephrology');
            }
        });
        
        // Default to general internal medicine if no specific specialties detected
        if (specialties.size === 0) {
            specialties.add('Internal Medicine');
        }
        
        return Array.from(specialties);
        
    } catch (error) {
        console.error('❌ Error detecting specialties:', error);
        return ['Internal Medicine']; // Fallback
    }
}

/**
 * Test function for CCAS system
 */
exports.testCCAS = onCall(
    {cors: true},
    async (request) => {
        const {auth} = request;
        
        if (!auth) {
            throw new HttpsError("unauthenticated", "User must be logged in");
        }
        
        try {
            console.log('🧪 Testing CCAS system...');
            
            // Test with the authenticated user's ID
            const testUserId = auth.uid;
            
            const result = await orchestrator.startAssessment(testUserId, ['Internal Medicine'], {
                timePeriod: null
            });
            
            return {
                success: true,
                message: 'CCAS test completed successfully',
                case_id: result.case_id,
                test_summary: result.summary
            };
            
        } catch (error) {
            console.error('❌ CCAS test failed:', error);
            throw new HttpsError("internal", `CCAS test failed: ${error.message}`);
        }
    }
);
