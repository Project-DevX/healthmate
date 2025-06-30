// Test script to manually call the debug function
// Run this in the Firebase Functions shell

// First, start the functions shell:
// firebase functions:shell

// Then run this command:
analyzeMedicalRecords({}, {auth: {uid: 'test-user-id', token: {email: 'test@example.com'}}})

// Or test the debug function:
debugFunction({}, {auth: {uid: 'test-user-id', token: {email: 'test@example.com'}}})
