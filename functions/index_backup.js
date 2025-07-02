/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onCall} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const functions = require("firebase-functions");

// Set global options
setGlobalOptions({region: "us-central1"}); // Change to your preferred region

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Debug function to test Cloud Functions connectivity
 */
exports.debugFunction = onCall(
  {cors: true},
  async (request) => {
    const {auth} = request;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    return {
      message: "Debug function working correctly",
      timestamp: new Date().toISOString(),
      userId: auth.uid,
      geminiApiKey: process.env.GEMINI_API_KEY ? "Present" : "Missing"
    };
  }
);

/**
 * Classify medical documents using Gemini AI
 */
exports.classifyMedicalDocument = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== CLASSIFY MEDICAL DOCUMENT ===');
      console.log('Auth UID:', auth?.uid);
      console.log('Data:', data);

      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const {fileName, storagePath} = data;
      
      if (!fileName || !storagePath) {
        throw new HttpsError("invalid-argument", "fileName and storagePath are required");
      }

      try {
        const geminiApiKey = process.env.GEMINI_API_KEY;
        if (!geminiApiKey) {
          console.warn('⚠️ Gemini API key not configured, using filename-based classification');
          return classifyByFilename(fileName);
        }

        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
        const bucket = admin.storage().bucket();

        // Check if file exists and is an image
        const file = bucket.file(storagePath);
        const [exists] = await file.exists();
        
        if (!exists) {
          console.error(`❌ File not found: ${storagePath}`);
          return classifyByFilename(fileName);
        }

        // Check if it's an image file for AI analysis
        const isImage = /\.(jpg|jpeg|png|gif|bmp|webp)$/i.test(fileName);
        
        if (!isImage) {
          console.log(`📄 Non-image file, using filename classification: ${fileName}`);
          return classifyByFilename(fileName);
        }

        // Download and analyze the image
        const [fileBuffer] = await file.download();
        const base64Data = fileBuffer.toString('base64');
        
        let mimeType = 'image/jpeg';
        if (fileName.toLowerCase().endsWith('.png')) mimeType = 'image/png';
        else if (fileName.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';
        else if (fileName.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';

        const classificationPrompt = `
Analyze this medical document image and classify it into one of these categories:
- lab_reports: Laboratory test results, blood work, pathology reports
- prescriptions: Medication prescriptions, pharmacy receipts
- doctor_notes: Doctor consultation notes, clinical observations, medical certificates
- other: Insurance documents, appointment cards, general medical documents

Return ONLY a JSON object with this exact structure:
{
  "category": "one of: lab_reports, prescriptions, doctor_notes, other",
  "confidence": 0.0-1.0,
  "suggestedSubfolder": "descriptive folder name",
  "reasoning": "brief explanation of classification"
}

Focus on identifying:
1. Lab values, test results, reference ranges → lab_reports
2. Drug names, dosages, pharmacy stamps → prescriptions  
3. Doctor signatures, clinical notes, diagnoses → doctor_notes
4. Insurance info, appointment details → other
`;

        const result = await model.generateContent([
          classificationPrompt,
          {
            inlineData: {
              data: base64Data,
              mimeType: mimeType
            }
          }
        ]);

        const response = result.response.text();
        console.log('🤖 Gemini classification response:', response);

        // Try to parse the JSON response
        try {
          const classification = JSON.parse(response);
          
          // Validate the response structure
          if (classification.category && typeof classification.confidence === 'number') {
            return {
              category: classification.category,
              confidence: Math.max(0, Math.min(1, classification.confidence)),
              suggestedSubfolder: classification.suggestedSubfolder || getDefaultSubfolder(classification.category),
              reasoning: classification.reasoning || 'AI classification'
            };
          }
        } catch (parseError) {
          console.error('❌ Failed to parse Gemini response as JSON:', parseError);
        }

        // Fallback to filename classification if AI fails
        console.log('⚠️ AI classification failed, falling back to filename analysis');
        return classifyByFilename(fileName);

      } catch (error) {
        console.error('❌ Error in document classification:', error);
        
        // Fallback to filename classification
        return classifyByFilename(fileName);
      }
    }
);

