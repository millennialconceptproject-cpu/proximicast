import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user has completed onboarding (personal and academic info)
  static Future<bool> hasCompletedOnboarding(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return false;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if onboarding is explicitly marked as complete
      bool onboardingComplete = userData['onboardingComplete'] == true;
      
      // Also verify that both personal and academic info exist
      bool hasPersonalInfo = userData['personalInfo'] != null;
      bool hasAcademicInfo = userData['academicInfo'] != null;
      
      return onboardingComplete && hasPersonalInfo && hasAcademicInfo;
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

  // Save user's personal and academic information
  static Future<bool> saveOnboardingData(String uid, Map<String, dynamic> personalInfo, Map<String, dynamic> academicInfo) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'personalInfo': personalInfo,
        'academicInfo': academicInfo,
        'onboardingComplete': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      print('Error saving onboarding data: $e');
      return false;
    }
  }

  // Get user's personal information
  static Future<Map<String, dynamic>?> getPersonalInfo(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return null;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['personalInfo'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting personal info: $e');
      return null;
    }
  }

  // Get user's academic information
  static Future<Map<String, dynamic>?> getAcademicInfo(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return null;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['academicInfo'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting academic info: $e');
      return null;
    }
  }
}

// Extension to make UserService easier to use with FirebaseAuth
extension UserExtension on User {
  Future<bool> hasCompletedOnboarding() async {
    return await UserService.hasCompletedOnboarding(uid);
  }

  Future<String> getRedirectRoute() async {
    return await UserService.getRedirectRoute(this);
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    return await UserService.getUserInfo(uid);
  }

  Future<Map<String, dynamic>?> getPersonalInfo() async {
    return await UserService.getPersonalInfo(uid);
  }

  Future<Map<String, dynamic>?> getAcademicInfo() async {
    return await UserService.getAcademicInfo(uid);
  }
}