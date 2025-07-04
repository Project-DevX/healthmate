import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register.dart';
import 'services/auth_service.dart';
import 'config/testing_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // Handle arguments passed from registration pages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null) {
        print('🧪 Login page received arguments: $arguments');
        final email = arguments['email'] as String?;
        final password = arguments['password'] as String?;
        final message = arguments['message'] as String?;

        if (email != null) {
          _emailController.text = email;
          print('🧪 Email pre-filled: $email');
        }
        if (password != null) {
          _passwordController.text = password;
          print(
            '🧪 Password pre-filled: ${password.replaceAll(RegExp(r'.'), '*')}',
          );
        }
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }

        // Force UI rebuild to show pre-filled values
        setState(() {});
      }
    });
  }

  // Add this function to update last login time in Firestore
  Future<void> _updateLastLoginTime(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      print('Last login time updated successfully');
    } catch (e) {
      print('Error updating last login time: $e');
      // Don't throw the error - we still want the user to be logged in
      // even if updating the timestamp fails
    }
  }

  // Save login state to SharedPreferences
  Future<void> _saveLoginState(
    String userId,
    String email,
    String userType,
  ) async {
    if (_rememberMe) {
      await AuthService.saveLoginState(userId, email, userType);
    }
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print(
        '🔐 Starting authentication for email: ${_emailController.text.trim()}',
      );

      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      print(
        '✅ Firebase authentication successful for user: ${userCredential.user?.uid}',
      );

      // If sign-in is successful, update the last login time
      if (userCredential.user != null) {
        await _updateLastLoginTime(userCredential.user!.uid);

        // Check user type and navigate accordingly
        print('📋 Fetching user data from Firestore...');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (mounted) {
          if (userDoc.exists) {
            final userData = userDoc.data();
            final userType = userData?['userType'] as String? ?? 'patient';

            print('👤 User type found: $userType');
            print('📄 User data: $userData');

            // Save login state if remember me is checked
            await _saveLoginState(
              userCredential.user!.uid,
              userCredential.user!.email ?? '',
              userType,
            );

            if (userType == 'patient') {
              print('🏥 Navigating to patient dashboard...');
              Navigator.pushReplacementNamed(context, '/patientDashboard');
            } else if (userType == 'doctor') {
              print('👨‍⚕️ Navigating to doctor dashboard...');
              Navigator.pushReplacementNamed(context, '/doctorDashboard');
            } else if (userType == 'caregiver') {
              print('🧑‍🦳 Navigating to caregiver dashboard...');
              Navigator.pushReplacementNamed(context, '/caregiverDashboard');
            } else if (userType == 'hospital') {
              print('🏥 Navigating to hospital dashboard...');
              Navigator.pushReplacementNamed(context, '/hospitalDashboard');
            } else if (userType == 'lab') {
              print('🧪 Navigating to lab dashboard...');
              Navigator.pushReplacementNamed(context, '/labDashboard');
            } else {
              print('❓ Unknown user type, returning to login.');
              Navigator.pushReplacementNamed(context, '/login');
            }
          } else {
            print(
              '⚠️ User document not found in Firestore, creating default patient profile...',
            );
            // If user document doesn't exist, create as patient and go to patient dashboard
            await _saveLoginState(
              userCredential.user!.uid,
              userCredential.user!.email ?? '',
              'patient',
            );
            Navigator.pushReplacementNamed(context, '/patientDashboard');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Exception: ${e.code} - ${e.message}');
      String errorMessage = 'Authentication failed';

      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      print('❌ General authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Clean Google Sign-in implementation
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      print('🔐 Starting Google Sign-in process...');

      // Initialize Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Start the sign-in flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('🚫 User cancelled Google Sign-in');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Google account obtained: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        print('🔥 Firebase authentication successful');

        // Update last login time
        await _updateLastLoginTime(userCredential.user!.uid);

        // Check if user exists in Firestore, if not create them as a patient
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // New Google Sign-in user - create as patient
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'uid': userCredential.user!.uid,
                'email': userCredential.user!.email,
                'displayName': userCredential.user!.displayName ?? '',
                'photoURL': userCredential.user!.photoURL ?? '',
                'userType':
                    'patient', // Google Sign-in users are always patients
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
                'accountComplete': true, // Google users have basic info
              });
          print('👤 New patient profile created for Google user');
        }

        // Save login state if remember me is checked
        await _saveLoginState(
          userCredential.user!.uid,
          userCredential.user!.email ?? '',
          'patient',
        );

        print('🏥 Navigating to patient dashboard...');

        if (mounted) {
          // Google Sign-in users always go to patient dashboard
          Navigator.pushReplacementNamed(context, '/patientDashboard');
        }
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Exception: ${e.code} - ${e.message}');
      String errorMessage = 'Google Sign-in failed';

      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with this email address';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid Google credentials';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      print('❌ General Google Sign-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-in failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HealthMate Login'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_hospital, size: 64, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                'Welcome to HealthMate',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              // Testing mode indicator
              if (TestingConfig.isTestingMode) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🧪 TESTING MODE: Credentials auto-filled from registration',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          TestingConfig.isTestingMode &&
                              _emailController.text.isNotEmpty
                          ? Colors.orange
                          : Colors.grey,
                      width:
                          TestingConfig.isTestingMode &&
                              _emailController.text.isNotEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.email,
                    color:
                        TestingConfig.isTestingMode &&
                            _emailController.text.isNotEmpty
                        ? Colors.orange
                        : null,
                  ),
                  suffixIcon:
                      TestingConfig.isTestingMode &&
                          _emailController.text.isNotEmpty
                      ? const Icon(
                          Icons.auto_fix_high,
                          color: Colors.orange,
                          size: 20,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          TestingConfig.isTestingMode &&
                              _passwordController.text.isNotEmpty
                          ? Colors.orange
                          : Colors.grey,
                      width:
                          TestingConfig.isTestingMode &&
                              _passwordController.text.isNotEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.lock,
                    color:
                        TestingConfig.isTestingMode &&
                            _passwordController.text.isNotEmpty
                        ? Colors.orange
                        : null,
                  ),
                  suffixIcon:
                      TestingConfig.isTestingMode &&
                          _passwordController.text.isNotEmpty
                      ? const Icon(
                          Icons.auto_fix_high,
                          color: Colors.orange,
                          size: 20,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Testing mode credential info
              if (TestingConfig.isTestingMode &&
                  _emailController.text.isNotEmpty &&
                  _passwordController.text.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ready to login with registration credentials!',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text('Remember me'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        TestingConfig.isTestingMode &&
                            _emailController.text.isNotEmpty &&
                            _passwordController.text.isNotEmpty
                        ? Colors.orange
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (TestingConfig.isTestingMode &&
                                _emailController.text.isNotEmpty &&
                                _passwordController.text.isNotEmpty) ...[
                              const Icon(Icons.auto_fix_high, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              TestingConfig.isTestingMode &&
                                      _emailController.text.isNotEmpty &&
                                      _passwordController.text.isNotEmpty
                                  ? 'Sign In (Testing Mode)'
                                  : 'Sign In',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('OR'),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/glogo.png', height: 24, width: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    child: const Text('Register'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
