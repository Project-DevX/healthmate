# Testing Configuration

## Overview

The `TestingConfig` class provides a centralized way to control testing-related features in the HealthMate app.

## Quick Setup

### Enable Testing Mode

```dart
// In lib/config/testing_config.dart
static const bool isTestingMode = true;  // Set to true for testing
```

### Disable Testing Mode (Production)

```dart
// In lib/config/testing_config.dart
static const bool isTestingMode = false; // Set to false for production
```

## Features Controlled by Testing Mode

### When `isTestingMode = true`:

1. **Document Upload Bypass**: All document upload requirements are skipped during registration
2. **Enhanced Debug UI**: Debug buttons are visible even outside of Flutter debug mode
3. **Sample Data Auto-fill**: Quick registration with valid test data
4. **Visual Testing Indicators**: Orange banners and indicators show testing mode is active

### When `isTestingMode = false`:

1. **Production Behavior**: All validation and requirements are enforced
2. **Debug UI Hidden**: Debug buttons only appear in Flutter debug mode (`kDebugMode`)
3. **Full Validation**: Document uploads and all fields are required

## Registration Pages Affected

All registration pages now respect the testing configuration:

- **Hospital/Institution Registration** (`hospitalReg.dart`)
- **Doctor Registration** (`doctorReg.dart`)
- **Patient Registration** (`patientReg.dart`)
- **Caregiver Registration** (`caregiverReg.dart`)

## Usage Examples

### For Testing/Development:

1. Set `isTestingMode = true` in `testing_config.dart`
2. Run the app
3. Navigate to any registration page
4. Click "Fill Sample Data (DEBUG)" button
5. Complete registration without uploading documents

### For Production:

1. Set `isTestingMode = false` in `testing_config.dart`
2. Build the app for release
3. All document requirements will be enforced
4. Debug buttons will be hidden

## File Structure

```
lib/
├── config/
│   └── testing_config.dart    # Main testing configuration
├── hospitalReg.dart           # Uses TestingConfig
├── doctorReg.dart            # Uses TestingConfig
├── patientReg.dart           # Uses TestingConfig
└── caregiverReg.dart         # Uses TestingConfig
```

## Safety Notes

- **Always set `isTestingMode = false` before production builds**
- Testing mode bypasses important security validations
- Document upload requirements exist for compliance reasons
- Use testing mode only during development and QA testing
