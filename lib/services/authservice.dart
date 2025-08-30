import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String allowedDomain = '@bisu.edu.ph';

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Validate email domain
  bool isValidEmailDomain(String email) {
    return email.toLowerCase().endsWith(allowedDomain.toLowerCase());
  }

  // Generate secure random password
  String generateSecurePassword() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final Random random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      // Add domain if not present
      if (!email.contains('@')) {
        email = '$email$allowedDomain';
      }

      if (!isValidEmailDomain(email)) {
        throw FirebaseAuthException(
          code: 'invalid-domain',
          message: 'Only $allowedDomain email addresses are allowed',
        );
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign In
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return AuthResult(
          success: false,
          message: 'Sign in cancelled',
          isNewUser: false,
        );
      }

      if (!isValidEmailDomain(googleUser.email)) {
        await _googleSignIn.signOut();
        return AuthResult(
          success: false,
          message: 'Only $allowedDomain email addresses are allowed',
          isNewUser: false,
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if user already exists with email/password
      final signInMethods = await _auth.fetchSignInMethodsForEmail(googleUser.email);
      if (signInMethods.isNotEmpty && signInMethods.contains('password')) {
        await _googleSignIn.signOut();
        return AuthResult(
          success: false,
          message: 'An account with this email already exists. Please sign in with your password instead.',
          isNewUser: false,
        );
      }

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Create user profile in Firestore
        await _createUserProfile(userCredential.user!);
      }

      return AuthResult(
        success: true,
        message: 'Sign in successful',
        isNewUser: isNewUser,
        userCredential: userCredential,
      );

    } on FirebaseAuthException catch (e) {
      await _googleSignIn.signOut();
      return AuthResult(
        success: false,
        message: _getAuthErrorMessage(e),
        isNewUser: false,
      );
    } catch (e) {
      await _googleSignIn.signOut();
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
        isNewUser: false,
      );
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'passwordSet': false, // Indicates if user has set a permanent password
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  // Update password and mark as set
  Future<bool> updatePassword(String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      await user.updatePassword(newPassword);
      
      // Update Firestore to indicate password has been set
      await _firestore.collection('users').doc(user.uid).update({
        'passwordSet': true,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  // Check if user needs to set password
  // In authservice.dart - Replace the needsPasswordSetup method

// Check if user needs to set password
Future<bool> needsPasswordSetup() async {
  try {
    User? user = _auth.currentUser;
    if (user == null) return false;

    DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return true;  // If no document exists, assume setup is needed

    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Check both field names for backward compatibility
    bool passwordSetupComplete = data['passwordSetupComplete'] ?? false;
    bool passwordSet = data['passwordSet'] ?? false;
    
    // Return true if NEITHER field indicates completion
    return !(passwordSetupComplete || passwordSet);
  } catch (e) {
    print('Error checking password setup status: $e');
    return true; // Default to needing setup if we can't check
  }
}

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      if (!isValidEmailDomain(email)) {
        throw FirebaseAuthException(
          code: 'invalid-domain',
          message: 'Only $allowedDomain email addresses are allowed',
        );
      }

      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  // Delete account
  Future<bool> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete the user account
      await user.delete();
      
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  // Get readable error message
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'weak-password':
        return 'The password provided is too weak';
      case 'requires-recent-login':
        return 'Please sign in again to update your password';
      case 'invalid-domain':
        return e.message ?? 'Invalid email domain';
      default:
        return e.message ?? 'An unexpected error occurred';
    }
  }
}

// Result class for authentication operations
class AuthResult {
  final bool success;
  final String message;
  final bool isNewUser;
  final UserCredential? userCredential;

  AuthResult({
    required this.success,
    required this.message,
    required this.isNewUser,
    this.userCredential,
  });
}