/**
 * Analyze ONLY lab reports using Gemini AI
 */
exports.analyzeLabReports = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== ANALYZE LAB REPORTS ===');
      console.log('Auth UID:', auth?.uid);

      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const userId = auth.uid;
      const forceReanalysis = data?.forceReanalysis || false;
      
      try {
        const geminiApiKey = process.env.GEMINI_API_KEY;
        if (!geminiApiKey) {
          throw new HttpsError("failed-precondition", "API key not configured");
        }

        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
        const db = admin.firestore();

        // Get existing lab analysis
        const existingAnalysisDoc = await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("lab_reports")
            .get();

        const existingAnalysis = existingAnalysisDoc.exists ? existingAnalysisDoc.data() : null;
        const analyzedDocumentIds = existingAnalysis?.analyzedDocuments || [];

        // Get LAB REPORTS only from new document structure
        const documentsSnapshot = await db
            .collection("medical_records")
            .doc(userId)
            .collection("documents")
            .where("category", "in", ["Lab Reports", "lab_reports", "Lab Report"])
            .orderBy("uploadDate", "desc")
            .get();

        if (documentsSnapshot.empty) {
          return {
            summary: "No lab reports found for analysis. Please upload some lab test results first.",
            documentsAnalyzed: 0,
            newDocumentsAnalyzed: 0,
            isCached: false,
            analysisType: 'lab_reports_only'
          };
        }

        // Process lab reports
        const allLabReports = [];
        const newLabReports = [];

        documentsSnapshot.forEach((doc) => {
          const docData = doc.data();
          const docInfo = {
            id: doc.id,
            fileName: docData.fileName,
            storagePath: docData.filePath, // Updated field name
            downloadUrl: docData.downloadUrl,
            uploadDate: docData.uploadDate,
            category: docData.category,
            ...docData
          };
          
          allLabReports.push(docInfo);
          
          const wasAnalyzed = analyzedDocumentIds.includes(doc.id);
          if (forceReanalysis || !wasAnalyzed) {
            newLabReports.push(docInfo);
          }
        });

        console.log(`📄 Total lab reports: ${allLabReports.length}`);
        console.log(`🆕 New lab reports to analyze: ${newLabReports.length}`);

        // Return cached if no new lab reports
        if (newLabReports.length === 0 && existingAnalysis && !forceReanalysis) {
          return {
            summary: existingAnalysis.summary,
            lastUpdated: existingAnalysis.timestamp.toDate().toISOString(),
            documentsAnalyzed: analyzedDocumentIds.length,
            newDocumentsAnalyzed: 0,
            isCached: true,
            analysisType: 'lab_reports_only'
          };
        }

        // Analyze new lab reports
        const newLabAnalyses = await analyzeDocuments(newLabReports, model, 'lab_reports');

        // Generate lab-focused summary
        const labSummaryPrompt = `
Based on the following LAB REPORT analyses, create a comprehensive LABORATORY RESULTS SUMMARY:

${existingAnalysis && !forceReanalysis ? `
**EXISTING LAB SUMMARY:**
${existingAnalysis.summary}

**NEW LAB REPORTS TO INTEGRATE:**
` : '**LAB REPORT ANALYSES:**'}

${newLabAnalyses.map((doc, index) => 
  `\n--- Lab Report ${index + 1}: ${doc.fileName} (${doc.uploadDate}) ---\n${doc.analysis}\n`
).join('\n')}

Create a focused LAB RESULTS SUMMARY with:

1. **Laboratory Test Overview**: Summary of all tests performed
2. **Key Laboratory Findings**: 
   - Abnormal values with reference ranges
   - Critical or concerning lab results
   - Trending patterns in repeat tests
3. **Test Results by Category**:
   - Blood Chemistry (glucose, lipids, liver function, kidney function)
   - Hematology (CBC, blood counts)
   - Hormones (thyroid, diabetes markers)
   - Specialty Tests (cardiac markers, tumor markers, etc.)
4. **Abnormal Results Summary**: All out-of-range values with clinical significance
5. **Laboratory Timeline**: Chronological progression of test results
6. **Health Risk Assessment**: Based on lab findings
7. **Recommended Follow-up**: Suggested additional tests or monitoring

Focus ONLY on laboratory data. Include specific values, units, and reference ranges.
Mark new findings with "**NEW:**" if updating existing summary.
Be precise with medical terminology and lab values.
`;

        const result = await model.generateContent(labSummaryPrompt);
        const summary = result.response.text();

        // Update analyzed documents list
        const updatedAnalyzedDocuments = [...new Set([
          ...analyzedDocumentIds,
          ...newLabAnalyses.map(doc => doc.documentId)
        ])];

        // Store lab analysis
        await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("lab_reports")
            .set({
              summary: summary,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              documentCount: allLabReports.length,
              analyzedDocuments: updatedAnalyzedDocuments,
              analysisType: 'lab_reports_only',
              lastAnalysisType: forceReanalysis ? 'full_reanalysis' : 
                               (existingAnalysis ? 'incremental_update' : 'initial_analysis')
            });

        return {
          summary: summary,
          documentsAnalyzed: allLabReports.length,
          newDocumentsAnalyzed: newLabAnalyses.length,
          lastUpdated: new Date().toISOString(),
          isCached: false,
          analysisType: 'lab_reports_only'
        };

      } catch (error) {
        console.error("Error analyzing lab reports:", error);
        throw new HttpsError("internal", "Failed to analyze lab reports", error.message);
      }
    }
);

