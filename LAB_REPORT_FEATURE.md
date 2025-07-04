# Lab Report Content Extraction Feature

## Overview
This feature automatically extracts text content from lab reports using Gemini AI's OCR capabilities when documents are classified as lab reports during upload.

## Implementation Details

### Cloud Functions (Firebase)

#### 1. Modified `classifyMedicalDocument` Function
- When a document is classified as `lab_reports`, it automatically triggers text extraction
- Uses Gemini AI's vision capabilities to extract text from lab report images
- Stores extracted content in a new Firestore collection `lab_report_content`

#### 2. New `extractLabReportContent` Function
- Extracts comprehensive text content from lab report images
- Identifies and categorizes lab report types:
  - `blood_sugar` - Glucose, diabetes-related tests
  - `cholesterol` - Lipid panel, triglycerides
  - `liver_function` - ALT, AST, bilirubin
  - `kidney_function` - Creatinine, BUN, GFR
  - `thyroid_function` - TSH, T3, T4
  - `complete_blood_count` - CBC, hemoglobin, platelets
  - `cardiac_markers` - Troponin, CK-MB
  - `vitamin_levels` - B12, D, folate
  - `inflammatory_markers` - ESR, CRP
  - `other_lab_tests` - Any other type
- Extracts structured test results with values, units, reference ranges, and status
- Stores patient info, lab info, and test dates when visible

#### 3. New `getLabReportContent` Function
- Retrieves lab report content for authenticated users
- Supports filtering by lab report type
- Returns organized data grouped by type
- Provides pagination support

#### 4. `storeBasicLabReportInfo` Function
- Fallback function when API key is not configured
- Stores basic lab report information without text extraction

### Flutter App Components

#### 1. `LabReportService` Class
- Service class for interacting with lab report Cloud Functions
- Provides methods to fetch lab report content
- Includes data models for structured lab report data

#### 2. `LabReportContentScreen` Widget
- Main screen for viewing extracted lab report content
- Features:
  - Filter by lab report type
  - Expandable cards showing detailed information
  - Structured test results display with status indicators
  - Full extracted text view
  - Laboratory and physician information

#### 3. Data Models
- `LabReportContent` - Main lab report data model
- `TestResult` - Individual test result with value, unit, reference range, status
- `PatientInfo` - Patient information extracted from reports
- `LabInfo` - Laboratory and physician information

### Firestore Collection Structure

```
users/{userId}/lab_report_content/{documentId}
{
  fileName: string,
  storagePath: string,
  labReportType: string,
  extractedText: string,
  testResults: [
    {
      test_name: string,
      value: string,
      unit: string,
      reference_range: string,
      status: "normal" | "high" | "low"
    }
  ],
  testDate: string,
  patientInfo: {
    name: string,
    id: string
  },
  labInfo: {
    name: string,
    ordering_physician: string
  },
  createdAt: timestamp,
  extractionMethod: "gemini_ocr" | "basic_info_only"
}
```

## User Experience

### For Patients
1. Upload a lab report document
2. System automatically classifies it as a lab report
3. Gemini AI extracts text content and structures test results
4. Content is stored in the `lab_report_content` collection
5. Patients can view extracted content through the "Lab Reports" button in their dashboard
6. Structured test results show values, units, reference ranges, and status (normal/high/low)
7. Abnormal results are highlighted for easy identification

### Navigation
- Added "Lab Reports" button to patient dashboard quick access section
- Button navigates to `LabReportContentScreen`
- Screen provides filtering and detailed view of all lab report content

## Key Features

1. **Automatic Text Extraction**: No manual intervention required
2. **Intelligent Classification**: Categorizes lab reports by type
3. **Structured Data**: Extracts test results in a structured format
4. **Status Indicators**: Identifies abnormal values (high/low)
5. **Comprehensive Information**: Includes patient info, lab details, dates
6. **Fallback Handling**: Works even when API key is not configured
7. **User-Friendly Interface**: Easy-to-use filtering and viewing interface

## Error Handling

- Graceful fallback when Gemini API is not available
- Basic information storage when text extraction fails
- User-friendly error messages in the app
- Logging for debugging and monitoring

## Future Enhancements

1. **Trend Analysis**: Track lab values over time
2. **Normal Range Comparisons**: Highlight values outside normal ranges
3. **Export Functionality**: Export lab data to PDF or CSV
4. **Sharing**: Share lab results with healthcare providers
5. **Reminders**: Set reminders for regular lab tests
