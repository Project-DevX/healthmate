# Automated Lab Report Classification with Gemini

This document outlines the implementation of an intelligent, automated lab report classification system. The goal of this feature is to streamline the document upload process by automatically identifying the specific type of a lab report (e.g., "Blood Sugar," "Cholesterol," "CBC") without requiring user input, and to create a self-improving system that becomes more accurate over time.

## Key Changes

### 1. Enhanced Cloud Function (`functions/index.js`)

The core logic resides in the `classifyMedicalDocument` and a new `extractLabReportContent` function.

- **Automated Sub-Classification:** When a document is identified as a `lab_report`, the system now performs a second, more detailed analysis. It sends an enhanced prompt to the Gemini model, instructing it to analyze the report's content and determine its specific sub-type.

- **Dynamic & Learning-Based Prompts:** The system now maintains a list of lab report types for each user in Firestore.
  - When a new lab report is analyzed, the function first fetches the user's personalized list of known lab report types.
  - This list is injected directly into the Gemini prompt, guiding the AI to classify the report using categories it has seen before for that specific user.
  - If the AI identifies a new, valid lab report type that isn't in the user's list, it automatically adds it, allowing the system to learn and expand its knowledge base over time.

- **New Firestore Integration:**
  - A new collection at `users/{userId}/settings/lab_report_types` stores the list of known lab report types for each user.
  - Helper functions `getLabReportTypesForUser` and `saveLabReportTypeForUser` were created to manage this data.

### 2. Simplified Frontend (`lib/services/document_service.dart`)

- **Removal of User Prompt:** The code that previously displayed the `LabReportTypeSelectionDialog` to the user has been completely removed. The manual selection step is no longer necessary.
- **Direct Metadata Update:** The `uploadDocument` function now receives the AI-detected `labReportType` directly from the `classifyMedicalDocument` cloud function's response. This value is then saved along with the rest of the document's metadata in Firestore.

### 3. Code Cleanup

- **Deleted Unused Widget:** The `lib/widgets/lab_report_type_dialog.dart` file, which was responsible for the manual user prompt, has been deleted as it is now redundant.

## Benefits of the New System

1.  **Improved User Experience:** Users no longer need to manually classify their lab reports, making the upload process faster and more seamless.
2.  **Increased Accuracy:** By analyzing the full content of the document, the AI can make a more accurate determination of the lab report type than a user might, especially for complex or unfamiliar reports.
3.  **Personalized & Self-Improving:** The system adapts to each user. As a user uploads more documents, the AI becomes more attuned to the specific types of lab reports they receive, leading to more consistent and reliable classifications in the future.
