// import 'package:flutter/material.dart';
// import 'package:uktalhybird/BoottomNavigationlayout.dart';
// import 'package:uktalhybird/login.dart';

// class Signup extends StatefulWidget {
//   const Signup({super.key});

//   @override
//   State<Signup> createState() => _SignupState();
// }

// class _SignupState extends State<Signup> {
//   // Same colors as login
//   static const Color primaryBlue = Color(0xFF2962FF);
//   static const Color backgroundWhite = Color(0xFFFFFFFF);
//   static const Color cardBackground = Color(0xFFF5F5F5);
//   static const Color textBlack = Color(0xFF000000);
//   static const Color textGrey = Color(0xFF616161);

//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _fullNameController = TextEditingController();
//   final TextEditingController _countryController = TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _usernameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//       TextEditingController();
//   final TextEditingController _securityPinController = TextEditingController();

//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;

//     return Scaffold(
//       backgroundColor: backgroundWhite,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const SizedBox(height: 20),

//                 // Welcome text
//                 Text(
//                   'Welcome!',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.07,
//                     fontWeight: FontWeight.bold,
//                     color: primaryBlue,
//                   ),
//                 ),
//                 const SizedBox(height: 6),

//                 // Create Account Title
//                 Text(
//                   'Create Account',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.06,
//                     fontWeight: FontWeight.w600,
//                     color: textBlack,
//                   ),
//                 ),
//                 const SizedBox(height: 6),

//                 // Subtitle
//                 Text(
//                   'Fill in your details to get started',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.035,
//                     color: textGrey,
//                   ),
//                 ),
//                 const SizedBox(height: 25),

//                 // Form Fields (modern + responsive)
//                 _buildFormField('Full Name', _fullNameController),
//                 const SizedBox(height: 15),
//                 _buildFormField('Country', _countryController),
//                 const SizedBox(height: 15),
//                 _buildFormField(
//                   'Phone Number',
//                   _phoneController,
//                   keyboardType: TextInputType.phone,
//                 ),
//                 const SizedBox(height: 15),
//                 _buildFormField(
//                   'Email',
//                   _emailController,
//                   keyboardType: TextInputType.emailAddress,
//                 ),
//                 const SizedBox(height: 15),
//                 _buildFormField('Username', _usernameController),
//                 const SizedBox(height: 15),
//                 _buildFormField(
//                   'Password',
//                   _passwordController,
//                   isPassword: true,
//                 ),
//                 const SizedBox(height: 15),
//                 _buildFormField(
//                   'Confirm Password',
//                   _confirmPasswordController,
//                   isPassword: true,
//                 ),
//                 const SizedBox(height: 15),
//                 _buildFormField(
//                   'Security PIN',
//                   _securityPinController,
//                   keyboardType: TextInputType.number,
//                 ),
//                 const SizedBox(height: 25),

//                 // Signup Button
//                 SizedBox(
//                   height: 50,
//                   child: ElevatedButton(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => MainScreen()),
//                       );
//                       if (_formKey.currentState!.validate()) {
//                         // ScaffoldMessenger.of(context).showSnackBar(
//                         //   SnackBar(
//                         //     content: Text(
//                         //       'Account created successfully!',
//                         //       style: TextStyle(color: Colors.white),
//                         //     ),
//                         //     backgroundColor: primaryBlue,
//                         //   ),
//                         // );
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: primaryBlue,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(28),
//                       ),
//                       elevation: 6,
//                     ),
//                     child: const Text(
//                       'Sign Up',
//                       style: TextStyle(
//                         fontSize: 15,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 18),

//                 // Already have account
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       "Already have an account? ",
//                       style: TextStyle(color: textGrey, fontSize: 13),
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => const Login(),
//                           ),
//                         );
//                       },
//                       child: Text(
//                         'Log In',
//                         style: TextStyle(
//                           color: primaryBlue,
//                           fontSize: 13,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFormField(
//     String label,
//     TextEditingController controller, {
//     bool isPassword = false,
//     TextInputType keyboardType = TextInputType.text,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color: cardBackground,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: Colors.grey.shade400, // border color
//           width: 1, // border width
//         ),
//       ),
//       child: TextFormField(
//         controller: controller,
//         obscureText: isPassword
//             ? (label.contains('Confirm')
//                   ? _obscureConfirmPassword
//                   : _obscurePassword)
//             : false,
//         keyboardType: keyboardType,
//         style: const TextStyle(color: textBlack, fontSize: 14),
//         decoration: InputDecoration(
//           labelText: label,
//           labelStyle: TextStyle(color: textGrey, fontSize: 13),
//           contentPadding: const EdgeInsets.symmetric(
//             horizontal: 16,
//             vertical: 10, // reduced vertical padding (smaller height)
//           ),
//           border: InputBorder.none,
//           suffixIcon: isPassword
//               ? IconButton(
//                   icon: Icon(
//                     label.contains('Confirm')
//                         ? (_obscureConfirmPassword
//                               ? Icons.visibility_off
//                               : Icons.visibility)
//                         : (_obscurePassword
//                               ? Icons.visibility_off
//                               : Icons.visibility),
//                     color: textGrey,
//                   ),
//                   onPressed: () {
//                     setState(() {
//                       if (label.contains('Confirm')) {
//                         _obscureConfirmPassword = !_obscureConfirmPassword;
//                       } else {
//                         _obscurePassword = !_obscurePassword;
//                       }
//                     });
//                   },
//                 )
//               : null,
//         ),
//         validator: (value) {
//           if (value == null || value.isEmpty) {
//             return 'Please enter $label';
//           }
//           return null;
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _fullNameController.dispose();
//     _countryController.dispose();
//     _phoneController.dispose();
//     _emailController.dispose();
//     _usernameController.dispose();
//     _passwordController.dispose();
//     _confirmPasswordController.dispose();
//     _securityPinController.dispose();
//     super.dispose();
//   }
// }
