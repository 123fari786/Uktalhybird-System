import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uktalhybird/Metrixcreen/MetrixincomeQRcode.dart';

class MatrixIncomeDepositScreen extends StatefulWidget {
  const MatrixIncomeDepositScreen({super.key});

  @override
  State<MatrixIncomeDepositScreen> createState() =>
      _MatrixIncomeDepositScreenState();
}

class _MatrixIncomeDepositScreenState extends State<MatrixIncomeDepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final primaryBlue = const Color(0xFF0000FF);
  final lightBlue = const Color(0xFFE6E6FF);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default amount to $11
    _amountController.text = "11.50";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Center(
          child: Padding(
            padding: EdgeInsets.only(right: 30),
            child: Text(
              'Matrix Income Deposit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF0000FF),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Matrix Income Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.account_tree, color: Colors.white, size: 32),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Matrix Income System",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Activate your matrix levels and start earning",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 🔹 Deposit Form Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, lightBlue.withOpacity(0.3)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: primaryBlue, size: 24),
                          SizedBox(width: 10),
                          Text(
                            "Create Payment",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Deposit Fee Notice
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange[800]),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "1% Deposit fee will be applied",
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 15),

                      // Amount Input
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          readOnly:
                              true, // ✅ Add this line to make it read-only

                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: "Deposit Amount",
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                            hintText: "Enter amount in USD",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryBlue),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: primaryBlue,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.attach_money,
                              color: primaryBlue,
                            ),
                            suffixText: "USD",
                            suffixStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 15),

                      // Payment Details
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: primaryBlue.withOpacity(0.05),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Payment Details",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                            SizedBox(height: 10),
                            _buildDetailRow("Currency:", "USDT (BSC)"),
                            _buildDetailRow("Category:", "Matrix"),
                            _buildDetailRow("Network:", "Binance Smart Chain"),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Create Payment Button
                      _isLoading
                          ? Container(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryBlue,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    "Creating Payment...",
                                    style: TextStyle(
                                      color: primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [primaryBlue, Color(0xFF0000CC)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _createMatrixPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_open,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Create Matrix Payment",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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

            SizedBox(height: 20),

            // 🔹 Matrix Benefits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green[800]),
                      SizedBox(width: 8),
                      Text(
                        "Matrix Benefits",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildBenefit("Unlock 8 Matrix Levels"),
                  _buildBenefit("Global Matrix System"),
                  _buildBenefit("Automatic Level Progression"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createMatrixPayment() async {
    // Validate amount
    final amount = _amountController.text.trim();
    if (amount.isEmpty || double.tryParse(amount) == null) {
      _showErrorSnackBar("Please enter a valid deposit amount");
      return;
    }

    final amountValue = double.parse(amount);
    if (amountValue < 5) {
      _showErrorSnackBar("Minimum deposit amount is \$5");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user UID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar("Please login first");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('🔄 Creating matrix income payment for user: ${user.uid}');

      // ✅ Step 1: Authenticate with API
      final accessToken = await _authenticate();
      if (accessToken == null) {
        _showErrorSnackBar("Authentication failed. Please try again.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // ✅ Step 2: Create Payment with authentication
      final paymentBody = {
        "amount": amount,
        "payCurrency": "usdtbsc",
        "userId": user.uid,
        "category": "matrix",
      };

      print('📦 Payment Body: $paymentBody');

      final response = await http.post(
        Uri.parse('http://72.61.126.198:5000/api/payments/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'X-API-Key': 'faad44dba3074301571c2210e453b459',
        },
        body: jsonEncode(paymentBody),
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final payment = responseData['data'];
          print('✅ Matrix Payment Created Successfully!');
          print('Payment ID: ${payment['payment_id']}');
          print('Pay Address: ${payment['pay_address']}');

          // ✅ Navigate to QR Code Screen after success
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MatrixIncomeDepositQrCodeScreen(paymentData: payment),
            ),
          );
        } else {
          _showErrorSnackBar(
            "Payment Error: ${responseData['error'] ?? 'Unknown error'}",
          );
        }
      } else if (response.statusCode == 401) {
        _showErrorSnackBar("Session expired. Please try again.");
      } else if (response.statusCode == 403) {
        _showErrorSnackBar(
          "Payment creation not allowed. Please contact support.",
        );
      } else {
        _showErrorSnackBar("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error creating matrix payment: $e");
      _showErrorSnackBar("Payment process failed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ Simple Authentication with API Key only
  Future<String?> _authenticate() async {
    try {
      print('🔐 Authenticating with API key...');

      final loginResponse = await http.post(
        Uri.parse('http://72.61.126.198:5000/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': 'faad44dba3074301571c2210e453b459',
        },
        body: jsonEncode({"clientId": "deposit-client"}),
      );

      print('🔐 Login Response Status: ${loginResponse.statusCode}');
      print('🔐 Login Response Body: ${loginResponse.body}');

      if (loginResponse.statusCode == 200) {
        final loginData = jsonDecode(loginResponse.body);
        if (loginData['success'] == true) {
          print('✅ Permissions: ${loginData['data']['permissions']}');
          return loginData['data']['accessToken'];
        }
      }

      return null;
    } catch (e) {
      print('💥 Authentication error: $e');
      return null;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
