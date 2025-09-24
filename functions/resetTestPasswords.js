/**
 * Reset password for test accounts
 */
exports.resetTestAccountPasswords = onCall(
    {cors: true},
    async (request) => {
        const testEmails = [
            'info.metrolab@gmail.com',
            'contact.healthcarepharm@gmail.com'
        ];

        const results = [];

        for (const email of testEmails) {
            try {
                // Get user by email
                const userRecord = await admin.auth().getUserByEmail(email);
                
                // Update password
                await admin.auth().updateUser(userRecord.uid, {
                    password: 'password123'
                });
                
                results.push(`✅ Reset password for: ${email}`);
            } catch (error) {
                results.push(`❌ Error resetting password for ${email}: ${error.message}`);
            }
        }

        return {
            success: true,
            message: 'Password reset completed',
            results: results
        };
    }
);