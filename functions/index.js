/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");

// Initialize Firebase Admin
admin.initializeApp();

/**
 * Analyze medical records using Gemini AI
 */
exports.analyzeMedicalRecords = functions.https.onCall(
    async (data, context) => {
      // Verify user authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in",
        );
      }

      const {userId} = data;

      try {
        // Get the API key from Firebase config
        const geminiApiKey = functions.config().gemini.api_key;

        if (!geminiApiKey) {
          throw new functions.https.HttpsError(
              "failed-precondition",
              "API key not configured",
          );
        }

        // Initialize Gemini AI
        const genAI = new GoogleGenerativeAI(geminiApiKey);
        const model = genAI.getGenerativeModel({model: "gemini-pro"});

        // Get user's medical documents from Firestore
        const db = admin.firestore();
        const documentsSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("documents")
            .orderBy("uploadDate", "desc")
            .get();

        if (documentsSnapshot.empty) {
          return {
            summary: "No medical records found for analysis. " +
              "Please upload some medical documents first.",
          };
        }

        // Get user profile data for context
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data() || {};

        // Prepare document information for analysis
        const documents = [];
        documentsSnapshot.forEach((doc) => {
          const docData = doc.data();
          documents.push({
            fileName: docData.fileName,
            fileType: docData.fileType,
            uploadDate: docData.uploadDate.toDate().toLocaleDateString(),
            fileSize: docData.fileSize,
          });
        });

        // Create date of birth text
        const dobText = userData.dateOfBirth ?
          new Date(userData.dateOfBirth.seconds * 1000)
              .toLocaleDateString() :
          "Not specified";

        // Create a comprehensive prompt for medical analysis
        const prompt = `
As a medical AI assistant, please analyze the following medical records 
and provide a comprehensive summary.

Patient Information:
- Gender: ${userData.gender || "Not specified"}
- Age: ${userData.age || "Not specified"}
- Date of Birth: ${dobText}

Available Medical Documents (${documents.length} total):
${documents.map((doc) =>
    `• ${doc.fileName} (${doc.fileType.toUpperCase()}) - ` +
    `Uploaded: ${doc.uploadDate}`,
).join("\n")}

Please provide a medical history summary with the following sections:

1. **Document Overview**: Brief description of available records
2. **Key Medical Conditions**: Any diagnoses or conditions inferred
3. **Medications & Treatments**: Current or past medications and treatments
4. **Important Dates**: Timeline of medical events
5. **Health Recommendations**: General health recommendations
6. **Follow-up Suggestions**: Recommended medical follow-ups or screenings

Note: This analysis is based on document metadata only. For complete 
analysis, actual document content would need to be processed.

Please format the response in clear, easy-to-read sections with bullet 
points where appropriate.
        `;

        // Generate content using Gemini
        const result = await model.generateContent(prompt);
        const summary = result.response.text();

        // Store the analysis result in Firestore
        await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("latest")
            .set({
              summary: summary,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              documentCount: documents.length,
              analyzedDocuments: documents.map((doc) => doc.fileName),
            });

        return {summary};
      } catch (error) {
        console.error("Error analyzing medical records:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to analyze medical records",
            error.message,
        );
      }
    },
);

/**
 * Get cached medical analysis
 */
exports.getMedicalAnalysis = functions.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in",
        );
      }

      const {userId} = data;

      try {
        const db = admin.firestore();
        const analysisDoc = await db
            .collection("users")
            .doc(userId)
            .collection("ai_analysis")
            .doc("latest")
            .get();

        if (!analysisDoc.exists) {
          return {summary: null};
        }

        const analysisData = analysisDoc.data();
        return {
          summary: analysisData.summary,
          timestamp: analysisData.timestamp,
          documentCount: analysisData.documentCount,
        };
      } catch (error) {
        console.error("Error getting medical analysis:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to get medical analysis",
        );
      }
    },
);

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
