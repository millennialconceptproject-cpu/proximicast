import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class UserAccountPopup extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onLogout; // Add logout callback
  
  const UserAccountPopup({
    Key? key,
    required this.onClose,
    this.onLogout,
  }) : super(key: key);

  @override
  State<UserAccountPopup> createState() => _UserAccountPopupState();
}

class _UserAccountPopupState extends State<UserAccountPopup> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final localUserData = await DatabaseService.getUserByUid(user.uid);
        setState(() {
          userData = localUserData;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      // Show confirmation dialog
      bool shouldLogout = await _showLogoutConfirmation();
      if (!shouldLogout) return;

      // Close the popup first
      widget.onClose();

      // Get current user before signing out
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Clear remember me preference
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('remember_me_${user.uid}');
      }

      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();
      
      // Sign out from Google Sign In
      await GoogleSignIn().signOut();
      
      // Call the logout callback if provided
      if (widget.onLogout != null) {
        widget.onLogout!();
      }
    } catch (e) {
      print('Error during logout: $e');
      // Show error message using the context that called this popup
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showLogoutConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to sign out?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _handleManageAccount() {
    // Close the popup first
    widget.onClose();
    
    // Show a snackbar for now since the feature isn't implemented
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Manage Account feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return GestureDetector(
      onTap: widget.onClose,
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping the popup itself
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.only(top: 70, right: 16),
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header section with user info
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Profile image (larger version)
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                      ? Image.network(
                                          user.photoURL!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[100],
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.grey,
                                                size: 30,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[100],
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.grey,
                                            size: 30,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // User details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userData?['displayName']?.isNotEmpty == true
                                          ? userData!['displayName']
                                          : '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}'.trim().isEmpty
                                              ? 'User'
                                              : '${userData!['firstName']} ${userData!['lastName']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userData?['email'] ?? user?.email ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (userData?['studentIdNumber'] != null && userData!['studentIdNumber'].isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: ${userData!['studentIdNumber']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Divider
                        Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        
                        // Action buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              // Manage Account button
                              InkWell(
                                onTap: _handleManageAccount,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.settings_outlined,
                                        size: 20,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Manage Account',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Logout button
                              InkWell(
                                onTap: _handleLogout,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.logout_outlined,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Logout',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
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
      ),
    );
  }
}