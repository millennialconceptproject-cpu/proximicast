import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/user_service.dart';
import 'services/device_lock_service.dart';
import 'services/database_service.dart'; // Import the SQLite service
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _rememberMe = true; // Default to true for Google sign-in
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
        // Check device lock authorization first
        bool isAuthorized = await DeviceLockService.isUserAuthorized(currentUser.uid);
        if (!isAuthorized) {
          print('User not authorized for this device, signing out');
          await _auth.signOut();
          await _googleSignIn.signOut();
          _showDeviceLockDialog();
          return;
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool rememberMe = prefs.getBool('remember_me_${currentUser.uid}') ?? false;
        
        if (rememberMe) {
          print('Auto-login enabled, checking onboarding status...');
          
          // Check if user has completed onboarding
          bool hasCompletedOnboarding = await UserService.hasCompletedOnboarding(currentUser.uid);
          
          if (hasCompletedOnboarding) {
            // Check if user data exists in local database
            bool userExistsLocally = await DatabaseService.userExists(currentUser.uid);
            
            if (!userExistsLocally) {
              print('User data not found locally, fetching from Firestore...');
              try {
                await DatabaseService.fetchAndStoreUserFromFirestore(currentUser.uid);
                print('User data fetched and stored locally');
              } catch (e) {
                print('Error fetching user data from Firestore: $e');
                // Continue to dashboard anyway, user might need to re-onboard
              }
            } else {
              print('User data found in local database');
            }
            
            // Update last sign in and go to dashboard
            await UserService.updateLastSignIn(currentUser.uid);
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/dashboard', 
              (route) => false, // Remove all previous routes
            );
          } else {
            // User needs to complete onboarding
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/onboarding', 
              (route) => false, // Remove all previous routes
            );
          }
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

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(googleCredential);
      final user = userCredential.user!;
      print("Google sign-in successful: ${user.email}");

      // CHECK DEVICE LOCK AUTHORIZATION BEFORE PROCEEDING
      bool isAuthorized = await DeviceLockService.isUserAuthorized(user.uid);
      if (!isAuthorized) {
        print('User not authorized for this device');
        // Sign out the user immediately
        await _auth.signOut();
        await _googleSignIn.signOut();
        _showDeviceLockDialog();
        return;
      }

      // Handle successful login (device authorization passed)
      await _handleSuccessfulLogin(user, userCredential.additionalUserInfo?.isNewUser ?? false);

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

  // Handle successful login
  Future<void> _handleSuccessfulLogin(User user, bool isNewUser) async {
    try {
      // Save Remember Me preference
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me_${user.uid}', _rememberMe);
      
      // Update or create user basic info in Firestore
      await _updateUserBasicInfo(user, isNewUser);
      
      // Check if user has completed onboarding (personal and academic info)
      bool hasCompletedOnboarding = await UserService.hasCompletedOnboarding(user.uid);
      
      if (hasCompletedOnboarding) {
        print('User has completed onboarding, checking local database...');
        
        // Check if user data exists in local database
        bool userExistsLocally = await DatabaseService.userExists(user.uid);
        
        if (!userExistsLocally) {
          print('User data not found locally, fetching from Firestore...');
          try {
            await DatabaseService.fetchAndStoreUserFromFirestore(user.uid);
            print('User data fetched and stored locally');
          } catch (e) {
            print('Error fetching user data from Firestore: $e');
            // Show error but continue to dashboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to sync user data. Some features may be limited.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          print('User data found in local database');
        }
        
        // Update last sign in time
        await UserService.updateLastSignIn(user.uid);
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/dashboard', 
          (route) => false, // Remove all previous routes
        );
      } else {
        print('User needs to complete onboarding, going to onboarding screen');
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/onboarding', 
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      print('Error in handleSuccessfulLogin: $e');
      _showErrorDialog('An error occurred while setting up your account. Please try again.');
    }
  }

  Future<void> _updateUserBasicInfo(User user, bool isNewUser) async {
    try {
      Map<String, dynamic> userData = {
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoURL': user.photoURL,
        'lastSignIn': FieldValue.serverTimestamp(),
      };

      if (isNewUser) {
        userData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'onboardingComplete': false, // New users need to complete onboarding
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));
      
      print('User basic info updated successfully');
    } catch (e) {
      print('Error updating user basic info: $e');
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

  void _showDeviceLockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Device Locked'),
          ],
        ),
        content: const Text(
          'This device is already registered to another user account. Each device can only be used by one user for security purposes.\n\nIf you are the device owner and need to reset this restriction, please contact your administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
          // Optional: Add a debug button for development (remove in production)
          if (false) // Set to false in production
            TextButton(
              onPressed: () async {
                await DeviceLockService.resetDeviceLock();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device lock reset for testing'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: Text(
                'Reset (Debug)',
                style: TextStyle(color: Colors.orange[700]),
              ),
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
                width: 200,
                height: 200,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
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
              
              const SizedBox(height: 20),
              
              Text(
                'Attendance?\nNow at your Fingertips!',
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                  height: 1.0,
                ),
              ),
              
              const SizedBox(height: 12),
              
              const SizedBox(height: 30),

              // Google Login Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleLogin,
                icon: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Image.asset(
                        'images/google_logo.jpg',
                        height: 24,
                        width: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.login, color: Colors.white);
                        },
                      ),
                label: Text(
                  _isLoading ? 'Signing in...' : 'Continue with Google',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 4),

              // Remember Me Checkbox
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
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
                  const Text(
                    'Remember Me',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Domain restriction notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.purple[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Only $allowedDomain email addresses are allowed',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontSize: 14,
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