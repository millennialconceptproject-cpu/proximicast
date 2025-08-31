import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/user_service.dart';

class AuthWrapper extends StatelessWidget {
  final Widget loginScreen;
  final Widget onboardingScreen;
  final Widget dashboardScreen;

  const AuthWrapper({
    super.key,
    required this.loginScreen,
    required this.onboardingScreen,
    required this.dashboardScreen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.purple,
              ),
            ),
          );
        }

        // User is not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return loginScreen;
        }

        // User is logged in, determine where to redirect
        return FutureBuilder<String>(
          future: UserService.getRedirectRoute(snapshot.data!),
          builder: (context, routeSnapshot) {
            if (routeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.purple,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Setting up your account...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Handle routing based on user status
            switch (routeSnapshot.data) {
              case '/onboarding':
                return onboardingScreen;
              case '/dashboard':
                // Update last sign in time
                UserService.updateLastSignIn(snapshot.data!.uid);
                return dashboardScreen;
              default:
                return dashboardScreen;
            }
          },
        );
      },
    );
  }
}

// Alternative approach if you prefer using named routes
class AuthWrapperWithRoutes extends StatelessWidget {
  const AuthWrapperWithRoutes({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.purple)),
          );
        }

        return FutureBuilder<String>(
          future: UserService.getRedirectRoute(snapshot.data!),
          builder: (context, routeSnapshot) {
            if (routeSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.purple),
                      SizedBox(height: 16),
                      Text(
                        'Setting up your account...',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Navigate to appropriate route
            WidgetsBinding.instance.addPostFrameCallback((_) {
              String route = routeSnapshot.data ?? '/dashboard';
              if (ModalRoute.of(context)?.settings.name != route) {
                Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
              }
              
              // Update last sign in time if going to dashboard
              if (route == '/dashboard') {
                UserService.updateLastSignIn(snapshot.data!.uid);
              }
            });

            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.purple)),
            );
          },
        );
      },
    );
  }
}