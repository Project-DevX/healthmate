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

// Set global options
setGlobalOptions({region: "us-central1"}); // Change to your preferred region

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Analyze medical records using Gemini AI - only analyzes new documents and combines with existing summaries
 */
exports.analyzeMedicalRecords = onCall(
    {cors: true}, // Enable CORS
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== ANALYZE MEDICAL RECORDS V3 ===');
      console.log('Request data:', data);
      console.log('Auth exists:', !!auth);
      console.log('Auth UID:', auth?.uid);
      console.log('=================================');

      // Verify user authentication
      if (!auth) {
        console.error('No authentication context found');
        throw new HttpsError(
            "unauthenticated",
            "User must be logged in",
        );
      }

      if (!auth.uid) {
        console.error('No UID in authentication context');
        throw new HttpsError(
            "unauthenticated",
            "Invalid authentication token",
        );
      }

      // Use the authenticated user's ID from context
      const userId = auth.uid;
      const forceReanalysis = data?.forceReanalysis || false; // Allow forcing re-analysis of all documents
      
      console.log('✅ Authenticated user ID:', userId);
      console.log('🔄 Force reanalysis:', forceReanalysis);

      try {
        // Get the API key from environment variables
        const geminiApiKey = process.env.GEMINI_API_KEY;

        console.log('🔑 API key source: Environment');
        console.log('🔑 API key exists:', !!geminiApiKey);

        if (!geminiApiKey) {
          console.error('❌ GEMINI_API_KEY not configured in Firebase config or environment');
          throw new HttpsError(
              "failed-precondition",
              "API key not configured",
          );
        }

        // Initialize Gemini AI
        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});

        // Get user's medical documents from Firestore
        const db = admin.firestore();
        
        // Check if there's an existing analysis
        const existingAnalysisDoc = await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("latest")
            .get();

        const existingAnalysis = existingAnalysisDoc.exists ? existingAnalysisDoc.data() : null;
        const analyzedDocumentIds = existingAnalysis?.analyzedDocuments || [];
        
        console.log('📊 Existing analysis found:', !!existingAnalysis);
        console.log('� Previously analyzed documents:', analyzedDocumentIds.length);

        // Get all documents
        const documentsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .orderBy("uploadDate", "desc")
            .get();

        if (documentsSnapshot.empty) {
          return {
            summary: "No medical records found for analysis. Please upload some medical documents first.",
            documentsAnalyzed: 0,
            newDocumentsAnalyzed: 0,
            isCached: false
          };
        }

        // Separate new documents from already analyzed ones
        const allDocuments = [];
        const newDocuments = [];

        documentsSnapshot.forEach((doc) => {
          const docData = doc.data();
          const docInfo = {
            id: doc.id,
            fileName: docData.fileName,
            filePath: docData.filePath,
            uploadDate: docData.uploadDate,
            ...docData
          };
          
          allDocuments.push(docInfo);
          
          // If force reanalysis, treat all as new; otherwise only include unanalyzed documents
          const wasAnalyzed = analyzedDocumentIds.includes(doc.id);
          if (forceReanalysis || !wasAnalyzed) {
            newDocuments.push(docInfo);
          }
        });

        console.log(`📄 Total documents: ${allDocuments.length}`);
        console.log(`🆕 New documents to analyze: ${newDocuments.length}`);

        // If no new documents and we have existing analysis, return cached result
        if (newDocuments.length === 0 && existingAnalysis && !forceReanalysis) {
          console.log('✅ No new documents found, returning cached analysis');
          return {
            summary: existingAnalysis.summary,
            lastUpdated: existingAnalysis.timestamp.toDate().toISOString(),
            documentsAnalyzed: analyzedDocumentIds.length,
            newDocumentsAnalyzed: 0,
            isCached: true
          };
        }

        // Get user profile data for context
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data() || {};

        // Process NEW documents with Gemini Vision to extract text content
        const newDocumentAnalyses = [];
        const bucket = admin.storage().bucket();

        console.log(`📄 Processing ${newDocuments.length} NEW documents with vision analysis...`);

        for (const docInfo of newDocuments) {
          const fileName = docInfo.fileName;
          const filePath = docInfo.filePath;
          
          console.log(`🔍 Analyzing NEW document: ${fileName}`);

          try {
            // Check if it's an image file that Gemini can process
            const isImage = /\.(jpg|jpeg|png|gif|bmp|webp)$/i.test(fileName);
            
            if (!isImage) {
              console.log(`⚠️ Skipping non-image file: ${fileName}`);
              newDocumentAnalyses.push({
                documentId: docInfo.id,
                fileName: fileName,
                uploadDate: docInfo.uploadDate.toDate().toLocaleDateString(),
                analysis: `Document type not supported for text extraction: ${fileName}. Only image files (JPG, PNG, etc.) can be analyzed for text content.`
              });
              continue;
            }

            // Download the file from Firebase Storage
            const file = bucket.file(filePath);
            const [fileBuffer] = await file.download();
            
            // Convert to base64 for Gemini API
            const base64Data = fileBuffer.toString('base64');
            
            // Determine the MIME type
            let mimeType = 'image/jpeg';
            if (fileName.toLowerCase().endsWith('.png')) {
              mimeType = 'image/png';
            } else if (fileName.toLowerCase().endsWith('.gif')) {
              mimeType = 'image/gif';
            } else if (fileName.toLowerCase().endsWith('.webp')) {
              mimeType = 'image/webp';
            }

            // Create a detailed prompt for medical document OCR and analysis
            const visionPrompt = `
Please carefully analyze this medical document image and extract ALL visible text and information. Focus on:

1. **Document Type**: What type of medical document is this? (lab report, prescription, discharge summary, etc.)
2. **Patient Information**: Any patient details visible (name, ID, demographics)
3. **Medical Tests & Results**: 
   - Lab values and their reference ranges
   - Abnormal results (mark as HIGH/LOW if indicated)
   - Test names and measurements
4. **Diagnoses & Conditions**: Any medical conditions, diagnoses, or health issues mentioned
5. **Medications**: Any medications listed with dosages, frequencies
6. **Vital Signs**: Blood pressure, heart rate, temperature, etc.
7. **Dates & Times**: All dates mentioned in the document
8. **Healthcare Providers**: Doctor names, hospital/clinic information
9. **Clinical Notes**: Any doctor's observations or recommendations
10. **Reference Values**: Normal ranges for lab tests

Please extract and transcribe ALL readable text, numbers, and medical information from this image. 
Be extremely thorough and include specific values, units, and reference ranges where visible.
Format the response in clear sections with bullet points for easy reading.

If any text is unclear or partially obscured, indicate this in your response.
`;

            // Analyze the document with Gemini Vision
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
            
            newDocumentAnalyses.push({
              documentId: docInfo.id,
              fileName: fileName,
              uploadDate: docInfo.uploadDate.toDate().toLocaleDateString(),
              analysis: analysis
            });

            console.log(`✅ Successfully analyzed image content for: ${fileName}`);

          } catch (error) {
            console.error(`❌ Error analyzing ${fileName}:`, error);
            newDocumentAnalyses.push({
              documentId: docInfo.id,
              fileName: fileName,
              uploadDate: docInfo.uploadDate.toDate().toLocaleDateString(),
              analysis: `Error extracting text from image: ${error.message}. The image may be corrupted or in an unsupported format.`
            });
          }
        }

        // Create date of birth text
        const dobText = userData.dateOfBirth ?
          new Date(userData.dateOfBirth.seconds * 1000).toLocaleDateString() :
          "Not specified";

        // Prepare the summary prompt
        let summaryPrompt;
        
        if (existingAnalysis && !forceReanalysis && newDocumentAnalyses.length > 0) {
          // Combine new analysis with existing summary
          summaryPrompt = `
You are updating an existing medical summary with new document analysis. Here is the context:

**EXISTING MEDICAL SUMMARY:**
${existingAnalysis.summary}

**NEW DOCUMENT ANALYSES TO INTEGRATE:**
${newDocumentAnalyses.map((doc, index) => 
  `\n--- NEW Document ${index + 1}: ${doc.fileName} (${doc.uploadDate}) ---\n${doc.analysis}\n`
).join('\n')}

**PATIENT INFORMATION:**
- Gender: ${userData.gender || "Not specified"}
- Age: ${userData.age || "Not specified"}
- Date of Birth: ${dobText}

Please create an UPDATED comprehensive medical summary that:
1. **Preserves all important information** from the existing summary
2. **Integrates the new document findings** seamlessly
3. **Updates timelines** with new dates and events
4. **Highlights any new conditions, medications, or test results**
5. **Maintains the same structure** as the original summary
6. **Notes what information is new** in this update

Structure the response with clear headings:
- Document Overview (updated count)
- Key Medical Findings (including new findings)
- Test Results Summary (with new results integrated)
- Medications & Treatments (updated)
- Clinical Timeline (chronologically updated)
- Health Recommendations (updated based on new findings)
- Risk Factors (updated assessment)

Mark new findings with "**NEW:**" where appropriate for easy identification.
          `;
        } else {
          // Create fresh summary (either no existing analysis or force reanalysis)
          summaryPrompt = `
Based on the following detailed medical document analyses extracted from images, create a comprehensive medical summary:

**PATIENT INFORMATION:**
- Gender: ${userData.gender || "Not specified"}
- Age: ${userData.age || "Not specified"}
- Date of Birth: ${dobText}

**DOCUMENT ANALYSES:**
${newDocumentAnalyses.map((doc, index) => 
  `\n--- Document ${index + 1}: ${doc.fileName} (${doc.uploadDate}) ---\n${doc.analysis}\n`
).join('\n')}

Based on the extracted content above, please provide a comprehensive medical summary with:

1. **Document Overview**: Summary of all documents analyzed
2. **Key Medical Findings**: 
   - Laboratory abnormalities (with specific values and reference ranges)
   - Diagnoses and medical conditions identified
   - Critical or concerning findings
3. **Test Results Summary**:
   - Organize lab results by category (blood chemistry, hematology, etc.)
   - Highlight abnormal values
   - Include reference ranges where available
4. **Medications & Treatments**: Any medications or treatments mentioned
5. **Clinical Timeline**: Chronological order of medical events and test dates
6. **Health Recommendations**: Based on the findings, suggest potential follow-up actions
7. **Risk Factors**: Identify any concerning patterns or risk factors

Please be specific and include actual values, dates, and medical terminology from the extracted text.
Format with clear headings and bullet points for readability.
          `;
        }

        // Generate comprehensive summary using Gemini
        const result = await model.generateContent(summaryPrompt);
        const summary = result.response.text();

        // Update the list of analyzed documents
        const updatedAnalyzedDocuments = [...new Set([
          ...analyzedDocumentIds,
          ...newDocumentAnalyses.map(doc => doc.documentId)
        ])];

        // Store the updated analysis result in Firestore
        await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("latest")
            .set({
              summary: summary,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              documentCount: allDocuments.length,
              analyzedDocuments: updatedAnalyzedDocuments,
              lastAnalysisType: forceReanalysis ? 'full_reanalysis' : 
                               (existingAnalysis ? 'incremental_update' : 'initial_analysis')
            });

        console.log(`✅ Analysis complete. Total docs: ${allDocuments.length}, New docs analyzed: ${newDocumentAnalyses.length}`);

        return {
          summary: summary,
          documentsAnalyzed: allDocuments.length,
          newDocumentsAnalyzed: newDocumentAnalyses.length,
          lastUpdated: new Date().toISOString(),
          isCached: false,
          analysisType: forceReanalysis ? 'full_reanalysis' : 
                       (existingAnalysis ? 'incremental_update' : 'initial_analysis')
        };
      } catch (error) {
        console.error("Error analyzing medical records:", error);
        throw new HttpsError(
            "internal",
            "Failed to analyze medical records",
            error.message,
        );
      }
    },
);

