const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('../functions/serviceAccountKey.json'); // You'll need to add this

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const testAccounts = [
  {
    email: 'info.metrolab@gmail.com',
    password: 'password123',
    displayName: 'Metro Medical Laboratory',
    userType: 'lab',
    organizationName: 'Metro Medical Laboratory',
    licenseNumber: 'LAB001',
    address: '123 Medical District, City Center',
    phoneNumber: '+1234567890',
    services: ['Blood Tests', 'Urine Analysis', 'X-Ray'],
  },
  {
    email: 'contact.healthcarepharm@gmail.com',
    password: 'password123',
    displayName: 'HealthCare Pharmacy',
    userType: 'pharmacy',
    organizationName: 'HealthCare Pharmacy',
    licenseNumber: 'PHARM001',
    address: '456 Pharmacy Street, Downtown',
    phoneNumber: '+1234567891',
    services: ['Prescription Filling', 'Medication Counseling', 'Health Screenings'],
  },
];

async function createTestAccounts() {
  console.log('🚀 Creating test accounts...');
  
  for (const account of testAccounts) {
    try {
      // Check if user already exists
      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(account.email);
        console.log(`✅ User ${account.email} already exists`);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          // Create the user
          userRecord = await admin.auth().createUser({
            email: account.email,
            password: account.password,
            displayName: account.displayName,
            emailVerified: true,
          });
          console.log(`✅ Created user: ${account.email}`);
        } else {
          throw error;
        }
      }

      // Create Firestore document for the user
      const userData = {
        uid: userRecord.uid,
        email: account.email,
        displayName: account.displayName,
        userType: account.userType,
        organizationName: account.organizationName,
        licenseNumber: account.licenseNumber,
        address: account.address,
        phoneNumber: account.phoneNumber,
        services: account.services,
        isVerified: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginTime: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await admin.firestore().collection('users').doc(userRecord.uid).set(userData, { merge: true });
      console.log(`✅ Created Firestore document for: ${account.email}`);

    } catch (error) {
      console.error(`❌ Error creating account ${account.email}:`, error);
    }
  }
  
  console.log('🎉 Test account creation completed!');
}

createTestAccounts().then(() => {
  process.exit(0);
}).catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});