import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user has completed password setup
  static Future<bool> hasCompletedPasswordSetup(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return false;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['passwordSetupComplete'] == true || userData['passwordSet'] == true;
    } catch (e) {
      print('Error checking password setup status: $e');
      return false;
    }
  }

  // Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return false;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['onboardingComplete'] == true;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  // Get user's complete information
  static Future<Map<String, dynamic>?> getUserInfo(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return null;
      
      return userDoc.data() as Map<String, dynamic>;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  // Determine where to redirect user based on their status
  static Future<String> getRedirectRoute(User user) async {
    try {
      // Check password setup first
      bool passwordSetup = await hasCompletedPasswordSetup(user.uid);
      if (!passwordSetup) {
        return '/interrupt'; // Need to set password first
      }

      // Check onboarding completion
      bool onboardingComplete = await hasCompletedOnboarding(user.uid);
      if (!onboardingComplete) {
        return '/onboarding'; // Need to complete onboarding
      }

      // Everything is complete, go to dashboard
      return '/dashboard';
    } catch (e) {
      print('Error determining redirect route: $e');
      return '/dashboard'; // Default fallback
    }
  }

  // Update user's last sign in time
  static Future<void> updateLastSignIn(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastSignIn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last sign in: $e');
    }
  }
}

// Extension to make UserService easier to use with FirebaseAuth
extension UserExtension on User {
  Future<bool> hasCompletedPasswordSetup() async {
    return await UserService.hasCompletedPasswordSetup(uid);
  }

  Future<bool> hasCompletedOnboarding() async {
    return await UserService.hasCompletedOnboarding(uid);
  }

  Future<String> getRedirectRoute() async {
    return await UserService.getRedirectRoute(this);
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    return await UserService.getUserInfo(uid);
  }
}