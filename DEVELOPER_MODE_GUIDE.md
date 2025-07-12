# Developer Role Switcher for HealthMate 🔧

## Overview

The Developer Role Switcher is a powerful development tool that allows you to quickly switch between different user roles (Patient, Doctor, Hospital, Caregiver, Lab, Pharmacy) during development without having to log out and create new accounts.

## Features ✨

- **Quick Role Switching**: Switch between all 6 user types instantly
- **Sample Credentials**: Pre-configured test credentials for each role
- **Visual Indicators**: Clear indicators when developer mode is active
- **Testing Mode Integration**: Only shows when `TestingConfig.isTestingMode = true`
- **Persistent State**: Remembers your selected role across app restarts
- **Easy Navigation**: Automatically navigates to the appropriate dashboard for each role

## How to Use 🚀

### 1. Enable Testing Mode

Make sure testing mode is enabled in your `lib/config/testing_config.dart`:

```dart
class TestingConfig {
  static const bool isTestingMode = true; // Set to true for development
  // ... other settings
}
```

### 2. Access Developer Mode

#### From Login Screen

- Look for the orange "🔧 Developer Mode - Switch Roles" button
- Tap to open the role switcher dialog

#### From Any Dashboard

- Look for the orange developer mode indicator at the top
- Tap "Switch" to change roles

#### Via Floating Button (Optional)

Some screens may have an orange floating button with a developer icon.

### 3. Switch Roles

1. **Enable Developer Mode**: Toggle the switch in the dialog
2. **Select Role**: Tap on any role icon (Patient, Doctor, Hospital, etc.)
3. **Automatic Login**: The app will simulate login and navigate to the appropriate dashboard

## Available Roles 👥

| Role           | Icon | Dashboard           | Sample Credentials           |
| -------------- | ---- | ------------------- | ---------------------------- |
| **Patient**    | 🏥   | Patient Dashboard   | patient@test.com / test123   |
| **Doctor**     | 👨‍⚕️   | Doctor Dashboard    | doctor@test.com / test123    |
| **Hospital**   | 🏥   | Hospital Dashboard  | hospital@test.com / test123  |
| **Caregiver**  | 🧑‍🦳   | Caregiver Dashboard | caregiver@test.com / test123 |
| **Laboratory** | 🧪   | Lab Dashboard       | lab@test.com / test123       |
| **Pharmacy**   | 💊   | Pharmacy Dashboard  | pharmacy@test.com / test123  |

## Implementation Details 🔧

### Components Added

1. **DevModeService** (`lib/services/dev_mode_service.dart`)

   - Core service for managing developer mode state
   - Handles role switching and credential management
   - Integrates with SharedPreferences for persistence

2. **DevRoleSwitcher** (`lib/widgets/dev_role_switcher.dart`)

   - Main widget for role switching interface
   - Multiple display modes (inline, dialog, drawer)
   - Visual feedback and error handling

3. **DevRoleSwitcherButton** (`lib/widgets/dev_role_switcher.dart`)

   - Quick access button for login screen
   - Only shows in testing mode

4. **DevModeFloatingButton** (`lib/widgets/dev_mode_floating_button.dart`)
   - Optional floating button for any screen
   - Easy integration with existing dashboards

### Integration Points

- **Login Screen**: Added developer mode button
- **Patient Dashboard**: Added inline developer mode indicator
- **Doctor Dashboard**: Added inline developer mode indicator
- **Hospital Dashboard**: Added inline developer mode indicator
- **AuthService**: Enhanced to support simulated login states

## Usage Examples 📱

### Quick Testing Workflow

1. **Start Development**: Open the app, enable developer mode from login
2. **Test Patient Flow**: Switch to Patient role, test medical records upload
3. **Test Doctor Flow**: Switch to Doctor role, test prescriptions
4. **Test Hospital Flow**: Switch to Hospital role, test staff management
5. **Continue Testing**: Switch between roles as needed

### Feature Testing

```dart
// Test a feature across multiple roles
1. Switch to Patient → Upload medical document
2. Switch to Doctor → View patient records
3. Switch to Hospital → Check analytics
4. Switch back to Patient → Verify updates
```

## Visual Indicators 🎨

### Developer Mode Active

- **Orange banner** at top of dashboards
- **Text**: "🎭 Dev Mode: [Current Role]"
- **Switch button** to change roles

### Testing Mode Active

- **Orange borders** on login fields when auto-filled
- **Orange login button** when credentials are pre-filled
- **Testing mode banner** on login screen

## Best Practices 💡

### During Development

- ✅ Keep `TestingConfig.isTestingMode = true`
- ✅ Use role switcher to test cross-role features
- ✅ Test role-specific permissions and views
- ✅ Verify navigation between dashboards

### Before Production

- ❌ Set `TestingConfig.isTestingMode = false`
- ❌ Remove or disable developer mode components
- ❌ Test with real authentication flow
- ❌ Verify no developer UI elements appear

## Troubleshooting 🔍

### Developer Mode Not Showing

- Check `TestingConfig.isTestingMode = true`
- Verify imports are correct
- Hot reload/restart the app

### Role Switch Not Working

- Check SharedPreferences permissions
- Verify AuthService integration
- Check console for error messages

### Navigation Issues

- Verify all dashboard routes exist in main.dart
- Check route names match in DevModeService
- Ensure dashboards are properly implemented

## Advanced Features 🔬

### Custom Credentials

```dart
// Save custom credentials for a role
await DevModeService.saveCustomCredentials(
  'doctor',
  'mydoctor@custom.com',
  'mypassword'
);
```

### Reset Developer Mode

```dart
// Clear all developer mode settings
await DevModeService.resetDevMode();
```

### Check Current State

```dart
// Check if developer mode is enabled
bool isEnabled = await DevModeService.isDevModeEnabled();

// Get current role
String? role = await DevModeService.getSelectedRole();
```

## Security Notes 🔒

- **Development Only**: This feature should NEVER be enabled in production
- **Sample Credentials**: Use only for testing, not real user data
- **State Management**: Developer mode state is stored locally only
- **Authentication**: This simulates login state, doesn't bypass Firebase Auth

## Future Enhancements 🚀

Potential improvements for the developer mode:

1. **Role-Specific Test Data**: Pre-populate each role with relevant test data
2. **Scenario Testing**: Pre-defined test scenarios (e.g., "Emergency Patient Flow")
3. **Performance Monitoring**: Track role switching performance
4. **UI Testing**: Automated UI tests for each role
5. **Mock Data Generator**: Generate realistic test data for each role

---

## Quick Reference Commands

```bash
# Enable testing mode
# Set TestingConfig.isTestingMode = true

# Access developer mode
# Login screen → "Developer Mode" button
# Dashboard → Orange banner → "Switch" button

# Reset everything
# Developer dialog → "Reset" button
```

**Happy Testing! 🎉**
