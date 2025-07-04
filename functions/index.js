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
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");

// Define secrets
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// Set global options
setGlobalOptions({region: "us-central1"}); // Change to your preferred region

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Debug function to test Cloud Functions connectivity
 */
exports.debugFunction = onCall(
  {cors: true, secrets: [geminiApiKey]},
  async (request) => {
    const {auth} = request;
    
    if (!auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }
    
    return {
      message: "Debug function working correctly",
      timestamp: new Date().toISOString(),
      userId: auth.uid,
      geminiApiKey: geminiApiKey.value() ? "Present" : "Missing"
    };
  }
);

/**
 * Classify medical documents using Gemini AI
 */
exports.classifyMedicalDocument = onCall(
    {cors: true, secrets: [geminiApiKey]},
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
        const apiKey = geminiApiKey.value();
        if (!apiKey) {
          console.warn('⚠️ Gemini API key not configured, using filename-based classification');
          const fallbackResult = intelligentClassifyByFilename(fileName);
          
          // Even without API key, if classified as lab report, store basic info
          if (fallbackResult.category === 'lab_reports' && auth?.uid) {
            try {
              await storeBasicLabReportInfo(auth.uid, fileName, storagePath);
            } catch (storeError) {
              console.error('❌ Failed to store basic lab report info:', storeError);
            }
          }
          
          return fallbackResult;
        }

        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
        const bucket = admin.storage().bucket();

        // Check if file exists and is an image
        const file = bucket.file(storagePath);
        const [exists] = await file.exists();
        
        if (!exists) {
          console.error(`❌ File not found: ${storagePath}`);
          return intelligentClassifyByFilename(fileName);
        }

        // Check if it's an image file for AI analysis
        const isImage = /\.(jpg|jpeg|png|gif|bmp|webp)$/i.test(fileName);
        
        if (!isImage) {
          console.log(`📄 Non-image file, using filename classification: ${fileName}`);
          return intelligentClassifyByFilename(fileName);
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
            const result = {
              category: classification.category,
              confidence: Math.max(0, Math.min(1, classification.confidence)),
              suggestedSubfolder: classification.suggestedSubfolder || getDefaultSubfolder(classification.category),
              reasoning: classification.reasoning || 'AI classification'
            };

            // If classified as lab report, extract text content
            if (classification.category === 'lab_reports' && auth?.uid) {
              try {
                await extractLabReportContent(auth.uid, fileName, storagePath, base64Data, mimeType, model, null);
              } catch (extractError) {
                console.error('❌ Failed to extract lab report content:', extractError);
                // Don't fail the classification if extraction fails
              }
            }

            return result;
          }
        } catch (parseError) {
          console.error('❌ Failed to parse Gemini response as JSON:', parseError);
        }

        // Fallback to filename classification if AI fails
        console.log('⚠️ AI classification failed, falling back to filename analysis');
        const fallbackResult = intelligentClassifyByFilename(fileName);
        
        // If fallback classifies as lab report and we have image data, try to extract content
        if (fallbackResult.category === 'lab_reports' && auth?.uid && base64Data && mimeType) {
          try {
            const genAI = new GoogleGenerativeAI(apiKey);
            const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
            await extractLabReportContent(auth.uid, fileName, storagePath, base64Data, mimeType, model);
          } catch (extractError) {
            console.error('❌ Failed to extract lab report content in fallback:', extractError);
          }
        }
        
        return fallbackResult;

      } catch (error) {
        console.error('❌ Error in document classification:', error);
        
        // Fallback to filename classification
        return intelligentClassifyByFilename(fileName);
      }
    }
);

/**
 * Analyze ONLY lab reports using Gemini AI
 */
