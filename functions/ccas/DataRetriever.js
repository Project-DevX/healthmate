/**
 * DataRetriever - Tool A for CCAS
 * 
 * This component fetches patient data from Firebase and populates
 * the SharedPatientContext with comprehensive medical information.
 * It integrates with existing HealthMate collections and functions.
 */

const admin = require("firebase-admin");
const SharedPatientContext = require('./SharedPatientContext');

class DataRetriever {
    constructor() {
        this.db = admin.firestore();
    }

    /**
     * Create and populate a SharedPatientContext for a patient
     * @param {string} userId - The patient's user ID
     * @param {Object} timePeriod - Optional time period filter
     * @returns {Promise<SharedPatientContext>}
     */
    async createPatientContext(userId, timePeriod = null) {
        console.log(`🔍 Creating patient context for user: ${userId}`);
        
        // Initialize the context
        const context = new SharedPatientContext(userId, timePeriod);
        context.setAnalysisStage('data_retrieval');
        
        try {
            // Fetch all patient data in parallel for efficiency
            const [
                demographics,
                labResults,
                medicalRecords,
                documents,
                conditions,
                medications
            ] = await Promise.all([
                this._fetchDemographics(userId),
                this._fetchLabResults(userId, timePeriod),
                this._fetchMedicalRecords(userId, timePeriod),
                this._fetchDocuments(userId, timePeriod),
                this._fetchConditions(userId),
                this._fetchMedications(userId)
            ]);

            // Populate the context with raw data
            context.addRawData('demographics', demographics);
            context.addRawData('lab_results', labResults);
            context.addRawData('reports', medicalRecords);
            context.addRawData('conditions', conditions);
            context.addRawData('medications', medications);
            
            // Add documents (scanned reports, etc.)
            if (documents && documents.length > 0) {
                context.addRawData('reports', documents);
            }

            context.setAnalysisStage('data_loaded');
            
            console.log(`✅ Patient context created with ${Object.keys(labResults).length} lab types, ${conditions.length} conditions, ${medicalRecords.length} records`);
            
            return context;
            
        } catch (error) {
            console.error('❌ Error creating patient context:', error);
            throw error;
        }
    }

    /**
     * Fetch patient demographics and basic info
     */
    async _fetchDemographics(userId) {
        try {
            const userDoc = await this.db.collection('users').doc(userId).get();
            
            if (!userDoc.exists) {
                console.warn(`⚠️ No user document found for: ${userId}`);
                return null;
            }

            const userData = userDoc.data();
            
            return {
                userId: userId,
                email: userData.email,
                role: userData.role,
                registrationDate: userData.createdAt,
                personalInfo: userData.personalInfo || {},
                contactInfo: userData.contactInfo || {},
                emergencyContact: userData.emergencyContact || {}
            };
            
        } catch (error) {
            console.error(`❌ Error fetching demographics for ${userId}:`, error);
            return null;
        }
    }

    /**
     * Fetch lab results organized by test type
     */
    async _fetchLabResults(userId, timePeriod = null) {
        try {
            let query = this.db
                .collection('users')
                .doc(userId)
                .collection('lab_report_content');

            // Apply time filter if provided
            if (timePeriod && timePeriod.start) {
                query = query.where('createdAt', '>=', new Date(timePeriod.start));
            }
            if (timePeriod && timePeriod.end) {
                query = query.where('createdAt', '<=', new Date(timePeriod.end));
            }

            const labSnapshot = await query.orderBy('createdAt', 'desc').get();
            
            // Organize by lab report type
            const labResults = {};
            
            labSnapshot.docs.forEach(doc => {
                const data = doc.data();
                const labType = data.labReportType || 'Unknown';
                
                if (!labResults[labType]) {
                    labResults[labType] = [];
                }
                
                labResults[labType].push({
                    id: doc.id,
                    timestamp: data.createdAt,
                    labReportType: labType,
                    extractedData: data.extractedData || {},
                    normalizedValues: data.normalizedValues || {},
                    documentUrl: data.documentUrl,
                    processingDate: data.processingDate
                });
            });

            console.log(`📊 Found lab results for ${Object.keys(labResults).length} test types`);
            return labResults;
            
        } catch (error) {
            console.error(`❌ Error fetching lab results for ${userId}:`, error);
            return {};
        }
    }

    /**
     * Fetch medical records and reports
     */
    async _fetchMedicalRecords(userId, timePeriod = null) {
        try {
            // Check both locations: users/{userId}/medical_records and medical_records/{userId}/documents
            const [userMedicalRecords, medicalDocuments] = await Promise.all([
                this._fetchFromUserMedicalRecords(userId, timePeriod),
                this._fetchFromMedicalRecordsCollection(userId, timePeriod)
            ]);

            // Combine and deduplicate
            const allRecords = [...userMedicalRecords, ...medicalDocuments];
            
            console.log(`📋 Found ${allRecords.length} medical records`);
            return allRecords;
            
        } catch (error) {
            console.error(`❌ Error fetching medical records for ${userId}:`, error);
            return [];
        }
    }

