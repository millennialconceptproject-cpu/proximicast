import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Data models for storing user information
class PersonalInfo {
  String firstName;
  String lastName;
  String middleName;
  DateTime? birthdate;
  String contactNumber;

  PersonalInfo({
    this.firstName = '',
    this.lastName = '',
    this.middleName = '',
    this.birthdate,
    this.contactNumber = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'birthdate': birthdate != null ? Timestamp.fromDate(birthdate!) : null,
      'contactNumber': contactNumber,
    };
  }
}

class AcademicInfo {
  String idNumber;
  String program;
  String year;
  String block;

  AcademicInfo({
    this.idNumber = '',
    this.program = '',
    this.year = '',
    this.block = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'idNumber': idNumber,
      'program': program,
      'year': year,
      'block': block,
    };
  }
}

class UserOnboardingContainer extends StatefulWidget {
  const UserOnboardingContainer({super.key});

  @override
  _UserOnboardingContainerState createState() => _UserOnboardingContainerState();
}

class _UserOnboardingContainerState extends State<UserOnboardingContainer> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Data storage
  final PersonalInfo _personalInfo = PersonalInfo();
  final AcademicInfo _academicInfo = AcademicInfo();
  
  // Form keys for validation
  final GlobalKey<FormState> _personalFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _academicFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      // Validate personal info before proceeding
      if (_personalFormKey.currentState!.validate()) {
        _personalFormKey.currentState!.save();
        _goToNextPage();
      }
    } else if (_currentPage == 1) {
      // Validate academic info before proceeding
      if (_academicFormKey.currentState!.validate()) {
        _academicFormKey.currentState!.save();
        _goToNextPage();
      }
    }
  }

  void _goToNextPage() {
    if (_currentPage < 2) {
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

  Future<void> _submitAllData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Prepare data for Firestore
      Map<String, dynamic> userData = {
        'personalInfo': _personalInfo.toMap(),
        'academicInfo': _academicInfo.toMap(),
        'onboardingComplete': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      };

      // Update user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(userData, SetOptions(merge: true));

      print('User onboarding data saved successfully');

      // Navigate to dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');

    } catch (e) {
      print('Error saving user data: $e');
      _showErrorDialog('Failed to save user information. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentPage > 0) {
          _previousPage();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                          decoration: BoxDecoration(
                            color: i <= _currentPage ? Colors.purple : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    PersonalInfoScreen(
                      formKey: _personalFormKey,
                      personalInfo: _personalInfo,
                    ),
                    AcademicInfoScreen(
                      formKey: _academicFormKey,
                      academicInfo: _academicInfo,
                    ),
                    CompletionScreen(
                      onComplete: _submitAllData,
                    ),
                  ],
                ),
              ),

              // Navigation buttons (only for first two pages)
              if (_currentPage < 2)
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.purple),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(color: Colors.purple),
                            ),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }
}

// Personal Information Screen
class PersonalInfoScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final PersonalInfo personalInfo;

  const PersonalInfoScreen({
    super.key,
    required this.formKey,
    required this.personalInfo,
  });

  @override
  _PersonalInfoScreenState createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _firstNameController.text = widget.personalInfo.firstName;
    _lastNameController.text = widget.personalInfo.lastName;
    _middleNameController.text = widget.personalInfo.middleName;
    _contactController.text = widget.personalInfo.contactNumber;
    if (widget.personalInfo.birthdate != null) {
      _birthdateController.text = "${widget.personalInfo.birthdate!.day}/${widget.personalInfo.birthdate!.month}/${widget.personalInfo.birthdate!.year}";
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _contactController.dispose();
    _birthdateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.personalInfo.birthdate ?? DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.purple),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        widget.personalInfo.birthdate = picked;
        _birthdateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.person,
                    color: Colors.purple,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please provide your personal details',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // First Name
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'First name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'First name must be at least 2 characters';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.personalInfo.firstName = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Last name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'Last name must be at least 2 characters';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.personalInfo.lastName = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Middle Name
                    TextFormField(
                      controller: _middleNameController,
                      decoration: InputDecoration(
                        labelText: 'Middle Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      onSaved: (value) => widget.personalInfo.middleName = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Birthdate
                    TextFormField(
                      controller: _birthdateController,
                      readOnly: true,
                      onTap: _selectDate,
                      decoration: InputDecoration(
                        labelText: 'Birthdate *',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (widget.personalInfo.birthdate == null) {
                          return 'Birthdate is required';
                        }
                        // Check if user is at least 13 years old
                        final now = DateTime.now();
                        final age = now.difference(widget.personalInfo.birthdate!).inDays / 365.25;
                        if (age < 13) {
                          return 'You must be at least 13 years old';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Number
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Contact Number *',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Contact number is required';
                        }
                        // Basic Philippine mobile number validation
                        String cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
                        if (cleaned.length < 10 || cleaned.length > 13) {
                          return 'Please enter a valid contact number';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.personalInfo.contactNumber = value?.trim() ?? '',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Academic Information Screen
class AcademicInfoScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final AcademicInfo academicInfo;

  const AcademicInfoScreen({
    super.key,
    required this.formKey,
    required this.academicInfo,
  });

  @override
  _AcademicInfoScreenState createState() => _AcademicInfoScreenState();
}

class _AcademicInfoScreenState extends State<AcademicInfoScreen> {
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _programController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _blockController = TextEditingController();

  final List<String> _yearLevels = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    _idNumberController.text = widget.academicInfo.idNumber;
    _programController.text = widget.academicInfo.program;
    _blockController.text = widget.academicInfo.block;
    _selectedYear = widget.academicInfo.year.isNotEmpty ? widget.academicInfo.year : null;
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _programController.dispose();
    _yearController.dispose();
    _blockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.school,
                    color: Colors.purple,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Academic Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please provide your academic details',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ID Number
                    TextFormField(
                      controller: _idNumberController,
                      decoration: InputDecoration(
                        labelText: 'Student ID Number *',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Student ID is required';
                        }
                        if (value.trim().length < 6) {
                          return 'Please enter a valid student ID';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.academicInfo.idNumber = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Program
                    TextFormField(
                      controller: _programController,
                      decoration: InputDecoration(
                        labelText: 'Program/Course *',
                        prefixIcon: const Icon(Icons.book),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Program is required';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.academicInfo.program = value?.trim() ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Year Level
                    DropdownButtonFormField<String>(
                      value: _selectedYear,
                      decoration: InputDecoration(
                        labelText: 'Year Level *',
                        prefixIcon: const Icon(Icons.timeline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      items: _yearLevels.map((String year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedYear = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Year level is required';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.academicInfo.year = value ?? '',
                    ),
                    const SizedBox(height: 16),

                    // Block
                    TextFormField(
                      controller: _blockController,
                      decoration: InputDecoration(
                        labelText: 'Block/Section *',
                        prefixIcon: const Icon(Icons.group),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.purple, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Block/Section is required';
                        }
                        return null;
                      },
                      onSaved: (value) => widget.academicInfo.block = value?.trim() ?? '',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple completion screen (replaces the device info loading screen)
class CompletionScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CompletionScreen({
    super.key,
    required this.onComplete,
  });

  @override
  _CompletionScreenState createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String _statusText = 'Finalizing your account setup...';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Start the process after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _statusText = 'Almost done...';
      });
      
      Future.delayed(const Duration(seconds: 1), () {
        widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 2 * 3.14159,
                      child: const Icon(
                        Icons.sync,
                        size: 60,
                        color: Colors.purple,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  _statusText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  color: Colors.purple,
                  backgroundColor: Colors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Setting up your account profile...',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
    }