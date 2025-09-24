const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

/**
 * Create test accounts for development
 * This function should only be used in development/testing
 */
exports.createTestAccounts = onCall(
    {cors: true},
    async (request) => {
        // Only allow this in development - add your own security checks here
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

        const results = [];

        for (const account of testAccounts) {
            try {
                // Check if user already exists
                let userRecord;
                try {
                    userRecord = await admin.auth().getUserByEmail(account.email);
                    results.push(`✅ User ${account.email} already exists`);
                } catch (error) {
                    if (error.code === 'auth/user-not-found') {
                        // Create the user
                        userRecord = await admin.auth().createUser({
                            email: account.email,
                            password: account.password,
                            displayName: account.displayName,
                            emailVerified: true,
                        });
                        results.push(`✅ Created user: ${account.email}`);
                    } else {
                        throw error;
                    }
                }

                // Create Firestore document for the user
                const userData = {
                    uid: userRecord.uid,
                    email: account.email,
                    displayName: account.displayName,
                    fullName: account.displayName,
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
                results.push(`✅ Created Firestore document for: ${account.email}`);

            } catch (error) {
                results.push(`❌ Error creating account ${account.email}: ${error.message}`);
            }
        }

        return {
            success: true,
            message: 'Test account creation completed',
            results: results
        };
    }
);