exports.analyzeLabReports = onCall(
    {cors: true, secrets: [geminiApiKey]},
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
        const apiKey = geminiApiKey.value();
        if (!apiKey) {
          throw new HttpsError("failed-precondition", "API key not configured");
        }

        const genAI = new GoogleGenerativeAI(apiKey);
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
        console.log('🔍 Querying for lab reports...');
        
        // DEBUG: Check multiple possible document locations
        console.log('🔍 Checking different possible document locations...');
        
        // Check users/{userId}/documents
        const userDocsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .get();
        console.log(`📄 users/${userId}/documents: ${userDocsSnapshot.size} documents`);
        
        // Check users/{userId}/medical_records  
        const userMedicalSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("medical_records")
            .get();
        console.log(`📄 users/${userId}/medical_records: ${userMedicalSnapshot.size} documents`);
        
        // Check medical_records/{userId}/documents
        const medicalDocsSnapshot = await db
            .collection("medical_records")
            .doc(userId)
            .collection("documents")
            .get();
        console.log(`📄 medical_records/${userId}/documents: ${medicalDocsSnapshot.size} documents`);
        
        // First check if any documents exist at all
        const allDocsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .get();
            
        console.log(`📊 Total documents found: ${allDocsSnapshot.size}`);
        
        if (!allDocsSnapshot.empty) {
          allDocsSnapshot.forEach((doc) => {
            const data = doc.data();
            console.log(`📄 Document: ${doc.id}, category: ${data.category}, fileName: ${data.fileName}`);
          });
        }
        
        // TEMP: Remove the where clause to avoid index error
        const documentsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .get();
        
        // Filter lab reports in memory for now
        const labReportDocs = [];
        documentsSnapshot.forEach((doc) => {
          const data = doc.data();
          const category = data.category || '';
          if (category.toLowerCase().includes('lab') || 
              category.toLowerCase().includes('report') ||
              category === 'lab_reports') {
            labReportDocs.push({id: doc.id, data});
          }
        });

        console.log(`🧪 Lab reports found: ${labReportDocs.length}`);

        if (labReportDocs.length === 0) {
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

        for (const labDoc of labReportDocs) {
          const docData = labDoc.data;
          const docInfo = {
            id: labDoc.id,
            fileName: docData.fileName,
            storagePath: docData.filePath, // Updated field name
            downloadUrl: docData.downloadUrl,
            uploadDate: docData.uploadDate,
            category: docData.category,
            ...docData
          };
          
          allLabReports.push(docInfo);
          
          const wasAnalyzed = analyzedDocumentIds.includes(labDoc.id);
          if (forceReanalysis || !wasAnalyzed) {
            newLabReports.push(docInfo);
          }
        }

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
    {cors: true, secrets: [geminiApiKey]},
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
        const apiKey = geminiApiKey.value();
        if (!apiKey) {
          throw new HttpsError("failed-precondition", "API key not configured");
        }

        const genAI = new GoogleGenerativeAI(apiKey);
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
        console.log('🔍 Querying for all medical documents...');
        
        // DEBUG: Check multiple possible document locations
        console.log('🔍 Checking different possible document locations...');
        
        // Check users/{userId}/documents
        const userDocsSnapshot2 = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .get();
        console.log(`📄 users/${userId}/documents: ${userDocsSnapshot2.size} documents`);
        
        // Check users/{userId}/medical_records  
        const userMedicalSnapshot2 = await db
            .collection("users")
            .doc(userId)
            .collection("medical_records")
            .get();
        console.log(`📄 users/${userId}/medical_records: ${userMedicalSnapshot2.size} documents`);
        
        const documentsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .get();

        console.log(`📊 Total medical documents found: ${documentsSnapshot.size}`);

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
 * Extract text content from lab reports using Gemini OCR
 */
async function extractLabReportContent(userId, fileName, storagePath, base64Data, mimeType, model, userSelectedType = null) {
  console.log(`🔬 Extracting lab report content for: ${fileName}`);
  
  try {
    const extractionPrompt = `
Analyze this lab report image and extract ALL text content with extreme precision.
Focus on extracting:

1. **Test Names**: All laboratory tests performed
2. **Test Values**: Exact numerical results with units
3. **Reference Ranges**: Normal ranges for each test
4. **Patient Information**: Name, ID, demographics if visible
5. **Date Information**: Test date, collection date, report date
6. **Laboratory Information**: Lab name, ordering physician
7. **Clinical Notes**: Any comments or interpretations

${userSelectedType ? `
The user has indicated this is a "${userSelectedType}" lab report. Please classify accordingly.
` : `
Based on the tests present, classify this lab report type as one of:
- blood_sugar (glucose, diabetes-related tests)
- cholesterol (lipid panel, triglycerides)
- liver_function (ALT, AST, bilirubin)
- kidney_function (creatinine, BUN, GFR)
- thyroid_function (TSH, T3, T4)
- complete_blood_count (CBC, hemoglobin, platelets)
- cardiac_markers (troponin, CK-MB)
- vitamin_levels (B12, D, folate)
- inflammatory_markers (ESR, CRP)
- other_lab_tests (any other type)
`}

Return a JSON object with this structure:
{
  "lab_report_type": "${userSelectedType || 'auto-detected type'}",
  "extracted_text": "complete text content extracted from the image",
  "test_results": [
    {
      "test_name": "test name",
      "value": "result value",
      "unit": "unit of measurement",
      "reference_range": "normal range",
      "status": "normal/high/low"
    }
  ],
  "test_date": "date when tests were performed",
  "patient_info": {
    "name": "patient name if visible",
    "id": "patient ID if visible"
  },
  "lab_info": {
    "name": "laboratory name",
    "ordering_physician": "doctor name if visible"
  }
}

Extract ALL visible text and be extremely thorough.
`;

    const result = await model.generateContent([
      extractionPrompt,
      {
        inlineData: {
          data: base64Data,
          mimeType: mimeType
        }
      }
    ]);

    const response = result.response.text();
    console.log('🤖 Gemini extraction response:', response);

    let extractedData;
    try {
      extractedData = JSON.parse(response);
    } catch (parseError) {
      console.error('❌ Failed to parse extraction response as JSON:', parseError);
      // Fallback to storing raw text
      extractedData = {
        lab_report_type: userSelectedType || 'other_lab_tests',
        extracted_text: response,
        test_results: [],
        test_date: null,
        patient_info: {},
        lab_info: {}
      };
    }

    // Use user-selected type if provided, otherwise use AI-detected type
    const finalLabReportType = userSelectedType || extractedData.lab_report_type || 'other_lab_tests';

    // Store in Firestore
    const db = admin.firestore();
    const labReportContentRef = db
      .collection('users')
      .doc(userId)
      .collection('lab_report_content')
      .doc(); // Auto-generate document ID

    const labReportData = {
      fileName: fileName,
      storagePath: storagePath,
      labReportType: finalLabReportType,
      extractedText: extractedData.extracted_text || '',
      testResults: extractedData.test_results || [],
      testDate: extractedData.test_date || null,
      patientInfo: extractedData.patient_info || {},
      labInfo: extractedData.lab_info || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      extractionMethod: 'gemini_ocr',
      userSelectedType: userSelectedType ? true : false
    };

    await labReportContentRef.set(labReportData);
    
    console.log(`✅ Lab report content extracted and stored: ${labReportContentRef.id}`);
    return labReportContentRef.id;

  } catch (error) {
    console.error('❌ Error extracting lab report content:', error);
    throw error;
  }
}

/**
 * Store basic lab report info when API key is not available
 */
async function storeBasicLabReportInfo(userId, fileName, storagePath) {
  console.log(`📄 Storing basic lab report info for: ${fileName}`);
  
  try {
    const db = admin.firestore();
    const labReportContentRef = db
      .collection('users')
      .doc(userId)
      .collection('lab_report_content')
      .doc();

    const basicLabReportData = {
      fileName: fileName,
      storagePath: storagePath,
      labReportType: 'other_lab_tests', // Default type when can't analyze
      extractedText: 'Content extraction requires API key configuration',
      testResults: [],
      testDate: null,
      patientInfo: {},
      labInfo: {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      extractionMethod: 'basic_info_only'
    };

    await labReportContentRef.set(basicLabReportData);
    
    console.log(`✅ Basic lab report info stored: ${labReportContentRef.id}`);
    return labReportContentRef.id;

  } catch (error) {
    console.error('❌ Error storing basic lab report info:', error);
    throw error;
  }
}

/**
 * Store basic lab report info with user-selected type when API key is not available
 */
async function storeBasicLabReportInfoWithType(userId, fileName, storagePath, selectedType) {
  console.log(`📄 Storing basic lab report info with type ${selectedType} for: ${fileName}`);
  
  try {
    const db = admin.firestore();
    const labReportContentRef = db
      .collection('users')
      .doc(userId)
      .collection('lab_report_content')
      .doc();

    const basicLabReportData = {
      fileName: fileName,
      storagePath: storagePath,
      labReportType: selectedType,
      extractedText: 'Content extraction requires API key configuration',
      testResults: [],
      testDate: null,
      patientInfo: {},
      labInfo: {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      extractionMethod: 'basic_info_only',
      userSelectedType: true
    };

    await labReportContentRef.set(basicLabReportData);
    
    console.log(`✅ Basic lab report info with type stored: ${labReportContentRef.id}`);
    return labReportContentRef.id;

  } catch (error) {
    console.error('❌ Error storing basic lab report info with type:', error);
    throw error;
  }
}

/**
 * Intelligent fallback classification with enhanced medical keyword analysis
 */
function intelligentClassifyByFilename(fileName) {
  console.log(`🎯 Using intelligent classification for: ${fileName}`);
  
  const nameLower = fileName.toLowerCase();
  const fileExtension = fileName.split('.').pop().toLowerCase();
  
  // Enhanced filename analysis with comprehensive medical keywords
  const medicalKeywords = {
    lab_reports: [
      'lab', 'test', 'blood', 'report', 'result', 'analysis', 'pathology',
      'biopsy', 'culture', 'panel', 'screening', 'assay', 'chemistry',
      'hematology', 'urinalysis', 'microbiology', 'serology', 'toxicology',
      'glucose', 'cholesterol', 'hemoglobin', 'platelet', 'white', 'red', 'cell',
      'cbc', 'comprehensive', 'metabolic', 'lipid', 'liver', 'kidney', 'thyroid'
    ],
    prescriptions: [
      'prescription', 'medicine', 'drug', 'pharmacy', 'rx', 'medication',
      'pills', 'tablet', 'capsule', 'dosage', 'mg', 'ml', 'dose',
      'antibiotic', 'insulin', 'aspirin', 'ibuprofen', 'acetaminophen',
      'prescribed', 'refill', 'generic', 'brand', 'cvs', 'walgreens', 'rite aid'
    ],
    doctor_notes: [
      'doctor', 'consultation', 'visit', 'note', 'clinical', 'medical',
      'diagnosis', 'treatment', 'examination', 'assessment', 'history',
      'symptoms', 'patient', 'hospital', 'clinic', 'physician', 'nurse',
      'discharge', 'admission', 'follow-up', 'referral', 'progress', 'summary'
    ]
  };
  
  // Calculate keyword scores for each category
  const scores = {};
  let maxScore = 0;
  let bestCategory = 'other';
  
  for (const [category, keywords] of Object.entries(medicalKeywords)) {
    scores[category] = 0;
    
    keywords.forEach(keyword => {
      if (nameLower.includes(keyword)) {
        // Give higher weight to longer medical terms
        const weight = keyword.length > 4 ? 2 : 1;
        scores[category] += weight;
      }
    });
    
    if (scores[category] > maxScore) {
      maxScore = scores[category];
      bestCategory = category;
    }
  }
  
  // File extension-based intelligent defaults
  let extensionHint = '';
  let extensionConfidenceBoost = 0;
  
  switch (fileExtension) {
    case 'pdf':
      extensionHint = 'PDF document - analyzing for medical content';
      extensionConfidenceBoost = 0.1;
      // If no keywords found, make educated guess based on common patterns
      if (bestCategory === 'other' && maxScore === 0) {
        bestCategory = 'doctor_notes'; // PDFs are often clinical documents
        maxScore = 1;
      }
      break;
    case 'jpg':
    case 'jpeg':
    case 'png':
      extensionHint = 'Image file - likely scanned medical document';
      extensionConfidenceBoost = 0.15;
      // Images are often lab results or scanned reports
      if (bestCategory === 'other' && maxScore === 0) {
        bestCategory = 'lab_reports';
        maxScore = 1;
      }
      break;
    case 'doc':
    case 'docx':
      extensionHint = 'Word document - likely clinical notes or reports';
      extensionConfidenceBoost = 0.1;
      if (bestCategory === 'other' && maxScore === 0) {
        bestCategory = 'doctor_notes';
        maxScore = 1;
      }
      break;
  }
  
  // Calculate confidence based on keyword matches and file type
  let confidence = Math.min(0.8, (maxScore * 0.12) + extensionConfidenceBoost);
  
  // Ensure reasonable confidence for all medical files
  if (confidence < 0.25) {
    confidence = 0.25;
  }
  
  // Create detailed reasoning
  let reasoning = '';
  if (maxScore > 0) {
    reasoning = `Intelligent analysis: Found ${maxScore} medical keywords suggesting ${bestCategory}.`;
  } else {
    reasoning = `Smart fallback: No clear keywords found, classified as ${bestCategory} based on file type patterns.`;
  }
  reasoning += ` ${extensionHint}`;
  
  console.log(`📊 Classification result: ${bestCategory} (confidence: ${confidence.toFixed(2)}, score: ${maxScore})`);
  
  return {
    category: bestCategory,
    confidence: confidence,
    suggestedSubfolder: getDefaultSubfolder(bestCategory),
    reasoning: reasoning
  };
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
 * Get lab report content for a user
 */
exports.getLabReportContent = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== GET LAB REPORT CONTENT ===');
      console.log('Auth UID:', auth?.uid);

      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const userId = auth.uid;
      const { labReportType, limit = 50 } = data || {};
      
      try {
        const db = admin.firestore();
        
        let query = db
          .collection('users')
          .doc(userId)
          .collection('lab_report_content')
          .orderBy('createdAt', 'desc')
          .limit(limit);

        // Filter by lab report type if specified
        if (labReportType && labReportType !== 'all') {
          query = query.where('labReportType', '==', labReportType);
        }

        const snapshot = await query.get();
        
        const labReports = [];
        snapshot.forEach(doc => {
          const data = doc.data();
          labReports.push({
            id: doc.id,
            fileName: data.fileName,
            labReportType: data.labReportType,
            extractedText: data.extractedText,
            testResults: data.testResults || [],
            testDate: data.testDate,
            patientInfo: data.patientInfo || {},
            labInfo: data.labInfo || {},
            createdAt: data.createdAt?.toDate?.()?.toISOString() || null,
            extractionMethod: data.extractionMethod
          });
        });

        // Group by lab report type for summary
        const reportsByType = {};
        labReports.forEach(report => {
          const type = report.labReportType;
          if (!reportsByType[type]) {
            reportsByType[type] = [];
          }
          reportsByType[type].push(report);
        });

        return {
          labReports: labReports,
          totalCount: labReports.length,
          reportsByType: reportsByType,
          availableTypes: Object.keys(reportsByType)
        };

      } catch (error) {
        console.error("Error getting lab report content:", error);
        throw new HttpsError("internal", "Failed to get lab report content", error.message);
      }
    }
);

/**
 * Update lab report content with user-selected type
 */
exports.updateLabReportType = onCall(
    {cors: true, secrets: [geminiApiKey]},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== UPDATE LAB REPORT TYPE ===');
      console.log('Auth UID:', auth?.uid);

      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      const {fileName, storagePath, selectedType} = data;
      
      if (!fileName || !storagePath || !selectedType) {
        throw new HttpsError("invalid-argument", "fileName, storagePath, and selectedType are required");
      }

      const userId = auth.uid;

      try {
        const apiKey = geminiApiKey.value();
        if (!apiKey) {
          // Store basic info with user-selected type
          await storeBasicLabReportInfoWithType(userId, fileName, storagePath, selectedType);
          return { success: true, message: "Basic lab report info stored with selected type" };
        }

        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
        const bucket = admin.storage().bucket();

        // Check if file exists and is an image
        const file = bucket.file(storagePath);
        const [exists] = await file.exists();
        
        if (!exists) {
          console.error(`❌ File not found: ${storagePath}`);
          await storeBasicLabReportInfoWithType(userId, fileName, storagePath, selectedType);
          return { success: true, message: "File not found, stored basic info" };
        }

        // Check if it's an image file for AI analysis
        const isImage = /\.(jpg|jpeg|png|gif|bmp|webp)$/i.test(fileName);
        
        if (!isImage) {
          console.log(`📄 Non-image file, storing basic info: ${fileName}`);
          await storeBasicLabReportInfoWithType(userId, fileName, storagePath, selectedType);
          return { success: true, message: "Non-image file, stored basic info" };
        }

        // Download and analyze the image
        const [fileBuffer] = await file.download();
        const base64Data = fileBuffer.toString('base64');
        
        let mimeType = 'image/jpeg';
        if (fileName.toLowerCase().endsWith('.png')) mimeType = 'image/png';
        else if (fileName.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';
        else if (fileName.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';

        // Extract content with user-selected type
        await extractLabReportContent(userId, fileName, storagePath, base64Data, mimeType, model, selectedType);
        
        return { success: true, message: "Lab report content extracted with selected type" };

      } catch (error) {
        console.error('❌ Error updating lab report type:', error);
        throw new HttpsError("internal", "Failed to update lab report type", error.message);
      }
    }
);
