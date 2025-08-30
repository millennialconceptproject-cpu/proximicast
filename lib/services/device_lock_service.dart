import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeviceLockService {
  static const String _deviceUserKey = 'device_bound_user_id';
  static const String _deviceLockEnabledKey = 'device_lock_enabled';

  /// Check if this device is locked to a specific user
  static Future<bool> isDeviceLocked() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? boundUserId = prefs.getString(_deviceUserKey);
      bool lockEnabled = prefs.getBool(_deviceLockEnabledKey) ?? false;
      
      return lockEnabled && boundUserId != null && boundUserId.isNotEmpty;
    } catch (e) {
      print('Error checking device lock status: $e');
      return false;
    }
  }

  /// Get the user ID that this device is bound to
  static Future<String?> getBoundUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deviceUserKey);
    } catch (e) {
      print('Error getting bound user ID: $e');
      return null;
    }
  }

  /// Bind this device to a specific user (first time setup)
  static Future<void> bindDeviceToUser(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceUserKey, userId);
      await prefs.setBool(_deviceLockEnabledKey, true);
      print('Device successfully bound to user: $userId');
    } catch (e) {
      print('Error binding device to user: $e');
      throw Exception('Failed to bind device to user');
    }
  }

  /// Check if the current user is authorized to use this device
  static Future<bool> isUserAuthorized(String userId) async {
    try {
      bool deviceLocked = await isDeviceLocked();
      
      if (!deviceLocked) {
        // Device not locked yet, authorize any user and bind device
        await bindDeviceToUser(userId);
        return true;
      }

      // Device is locked, check if user matches
      String? boundUserId = await getBoundUserId();
      bool authorized = boundUserId == userId;
      
      print('Device lock check - Bound User: $boundUserId, Current User: $userId, Authorized: $authorized');
      return authorized;
    } catch (e) {
      print('Error checking user authorization: $e');
      return false;
    }
  }

  /// Reset device lock (for testing or admin purposes)
  static Future<void> resetDeviceLock() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceUserKey);
      await prefs.remove(_deviceLockEnabledKey);
      print('Device lock reset successfully');
    } catch (e) {
      print('Error resetting device lock: $e');
    }
  }

  /// Get device lock info for debugging
  static Future<Map<String, dynamic>> getDeviceLockInfo() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return {
        'isLocked': await isDeviceLocked(),
        'boundUserId': prefs.getString(_deviceUserKey),
        'lockEnabled': prefs.getBool(_deviceLockEnabledKey) ?? false,
      };
    } catch (e) {
      print('Error getting device lock info: $e');
      return {};
    }
  }

  /// Check if device lock should be enforced based on app installation state
  static Future<bool> shouldEnforceDeviceLock() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Check if this is first time opening the app
      bool isFirstRun = prefs.getBool('is_first_run') ?? true;
      
      if (isFirstRun) {
        // Mark as not first run anymore
        await prefs.setBool('is_first_run', false);
        // Don't enforce lock on first run
        return false;
      }
      
      // For subsequent runs, enforce if device is locked
      return await isDeviceLocked();
    } catch (e) {
      print('Error checking device lock enforcement: $e');
      return false;
    }
  }
}