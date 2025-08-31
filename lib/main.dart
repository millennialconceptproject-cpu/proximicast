import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import your pages
import 'landing_page.dart';
import 'login_page.dart';
import 'dashboard.dart';
import 'services/authservice.dart';
import 'user_onboarding_container.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    runApp(const ProximicastApp());
  } catch (e) {
    print('Firebase initialization error: $e');
    // Run app without Firebase for development
    runApp(const ProximicastApp());
  }
}

class ProximicastApp extends StatelessWidget {
  const ProximicastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximicast',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/onboarding': (context) => const UserOnboardingContainer(),
        '/dashboard': (context) => const Dashboard(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _firebaseInitialized = false;
  String _statusMessage = 'Initializing app...';

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start the fade animation
    _animationController.forward();

    // Check Firebase initialization and navigate accordingly
    _initializeAndNavigate();
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }

  Future<void> _initializeAndNavigate() async {
    // Wait for animation to complete and minimum splash duration
    await Future.wait([
      _animationController.forward(),
      Future.delayed(const Duration(seconds: 2)),
    ]);

    if (!mounted) return;

    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isNotEmpty) {
        _firebaseInitialized = true;
        _updateStatus('Checking authentication...');
        
        // Check authentication state
        User? currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser != null) {
          // Refresh user data
          await currentUser.reload();
          currentUser = FirebaseAuth.instance.currentUser;

          if (currentUser == null) {
            _navigateToLanding();
            return;
          }

          // Check if user has remember me enabled
          SharedPreferences prefs = await SharedPreferences.getInstance();
          bool rememberMe = prefs.getBool('remember_me_${currentUser.uid}') ?? false;
          
          if (!rememberMe) {
            // User doesn't want to be remembered, sign them out and go to landing
            await FirebaseAuth.instance.signOut();
            await GoogleSignIn().signOut();
            _navigateToLanding();
            return;
          }
          
          _updateStatus('Checking account setup...');
          
          // Check if user has completed onboarding
          bool hasCompletedOnboarding = await UserService.hasCompletedOnboarding(currentUser.uid);
          
          if (!hasCompletedOnboarding) {
            _updateStatus('Completing account setup...');
            _navigateToOnboarding();
          } else {
            _updateStatus('Welcome back!');
            // Update last sign in time
            await UserService.updateLastSignIn(currentUser.uid);
            _navigateToDashboard();
          }
        } else {
          // No user signed in, go to landing page
          _updateStatus('Ready to start...');
          _navigateToLanding();
        }
      } else {
        // Firebase not initialized, go to landing page
        _updateStatus('Ready to start...');
        _navigateToLanding();
      }
    } catch (e) {
      print('Error checking auth state: $e');
      _updateStatus('Something went wrong...');
      // On error, go to landing page after a brief delay
      await Future.delayed(const Duration(seconds: 1));
      _navigateToLanding();
    }
  }

  void _navigateToLanding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LandingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const UserOnboardingContainer(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const Dashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8A2BE2), // BlueViolet
              Color(0xFF9932CC), // DarkOrchid
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Your logo and text image goes here
              Image.asset(
                'images/proximicast_logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image doesn't exist
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cast,
                          color: Colors.white,
                          size: 80,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'ProximiCast',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              // Loading indicator with status text
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
              const SizedBox(height: 20),
              // Dynamic status message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusMessage,
                  key: ValueKey<String>(_statusMessage),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}