/**
 * Analyze ALL medical documents using Gemini AI
 */
exports.analyzeAllMedicalRecords = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== ANALYZE ALL MEDICAL RECORDS ===');
      console.log('Auth UID:', auth?.uid);

      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const userId = auth.uid;
      const forceReanalysis = data?.forceReanalysis || false;
      
      try {
        const geminiApiKey = process.env.GEMINI_API_KEY;
        if (!geminiApiKey) {
          throw new HttpsError("failed-precondition", "API key not configured");
        }

        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
        const db = admin.firestore();

        // Get existing comprehensive analysis
        const existingAnalysisDoc = await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("comprehensive")
            .get();

        const existingAnalysis = existingAnalysisDoc.exists ? existingAnalysisDoc.data() : null;
        const analyzedDocumentIds = existingAnalysis?.analyzedDocuments || [];

        // Get ALL documents from new structure
        const documentsSnapshot = await db
            .collection("medical_records")
            .doc(userId)
            .collection("documents")
            .orderBy("uploadDate", "desc")
            .get();

        if (documentsSnapshot.empty) {
          return {
            summary: "No medical documents found for analysis. Please upload some medical records first.",
            documentsAnalyzed: 0,
            newDocumentsAnalyzed: 0,
            isCached: false,
            analysisType: 'comprehensive'
          };
        }

        // Process all documents
        const allDocuments = [];
        const newDocuments = [];

        documentsSnapshot.forEach((doc) => {
          const docData = doc.data();
          const docInfo = {
            id: doc.id,
            fileName: docData.fileName,
            storagePath: docData.filePath, // Updated field name
            downloadUrl: docData.downloadUrl,
            uploadDate: docData.uploadDate,
            category: docData.category,
            ...docData
          };
          
          allDocuments.push(docInfo);
          
          const wasAnalyzed = analyzedDocumentIds.includes(doc.id);
          if (forceReanalysis || !wasAnalyzed) {
            newDocuments.push(docInfo);
          }
        });

        console.log(`📄 Total documents: ${allDocuments.length}`);
        console.log(`🆕 New documents to analyze: ${newDocuments.length}`);

        // Return cached if no new documents
        if (newDocuments.length === 0 && existingAnalysis && !forceReanalysis) {
          return {
            summary: existingAnalysis.summary,
            lastUpdated: existingAnalysis.timestamp.toDate().toISOString(),
            documentsAnalyzed: analyzedDocumentIds.length,
            newDocumentsAnalyzed: 0,
            isCached: true,
            analysisType: 'comprehensive'
          };
        }

        // Get user profile for context
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data() || {};

        // Analyze new documents
        const newDocumentAnalyses = await analyzeDocuments(newDocuments, model, 'comprehensive');

        // Group documents by category for better organization
        const documentsByCategory = groupDocumentsByCategory(newDocumentAnalyses);

        // Create comprehensive summary prompt
        const dobText = userData.dateOfBirth ?
          new Date(userData.dateOfBirth.seconds * 1000).toLocaleDateString() :
          "Not specified";

        const comprehensiveSummaryPrompt = `
Create a COMPREHENSIVE MEDICAL SUMMARY based on ALL medical document types:

**PATIENT INFORMATION:**
- Gender: ${userData.gender || "Not specified"}
- Age: ${userData.age || "Not specified"}
- Date of Birth: ${dobText}

${existingAnalysis && !forceReanalysis ? `
**EXISTING COMPREHENSIVE SUMMARY:**
${existingAnalysis.summary}

**NEW DOCUMENTS TO INTEGRATE:**
` : '**ALL DOCUMENT ANALYSES:**'}

**LAB REPORTS:**
${documentsByCategory.labReports.map((doc, i) => 
  `${i + 1}. ${doc.fileName} (${doc.uploadDate})\n${doc.analysis}\n`
).join('\n') || 'No lab reports found.'}

**PRESCRIPTIONS:**
${documentsByCategory.prescriptions.map((doc, i) => 
  `${i + 1}. ${doc.fileName} (${doc.uploadDate})\n${doc.analysis}\n`
).join('\n') || 'No prescriptions found.'}

**DOCTOR NOTES:**
${documentsByCategory.doctorNotes.map((doc, i) => 
  `${i + 1}. ${doc.fileName} (${doc.uploadDate})\n${doc.analysis}\n`
).join('\n') || 'No doctor notes found.'}

**OTHER DOCUMENTS:**
${documentsByCategory.other.map((doc, i) => 
  `${i + 1}. ${doc.fileName} (${doc.uploadDate})\n${doc.analysis}\n`
).join('\n') || 'No other documents found.'}

Create a COMPREHENSIVE medical summary with:

1. **Document Overview**: Complete inventory of all medical records
2. **Medical History Summary**: 
   - Diagnoses and conditions from all sources
   - Treatment history and outcomes
   - Surgical and procedural history
3. **Laboratory Results Integration**:
   - Key lab findings with trends
   - Abnormal values and their clinical context
4. **Medications & Treatment Plans**:
   - Current and past medications
   - Dosages, frequencies, and treatment duration
   - Treatment response and adjustments
5. **Clinical Timeline**: 
   - Comprehensive chronological medical events
   - Disease progression and treatment milestones
6. **Healthcare Team & Facilities**:
   - Involved healthcare providers
   - Hospitals and clinics visited
7. **Health Status Assessment**:
   - Current health status based on all available data
   - Risk factors and potential concerns
8. **Integrated Recommendations**:
   - Care coordination suggestions
   - Monitoring and follow-up recommendations

Integrate information from ALL document types for a complete picture.
Mark new findings with "**NEW:**" if updating existing summary.
`;

        const result = await model.generateContent(comprehensiveSummaryPrompt);
        const summary = result.response.text();

        // Update analyzed documents list
        const updatedAnalyzedDocuments = [...new Set([
          ...analyzedDocumentIds,
          ...newDocumentAnalyses.map(doc => doc.documentId)
        ])];

        // Store comprehensive analysis
        await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("comprehensive")
            .set({
              summary: summary,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              documentCount: allDocuments.length,
              analyzedDocuments: updatedAnalyzedDocuments,
              analysisType: 'comprehensive',
              documentCategories: {
                labReports: documentsByCategory.labReports.length,
                prescriptions: documentsByCategory.prescriptions.length,
                doctorNotes: documentsByCategory.doctorNotes.length,
                other: documentsByCategory.other.length
              },
              lastAnalysisType: forceReanalysis ? 'full_reanalysis' : 
                               (existingAnalysis ? 'incremental_update' : 'initial_analysis')
            });

        return {
          summary: summary,
          documentsAnalyzed: allDocuments.length,
          newDocumentsAnalyzed: newDocumentAnalyses.length,
          lastUpdated: new Date().toISOString(),
          isCached: false,
          analysisType: 'comprehensive',
          categoryBreakdown: {
            labReports: documentsByCategory.labReports.length,
            prescriptions: documentsByCategory.prescriptions.length,
            doctorNotes: documentsByCategory.doctorNotes.length,
            other: documentsByCategory.other.length
          }
        };

      } catch (error) {
        console.error("Error analyzing all medical records:", error);
        throw new HttpsError("internal", "Failed to analyze medical records", error.message);
      }
    }
);

