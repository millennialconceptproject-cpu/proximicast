import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Google Sign In (Primary authentication method)
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

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        // Create user profile in Firestore
        await _createUserProfile(userCredential.user!);
      } else {
        // Update last login for existing user
        await _updateLastLogin(userCredential.user!);
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

  // Create user profile in Firestore for new users
  Future<void> _createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSignIn': FieldValue.serverTimestamp(),
        'onboardingComplete': false, // New users need to complete onboarding
      });
      print('New user profile created successfully');
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  // Update last login time for existing users
  Future<void> _updateLastLogin(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastSignIn': FieldValue.serverTimestamp(),
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      });
      print('User last login updated successfully');
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data['onboardingComplete'] == true;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  // Mark onboarding as complete
  Future<bool> completeOnboarding(String uid, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...userData,
        'onboardingComplete': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error completing onboarding: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      print('User signed out successfully');
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