/**
 * Get cached medical analysis and check for new documents
 */
exports.getMedicalAnalysis = onCall(
    {cors: true}, // Add options for consistency
    async (request) => {
      const {auth, data} = request;
      
      if (!auth) {
        throw new HttpsError(
            "unauthenticated",
            "User must be logged in",
        );
      }

      // Use authenticated user's ID from context
      const userId = auth.uid;

      try {
        const db = admin.firestore();
        
        // Get existing analysis
        const analysisDoc = await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("latest")
            .get();

        // Get all documents to check for new ones
        const documentsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .orderBy("uploadDate", "desc")
            .get();

        const totalDocuments = documentsSnapshot.size;
        
        if (!analysisDoc.exists) {
          return {
            summary: null,
            hasAnalysis: false,
            totalDocuments: totalDocuments,
            newDocumentsAvailable: totalDocuments > 0,
            analysisUpToDate: false
          };
        }

        const analysisData = analysisDoc.data();
        const analyzedDocumentIds = analysisData.analyzedDocuments || [];
        
        // Check for new documents
        let newDocumentsCount = 0;
        documentsSnapshot.forEach((doc) => {
          if (!analyzedDocumentIds.includes(doc.id)) {
            newDocumentsCount++;
          }
        });

        return {
          summary: analysisData.summary,
          timestamp: analysisData.timestamp,
          documentCount: analysisData.documentCount,
          hasAnalysis: true,
          totalDocuments: totalDocuments,
          analyzedDocuments: analyzedDocumentIds.length,
          newDocumentsAvailable: newDocumentsCount > 0,
          newDocumentsCount: newDocumentsCount,
          analysisUpToDate: newDocumentsCount === 0,
          lastAnalysisType: analysisData.lastAnalysisType || 'unknown'
        };
      } catch (error) {
        console.error("Error getting medical analysis:", error);
        throw new HttpsError(
            "internal",
            "Failed to get medical analysis",
        );
      }
    },
);