    async _fetchFromUserMedicalRecords(userId, timePeriod) {
        let query = this.db
            .collection('users')
            .doc(userId)
            .collection('medical_records');

        if (timePeriod && timePeriod.start) {
            query = query.where('createdAt', '>=', new Date(timePeriod.start));
        }

        const snapshot = await query.orderBy('createdAt', 'desc').get();
        
        return snapshot.docs.map(doc => ({
            id: doc.id,
            source: 'user_medical_records',
            ...doc.data()
        }));
    }

    async _fetchFromMedicalRecordsCollection(userId, timePeriod) {
        let query = this.db
            .collection('medical_records')
            .doc(userId)
            .collection('documents');

        if (timePeriod && timePeriod.start) {
            query = query.where('createdAt', '>=', new Date(timePeriod.start));
        }

        const snapshot = await query.orderBy('createdAt', 'desc').get();
        
        return snapshot.docs.map(doc => ({
            id: doc.id,
            source: 'medical_records_collection',
            ...doc.data()
        }));
    }

    /**
     * Fetch uploaded documents
     */
    async _fetchDocuments(userId, timePeriod = null) {
        try {
            let query = this.db
                .collection('users')
                .doc(userId)
                .collection('documents');

            if (timePeriod && timePeriod.start) {
                query = query.where('uploadDate', '>=', new Date(timePeriod.start));
            }

            const docsSnapshot = await query.orderBy('uploadDate', 'desc').get();
            
            const documents = docsSnapshot.docs.map(doc => ({
                id: doc.id,
                type: 'uploaded_document',
                ...doc.data()
            }));

            console.log(`📄 Found ${documents.length} uploaded documents`);
            return documents;
            
        } catch (error) {
            console.error(`❌ Error fetching documents for ${userId}:`, error);
            return [];
        }
    }

    /**
     * Extract conditions/diagnoses from medical records
     */
    async _fetchConditions(userId) {
        try {
            // This would typically come from structured data or be extracted from documents
            // For now, we'll look for classification results that might contain diagnoses
            const conditionsSnapshot = await this.db
                .collection('users')
                .doc(userId)
                .collection('conditions')
                .get();

            const conditions = conditionsSnapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));

            console.log(`🩺 Found ${conditions.length} documented conditions`);
            return conditions;
            
        } catch (error) {
            console.error(`❌ Error fetching conditions for ${userId}:`, error);
            return [];
        }
    }

    /**
     * Extract medications from medical records
     */
    async _fetchMedications(userId) {
        try {
            const medicationsSnapshot = await this.db
                .collection('users')
                .doc(userId)
                .collection('medications')
                .get();

            const medications = medicationsSnapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));

            console.log(`💊 Found ${medications.length} documented medications`);
            return medications;
            
        } catch (error) {
            console.error(`❌ Error fetching medications for ${userId}:`, error);
            return [];
        }
    }

    /**
     * Get existing trend analysis data (integrate with your existing functions)
     */
    async fetchExistingTrendAnalysis(userId, labReportType = null) {
        try {
            let query = this.db
                .collection('users')
                .doc(userId)
                .collection('trend_analysis');

            if (labReportType) {
                query = query.where('labReportType', '==', labReportType);
            }

            const trendsSnapshot = await query.orderBy('createdAt', 'desc').get();
            
            const trends = {};
            trendsSnapshot.docs.forEach(doc => {
                const data = doc.data();
                const labType = data.labReportType;
                trends[labType] = {
                    id: doc.id,
                    ...data
                };
            });

            console.log(`📈 Found existing trend analysis for ${Object.keys(trends).length} lab types`);
            return trends;
            
        } catch (error) {
            console.error(`❌ Error fetching trend analysis for ${userId}:`, error);
            return {};
        }
    }

    /**
     * Update context with existing trend analysis
     */
    async enrichWithTrendAnalysis(context) {
        try {
            const trends = await this.fetchExistingTrendAnalysis(context.patient_id);
            
            // Add trends as engineered features
            for (const [labType, trendData] of Object.entries(trends)) {
                if (trendData.linearTrend) {
                    context.addEngineeredFeature('trends', `${labType}_slope`, trendData.linearTrend.slope);
                    context.addEngineeredFeature('trends', `${labType}_correlation`, trendData.linearTrend.correlation);
                    context.addEngineeredFeature('trends', `${labType}_trend_direction`, trendData.linearTrend.trendDirection);
                }
                
                if (trendData.predictions) {
                    context.addEngineeredFeature('temporal_patterns', `${labType}_predictions`, trendData.predictions);
                }
            }
            
            console.log(`📊 Enriched context with trend analysis for ${Object.keys(trends).length} lab types`);
            
        } catch (error) {
            console.error('❌ Error enriching with trend analysis:', error);
        }
    }
}

module.exports = DataRetriever;