/**
 * Debug function to test Cloud Functions connectivity
 */
exports.debugFunction = onCall(
  {cors: true},
  async (request) => {
    const {auth} = request;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    return {
      message: "Debug function working correctly",
      timestamp: new Date().toISOString(),
      userId: auth.uid,
      geminiApiKey: process.env.GEMINI_API_KEY ? "Present" : "Missing"
    };
  }
);

/**
 * Classify medical documents using Gemini AI
 */
exports.classifyMedicalDocument = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== CLASSIFY MEDICAL DOCUMENT ===');
      console.log('Auth UID:', auth?.uid);
      console.log('Data:', data);

      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const {fileName, storagePath} = data;
      
      if (!fileName || !storagePath) {
        throw new HttpsError("invalid-argument", "fileName and storagePath are required");
      }

      try {
        const geminiApiKey = process.env.GEMINI_API_KEY;
        if (!geminiApiKey) {
          console.warn('⚠️ Gemini API key not configured, using filename-based classification');
          return classifyByFilename(fileName);
        }

        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
        const bucket = admin.storage().bucket();

        // Check if file exists and is an image
        const file = bucket.file(storagePath);
        const [exists] = await file.exists();
        
        if (!exists) {
          console.error(`❌ File not found: ${storagePath}`);
          return classifyByFilename(fileName);
        }

        // Check if it's an image file for AI analysis
        const isImage = /\.(jpg|jpeg|png|gif|bmp|webp)$/i.test(fileName);
        
        if (!isImage) {
          console.log(`📄 Non-image file, using filename classification: ${fileName}`);
          return classifyByFilename(fileName);
        }

        // Download and analyze the image
        const [fileBuffer] = await file.download();
        const base64Data = fileBuffer.toString('base64');
        
        let mimeType = 'image/jpeg';
        if (fileName.toLowerCase().endsWith('.png')) mimeType = 'image/png';
        else if (fileName.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';
        else if (fileName.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';

        const classificationPrompt = `
Analyze this medical document image and classify it into one of these categories:
- lab_reports: Laboratory test results, blood work, pathology reports
- prescriptions: Medication prescriptions, pharmacy receipts
- doctor_notes: Doctor consultation notes, clinical observations, medical certificates
- other: Insurance documents, appointment cards, general medical documents

Return ONLY a JSON object with this exact structure:
{
  "category": "one of: lab_reports, prescriptions, doctor_notes, other",
  "confidence": 0.0-1.0,
  "suggestedSubfolder": "descriptive folder name",
  "reasoning": "brief explanation of classification"
}

Focus on identifying:
1. Lab values, test results, reference ranges → lab_reports
2. Drug names, dosages, pharmacy stamps → prescriptions  
3. Doctor signatures, clinical notes, diagnoses → doctor_notes
4. Insurance info, appointment details → other
`;

        const result = await model.generateContent([
          classificationPrompt,
          {
            inlineData: {
              data: base64Data,
              mimeType: mimeType
            }
          }
        ]);

        const response = result.response.text();
        console.log('🤖 Gemini classification response:', response);

        // Try to parse the JSON response
        try {
          const classification = JSON.parse(response);
          
          // Validate the response structure
          if (classification.category && typeof classification.confidence === 'number') {
            return {
              category: classification.category,
              confidence: Math.max(0, Math.min(1, classification.confidence)),
              suggestedSubfolder: classification.suggestedSubfolder || getDefaultSubfolder(classification.category),
              reasoning: classification.reasoning || 'AI classification'
            };
          }
        } catch (parseError) {
          console.error('❌ Failed to parse Gemini response as JSON:', parseError);
        }

        // Fallback to filename classification if AI fails
        console.log('⚠️ AI classification failed, falling back to filename analysis');
        return classifyByFilename(fileName);

      } catch (error) {
        console.error('❌ Error in document classification:', error);
        
        // Fallback to filename classification
        return classifyByFilename(fileName);
      }
    }
);

