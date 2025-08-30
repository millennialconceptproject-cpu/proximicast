import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Allowed email domain
  static const String allowedDomain = '@bisu.edu.ph';

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  // Check if user should be auto-logged in
  Future<void> _checkAutoLogin() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool rememberMe = prefs.getBool('remember_me_${currentUser.uid}') ?? false;
        
        if (rememberMe) {
          print('Auto-login enabled, going to dashboard');
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          print('Auto-login disabled, signing out user');
          await _auth.signOut();
          await _googleSignIn.signOut();
        }
      }
    } catch (e) {
      print('Error checking auto login: $e');
    }
  }

  // Validate email domain
  bool _isValidEmailDomain(String email) {
    return email.toLowerCase().endsWith(allowedDomain.toLowerCase());
  }

  void _handleLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String username = _usernameController.text.trim();
      String password = _passwordController.text;

      if (username.isEmpty || password.isEmpty) {
        _showErrorDialog('Please fill in all fields');
        return;
      }

      // Add @bisu.edu.ph if not present
      if (!username.contains('@')) {
        username = '$username$allowedDomain';
      }

      if (!_isValidEmailDomain(username)) {
        _showErrorDialog('Only $allowedDomain email addresses are allowed');
        return;
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: username,
        password: password,
      );

      if (userCredential.user != null) {
        // Save Remember Me preference
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me_${userCredential.user!.uid}', _rememberMe);
        
        // Update last sign in time
        try {
          await _updateUserLastSignIn(userCredential.user!);
        } catch (e) {
          print('Could not update last sign in time: $e');
        }
        
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials. Please check your email and password';
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      print('Unexpected error in email/password login: $e');
      _showErrorDialog('An unexpected error occurred');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleGoogleLogin() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Trigger Google sign-in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }

      // Validate email domain
      if (!_isValidEmailDomain(googleUser.email)) {
        await _googleSignIn.signOut();
        _showErrorDialog(
          'Only $allowedDomain email addresses are allowed. Please sign in with your institutional email.',
        );
        return;
      }

      // Get tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      // Build Google credential
      final googleCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if user already exists and what sign-in methods they have
      final signInMethods = await _auth.fetchSignInMethodsForEmail(googleUser.email);
      
      if (signInMethods.isNotEmpty && signInMethods.contains('password') && !signInMethods.contains('google.com')) {
        // User exists with password only, ask them to link accounts
        await _handleAccountLinking(googleUser.email, googleCredential);
        return;
      }

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(googleCredential);
      final user = userCredential.user!;
      print("Google sign-in successful: ${user.email}");

      // Check if this is a new user or returning user
      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      
      if (isNewUser) {
        // New user - needs password setup
        print("New Google user detected, needs password setup");
        await _handleSuccessfulLogin(user, true); // needsPasswordSetup = true
      } else {
        // Existing user - check their password setup status from Firestore
        print("Existing Google user detected, checking password setup status");
        final needsPasswordSetup = await _checkIfPasswordSetupNeeded(user);
        await _handleSuccessfulLogin(user, needsPasswordSetup);
      }

    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException: ${e.code} - ${e.message}");
      _showErrorDialog(_getFirebaseErrorMessage(e));
    } catch (e, stackTrace) {
      print("Unexpected error: $e");
      print(stackTrace);
      _showErrorDialog("An unexpected error occurred during Google sign-in.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccountLinking(String email, AuthCredential googleCredential) async {
    // Show dialog asking user to sign in with their password to link accounts
    String? password = await _showPasswordLinkingDialog(email);
    
    if (password != null) {
      try {
        // Sign in with email/password first
        UserCredential emailCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Link Google credential to existing account
        await emailCredential.user!.linkWithCredential(googleCredential);
        
        print('Successfully linked Google account to existing email/password account');
        
        // Update user info and proceed to dashboard
        await _handleSuccessfulLogin(emailCredential.user!, false);
        
      } catch (e) {
        print('Error linking accounts: $e');
        _showErrorDialog('Failed to link accounts. Please check your password and try again.');
      }
    }
  }

  Future<String?> _showPasswordLinkingDialog(String email) async {
    TextEditingController passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Link Accounts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('An account with $email already exists. Please enter your password to link your Google account.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: const Text('Link Accounts'),
          ),
        ],
      ),
    );
  }

  // Handle successful login
  Future<void> _handleSuccessfulLogin(User user, bool needsPasswordSetup) async {
    // Save Remember Me preference
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me_${user.uid}', _rememberMe);
    
    // Update user info
    await _updateUserInfo(user, needsPasswordSetup);
    
    if (needsPasswordSetup) {
      print('User needs password setup, going to interrupt screen');
      Navigator.pushReplacementNamed(context, '/interrupt_screen');
    } else {
      print('User setup complete, going to dashboard');
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<bool> _checkIfPasswordSetupNeeded(User user) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return userData['passwordSetupComplete'] != true;
      }
      
      return true; // If no document exists, assume setup is needed
    } catch (e) {
      print('Error checking password setup status: $e');
      return true; // Default to needing setup if we can't check
    }
  }

  Future<void> _updateUserInfo(User user, bool needsPasswordSetup) async {
    try {      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoURL': user.photoURL,
        'lastSignIn': FieldValue.serverTimestamp(),
        'passwordSetupComplete': !needsPasswordSetup,
      }, SetOptions(merge: true));
      
      print('User info updated successfully');
    } catch (e) {
      print('Error updating user info: $e');
    }
  }

  Future<void> _updateUserLastSignIn(User user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'email': user.email,
        'lastSignIn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Could not update last sign in time: $e');
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled for this app';
      default:
        return 'Google sign-in failed: ${e.message}';
    }
  }

  void _handleForgotPassword() async {
    String? email = await _showEmailInputDialog();
    if (email != null && email.isNotEmpty) {
      try {
        if (!_isValidEmailDomain(email)) {
          _showErrorDialog('Only $allowedDomain email addresses are allowed');
          return;
        }
        
        await _auth.sendPasswordResetEmail(email: email);
        _showSuccessDialog('Password reset email sent to $email');
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email address';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          default:
            errorMessage = 'Failed to send reset email: ${e.message}';
        }
        _showErrorDialog(errorMessage);
      }
    }
  }

  Future<String?> _showEmailInputDialog() async {
    TextEditingController emailController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Enter your email address',
            hintText: 'example@bisu.edu.ph',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(emailController.text.trim()),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Image.asset(
                'images/proximicast_second.png',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cast,
                      size: 80,
                      color: Colors.purple,
                    ),
                  );
                },
              ),
              
              const Text(
                'Sign in to your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Username/ID Number Field
              TextField(
                controller: _usernameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'ID Number or Email',
                  hintText: 'Enter your ID or email@bisu.edu.ph',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purple, width: 2),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password Field
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purple, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Remember Me & Forgot Password Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: _isLoading ? null : (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: Colors.purple,
                      ),
                      const Text('Remember Me'),
                    ],
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _handleForgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.purple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),

              // Divider
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Or', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Google Login Button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleLogin,
                icon: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.asset(
                        'images/google_logo.jpg',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.login, color: Colors.grey);
                        },
                      ),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Domain restriction notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only $allowedDomain email addresses are allowed',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}