// login.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uktalhybird/BoottomNavigationlayout.dart';
import 'package:uktalhybird/forgatpasswordscre.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // Colors
  static const Color primaryBlue = Color(0xFF0000FF);
  static const Color backgroundWhiteGrey = Color(0xFFF5F5F5);
  static const Color textBlack = Color(0xFF000000);
  static const Color textGrey = Color(0xFF616161);

  final _formKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _signupPasswordController =
      TextEditingController();
  final TextEditingController _signupConfirmPasswordController =
      TextEditingController();
  final TextEditingController _sponsorIdController =
      TextEditingController(); // Sponsor ID field
  final TextEditingController _usernameInputController =
      TextEditingController(); // Username input field

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureSignupPassword = true;
  bool _isbiometric = false;

  int _selectedTab = 0; // 0 = Login, 1 = Signup
  late PageController _pageController;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add this in your user app's main file
  void _handleDeepLink() {
    // This will be called when app opens via deep link
    // You can get the user data from the URL and auto-login
  }

  @override
  void initState() {
    super.initState();
    _handleDeepLink();

    _pageController = PageController(initialPage: _selectedTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _sponsorIdController.dispose();
    _usernameInputController.dispose();
    super.dispose();
  }

  String _generateReferralCode(String name) {
    String baseCode = name
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0] : '')
        .join()
        .toUpperCase();
    String randomNum = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(8, 11);
    return baseCode + randomNum;
  }

  // Check if username already exists
  Future<bool> _checkUsernameExists(String username) async {
    try {
      final query = await _firestore
          .collection('Signup_Data')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // NEW: Find email by username
  Future<String?> _findEmailByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('Signup_Data')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first['email'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _checkSponsorIdExists(String sponsorId) async {
    try {
      final query = await _firestore
          .collection('Signup_Data')
          .where('referralCode', isEqualTo: sponsorId.toUpperCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> AuthenticationwithBiometric() async {
    final LocalAuthentication localAuthentication = LocalAuthentication();
    final bool isBiometricSupported = await localAuthentication
        .isDeviceSupported();
    final bool canCheckBiometric = await localAuthentication.canCheckBiometrics;
    bool isAuthenticated = false;
    if (isBiometricSupported && canCheckBiometric) {
      isAuthenticated = await localAuthentication.authenticate(
        localizedReason: "Please Login with fingerprint",
      );
    }
    return isAuthenticated;
  }

  // ---------------- OVERLAY MESSAGE ----------------
  void _showMessage(String message, {bool success = true}) {
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: success ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)!.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      entry?.remove();
    });
  }

  /// ---------------- SIGNUP LOGIC ----------------
  // Replace these two methods with the updated versions:

  // Alternative simpler version without email check:
  Future<bool> _verifyEmail(String email) async {
    try {
      // Create the actual user account first
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: "tempPassword123", // Temporary password
      );

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showMessage(
          'Email already registered. Please use another email.',
          success: false,
        );
      } else {
        _showMessage(
          'Failed to send verification email: ${e.message}',
          success: false,
        );
      }
      return false;
    } catch (e) {
      _showMessage('Failed to verify email', success: false);
      return false;
    }
  }

  // Show email verification dialog
  void _showEmailVerificationDialog(
    String email,
    String password,
    String name,
    String username,
    String sponsorId,
  ) {
    bool isChecking = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Verify Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('A verification email has been sent to:'),
                  SizedBox(height: 8),
                  Text(email, style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Please verify your email before proceeding.'),
                  SizedBox(height: 16),
                  if (isChecking)
                    Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Checking verification...'),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () {
                          // Cancel and delete the temporary user
                          _deleteTemporaryUser();
                          Navigator.of(context).pop();
                        },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () async {
                          setState(() => isChecking = true);

                          // Check if email is verified
                          try {
                            // Reload the current user to get latest verification status
                            await _auth.currentUser?.reload();
                            final currentUser = _auth.currentUser;

                            if (currentUser != null &&
                                currentUser.emailVerified) {
                              Navigator.of(context).pop();
                              await _completeSignup(
                                currentUser,
                                password,
                                name,
                                username,
                                sponsorId,
                              );
                            } else {
                              setState(() => isChecking = false);
                              _showMessage(
                                'Email not verified yet. Please check your inbox.',
                                success: false,
                              );
                            }
                          } catch (e) {
                            setState(() => isChecking = false);
                            _showMessage(
                              'Error checking verification',
                              success: false,
                            );
                          }
                        },
                  child: Text('Check Verification'),
                ),
                TextButton(
                  onPressed: isChecking
                      ? null
                      : () async {
                          try {
                            await _auth.currentUser?.sendEmailVerification();
                            _showMessage(
                              'Verification email sent again!',
                              success: true,
                            );
                          } catch (e) {
                            _showMessage(
                              'Failed to resend email',
                              success: false,
                            );
                          }
                        },
                  child: Text('Resend Email'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete temporary user if verification cancelled
  Future<void> _deleteTemporaryUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      print('Error deleting temporary user: $e');
    }
  }

  // Complete the signup process after verification
  // Complete the signup process after verification
  Future<void> _completeSignup(
    User user,
    String password,
    String name,
    String username,
    String sponsorId,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Update password to the actual one
      await user.updatePassword(password);

      // Use user-input username and generate referral code
      final referralCode = _generateReferralCode(name);

      // Save user data to Firestore with ALL wallet fields
      await _firestore.collection('Signup_Data').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'username': username.toLowerCase(),
        'email': user.email,
        'referralCode': referralCode,
        'sponsorId': sponsorId,
        'emailVerified': true,

        // Wallet Fields
        'MetricWallet': 0.0,
        'lotteryWallet': 0.0,
        'packageWallet': 0.0,
        'passiveWallet': 0.0,
        'networkWallet': 0.0,

        // Other fields
        'level': 1,
        'joinedAt': FieldValue.serverTimestamp(),
        'totalInvestment': 0.0,
        'directBonus': 0.0,
        'levelBonus': 0.0,
      });

      // Update display name
      await user.updateDisplayName(name);

      // Remove loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Success message and switch to login tab
      _showMessage('Successfully Registered', success: true);

      // Clear signup fields
      _nameController.clear();
      _emailController.clear();
      _signupPasswordController.clear();
      _signupConfirmPasswordController.clear();
      _sponsorIdController.clear();
      _usernameInputController.clear();

      // Switch to Login tab
      setState(() {
        _selectedTab = 0;
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastLinearToSlowEaseIn,
      );
    } catch (e) {
      // Remove loading indicator
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showMessage('Error completing registration: $e', success: false);
      // Delete the user if final setup fails
      await _deleteTemporaryUser();
    }
  }

  /// ---------------- UPDATED SIGNUP LOGIC ----------------
  Future<void> _signup() async {
    final form = _signupFormKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _signupPasswordController.text;
    final confirmPassword = _signupConfirmPasswordController.text;
    final sponsorId = _sponsorIdController.text.trim().toUpperCase();
    final username = _usernameInputController.text.trim();

    // Username validation
    if (username.isEmpty) {
      _showMessage('Username is required', success: false);
      return;
    }

    if (username.length < 3) {
      _showMessage('Username must be at least 3 characters', success: false);
      return;
    }

    // Check if username already exists
    final usernameExists = await _checkUsernameExists(username);
    if (usernameExists) {
      _showMessage(
        'Username already taken. Please choose another one.',
        success: false,
      );
      return;
    }

    // Sponsor ID validation - check if it exists in database
    if (sponsorId.isEmpty) {
      _showMessage('Sponsor ID is required', success: false);
      return;
    }

    // Check if sponsor ID exists in database
    final sponsorExists = await _checkSponsorIdExists(sponsorId);
    if (!sponsorExists) {
      _showMessage(
        'Invalid Sponsor ID. Please enter a correct Sponsor ID.',
        success: false,
      );
      return;
    }

    // Email format check
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
    );
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Invalid email format', success: false);
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters', success: false);
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        'Password and Confirm Password do not match',
        success: false,
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Step 1: Verify email by sending verification
      final verificationSent = await _verifyEmail(email);

      if (!mounted) return;
      Navigator.of(context).pop(); // Remove loading indicator

      if (!verificationSent) {
        return; // Error message already shown in _verifyEmail
      }

      // Step 2: Show verification dialog
      _showEmailVerificationDialog(email, password, name, username, sponsorId);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Remove loading indicator
      }
      _showMessage('Failed to start verification process', success: false);
    }
  }

  // ---------------- LOGIN LOGIC ----------------
  Future<void> _login() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final usernameOrEmail = _usernameController.text.trim();
    final password = _passwordController.text;

    if (usernameOrEmail.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password', success: false);
      return;
    }

    try {
      String emailToUse = usernameOrEmail;

      // Check if input is username (not email format)
      final emailRegex = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
      );

      // If it's not an email format, treat it as username and find the email
      if (!emailRegex.hasMatch(usernameOrEmail)) {
        final foundEmail = await _findEmailByUsername(usernameOrEmail);
        if (foundEmail == null) {
          _showMessage('Username not found', success: false);
          return;
        }
        emailToUse = foundEmail;
      }

      // Login with the email (either directly entered or found from username)
      await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      // ✅ Save login status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      if (!mounted) return;
      _showMessage('Successfully logged in', success: true);

      // navigate to MainScreen (same as your original)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String err = 'Login failed';
      if (e.code == 'user-not-found') {
        err = 'Account not found';
      } else if (e.code == 'wrong-password') {
        err = 'Invalid password';
      } else if (e.code == 'invalid-email') {
        err = 'Invalid email/username';
      } else if (e.code == 'too-many-requests') {
        err = 'Too many attempts. Try again later.';
      } else {
        err = e.message ?? err;
      }
      _showMessage(err, success: false);
    } catch (e) {
      _showMessage('Login error', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWhiteGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                const SizedBox(height: 30),

                // 🔹 Main White Card
                Card(
                  elevation: 12,
                  shadowColor: Colors.black.withOpacity(0.25),
                  margin: const EdgeInsets.only(top: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    child: Column(
                      children: [
                        // 🔹 Fixed Login / SignUp Tabs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedTab = 0);
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 100),
                                  curve: Curves.fastLinearToSlowEaseIn,
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedTab == 0
                                          ? primaryBlue
                                          : textBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 2,
                                    width: 50,
                                    color: _selectedTab == 0
                                        ? primaryBlue
                                        : Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 80),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedTab = 1);
                                _pageController.animateToPage(
                                  1,
                                  duration: const Duration(milliseconds: 100),
                                  curve: Curves.fastLinearToSlowEaseIn,
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedTab == 1
                                          ? primaryBlue
                                          : textBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 2,
                                    width: 60,
                                    color: _selectedTab == 1
                                        ? primaryBlue
                                        : Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 🔹 PageView with dynamic height
                        SizedBox(
                          height: _selectedTab == 0
                              ? 420
                              : 520, // Dynamic height based on selected tab
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() => _selectedTab = index);
                            },
                            children: [_buildLoginForm(), _buildSignupForm()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- LOGIN FORM ----------------
  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          Text(
            'Welcome to Uktal Hybrid',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue your journey',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textGrey),
          ),
          const SizedBox(height: 20),

          _buildFormField('Username or Email', _usernameController),
          const SizedBox(height: 15),
          _buildFormField('Password', _passwordController, isPassword: true),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value!;
                      });
                    },
                    activeColor: primaryBlue,
                  ),
                  Text(
                    'Remember me',
                    style: TextStyle(fontSize: 13, color: textBlack),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },

                child: Text(
                  'Forgot password?',
                  style: TextStyle(color: primaryBlue, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                _login();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () async {
              _isbiometric = await AuthenticationwithBiometric();

              if (_isbiometric) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter a valid fingerprint"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Icon(Icons.fingerprint, size: 45, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  // ---------------- SIGNUP FORM ----------------
  Widget _buildSignupForm() {
    return SingleChildScrollView(
      child: Form(
        key: _signupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textBlack,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fill in your details to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textGrey),
            ),
            const SizedBox(height: 10),

            _buildSignupFormField(
              'Name',
              _nameController,
              hintText: 'Enter your name',
            ),
            const SizedBox(height: 15),

            _buildSignupFormField(
              'Email',
              _emailController,
              hintText: 'Enter your email',
            ),
            const SizedBox(height: 15),

            // Username Field (User Input)
            _buildSignupFormField(
              'Username',
              _usernameInputController,
              hintText: 'Enter your username',
            ),
            const SizedBox(height: 15),

            // Sponsor ID Field (Mandatory - only empty check)
            _buildSignupFormField(
              'Sponsor ID',
              _sponsorIdController,
              hintText: 'Enter your sponsor code',
            ),
            const SizedBox(height: 15),

            _buildSignupFormField(
              'Password',
              _signupPasswordController,
              hintText: 'Enter your password',
              isPassword: true,
            ),
            const SizedBox(height: 15),

            _buildSignupFormField(
              'Confirm Password',
              _signupConfirmPasswordController,
              hintText: 'Enter your Confirm password',
              isPassword: true,
            ),
            const SizedBox(height: 30),

            SizedBox(
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  _signup();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- REUSABLE FIELDS ----------------
  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(12),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: textBlack, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          labelStyle: const TextStyle(color: textGrey, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: textGrey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildSignupFormField(
    String label,
    TextEditingController controller, {
    String hintText = '',
    bool isPassword = false,
  }) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(12),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscureSignupPassword : false,
        style: const TextStyle(color: textBlack, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          hintText: hintText,
          labelStyle: const TextStyle(color: textGrey, fontSize: 13),
          hintStyle: const TextStyle(color: textGrey, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureSignupPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: textGrey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureSignupPassword = !_obscureSignupPassword;
                    });
                  },
                )
              : null,
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }
}

// login without email verification

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:uktalhybird/BoottomNavigationlayout.dart';
// import 'package:uktalhybird/forgatpasswordscre.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   // Colors
//   static const Color primaryBlue = Color(0xFF0000FF);
//   static const Color backgroundWhiteGrey = Color(0xFFF5F5F5);
//   static const Color textBlack = Color(0xFF000000);
//   static const Color textGrey = Color(0xFF616161);

//   final _formKey = GlobalKey<FormState>();
//   final _signupFormKey = GlobalKey<FormState>();
//   final TextEditingController _usernameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _signupPasswordController =
//       TextEditingController();
//   final TextEditingController _signupConfirmPasswordController =
//       TextEditingController();
//   final TextEditingController _sponsorIdController =
//       TextEditingController(); // Sponsor ID field
//   final TextEditingController _usernameInputController =
//       TextEditingController(); // Username input field

//   bool _rememberMe = false;
//   bool _obscurePassword = true;
//   bool _obscureSignupPassword = true;
//   bool _isbiometric = false;

//   int _selectedTab = 0; // 0 = Login, 1 = Signup
//   late PageController _pageController;

//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Add this in your user app's main file
//   void _handleDeepLink() {
//     // This will be called when app opens via deep link
//     // You can get the user data from the URL and auto-login
//   }

//   @override
//   void initState() {
//     super.initState();
//     _handleDeepLink();

//     _pageController = PageController(initialPage: _selectedTab);
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     _usernameController.dispose();
//     _passwordController.dispose();
//     _nameController.dispose();
//     _emailController.dispose();
//     _signupPasswordController.dispose();
//     _signupConfirmPasswordController.dispose();
//     _sponsorIdController.dispose();
//     _usernameInputController.dispose();
//     super.dispose();
//   }

//   String _generateReferralCode(String name) {
//     String baseCode = name
//         .split(' ')
//         .map((word) => word.isNotEmpty ? word[0] : '')
//         .join()
//         .toUpperCase();
//     String randomNum = DateTime.now().millisecondsSinceEpoch
//         .toString()
//         .substring(8, 11);
//     return baseCode + randomNum;
//   }

//   // Check if username already exists
//   Future<bool> _checkUsernameExists(String username) async {
//     try {
//       final query = await _firestore
//           .collection('Signup_Data')
//           .where('username', isEqualTo: username.toLowerCase())
//           .limit(1)
//           .get();
//       return query.docs.isNotEmpty;
//     } catch (e) {
//       return false;
//     }
//   }

//   // NEW: Find email by username
//   Future<String?> _findEmailByUsername(String username) async {
//     try {
//       final query = await _firestore
//           .collection('Signup_Data')
//           .where('username', isEqualTo: username.toLowerCase())
//           .limit(1)
//           .get();

//       if (query.docs.isNotEmpty) {
//         return query.docs.first['email'] as String?;
//       }
//       return null;
//     } catch (e) {
//       return null;
//     }
//   }

//   Future<bool> _checkSponsorIdExists(String sponsorId) async {
//     try {
//       final query = await _firestore
//           .collection('Signup_Data')
//           .where('referralCode', isEqualTo: sponsorId.toUpperCase())
//           .limit(1)
//           .get();
//       return query.docs.isNotEmpty;
//     } catch (e) {
//       return false;
//     }
//   }

//   Future<bool> AuthenticationwithBiometric() async {
//     final LocalAuthentication localAuthentication = LocalAuthentication();
//     final bool isBiometricSupported = await localAuthentication
//         .isDeviceSupported();
//     final bool canCheckBiometric = await localAuthentication.canCheckBiometrics;
//     bool isAuthenticated = false;
//     if (isBiometricSupported && canCheckBiometric) {
//       isAuthenticated = await localAuthentication.authenticate(
//         localizedReason: "Please Login with fingerprint",
//       );
//     }
//     return isAuthenticated;
//   }

//   // ---------------- OVERLAY MESSAGE ----------------
//   void _showMessage(String message, {bool success = true}) {
//     OverlayEntry? entry;

//     entry = OverlayEntry(
//       builder: (context) => Positioned(
//         top: 50,
//         left: 20,
//         right: 20,
//         child: Material(
//           color: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             decoration: BoxDecoration(
//               color: success ? Colors.green : Colors.red,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 6,
//                   offset: Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Text(
//               message,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//         ),
//       ),
//     );

//     Overlay.of(context)!.insert(entry);

//     Future.delayed(const Duration(seconds: 3), () {
//       entry?.remove();
//     });
//   }

//   /// ---------------- SIGNUP LOGIC ----------------
//   // Replace these two methods with the updated versions:

//   // Alternative simpler version without email check:
//   // Future<bool> _verifyEmail(String email) async {
//   //   try {
//   //     // Create the actual user account first
//   //     final userCredential = await _auth.createUserWithEmailAndPassword(
//   //       email: email,
//   //       password: "tempPassword123", // Temporary password
//   //     );

//   //     // Send verification email
//   //     await userCredential.user!.sendEmailVerification();

//   //     return true;
//   //   } on FirebaseAuthException catch (e) {
//   //     if (e.code == 'email-already-in-use') {
//   //       _showMessage(
//   //         'Email already registered. Please use another email.',
//   //         success: false,
//   //       );
//   //     } else {
//   //       _showMessage(
//   //         'Failed to send verification email: ${e.message}',
//   //         success: false,
//   //       );
//   //     }
//   //     return false;
//   //   } catch (e) {
//   //     _showMessage('Failed to verify email', success: false);
//   //     return false;
//   //   }
//   // }
//   Future<bool> _verifyEmail(String email) async {
//     try {
//       // Create the actual user account first
//       final userCredential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: "tempPassword123", // Temporary password
//       );

//       // COMMENTED OUT: Send verification email
//       // await userCredential.user!.sendEmailVerification();

//       return true;
//     } on FirebaseAuthException catch (e) {
//       if (e.code == 'email-already-in-use') {
//         _showMessage(
//           'Email already registered. Please use another email.',
//           success: false,
//         );
//       } else {
//         _showMessage('Failed to create account: ${e.message}', success: false);
//       }
//       return false;
//     } catch (e) {
//       _showMessage('Failed to create account', success: false);
//       return false;
//     }
//   }
//   // Show email verification dialog
//   // void _showEmailVerificationDialog(
//   //   String email,
//   //   String password,
//   //   String name,
//   //   String username,
//   //   String sponsorId,
//   // ) {
//   //   bool isChecking = false;

//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (BuildContext context) {
//   //       return StatefulBuilder(
//   //         builder: (context, setState) {
//   //           return AlertDialog(
//   //             title: Text('Verify Email'),
//   //             content: Column(
//   //               mainAxisSize: MainAxisSize.min,
//   //               children: [
//   //                 Text('A verification email has been sent to:'),
//   //                 SizedBox(height: 8),
//   //                 Text(email, style: TextStyle(fontWeight: FontWeight.bold)),
//   //                 SizedBox(height: 16),
//   //                 Text('Please verify your email before proceeding.'),
//   //                 SizedBox(height: 16),
//   //                 if (isChecking)
//   //                   Column(
//   //                     children: [
//   //                       CircularProgressIndicator(),
//   //                       SizedBox(height: 16),
//   //                       Text('Checking verification...'),
//   //                     ],
//   //                   ),
//   //               ],
//   //             ),
//   //             actions: [
//   //               TextButton(
//   //                 onPressed: isChecking
//   //                     ? null
//   //                     : () {
//   //                         // Cancel and delete the temporary user
//   //                         _deleteTemporaryUser();
//   //                         Navigator.of(context).pop();
//   //                       },
//   //                 child: Text('Cancel'),
//   //               ),
//   //               TextButton(
//   //                 onPressed: isChecking
//   //                     ? null
//   //                     : () async {
//   //                         setState(() => isChecking = true);

//   //                         // Check if email is verified
//   //                         try {
//   //                           // Reload the current user to get latest verification status
//   //                           await _auth.currentUser?.reload();
//   //                           final currentUser = _auth.currentUser;

//   //                           if (currentUser != null &&
//   //                               currentUser.emailVerified) {
//   //                             Navigator.of(context).pop();
//   //                             await _completeSignup(
//   //                               currentUser,
//   //                               password,
//   //                               name,
//   //                               username,
//   //                               sponsorId,
//   //                             );
//   //                           } else {
//   //                             setState(() => isChecking = false);
//   //                             _showMessage(
//   //                               'Email not verified yet. Please check your inbox.',
//   //                               success: false,
//   //                             );
//   //                           }
//   //                         } catch (e) {
//   //                           setState(() => isChecking = false);
//   //                           _showMessage(
//   //                             'Error checking verification',
//   //                             success: false,
//   //                           );
//   //                         }
//   //                       },
//   //                 child: Text('Check Verification'),
//   //               ),
//   //               TextButton(
//   //                 onPressed: isChecking
//   //                     ? null
//   //                     : () async {
//   //                         try {
//   //                           await _auth.currentUser?.sendEmailVerification();
//   //                           _showMessage(
//   //                             'Verification email sent again!',
//   //                             success: true,
//   //                           );
//   //                         } catch (e) {
//   //                           _showMessage(
//   //                             'Failed to resend email',
//   //                             success: false,
//   //                           );
//   //                         }
//   //                       },
//   //                 child: Text('Resend Email'),
//   //               ),
//   //             ],
//   //           );
//   //         },
//   //       );
//   //     },
//   //   );
//   // }

//   //----------
//   void _showEmailVerificationDialog(
//     String email,
//     String password,
//     String name,
//     String username,
//     String sponsorId,
//   ) {
//     bool isChecking = false;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Account Created'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text('Your account has been successfully created!'),
//                   SizedBox(height: 16),
//                   Text('You can now login with your credentials.'),
//                   // COMMENTED OUT: Verification email message
//                   /*
//                 Text('A verification email has been sent to:'),
//                 SizedBox(height: 8),
//                 Text(email, style: TextStyle(fontWeight: FontWeight.bold)),
//                 SizedBox(height: 16),
//                 Text('Please verify your email before proceeding.'),
//                 SizedBox(height: 16),
//                 */
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: isChecking
//                       ? null
//                       : () {
//                           Navigator.of(context).pop();
//                           // Proceed directly to complete signup
//                           _completeSignupAfterDialog(
//                             password,
//                             name,
//                             username,
//                             sponsorId,
//                           );
//                         },
//                   child: Text('Continue'),
//                 ),
//                 // COMMENTED OUT: Check verification and resend email buttons
//                 /*
//               TextButton(
//                 onPressed: isChecking
//                     ? null
//                     : () {
//                         setState(() => isChecking = true);

//                         // Check if email is verified
//                         try {
//                           // Reload the current user to get latest verification status
//                           await _auth.currentUser?.reload();
//                           final currentUser = _auth.currentUser;

//                           if (currentUser != null &&
//                               currentUser.emailVerified) {
//                             Navigator.of(context).pop();
//                             await _completeSignup(
//                               currentUser,
//                               password,
//                               name,
//                               username,
//                               sponsorId,
//                             );
//                           } else {
//                             setState(() => isChecking = false);
//                             _showMessage(
//                               'Email not verified yet. Please check your inbox.',
//                               success: false,
//                             );
//                           }
//                         } catch (e) {
//                           setState(() => isChecking = false);
//                           _showMessage(
//                             'Error checking verification',
//                             success: false,
//                           );
//                         }
//                       },
//                 child: Text('Check Verification'),
//               ),
//               TextButton(
//                 onPressed: isChecking
//                     ? null
//                     : () async {
//                         try {
//                           await _auth.currentUser?.sendEmailVerification();
//                           _showMessage(
//                             'Verification email sent again!',
//                             success: true,
//                           );
//                         } catch (e) {
//                           _showMessage(
//                             'Failed to resend email',
//                             success: false,
//                           );
//                         }
//                       },
//                 child: Text('Resend Email'),
//               ),
//               */
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Future<void> _completeSignupAfterDialog(
//     String password,
//     String name,
//     String username,
//     String sponsorId,
//   ) async {
//     final user = _auth.currentUser;
//     if (user == null) {
//       _showMessage('Error: User not found', success: false);
//       return;
//     }

//     await _completeSignup(user, password, name, username, sponsorId);
//   }

//   // Delete temporary user if verification cancelled
//   Future<void> _deleteTemporaryUser() async {
//     try {
//       final user = _auth.currentUser;
//       if (user != null) {
//         await user.delete();
//       }
//     } catch (e) {
//       print('Error deleting temporary user: $e');
//     }
//   }

//   // Complete the signup process after verification
//   // Complete the signup process after verification
//   // Future<void> _completeSignup(
//   //   User user,
//   //   String password,
//   //   String name,
//   //   String username,
//   //   String sponsorId,
//   // ) async {
//   //   // Show loading indicator
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (BuildContext context) {
//   //       return Center(child: CircularProgressIndicator());
//   //     },
//   //   );

//   //   try {
//   //     // Update password to the actual one
//   //     await user.updatePassword(password);

//   //     // Use user-input username and generate referral code
//   //     final referralCode = _generateReferralCode(name);

//   //     // Save user data to Firestore with ALL wallet fields
//   //     await _firestore.collection('Signup_Data').doc(user.uid).set({
//   //       'uid': user.uid,
//   //       'name': name,
//   //       'username': username.toLowerCase(),
//   //       'email': user.email,
//   //       'referralCode': referralCode,
//   //       'sponsorId': sponsorId,
//   //       'emailVerified': true,

//   //       // Wallet Fields
//   //       'MetricWallet': 0.0,
//   //       'lotteryWallet': 0.0,
//   //       'packageWallet': 0.0,
//   //       'passiveWallet': 0.0,
//   //       'networkWallet': 0.0,

//   //       // Other fields
//   //       'level': 1,
//   //       'joinedAt': FieldValue.serverTimestamp(),
//   //       'totalInvestment': 0.0,
//   //       'directBonus': 0.0,
//   //       'levelBonus': 0.0,
//   //     });

//   //     // Update display name
//   //     await user.updateDisplayName(name);

//   //     // Remove loading indicator
//   //     if (!mounted) return;
//   //     Navigator.of(context).pop();

//   //     // Success message and switch to login tab
//   //     _showMessage('Successfully Registered', success: true);

//   //     // Clear signup fields
//   //     _nameController.clear();
//   //     _emailController.clear();
//   //     _signupPasswordController.clear();
//   //     _signupConfirmPasswordController.clear();
//   //     _sponsorIdController.clear();
//   //     _usernameInputController.clear();

//   //     // Switch to Login tab
//   //     setState(() {
//   //       _selectedTab = 0;
//   //     });
//   //     _pageController.animateToPage(
//   //       0,
//   //       duration: const Duration(milliseconds: 200),
//   //       curve: Curves.fastLinearToSlowEaseIn,
//   //     );
//   //   } catch (e) {
//   //     // Remove loading indicator
//   //     if (mounted) {
//   //       Navigator.of(context).pop();
//   //     }
//   //     _showMessage('Error completing registration: $e', success: false);
//   //     // Delete the user if final setup fails
//   //     await _deleteTemporaryUser();
//   //   }
//   // }

//   // /// ---------------- UPDATED SIGNUP LOGIC ----------------
//   // Future<void> _signup() async {
//   //   final form = _signupFormKey.currentState;
//   //   if (form == null) return;
//   //   if (!form.validate()) return;

//   //   final name = _nameController.text.trim();
//   //   final email = _emailController.text.trim();
//   //   final password = _signupPasswordController.text;
//   //   final confirmPassword = _signupConfirmPasswordController.text;
//   //   final sponsorId = _sponsorIdController.text.trim().toUpperCase();
//   //   final username = _usernameInputController.text.trim();

//   //   // Username validation
//   //   if (username.isEmpty) {
//   //     _showMessage('Username is required', success: false);
//   //     return;
//   //   }

//   //   if (username.length < 3) {
//   //     _showMessage('Username must be at least 3 characters', success: false);
//   //     return;
//   //   }

//   //   // Check if username already exists
//   //   final usernameExists = await _checkUsernameExists(username);
//   //   if (usernameExists) {
//   //     _showMessage(
//   //       'Username already taken. Please choose another one.',
//   //       success: false,
//   //     );
//   //     return;
//   //   }

//   //   // Sponsor ID validation - check if it exists in database
//   //   if (sponsorId.isEmpty) {
//   //     _showMessage('Sponsor ID is required', success: false);
//   //     return;
//   //   }

//   //   // Check if sponsor ID exists in database
//   //   final sponsorExists = await _checkSponsorIdExists(sponsorId);
//   //   if (!sponsorExists) {
//   //     _showMessage(
//   //       'Invalid Sponsor ID. Please enter a correct Sponsor ID.',
//   //       success: false,
//   //     );
//   //     return;
//   //   }

//   //   // Email format check
//   //   final emailRegex = RegExp(
//   //     r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
//   //   );
//   //   if (!emailRegex.hasMatch(email)) {
//   //     _showMessage('Invalid email format', success: false);
//   //     return;
//   //   }

//   //   if (password.length < 6) {
//   //     _showMessage('Password must be at least 6 characters', success: false);
//   //     return;
//   //   }

//   //   if (password != confirmPassword) {
//   //     _showMessage(
//   //       'Password and Confirm Password do not match',
//   //       success: false,
//   //     );
//   //     return;
//   //   }

//   //   // Show loading indicator
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (BuildContext context) {
//   //       return Center(child: CircularProgressIndicator());
//   //     },
//   //   );

//   //   try {
//   //     // Step 1: Verify email by sending verification
//   //     final verificationSent = await _verifyEmail(email);

//   //     if (!mounted) return;
//   //     Navigator.of(context).pop(); // Remove loading indicator

//   //     if (!verificationSent) {
//   //       return; // Error message already shown in _verifyEmail
//   //     }

//   //     // Step 2: Show verification dialog
//   //     _showEmailVerificationDialog(email, password, name, username, sponsorId);
//   //   } catch (e) {
//   //     if (mounted) {
//   //       Navigator.of(context).pop(); // Remove loading indicator
//   //     }
//   //     _showMessage('Failed to start verification process', success: false);
//   //   }
//   // }

//   Future<void> _completeSignup(
//     User user,
//     String password,
//     String name,
//     String username,
//     String sponsorId,
//   ) async {
//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       // Update password to the actual one
//       await user.updatePassword(password);

//       // Use user-input username and generate referral code
//       final referralCode = _generateReferralCode(name);

//       // Save user data to Firestore with ALL wallet fields
//       await _firestore.collection('Signup_Data').doc(user.uid).set({
//         'uid': user.uid,
//         'name': name,
//         'username': username.toLowerCase(),
//         'email': user.email,
//         'referralCode': referralCode,
//         'sponsorId': sponsorId,
//         'emailVerified': true, // Set to true since we're skipping verification
//         // Wallet Fields
//         'MetricWallet': 0.0,
//         'lotteryWallet': 0.0,
//         'packageWallet': 0.0,
//         'passiveWallet': 0.0,
//         'networkWallet': 0.0,

//         // Other fields
//         'level': 1,
//         'joinedAt': FieldValue.serverTimestamp(),
//         'totalInvestment': 0.0,
//         'directBonus': 0.0,
//         'levelBonus': 0.0,
//       });

//       // Update display name
//       await user.updateDisplayName(name);

//       // Remove loading indicator
//       if (!mounted) return;
//       Navigator.of(context).pop();

//       // Success message and switch to login tab
//       _showMessage('Successfully Registered', success: true);

//       // Clear signup fields
//       _nameController.clear();
//       _emailController.clear();
//       _signupPasswordController.clear();
//       _signupConfirmPasswordController.clear();
//       _sponsorIdController.clear();
//       _usernameInputController.clear();

//       // Switch to Login tab
//       setState(() {
//         _selectedTab = 0;
//       });
//       _pageController.animateToPage(
//         0,
//         duration: const Duration(milliseconds: 200),
//         curve: Curves.fastLinearToSlowEaseIn,
//       );
//     } catch (e) {
//       // Remove loading indicator
//       if (mounted) {
//         Navigator.of(context).pop();
//       }
//       _showMessage('Error completing registration: $e', success: false);
//       // Delete the user if final setup fails
//       await _deleteTemporaryUser();
//     }
//   }

//   /// ---------------- UPDATED SIGNUP LOGIC ----------------
//   Future<void> _signup() async {
//     final form = _signupFormKey.currentState;
//     if (form == null) return;
//     if (!form.validate()) return;

//     final name = _nameController.text.trim();
//     final email = _emailController.text.trim();
//     final password = _signupPasswordController.text;
//     final confirmPassword = _signupConfirmPasswordController.text;
//     final sponsorId = _sponsorIdController.text.trim().toUpperCase();
//     final username = _usernameInputController.text.trim();

//     // Username validation
//     if (username.isEmpty) {
//       _showMessage('Username is required', success: false);
//       return;
//     }

//     if (username.length < 3) {
//       _showMessage('Username must be at least 3 characters', success: false);
//       return;
//     }

//     // Check if username already exists
//     final usernameExists = await _checkUsernameExists(username);
//     if (usernameExists) {
//       _showMessage(
//         'Username already taken. Please choose another one.',
//         success: false,
//       );
//       return;
//     }

//     // Sponsor ID validation - check if it exists in database
//     if (sponsorId.isEmpty) {
//       _showMessage('Sponsor ID is required', success: false);
//       return;
//     }

//     // Check if sponsor ID exists in database
//     final sponsorExists = await _checkSponsorIdExists(sponsorId);
//     if (!sponsorExists) {
//       _showMessage(
//         'Invalid Sponsor ID. Please enter a correct Sponsor ID.',
//         success: false,
//       );
//       return;
//     }

//     // Email format check
//     final emailRegex = RegExp(
//       r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
//     );
//     if (!emailRegex.hasMatch(email)) {
//       _showMessage('Invalid email format', success: false);
//       return;
//     }

//     if (password.length < 6) {
//       _showMessage('Password must be at least 6 characters', success: false);
//       return;
//     }

//     if (password != confirmPassword) {
//       _showMessage(
//         'Password and Confirm Password do not match',
//         success: false,
//       );
//       return;
//     }

//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(child: CircularProgressIndicator());
//       },
//     );

//     try {
//       // Step 1: Verify email by sending verification
//       final verificationSent = await _verifyEmail(email);

//       if (!mounted) return;
//       Navigator.of(context).pop(); // Remove loading indicator

//       if (!verificationSent) {
//         return; // Error message already shown in _verifyEmail
//       }

//       // Step 2: Show success dialog (instead of verification dialog)
//       _showEmailVerificationDialog(email, password, name, username, sponsorId);
//     } catch (e) {
//       if (mounted) {
//         Navigator.of(context).pop(); // Remove loading indicator
//       }
//       _showMessage('Failed to create account', success: false);
//     }
//   }

//   // ---------------- LOGIN LOGIC ----------------
//   Future<void> _login() async {
//     final form = _formKey.currentState;
//     if (form == null) return;
//     if (!form.validate()) return;

//     final usernameOrEmail = _usernameController.text.trim();
//     final password = _passwordController.text;

//     if (usernameOrEmail.isEmpty || password.isEmpty) {
//       _showMessage('Please enter email and password', success: false);
//       return;
//     }

//     try {
//       String emailToUse = usernameOrEmail;

//       // Check if input is username (not email format)
//       final emailRegex = RegExp(
//         r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
//       );

//       // If it's not an email format, treat it as username and find the email
//       if (!emailRegex.hasMatch(usernameOrEmail)) {
//         final foundEmail = await _findEmailByUsername(usernameOrEmail);
//         if (foundEmail == null) {
//           _showMessage('Username not found', success: false);
//           return;
//         }
//         emailToUse = foundEmail;
//       }

//       // Login with the email (either directly entered or found from username)
//       await _auth.signInWithEmailAndPassword(
//         email: emailToUse,
//         password: password,
//       );

//       // ✅ Save login status
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isLoggedIn', true);
//       if (!mounted) return;
//       _showMessage('Successfully logged in', success: true);

//       // navigate to MainScreen (same as your original)
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const MainScreen()),
//       );
//     } on FirebaseAuthException catch (e) {
//       String err = 'Login failed';
//       if (e.code == 'user-not-found') {
//         err = 'Account not found';
//       } else if (e.code == 'wrong-password') {
//         err = 'Invalid password';
//       } else if (e.code == 'invalid-email') {
//         err = 'Invalid email/username';
//       } else if (e.code == 'too-many-requests') {
//         err = 'Too many attempts. Try again later.';
//       } else {
//         err = e.message ?? err;
//       }
//       _showMessage(err, success: false);
//     } catch (e) {
//       _showMessage('Login error', success: false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundWhiteGrey,
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             child: Column(
//               children: [
//                 const SizedBox(height: 30),

//                 // 🔹 Main White Card
//                 Card(
//                   elevation: 12,
//                   shadowColor: Colors.black.withOpacity(0.25),
//                   margin: const EdgeInsets.only(top: 8),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   color: Colors.white,
//                   child: Container(
//                     padding: const EdgeInsets.all(20),
//                     width: double.infinity,
//                     child: Column(
//                       children: [
//                         // 🔹 Fixed Login / SignUp Tabs
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             GestureDetector(
//                               onTap: () {
//                                 setState(() => _selectedTab = 0);
//                                 _pageController.animateToPage(
//                                   0,
//                                   duration: const Duration(milliseconds: 100),
//                                   curve: Curves.fastLinearToSlowEaseIn,
//                                 );
//                               },
//                               child: Column(
//                                 children: [
//                                   Text(
//                                     "Login",
//                                     style: TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                       color: _selectedTab == 0
//                                           ? primaryBlue
//                                           : textBlack,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Container(
//                                     height: 2,
//                                     width: 50,
//                                     color: _selectedTab == 0
//                                         ? primaryBlue
//                                         : Colors.transparent,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(width: 80),
//                             GestureDetector(
//                               onTap: () {
//                                 setState(() => _selectedTab = 1);
//                                 _pageController.animateToPage(
//                                   1,
//                                   duration: const Duration(milliseconds: 100),
//                                   curve: Curves.fastLinearToSlowEaseIn,
//                                 );
//                               },
//                               child: Column(
//                                 children: [
//                                   Text(
//                                     "Sign Up",
//                                     style: TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                       color: _selectedTab == 1
//                                           ? primaryBlue
//                                           : textBlack,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Container(
//                                     height: 2,
//                                     width: 60,
//                                     color: _selectedTab == 1
//                                         ? primaryBlue
//                                         : Colors.transparent,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),

//                         // 🔹 PageView with dynamic height
//                         SizedBox(
//                           height: _selectedTab == 0
//                               ? 420
//                               : 520, // Dynamic height based on selected tab
//                           child: PageView(
//                             controller: _pageController,
//                             onPageChanged: (index) {
//                               setState(() => _selectedTab = index);
//                             },
//                             children: [_buildLoginForm(), _buildSignupForm()],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ---------------- LOGIN FORM ----------------
//   Widget _buildLoginForm() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           const SizedBox(height: 12),

//           Text(
//             'Welcome to Uktal Hybrid',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: textBlack,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Sign in to continue your journey',
//             textAlign: TextAlign.center,
//             style: TextStyle(fontSize: 14, color: textGrey),
//           ),
//           const SizedBox(height: 20),

//           _buildFormField('Username or Email', _usernameController),
//           const SizedBox(height: 15),
//           _buildFormField('Password', _passwordController, isPassword: true),
//           const SizedBox(height: 10),

//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   Checkbox(
//                     value: _rememberMe,
//                     onChanged: (value) {
//                       setState(() {
//                         _rememberMe = value!;
//                       });
//                     },
//                     activeColor: primaryBlue,
//                   ),
//                   Text(
//                     'Remember me',
//                     style: TextStyle(fontSize: 13, color: textBlack),
//                   ),
//                 ],
//               ),
//               TextButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const ForgotPasswordScreen(),
//                     ),
//                   );
//                 },

//                 child: Text(
//                   'Forgot password?',
//                   style: TextStyle(color: primaryBlue, fontSize: 13),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           SizedBox(
//             height: 45,
//             child: ElevatedButton(
//               onPressed: () {
//                 _login();
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: primaryBlue,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(25),
//                 ),
//                 elevation: 4,
//               ),
//               child: const Text(
//                 'Log In',
//                 style: TextStyle(
//                   fontSize: 15,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 18),
//           GestureDetector(
//             onTap: () async {
//               _isbiometric = await AuthenticationwithBiometric();

//               if (_isbiometric) {
//                 if (!mounted) return;
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (context) => const MainScreen()),
//                 );
//               } else {
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text("Please enter a valid fingerprint"),
//                     duration: Duration(seconds: 2),
//                   ),
//                 );
//               }
//             },
//             child: const Icon(Icons.fingerprint, size: 45, color: Colors.blue),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---------------- SIGNUP FORM ----------------
//   Widget _buildSignupForm() {
//     return SingleChildScrollView(
//       child: Form(
//         key: _signupFormKey,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Text(
//               'Create Account',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//                 color: textBlack,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               'Fill in your details to get started',
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 14, color: textGrey),
//             ),
//             const SizedBox(height: 10),

//             _buildSignupFormField(
//               'Name',
//               _nameController,
//               hintText: 'Enter your name',
//             ),
//             const SizedBox(height: 15),

//             _buildSignupFormField(
//               'Email',
//               _emailController,
//               hintText: 'Enter your email',
//             ),
//             const SizedBox(height: 15),

//             // Username Field (User Input)
//             _buildSignupFormField(
//               'Username',
//               _usernameInputController,
//               hintText: 'Enter your username',
//             ),
//             const SizedBox(height: 15),

//             // Sponsor ID Field (Mandatory - only empty check)
//             _buildSignupFormField(
//               'Sponsor ID',
//               _sponsorIdController,
//               hintText: 'Enter your sponsor code',
//             ),
//             const SizedBox(height: 15),

//             _buildSignupFormField(
//               'Password',
//               _signupPasswordController,
//               hintText: 'Enter your password',
//               isPassword: true,
//             ),
//             const SizedBox(height: 15),

//             _buildSignupFormField(
//               'Confirm Password',
//               _signupConfirmPasswordController,
//               hintText: 'Enter your Confirm password',
//               isPassword: true,
//             ),
//             const SizedBox(height: 30),

//             SizedBox(
//               height: 45,
//               child: ElevatedButton(
//                 onPressed: () {
//                   _signup();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: primaryBlue,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(25),
//                   ),
//                   elevation: 4,
//                 ),
//                 child: const Text(
//                   'Sign Up',
//                   style: TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ---------------- REUSABLE FIELDS ----------------
//   Widget _buildFormField(
//     String label,
//     TextEditingController controller, {
//     bool isPassword = false,
//   }) {
//     return Material(
//       elevation: 6,
//       shadowColor: Colors.black45,
//       borderRadius: BorderRadius.circular(12),
//       child: TextFormField(
//         controller: controller,
//         obscureText: isPassword ? _obscurePassword : false,
//         style: const TextStyle(color: textBlack, fontSize: 14),
//         decoration: InputDecoration(
//           filled: true,
//           fillColor: Colors.white,
//           labelText: label,
//           labelStyle: const TextStyle(color: textGrey, fontSize: 13),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 18,
//             vertical: 14,
//           ),
//           suffixIcon: isPassword
//               ? IconButton(
//                   icon: Icon(
//                     _obscurePassword ? Icons.visibility_off : Icons.visibility,
//                     color: textGrey,
//                   ),
//                   onPressed: () {
//                     setState(() {
//                       _obscurePassword = !_obscurePassword;
//                     });
//                   },
//                 )
//               : null,
//         ),
//         validator: (value) =>
//             value == null || value.isEmpty ? 'Please enter $label' : null,
//       ),
//     );
//   }

//   Widget _buildSignupFormField(
//     String label,
//     TextEditingController controller, {
//     String hintText = '',
//     bool isPassword = false,
//   }) {
//     return Material(
//       elevation: 6,
//       shadowColor: Colors.black45,
//       borderRadius: BorderRadius.circular(12),
//       child: TextFormField(
//         controller: controller,
//         obscureText: isPassword ? _obscureSignupPassword : false,
//         style: const TextStyle(color: textBlack, fontSize: 14),
//         decoration: InputDecoration(
//           filled: true,
//           fillColor: Colors.white,
//           labelText: label,
//           hintText: hintText,
//           labelStyle: const TextStyle(color: textGrey, fontSize: 13),
//           hintStyle: const TextStyle(color: textGrey, fontSize: 13),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 18,
//             vertical: 14,
//           ),
//           suffixIcon: isPassword
//               ? IconButton(
//                   icon: Icon(
//                     _obscureSignupPassword
//                         ? Icons.visibility_off
//                         : Icons.visibility,
//                     color: textGrey,
//                   ),
//                   onPressed: () {
//                     setState(() {
//                       _obscureSignupPassword = !_obscureSignupPassword;
//                     });
//                   },
//                 )
//               : null,
//         ),
//         validator: (value) =>
//             value == null || value.isEmpty ? 'Please enter $label' : null,
//       ),
//     );
//   }
// }