/**
 * Classify document based on filename when AI is not available
 */
function classifyByFilename(fileName) {
  const nameLower = fileName.toLowerCase();
  
  let category = 'other';
  let confidence = 0.3; // Lower confidence for filename-based classification
  let suggestedSubfolder = 'general';
  let reasoning = 'Filename-based classification';

  if (nameLower.includes('lab') || nameLower.includes('test') || nameLower.includes('blood') || 
      nameLower.includes('report') || nameLower.includes('result')) {
    category = 'lab_reports';
    suggestedSubfolder = 'lab_tests';
    confidence = 0.6;
    reasoning = 'Filename suggests lab report';
  } else if (nameLower.includes('prescription') || nameLower.includes('medicine') || 
             nameLower.includes('drug') || nameLower.includes('pharmacy') || nameLower.includes('rx')) {
    category = 'prescriptions';
    suggestedSubfolder = 'medications';
    confidence = 0.6;
    reasoning = 'Filename suggests prescription';
  } else if (nameLower.includes('doctor') || nameLower.includes('consultation') || 
             nameLower.includes('visit') || nameLower.includes('note') || nameLower.includes('clinical')) {
    category = 'doctor_notes';
    suggestedSubfolder = 'consultations';
    confidence = 0.6;
    reasoning = 'Filename suggests doctor note';
  }

  return {
    category,
    confidence,
    suggestedSubfolder,
    reasoning
  };
}