/**
 * Check if medical analysis needs to be updated (lighter version of getMedicalAnalysis)
 */
exports.checkAnalysisStatus = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      if (!auth) {
        throw new HttpsError(
            "unauthenticated",
            "User must be logged in",
        );
      }

      const userId = auth.uid;

      try {
        const db = admin.firestore();
        
        // Get existing analysis
        const analysisDoc = await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("latest")
            .get();

        // Get document count
        const documentsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .get();

        const totalDocuments = documentsSnapshot.size;
        
        if (!analysisDoc.exists) {
          return {
            hasAnalysis: false,
            totalDocuments: totalDocuments,
            needsAnalysis: totalDocuments > 0,
            statusMessage: totalDocuments > 0 ? 
              `${totalDocuments} document(s) ready for analysis` : 
              "No documents uploaded yet"
          };
        }

        const analysisData = analysisDoc.data();
        const analyzedDocumentIds = analysisData.analyzedDocuments || [];
        
        // Check for new documents
        let newDocumentsCount = 0;
        documentsSnapshot.forEach((doc) => {
          if (!analyzedDocumentIds.includes(doc.id)) {
            newDocumentsCount++;
          }
        });

        const needsAnalysis = newDocumentsCount > 0;
        let statusMessage;
        
        if (needsAnalysis) {
          statusMessage = `${newDocumentsCount} new document(s) available for analysis`;
        } else {
          statusMessage = "Analysis is up to date";
        }

        return {
          hasAnalysis: true,
          totalDocuments: totalDocuments,
          analyzedDocuments: analyzedDocumentIds.length,
          newDocumentsCount: newDocumentsCount,
          needsAnalysis: needsAnalysis,
          statusMessage: statusMessage,
          lastUpdated: analysisData.timestamp?.toDate()?.toISOString() || null
        };
      } catch (error) {
        console.error("Error checking analysis status:", error);
        throw new HttpsError(
            "internal",
            "Failed to check analysis status",
        );
      }
    },
);

/**
 * Simple debug function to test authentication and API key configuration
 */
exports.debugFunction = onCall(
    {cors: true},
    async (request) => {
      const {auth, data} = request;
      
      console.log('=== DEBUG FUNCTION CALLED ===');
      console.log('Auth exists:', !!auth);
      console.log('Auth UID:', auth?.uid);
      
      if (!auth) {
        throw new HttpsError("unauthenticated", "User must be logged in");
      }

      try {
        // Test API key access
        const geminiApiKey = process.env.GEMINI_API_KEY;
        
        // Test Firestore access
        const db = admin.firestore();
        const userDoc = await db.collection("users").doc(auth.uid).get();
        
        return {
          success: true,
          userId: auth.uid,
          userExists: userDoc.exists,
          hasApiKey: !!geminiApiKey,
          apiKeySource: 'Environment',
          timestamp: new Date().toISOString()
        };
      } catch (error) {
        console.error("Debug function error:", error);
        throw new HttpsError("internal", `Debug error: ${error.message}`);
      }
    },
);

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
