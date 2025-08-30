import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_onboarding_container.dart';

class InterruptScreen extends StatefulWidget {
  const InterruptScreen({super.key});

  @override
  _InterruptScreenState createState() => _InterruptScreenState();
}

class _InterruptScreenState extends State<InterruptScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordStrong() {
    return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (!_isPasswordStrong()) {
      return 'Please meet all password requirements';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _setupPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showErrorDialog('No user found. Please sign in again.');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      String newPassword = _passwordController.text;
      String userEmail = currentUser.email!;
      
      // Check current authentication providers
      List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(userEmail);
      bool hasPasswordProvider = signInMethods.contains('password');
      
      if (hasPasswordProvider) {
        // User already has email/password, just update the password
        await currentUser.updatePassword(newPassword);
        print('Password updated for existing email/password account');
      } else {
        // User only has Google auth, need to link email/password provider
        AuthCredential emailCredential = EmailAuthProvider.credential(
          email: userEmail,
          password: newPassword,
        );
        
        try {
          await currentUser.linkWithCredential(emailCredential);
          print('Successfully linked email/password provider to Google account');
        } catch (e) {
          if (e is FirebaseAuthException && e.code == 'provider-already-linked') {
            // This shouldn't happen, but if it does, just update the password
            await currentUser.updatePassword(newPassword);
            print('Provider was already linked, updated password instead');
          } else {
            throw e;
          }
        }
      }
      
      // Mark password setup as complete in Firestore
      await _markPasswordSetupComplete(currentUser.uid);
      
      // Reload user to get updated provider data
      await currentUser.reload();
      
      // Show success message and navigate
      _showSuccessDialog(
  'Password Setup Complete!',
  'Your account is now secure with your new password. Let\'s complete your profile setup.',
  () {
    // Navigate to user onboarding instead of dashboard
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const UserOnboardingContainer(),
      ),
    );
  },
);
      
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please sign in again to update your password';
          await _handleReauthRequired();
          return;
        case 'email-already-in-use':
          errorMessage = 'An account with this email already exists';
          break;
        case 'credential-already-in-use':
          errorMessage = 'These credentials are already associated with another account';
          break;
        default:
          errorMessage = 'Failed to setup password: ${e.message}';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      print('Unexpected error in password setup: $e');
      _showErrorDialog('An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReauthRequired() async {
    // User needs to reauthenticate - sign out and redirect to login
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // In interruptscreen.dart - Replace the _markPasswordSetupComplete method

Future<void> _markPasswordSetupComplete(String uid) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
      'passwordSetupComplete': true,
      'passwordSet': true,  // Add this line for consistency with AuthService
      'passwordSetupDate': FieldValue.serverTimestamp(),
      'authProviders': FieldValue.arrayUnion(['google.com', 'password']),
    }, SetOptions(merge: true));  // Use merge: true to avoid overwriting existing fields
    print('Password setup marked as complete for user: $uid');
  } catch (e) {
    print('Error marking password setup complete: $e');
    // Don't throw - this is not critical for the authentication flow
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

  void _showSuccessDialog(String title, String message, VoidCallback onOk) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOk();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isMet ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    
    return WillPopScope(
      onWillPop: () async {
        // Prevent going back - user must set password
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome message
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.security,
                          color: Colors.purple,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Complete Account Setup',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hello ${currentUser?.displayName ?? currentUser?.email?.split('@')[0]}!',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'To secure your account and enable email/password login, please create a password.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    onChanged: _checkPasswordStrength,
                    validator: _validatePassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
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

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    enabled: !_isLoading,
                    obscureText: _obscureConfirmPassword,
                    validator: _validateConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
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
                  const SizedBox(height: 24),

                  // Password Requirements
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Password Requirements:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPasswordRequirement('At least 8 characters', _hasMinLength),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('At least one uppercase letter', _hasUppercase),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('At least one lowercase letter', _hasLowercase),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('At least one number', _hasNumber),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('At least one special character', _hasSpecialChar),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Set Password Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _setupPassword,
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
                            'Complete Setup',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Security notice
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
                            'After setup, you can sign in using either Google or your email/password.',
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
        ),
      ),
    );
  }
}