/**
 * Get default subfolder for a category
 */
function getDefaultSubfolder(category) {
  switch (category) {
    case 'lab_reports': return 'lab_tests';
    case 'prescriptions': return 'medications';
    case 'doctor_notes': return 'consultations';
    default: return 'general';
  }
}

/**
 * Helper function to analyze documents with Gemini Vision
 */
async function analyzeDocuments(documents, model, analysisType) {
  const documentAnalyses = [];
  const bucket = admin.storage().bucket();

  for (const docInfo of documents) {
    const fileName = docInfo.fileName;
    const storagePath = docInfo.storagePath;
    
    console.log(`🔍 Analyzing document: ${fileName} (${docInfo.category})`);

    try {
      // Check if it's an image file
      const isImage = /\.(jpg|jpeg|png|gif|bmp|webp)$/i.test(fileName);
      
      if (!isImage) {
        documentAnalyses.push({
          documentId: docInfo.id,
          fileName: fileName,
          uploadDate: docInfo.uploadDate.toDate ? docInfo.uploadDate.toDate().toLocaleDateString() : new Date(docInfo.uploadDate.seconds * 1000).toLocaleDateString(),
          category: docInfo.category,
          analysis: `Document type not supported for text extraction: ${fileName}. Only image files can be analyzed.`
        });
        continue;
      }

      if (!storagePath) {
        documentAnalyses.push({
          documentId: docInfo.id,
          fileName: fileName,
          uploadDate: docInfo.uploadDate.toDate ? docInfo.uploadDate.toDate().toLocaleDateString() : new Date(docInfo.uploadDate.seconds * 1000).toLocaleDateString(),
          category: docInfo.category,
          analysis: `Error: Storage path not found for document ${fileName}.`
        });
        continue;
      }

      // Download and analyze
      const file = bucket.file(storagePath);
      const [fileBuffer] = await file.download();
      const base64Data = fileBuffer.toString('base64');
      
      let mimeType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      else if (fileName.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';
      else if (fileName.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';

      // Create category-specific prompt
      const visionPrompt = createCategorySpecificPrompt(docInfo.category, analysisType);

      const visionResult = await model.generateContent([
        visionPrompt,
        {
          inlineData: {
            data: base64Data,
            mimeType: mimeType
          }
        }
      ]);

      const analysis = visionResult.response.text();
      
      documentAnalyses.push({
        documentId: docInfo.id,
        fileName: fileName,
        uploadDate: docInfo.uploadDate.toDate ? docInfo.uploadDate.toDate().toLocaleDateString() : new Date(docInfo.uploadDate.seconds * 1000).toLocaleDateString(),
        category: docInfo.category,
        analysis: analysis
      });

      console.log(`✅ Successfully analyzed: ${fileName}`);

    } catch (error) {
      console.error(`❌ Error analyzing ${fileName}:`, error);
      documentAnalyses.push({
        documentId: docInfo.id,
        fileName: fileName,
        uploadDate: docInfo.uploadDate.toDate ? docInfo.uploadDate.toDate().toLocaleDateString() : new Date(docInfo.uploadDate.seconds * 1000).toLocaleDateString(),
        category: docInfo.category,
        analysis: `Error extracting text: ${error.message}`
      });
    }
  }

  return documentAnalyses;
}

/**
 * Create category-specific analysis prompts
 */
function createCategorySpecificPrompt(category, analysisType) {
  const basePrompt = `
Please analyze this medical document and extract ALL visible information with extreme precision.
ACT AS A MEDICAL EXPERT and provide detailed, accurate analysis.
`;

  if (analysisType === 'lab_reports' || category?.toLowerCase().includes('lab')) {
    return basePrompt + `
This is a LABORATORY REPORT. Focus on:

1. **Test Names**: All laboratory tests performed
2. **Test Values**: Exact numerical results with units
3. **Reference Ranges**: Normal ranges for each test
4. **Abnormal Indicators**: HIGH/LOW flags or out-of-range values
5. **Test Date**: When tests were performed
6. **Laboratory Information**: Lab name, location, ordering physician
7. **Sample Information**: Blood, urine, etc. collection details
8. **Critical Values**: Any critical or panic values
9. **Test Categories**: Chemistry, hematology, microbiology, etc.
10. **Clinical Notes**: Any lab comments or interpretations

Extract ALL numerical values, units, and reference ranges exactly as shown.
Format results clearly with test name, value, unit, and reference range.
Mark abnormal results clearly with HIGH/LOW indicators.
`;
  }

  if (category?.toLowerCase().includes('prescription')) {
    return basePrompt + `
This is a PRESCRIPTION document. Focus on:

1. **Medication Names**: All prescribed drugs (generic and brand names)
2. **Dosages**: Exact dosage amounts and units (mg, ml, etc.)
3. **Frequency**: How often to take (daily, BID, TID, QID, PRN)
4. **Duration**: Length of treatment
5. **Instructions**: Special administration instructions
6. **Prescriber Information**: Doctor name, credentials, contact
7. **Pharmacy Information**: Pharmacy details
8. **Prescription Date**: When prescribed
9. **Refills**: Number of refills allowed
10. **Medical Conditions**: Conditions being treated

Extract exact medication names, dosages, and administration instructions.
Include all prescription details for medication management.
`;
  }

  if (category?.toLowerCase().includes('doctor') || category?.toLowerCase().includes('note')) {
    return basePrompt + `
This is a DOCTOR'S NOTE or CLINICAL DOCUMENT. Focus on:

1. **Chief Complaint**: Primary reason for visit
2. **Medical History**: Relevant past medical history
3. **Physical Examination**: Examination findings
4. **Vital Signs**: BP, HR, temperature, weight, etc.
5. **Diagnoses**: Primary and secondary diagnoses
6. **Treatment Plan**: Recommended treatments
7. **Medications**: Prescribed or adjusted medications
8. **Follow-up**: Next appointment or monitoring instructions
9. **Healthcare Provider**: Doctor/specialist information
10. **Clinical Assessment**: Professional medical opinion

Extract all clinical observations, diagnoses, and treatment recommendations.
Include exact vital signs and examination findings.
`;
  }

  // Default comprehensive prompt
  return basePrompt + `
Extract ALL medical information including:

1. **Document Type**: Lab report, prescription, notes, etc.
2. **Medical Data**: All numerical values, test results, vital signs
3. **Medications**: Any drugs, dosages, frequencies mentioned
4. **Diagnoses**: Medical conditions or health issues
5. **Dates**: All dates mentioned in the document
6. **Healthcare Providers**: Doctor names, facilities
7. **Instructions**: Any medical advice or instructions
8. **Reference Values**: Normal ranges where provided

Be thorough and extract every piece of medical information visible.
Include specific values, units, and reference ranges.
`;
}

/**
 * Group documents by category for organized analysis
 */
function groupDocumentsByCategory(documentAnalyses) {
  const categories = {
    labReports: [],
    prescriptions: [],
    doctorNotes: [],
    other: []
  };

  documentAnalyses.forEach(doc => {
    const category = doc.category?.toLowerCase() || '';
    
    if (category.includes('lab') || category.includes('test')) {
      categories.labReports.push(doc);
    } else if (category.includes('prescription') || category.includes('medication')) {
      categories.prescriptions.push(doc);
    } else if (category.includes('doctor') || category.includes('note') || category.includes('consultation')) {
      categories.doctorNotes.push(doc);
    } else {
      categories.other.push(doc);
    }
  });

  return categories;
}

/**
 * Classify document based on filename when AI is not available
 */
function classifyByFilename(fileName) {
  const nameLower = fileName.toLowerCase();
  
  let category = 'other';
  let confidence = 0.3; // Lower confidence for filename-based classification
  let suggestedSubfolder = 'general';
  let reasoning = 'Filename-based classification';

  if (nameLower.includes('lab') || nameLower.includes('test') || nameLower.includes('blood') || 
      nameLower.includes('report') || nameLower.includes('result')) {
    category = 'lab_reports';
    suggestedSubfolder = 'lab_tests';
    confidence = 0.6;
    reasoning = 'Filename suggests lab report';
  } else if (nameLower.includes('prescription') || nameLower.includes('medicine') || 
             nameLower.includes('drug') || nameLower.includes('pharmacy') || nameLower.includes('rx')) {
    category = 'prescriptions';
    suggestedSubfolder = 'medications';
    confidence = 0.6;
    reasoning = 'Filename suggests prescription';
  } else if (nameLower.includes('doctor') || nameLower.includes('consultation') || 
             nameLower.includes('visit') || nameLower.includes('note') || nameLower.includes('clinical')) {
    category = 'doctor_notes';
    suggestedSubfolder = 'consultations';
    confidence = 0.6;
    reasoning = 'Filename suggests doctor note';
  }

  return {
    category,
    confidence,
    suggestedSubfolder,
    reasoning
  };
}

/**
 * Get default subfolder for a category
 */
function getDefaultSubfolder(category) {
  switch (category) {
    case 'lab_reports': return 'lab_tests';
    case 'prescriptions': return 'medications';
    case 'doctor_notes': return 'consultations';
    default: return 'general';
  }
}
