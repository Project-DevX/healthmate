import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn(
    // Get this from Firebase Console > Authentication > Sign-in method > Google > Web SDK configuration
    clientId:
        '535481523181-at94psvprrj58fltlu0p4ep2sgpv9o7r.apps.googleusercontent.com',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      // Attempt to sign in with email and password
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Successfully signed in
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred during sign in';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    print("==== Starting Google Sign-In Process ====");

    try {
      // Step 1: Initialize GoogleSignIn instance
      print("Step 1: Initializing GoogleSignIn instance");
      final GoogleSignIn googleSignIn = GoogleSignIn();
      print("GoogleSignIn instance created");

      // Step 2: Trigger the authentication flow
      print(
        "Step 2: Triggering authentication flow with googleSignIn.signIn()",
      );
      final GoogleSignInAccount? googleUser;
      try {
        googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          print("Error: User cancelled the sign-in process");
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign-in was cancelled')),
          );
          return;
        }
        print("Sign-in successful for user: ${googleUser.email}");
      } catch (e) {
        print(
          "ERROR IN STEP 2: Failed at googleSignIn.signIn() with error: $e",
        );
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed at authentication flow: ${e.toString()}'),
          ),
        );
        return;
      }

      // Step 3: Get authentication details
      print("Step 3: Getting authentication tokens");
      final GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication;
        print("Successfully obtained auth tokens");
      } catch (e) {
        print("ERROR IN STEP 3: Failed to get authentication tokens: $e");
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to get authentication details: ${e.toString()}',
            ),
          ),
        );
        return;
      }

      // Step 4: Create Firebase credential
      print("Step 4: Creating Firebase credential");
      try {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        print("Firebase credential created successfully");

        // Step 5: Sign in to Firebase
        print("Step 5: Signing in to Firebase with credential");
        final UserCredential userCredential = await FirebaseAuth.instance
            .signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user == null) {
          print("ERROR IN STEP 5: Firebase user is null after sign-in");
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get user data from Firebase'),
            ),
          );
          return;
        }

        print("Successfully signed in to Firebase as: ${user.email}");

        // Step 6: Save user to database (You can comment this out to isolate the issue)
        try {
          print("Step 6: Saving user data to Firestore");
          // Uncomment the line below when you want to save user data
          await _saveUserToDatabase(user);
          print("User data successfully saved to Firestore");
        } catch (e) {
          print("ERROR IN STEP 6: Failed to save user to database: $e");
          // Continue with navigation even if database operation fails
        }

        // Step 7: Navigate to home page
        print("Step 7: Navigating to home page");
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
          print("Navigation to home page successful");
        }
      } catch (e) {
        print("ERROR IN STEP 4/5: Failed during Firebase authentication: $e");
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase authentication failed: ${e.toString()}'),
          ),
        );
        return;
      }
    } catch (e) {
      // Catch-all error handler
      print("UNEXPECTED ERROR: Unhandled exception in _signInWithGoogle: $e");
      print("Error type: ${e.runtimeType}");
      print("Stack trace: ${StackTrace.current}");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in process failed: ${e.toString()}')),
        );
      }
    } finally {
      print("==== Google Sign-In Process Complete ====");
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
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmail,
                  style: ElevatedButton.styleFrom(
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
                      : const Text('Sign In', style: TextStyle(fontSize: 16)),
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
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: Image.asset('assets/glogo.png', height: 12, width: 12),
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
