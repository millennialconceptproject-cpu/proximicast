import 'package:flutter/material.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Parallax background image
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double offset = 0.0;
              if (_pageController.hasClients) {
                offset = _pageController.page ?? 0.0;
              }
              
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: const AssetImage('images/landing_page.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment(0.12 + (offset * 0.69), 0.0), // Less movement
                  ),
                ),
              );
            },
          ),
          // PageView with content
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildFirstScreen(),
              _buildSecondScreen(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFirstScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0), // Adjust these values
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top dots indicator - positioned on the right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDot(isActive: true),
                const SizedBox(width: 8),
                _buildDot(isActive: false),
              ],
            ),
            const SizedBox(height: 100),
            
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SKIP LONG\nQUEUE LINES',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 248, 241, 255),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 26),
                  
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 18,
                        color: Color.fromARGB(255, 248, 241, 255),
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(text: 'With '),
                        TextSpan(
                          text: 'PROXIMICAST',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ', you\ncan check your\nattendance anytime, \nanywhere'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom navigation - positioned on the right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2BE2),
                    foregroundColor: const Color.fromARGB(255, 237, 228, 245),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 18,
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Top dots indicator - positioned on the right side
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDot(isActive: false),
                const SizedBox(width: 8),
                _buildDot(isActive: true),
              ],
            ),
            const SizedBox(height: 250),
            
            // Main content - positioned on the right side
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'SECURE AND\nCONVENIENT',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 248, 241, 255),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Cast your attendance by\ndetermining your location,\nbut with security as our top\npriority',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color.fromARGB(255, 248, 241, 255),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom navigation - positioned on the right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A2BE2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: _previousPage,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color.fromARGB(255, 237, 228, 245),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Get Started button
                ElevatedButton(
  onPressed: () {
    // Navigate to login page
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const LoginPage())
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF8A2BE2),
    foregroundColor: const Color.fromARGB(255, 237, 228, 245),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 18,
    ),
    elevation: 0,
  ),
  child: const Text(
    'GET STARTED',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    ),
  ),
),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildDot({required bool isActive}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromARGB(255, 33, 49, 80),
          width: 1,
        ),
        shape: BoxShape.circle,
        color: isActive 
          ? const Color(0xFFA855F7) 
          : Color(0xFFD8B4FE),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}