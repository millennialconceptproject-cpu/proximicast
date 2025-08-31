import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/device_lock_service.dart';

class DeviceLockHelper {
  /// Wrapper method to handle Google sign-in with device lock validation
  static Future<bool> validateAndProcessLogin({
    required BuildContext context,
    required User user,
    required VoidCallback onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Check if user is authorized for this device
      bool isAuthorized = await DeviceLockService.isUserAuthorized(user.uid);
      
      if (!isAuthorized) {
        // User not authorized, show device lock dialog
        _showDeviceLockDialog(context);
        
        // Sign out the unauthorized user
        await FirebaseAuth.instance.signOut();
        return false;
      }

      // User is authorized, proceed with success callback
      onSuccess();
      return true;

    } catch (e) {
      print('Error in device lock validation: $e');
      onError('Device validation failed. Please try again.');
      return false;
    }
  }

  /// Show device lock dialog with detailed message
  static void _showDeviceLockDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Device Security'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This device is already registered to another user account.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              'For security purposes, each device can only be used by one user account.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you own this device and need to use a different account, please contact your administrator.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          // Debug reset button (remove in production)
          if (_isDebugMode())
            TextButton(
              onPressed: () async {
                await DeviceLockService.resetDeviceLock();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device lock reset (Debug mode)'),
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

  /// Check if app is in debug mode (you can implement your own logic)
  static bool _isDebugMode() {
    // In production, return false
    // In development, you can return true or check for debug flags
    return true; // Set to false for production builds
  }

  /// Get device lock status for UI display
  static Future<Widget> buildDeviceLockStatusWidget() async {
    try {
      Map<String, dynamic> lockInfo = await DeviceLockService.getDeviceLockInfo();
      bool isLocked = lockInfo['isLocked'] ?? false;
      
      if (!isLocked) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: Colors.green[700], size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Device secured and registered',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  /// Method to handle app initialization and device lock setup
  static Future<void> initializeDeviceLock() async {
    try {
      // Check if this is first app run after installation
      bool shouldEnforce = await DeviceLockService.shouldEnforceDeviceLock();
      print('Device lock enforcement: $shouldEnforce');
      
      // Get current device lock info for logging
      Map<String, dynamic> lockInfo = await DeviceLockService.getDeviceLockInfo();
      print('Current device lock info: $lockInfo');
      
    } catch (e) {
      print('Error initializing device lock: $e');
    }
  }

  /// Method to handle user logout with device lock considerations
  static Future<void> handleLogout(BuildContext context) async {
    try {
      // Note: We don't reset device lock on logout
      // The device remains bound to the first user who completed onboarding
      await FirebaseAuth.instance.signOut();
      
      // Navigate back to login
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
      
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  /// Check device authorization status for a specific user
  static Future<bool> checkUserDeviceAuthorization(String userId) async {
    try {
      return await DeviceLockService.isUserAuthorized(userId);
    } catch (e) {
      print('Error checking user device authorization: $e');
      return false;
    }
  }
}