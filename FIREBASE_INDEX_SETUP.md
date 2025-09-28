# Firebase Firestore Index Setup for Consent System

## 🔥 Critical: Required Firestore Indexes

The consent notification system requires specific Firestore composite indexes to function properly.

### 1. Consent Requests Query Index

**Required for:** Patient notification queries that filter by `patientId`, `status`, and order by `requestDate`

**Index Configuration:**
```
Collection: consent_requests
Fields:
  - patientId (Ascending)
  - status (Ascending) 
  - requestDate (Descending)
  - __name__ (Descending)
```

**Quick Setup URL:**
```
https://console.firebase.google.com/v1/r/project/healthmate-devx/firestore/indexes?create_composite=Clhwcm9qZWN0cy9oZWFsdGhtYXRlLWRldngvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2NvbnNlbnRfcmVxdWVzdHMvaW5kZXhlcy9fEAEaDQoJcGF0aWVudElkEAEaCgoGc3RhdHVzEAEaDwoLcmVxdWVzdERhdGUQAhoMCghfX25hbWVfXxAC
```

### 2. Manual Index Creation Steps

If the URL doesn't work, create manually:

1. **Go to Firebase Console**
   - Navigate to: https://console.firebase.google.com/
   - Select project: `healthmate-devx`
   - Go to Firestore Database → Indexes

2. **Create Composite Index**
   - Click "Create Index"
   - Collection ID: `consent_requests`
   - Add fields in this exact order:
     - `patientId` → Ascending
     - `status` → Ascending  
     - `requestDate` → Descending
     - `__name__` → Descending
   - Create Index

3. **Wait for Index Build**
   - Index creation takes 2-5 minutes
   - Status will show "Building" then "Ready"
   - App will work once status is "Ready"

### 3. Query Pattern This Index Supports

```dart
// This query requires the composite index above
FirebaseFirestore.instance
  .collection('consent_requests')
  .where('patientId', isEqualTo: patientId)
  .where('status', isEqualTo: 'pending')
  .orderBy('requestDate', descending: true)
  .limit(50)
```

### 4. Additional Recommended Indexes

For optimal performance, also create these indexes:

**Doctor's Sent Requests:**
```
Collection: consent_requests
Fields:
  - doctorId (Ascending)
  - status (Ascending)
  - requestDate (Descending)
```

**Patient's All Requests (History):**
```
Collection: consent_requests  
Fields:
  - patientId (Ascending)
  - requestDate (Descending)
```

### 5. Verification

After index creation, test with:

```bash
# In VS Code terminal
flutter hot restart
```

Look for these log messages:
```
✅ CONSENT NOTIFICATIONS: Successfully loaded X notifications
🔐 CONSENT NOTIFICATIONS: Connection state: ConnectionState.done
```

If you still see index errors, wait 2-3 more minutes for index building to complete.

### 6. Common Issues

**Issue:** "The query requires an index"
**Solution:** Wait for index building to complete (2-5 minutes)

**Issue:** Index creation fails
**Solution:** Check Firebase project permissions and retry

**Issue:** Still getting errors after index creation
**Solution:** Try flutter clean && flutter run

---

## 🚀 Once Index is Ready

The consent notification system will:
- Show real-time notifications in patient dashboard
- Display notification badge with pending count
- Update immediately when new consent requests arrive
- Allow smooth navigation to consent management