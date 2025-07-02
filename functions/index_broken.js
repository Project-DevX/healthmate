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

// Updated to use Gemini 2.5 Flash-Lite Preview for better performance

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
      geminiApiKey: functions.config().gemini?.api_key ? "Present" : "Missing"
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
        const geminiApiKey = functions.config().gemini?.api_key;
        if (!geminiApiKey) {
          console.warn('⚠️ Gemini API key not configured, using filename-based classification');
          return classifyByFilename(fileName);
        }

        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash-lite-preview-0617"});
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
Analyze this medical document image carefully and classify it into one of these categories:
- lab_reports: Laboratory test results, blood work, pathology reports, diagnostic tests
- prescriptions: Medication prescriptions, pharmacy receipts, drug prescriptions
- doctor_notes: Doctor consultation notes, clinical observations, medical certificates, discharge summaries
- other: Insurance documents, appointment cards, medical bills, general medical documents

Look for these specific indicators:
1. Lab values, test results, reference ranges, laboratory letterheads → lab_reports
2. Drug names, dosages, pharmacy stamps, "Rx" symbols → prescriptions  
3. Doctor signatures, clinical notes, diagnoses, hospital letterheads → doctor_notes
4. Insurance info, billing, appointment details → other

Return ONLY a JSON object with this exact structure:
{
  "category": "one of: lab_reports, prescriptions, doctor_notes, other",
  "confidence": 0.0-1.0,
  "suggestedSubfolder": "descriptive folder name",
  "reasoning": "detailed explanation of classification based on visual content"
}

Be thorough in your analysis and avoid defaulting to "other" unless clearly appropriate.
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
        console.log('🤖 Gemini image classification response:', response);

        // Try to parse the JSON response
        try {
          const classification = JSON.parse(response);
          
          if (classification.category && typeof classification.confidence === 'number') {
            return {
              success: true,
              result: {
                category: classification.category,
                confidence: Math.max(0, Math.min(1, classification.confidence)),
                suggestedSubfolder: classification.suggestedSubfolder || getDefaultSubfolder(classification.category),
                reasoning: classification.reasoning || 'AI image classification'
              }
            };
          }
        } catch (parseError) {
          console.error('❌ Failed to parse image classification JSON:', parseError);
        }
    } else {
      // For non-image files, try to extract text content and analyze
      console.log(`📄 Attempting text-based analysis for: ${fileName}`);
      
      // Try to extract meaningful content for text-based classification
      const textClassification = await analyzeFileContent(file, fileName, model);
      if (textClassification.success) {
        return textClassification;
      }
    }
    
    return { success: false };
  } catch (error) {
    console.error('❌ Error in AI classification attempt:', error);
    return { success: false };
  }
}

/**
 * Analyze file content for text-based documents
 */
async function analyzeFileContent(file, fileName, model) {
  try {
    const fileExtension = fileName.split('.').pop().toLowerCase();
    
    // For PDF files, we can attempt to use Gemini's document understanding
    if (fileExtension === 'pdf') {
      console.log(`📋 Attempting PDF analysis for: ${fileName}`);
      
      const [fileBuffer] = await file.download();
      const base64Data = fileBuffer.toString('base64');
      
      const pdfPrompt = `
This is a PDF medical document. Analyze its content and classify it into one of these categories:
- lab_reports: Laboratory test results, blood work, pathology reports, diagnostic tests
- prescriptions: Medication prescriptions, pharmacy receipts, drug prescriptions  
- doctor_notes: Doctor consultation notes, clinical observations, medical certificates, discharge summaries
- other: Insurance documents, appointment cards, medical bills, general medical documents

Look for medical indicators and content patterns to make an accurate classification.
Avoid defaulting to "other" - analyze the content thoroughly.

Return ONLY a JSON object:
{
  "category": "one of: lab_reports, prescriptions, doctor_notes, other",
  "confidence": 0.0-1.0,
  "suggestedSubfolder": "descriptive folder name", 
  "reasoning": "detailed explanation based on document content"
}
`;

      const result = await model.generateContent([
        pdfPrompt,
        {
          inlineData: {
            data: base64Data,
            mimeType: 'application/pdf'
          }
        }
      ]);

      const response = result.response.text();
      console.log('🤖 PDF classification response:', response);

      try {
        const classification = JSON.parse(response);
        
        if (classification.category && typeof classification.confidence === 'number') {
          return {
            success: true,
            result: {
              category: classification.category,
              confidence: Math.max(0, Math.min(1, classification.confidence)),
              suggestedSubfolder: classification.suggestedSubfolder || getDefaultSubfolder(classification.category),
              reasoning: classification.reasoning || 'AI PDF content classification'
            }
          };
        }
      } catch (parseError) {
        console.error('❌ Failed to parse PDF classification JSON:', parseError);
      }
    }
    
    return { success: false };
  } catch (error) {
    console.error('❌ Error in file content analysis:', error);
    return { success: false };
  }
}

