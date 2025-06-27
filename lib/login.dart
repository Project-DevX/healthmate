import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      print('🔐 Starting authentication for email: ${_emailController.text.trim()}');
      
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      print('✅ Firebase authentication successful for user: ${userCredential.user?.uid}');

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
            } else {
              print('🏠 Navigating to home page...');
              // Default route for other user types
              Navigator.pushReplacementNamed(context, '/home');
            }
          } else {
            print('⚠️ User document not found in Firestore, creating default...');
            // If user document doesn't exist, go to default home
            await _saveLoginState(
              userCredential.user!.uid,
              userCredential.user!.email ?? '',
              'patient',
            );
            Navigator.pushReplacementNamed(context, '/home');
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

  Future<UserCredential?> _signInWithGoogle(BuildContext context) async {
    print("STEP 0: Starting Google Sign-In process");
    try {
      // Step 1: Initialize Google Sign In
      print("STEP 1: Initializing Google Sign-In");
      final GoogleSignIn googleSignIn = GoogleSignIn();
      print("STEP 1: Completed - GoogleSignIn instance created");

      // Step 2: Start the sign-in flow
      print("STEP 2: Starting sign-in flow");
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      print(
        "STEP 2: Result - ${googleUser != null ? 'User account obtained' : 'User cancelled sign-in'}",
      );

      if (googleUser == null) {
        print("STEP 2: FAILED - User cancelled the sign-in process");
        return null;
      }

      // Step 3: Get authentication tokens
      print("STEP 3: Getting authentication tokens");
      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        print("STEP 3: Completed - Authentication tokens received");

        // Step 4: Create Firebase credential
        print("STEP 4: Creating Firebase credential");
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        print("STEP 4: Completed - Firebase credential created");

        // Step 5: Sign in with Firebase
        print("STEP 5: Starting Firebase sign-in");
        try {
          final UserCredential userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          print("STEP 5: Completed - Firebase sign-in successful");
          return userCredential;
        } catch (firebaseError) {
          print("STEP 5: FAILED - Firebase sign-in error: $firebaseError");
          print("STEP 5: Error type: ${firebaseError.runtimeType}");
          rethrow;
        }
      } catch (authError) {
        print(
          "STEP 3: FAILED - Getting authentication tokens error: $authError",
        );
        print("STEP 3: Error type: ${authError.runtimeType}");
        rethrow;
      }
    } catch (e) {
      print("GENERAL FAILURE: Google Sign-In process failed with error: $e");
      print("GENERAL FAILURE: Error type: ${e.runtimeType}");
      print("GENERAL FAILURE: Stack trace: ${StackTrace.current}");
      rethrow;
    }
  }

  Future<void> signInWithGoogleWorkaround(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      // 1. Just use Google Sign-In directly
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        setState(() => _isLoading = false);
        return;
      }

      // 2. Get basic profile info from Google
      final Map<String, dynamic> userData = {
        'email': googleUser.email,
        'displayName': googleUser.displayName,
        'id': googleUser.id,
        'photoUrl': googleUser.photoUrl,
      };

      // 3. Store user info in shared preferences for persistence
      // (You'll need to add shared_preferences package)
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.setString('user_email', userData['email']);
      // await prefs.setString('user_name', userData['displayName'] ?? '');

      // 4. Optional: Store in Firestore directly without Firebase Auth
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(googleUser.id)
            .set({
              'email': googleUser.email,
              'displayName': googleUser.displayName,
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        print("User data saved to Firestore");
      } catch (dbError) {
        print("Firestore error (non-critical): $dbError");
        // Continue anyway - this shouldn't block login
      }

      // 5. Navigate to home screen
      print("Login successful with Google: ${googleUser.email}");
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("Google Sign-In error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in failed')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Save user data to Firestore
  Future<void> _saveUserToDatabase(User user) async {
    // Check if user already exists in the database
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      // New user - add to database
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        // You can add other default fields here
        'userType': 'patient', // Default user type
        'accountComplete':
            false, // Flag to identify new accounts that need setup
      });
    } else {
      // Existing user - just update the login timestamp
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
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
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => signInWithGoogleWorkaround(context),
                  icon: const Icon(
                    Icons.g_translate,
                    size: 24,
                    color: Colors.red,
                  ),
                  label: const Text('Sign in with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
