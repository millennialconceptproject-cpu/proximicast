import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

class UserServiceHelper {
  
  // Get current user data from local database
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;
    
    return await DatabaseService.getUserByUid(currentUser.uid);
  }

  // Get user's full name from local database
  static Future<String> getCurrentUserFullName() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    if (userData == null) return 'User';
    
    String firstName = userData['firstName'] ?? '';
    String lastName = userData['lastName'] ?? '';
    String middleName = userData['middleName'] ?? '';
    
    if (firstName.isEmpty && lastName.isEmpty) return 'User';
    
    if (middleName.isNotEmpty) {
      return '$firstName $middleName $lastName';
    } else {
      return '$firstName $lastName';
    }
  }

  // Get user's student ID from local database
  static Future<String?> getCurrentUserStudentId() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    return userData?['studentIdNumber'];
  }

  // Get user's program from local database
  static Future<String?> getCurrentUserProgram() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    return userData?['program'];
  }

  // Get user's year and block from local database
  static Future<String?> getCurrentUserYearAndBlock() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    if (userData == null) return null;
    
    String year = userData['year'] ?? '';
    String block = userData['block'] ?? '';
    
    if (year.isEmpty || block.isEmpty) return null;
    
    return '$year - Block $block';
  }

  // Check if user data exists locally (for offline functionality)
  static Future<bool> hasLocalUserData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    
    return await DatabaseService.userExists(currentUser.uid);
  }

  // Refresh user data from Firestore to local database
  static Future<bool> refreshUserDataFromFirestore() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      
      await DatabaseService.fetchAndStoreUserFromFirestore(currentUser.uid);
      return true;
    } catch (e) {
      print('Error refreshing user data: $e');
      return false;
    }
  }

  // Clear user data on sign out
  static Future<void> clearUserDataOnSignOut() async {
    try {
      await DatabaseService.clearAllUsers();
      print('User data cleared from local database');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  // Get user's academic info as a formatted string
  static Future<Map<String, String?>> getCurrentUserAcademicInfo() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    if (userData == null) {
      return {
        'studentId': null,
        'program': null,
        'year': null,
        'block': null,
        'yearAndBlock': null,
      };
    }
    
    String year = userData['year'] ?? '';
    String block = userData['block'] ?? '';
    String yearAndBlock = '';
    
    if (year.isNotEmpty && block.isNotEmpty) {
      yearAndBlock = '$year - Block $block';
    }
    
    return {
      'studentId': userData['studentIdNumber'],
      'program': userData['program'],
      'year': userData['year'],
      'block': userData['block'],
      'yearAndBlock': yearAndBlock.isNotEmpty ? yearAndBlock : null,
    };
  }

  // Get user's personal info
  static Future<Map<String, String?>> getCurrentUserPersonalInfo() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    if (userData == null) {
      return {
        'firstName': null,
        'lastName': null,
        'middleName': null,
        'fullName': null,
        'email': null,
      };
    }
    
    String firstName = userData['firstName'] ?? '';
    String lastName = userData['lastName'] ?? '';
    String middleName = userData['middleName'] ?? '';
    String fullName = '';
    
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      if (middleName.isNotEmpty) {
        fullName = '$firstName $middleName $lastName';
      } else {
        fullName = '$firstName $lastName';
      }
    }
    
    return {
      'firstName': userData['firstName'],
      'lastName': userData['lastName'],
      'middleName': userData['middleName'],
      'fullName': fullName.isNotEmpty ? fullName : null,
      'email': userData['email'],
    };
  }

  // Update local user data (useful for profile updates)
  static Future<bool> updateLocalUserData(Map<String, dynamic> updates) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Get current user data
      Map<String, dynamic>? currentData = await DatabaseService.getUserByUid(currentUser.uid);
      if (currentData == null) return false;

      // Merge updates with current data
      Map<String, dynamic> updatedData = Map.from(currentData);
      updatedData.addAll(updates);

      // Update in database
      await DatabaseService.insertOrUpdateUser(
        uid: currentUser.uid,
        email: updatedData['email'] ?? '',
        firstName: updatedData['firstName'] ?? '',
        lastName: updatedData['lastName'] ?? '',
        middleName: updatedData['middleName'],
        studentIdNumber: updatedData['studentIdNumber'] ?? '',
        program: updatedData['program'] ?? '',
        year: updatedData['year'] ?? '',
        block: updatedData['block'] ?? '',
        displayName: updatedData['displayName'],
        photoURL: updatedData['photoURL'],
      );

      return true;
    } catch (e) {
      print('Error updating local user data: $e');
      return false;
    }
  }

  // Get database info for debugging
  static Future<Map<String, dynamic>> getLocalDatabaseInfo() async {
    return await DatabaseService.getDatabaseInfo();
  }

  // Validate if user data is complete
  static Future<bool> isUserDataComplete() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    if (userData == null) return false;

    // Check required fields
    List<String> requiredFields = [
      'firstName',
      'lastName',
      'studentIdNumber',
      'program',
      'year',
      'block'
    ];

    for (String field in requiredFields) {
      if (userData[field] == null || userData[field].toString().isEmpty) {
        return false;
      }
    }

    return true;
  }

  // Get user profile summary for display
  static Future<Map<String, String>> getUserProfileSummary() async {
    Map<String, dynamic>? userData = await getCurrentUserData();
    
    if (userData == null) {
      return {
        'status': 'No user data found',
        'fullName': 'Unknown User',
        'email': 'No email',
        'studentId': 'No ID',
        'program': 'No program',
        'yearBlock': 'No year/block',
      };
    }

    String firstName = userData['firstName'] ?? '';
    String lastName = userData['lastName'] ?? '';
    String middleName = userData['middleName'] ?? '';
    String fullName = '';

    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      if (middleName.isNotEmpty) {
        fullName = '$firstName $middleName $lastName';
      } else {
        fullName = '$firstName $lastName';
      }
    }

    String year = userData['year'] ?? '';
    String block = userData['block'] ?? '';
    String yearBlock = '';
    if (year.isNotEmpty && block.isNotEmpty) {
      yearBlock = '$year - Block $block';
    }

    return {
      'status': 'Complete',
      'fullName': fullName.isNotEmpty ? fullName : 'Unknown User',
      'email': userData['email'] ?? 'No email',
      'studentId': userData['studentIdNumber'] ?? 'No ID',
      'program': userData['program'] ?? 'No program',
      'yearBlock': yearBlock.isNotEmpty ? yearBlock : 'No year/block',
    };
  }
}