/**
 * Intelligent fallback classification when AI fails
 */
async function intelligentFallbackClassification(fileName) {
  console.log(`🎯 Using intelligent fallback classification for: ${fileName}`);
  
  const nameLower = fileName.toLowerCase();
  const fileExtension = fileName.split('.').pop().toLowerCase();
  
  // Enhanced filename analysis with medical keywords
  const medicalKeywords = {
    lab_reports: [
      'lab', 'test', 'blood', 'report', 'result', 'analysis', 'pathology',
      'biopsy', 'culture', 'panel', 'screening', 'assay', 'chemistry',
      'hematology', 'urinalysis', 'microbiology', 'serology', 'toxicology',
      'glucose', 'cholesterol', 'hemoglobin', 'platelet', 'white', 'red', 'cell'
    ],
    prescriptions: [
      'prescription', 'medicine', 'drug', 'pharmacy', 'rx', 'medication',
      'pills', 'tablet', 'capsule', 'dosage', 'mg', 'ml', 'dose',
      'antibiotic', 'insulin', 'aspirin', 'ibuprofen', 'acetaminophen',
      'prescribed', 'refill', 'generic', 'brand'
    ],
    doctor_notes: [
      'doctor', 'consultation', 'visit', 'note', 'clinical', 'medical',
      'diagnosis', 'treatment', 'examination', 'assessment', 'history',
      'symptoms', 'patient', 'hospital', 'clinic', 'physician', 'nurse',
      'discharge', 'admission', 'follow-up', 'referral', 'progress'
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
        // Give higher weight to exact matches and medical terms
        const weight = keyword.length > 4 ? 2 : 1;
        scores[category] += weight;
      }
    });
    
    if (scores[category] > maxScore) {
      maxScore = scores[category];
      bestCategory = category;
    }
  }
  
  // File extension-based hints
  let extensionHint = '';
  let extensionConfidenceBoost = 0;
  
  switch (fileExtension) {
    case 'pdf':
      extensionHint = 'PDF document - could be any medical document type';
      extensionConfidenceBoost = 0.1;
      break;
    case 'jpg':
    case 'jpeg':
    case 'png':
      extensionHint = 'Image file - likely scanned medical document';
      extensionConfidenceBoost = 0.1;
      break;
    case 'doc':
    case 'docx':
      extensionHint = 'Word document - likely clinical notes or reports';
      if (bestCategory === 'other' && maxScore === 0) {
        bestCategory = 'doctor_notes';
        maxScore = 1;
      }
      extensionConfidenceBoost = 0.1;
      break;
  }
  
  // Calculate confidence based on keyword matches
  let confidence = Math.min(0.8, (maxScore * 0.15) + extensionConfidenceBoost);
  
  // If no clear category is found but it's clearly a medical file, make educated guess
  if (bestCategory === 'other' && maxScore === 0) {
    // Use file extension and common patterns to make educated guesses
    if (fileExtension === 'pdf' || fileExtension.includes('doc')) {
      bestCategory = 'doctor_notes';
      confidence = 0.3;
    } else if (['jpg', 'jpeg', 'png'].includes(fileExtension)) {
      bestCategory = 'lab_reports'; // Images are often lab results or scanned reports
      confidence = 0.25;
    }
  }
  
  // Ensure minimum confidence for medical files
  if (confidence < 0.2) {
    confidence = 0.2;
  }
  
  const reasoning = `Intelligent fallback: ${maxScore > 0 ? 
    `Found ${maxScore} medical keywords suggesting ${bestCategory}` : 
    `No clear keywords found, classified as ${bestCategory} based on file type`}. ${extensionHint}`;
  
  return {
    category: bestCategory,
    confidence: confidence,
    suggestedSubfolder: getDefaultSubfolder(bestCategory),
    reasoning: reasoning
  };
}

/**
 * Helper function to analyze documents with Gemini Vision
 */



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
        const model = genAI.getGenerativeModel({model: "gemini-2.5-flash-lite-preview-0617"});
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
