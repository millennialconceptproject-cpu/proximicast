import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';
import 'event_service.dart';

class InitializationService {
  
  static Future<void> initializeApp() async {
    try {
      // Check if user is authenticated
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        print('User is authenticated: ${currentUser.uid}');
        
        // Initialize user data (only if not already exists to avoid overwriting)
        await _initializeUserData(currentUser.uid);
        
        // Initialize event data
        await _initializeEventData();
        
        print('App initialization completed successfully');
      } else {
        print('User is not authenticated');
        // Still try to get cached event data for offline use
        await _initializeEventData();
      }
    } catch (e) {
      print('Error during app initialization: $e');
      // Don't throw here - allow app to continue with existing local data
    }
  }
  
  static Future<void> _initializeUserData(String uid) async {
    try {
      // Check if user exists in local database
      bool userExists = await DatabaseService.userExists(uid);
      
      if (!userExists) {
        // Only fetch if user doesn't exist locally
        // Your existing UserService.hasCompletedOnboarding already handles this
        print('User data will be handled by existing UserService flow');
      } else {
        print('User already exists in local database');
      }
    } catch (e) {
      print('Error initializing user data: $e');
    }
  }
  
  static Future<void> _initializeEventData() async {
    try {
      // Sync events and locations data
      await EventService.syncEventData();
    } catch (e) {
      print('Error initializing event data: $e');
      // This is acceptable - app can work with cached data
    }
  }
  
  static Future<void> refreshData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Refresh event data (user data is handled by existing services)
        await EventService.syncEventData();
        
        print('Data refresh completed successfully');
      }
    } catch (e) {
      print('Error during data refresh: $e');
      throw e;
    }
  }
  
  static Future<void> clearLocalData() async {
    try {
      await DatabaseService.clearAllUsers();
      await DatabaseService.clearAllEvents();
      await DatabaseService.clearAllLocations();
      print('Local data cleared successfully');
    } catch (e) {
      print('Error clearing local data: $e');
      throw e;
    }
  }
  
  // Helper method to check if we have any event data locally
  static Future<bool> hasLocalEventData() async {
    try {
      final events = await DatabaseService.getAllEvents();
      return events.isNotEmpty;
    } catch (e) {
      print('Error checking local event data: $e');
      return false;
    }
  }
}