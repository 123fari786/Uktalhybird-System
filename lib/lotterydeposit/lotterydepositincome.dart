import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uktalhybird/lotterydeposit/lotterydepsitqrcode.dart';

class LotteryDepositScreen extends StatefulWidget {
  const LotteryDepositScreen({super.key});

  @override
  State<LotteryDepositScreen> createState() => _LotteryDepositScreenState();
}

class _LotteryDepositScreenState extends State<LotteryDepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedCurrency = 'usdtbsc';
  final primaryBlue = const Color(0xFF0000FF);
  final lightBlue = const Color(0xFFE6E6FF);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set fixed amount for lottery ticket
    _amountController.text = "1.15";
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
              'Lottery Ticket Purchase',
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
            // 🔹 Lottery Information Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lightBlue, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Lottery Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildDetailRow(
                        "Ticket Type:",
                        "Standard Lottery Ticket",
                      ),
                      _buildDetailRow("Ticket Price:", "\$1.00"),
                      _buildDetailRow("Processing Fee:", "\$0.15"),
                      _buildDetailRow("Total Amount:", "\$1.15", isTotal: true),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Purchase Form Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [lightBlue, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Purchase Lottery Ticket",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount Input (pre-filled with fixed lottery amount)
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        readOnly:
                            true, // Make it read-only since amount is fixed
                        decoration: InputDecoration(
                          labelText: "Amount (USD)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Currency Dropdown (Only BEP20)
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: InputDecoration(
                          labelText: "Payment Currency",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.currency_exchange),
                        ),
                        items: ['usdtbsc'].map((String currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text(
                              'USDT (BEP20)',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCurrency = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // Category Type (Read-only, showing lottery)
                      TextFormField(
                        readOnly: true,
                        initialValue: "lottery",
                        decoration: InputDecoration(
                          labelText: "Category Type",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Create Payment Button
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _createLotteryPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  shadowColor: primaryBlue.withOpacity(0.5),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  "Purchase Lottery Ticket",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Please pay exactly \$1.15 for Lottery Ticket. Only send USDT (BEP20) to the provided address.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Lottery Benefits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.purple[800]),
                      SizedBox(width: 8),
                      Text(
                        "Lottery Benefits",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildBenefit("Fair and transparent draws"),
                  _buildBenefit("Multiple winners every draw"),
                  _buildBenefit("Instant ticket confirmation"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? Colors.green[700] : Colors.black54,
              ),
            ),
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
          Icon(Icons.check_circle, color: Colors.purple, size: 16),
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

  Future<void> _createLotteryPayment() async {
    final amount = "1.15"; // Fixed lottery ticket amount

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar("Please login first");
        return;
      }

      print('🚀 Starting Lottery Payment API Flow');

      // ✅ Step 1: Authenticate
      final accessToken = await _authenticate();
      if (accessToken == null) {
        _showErrorSnackBar("Authentication failed. Please try again.");
        return;
      }

      // ✅ Step 2: Create Payment for Lottery
      final paymentBody = {
        "amount": amount,
        "payCurrency": _selectedCurrency,
        "userId": user.uid,
        "category": "lottery", // Changed from "packages" to "lottery"
      };

      print('📦 Lottery Payment Body: $paymentBody');

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
        // ✅ Accept both 200 and 201
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final payment = responseData['data'];
          print('✅ Lottery Payment Created Successfully!');
          print('Payment ID: ${payment['payment_id']}');
          print('Pay Address: ${payment['pay_address']}');

          // ✅ Navigate to QR Code Screen after success
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LotteryDepositQrCodeScreen(paymentData: responseData['data']),
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
      print("Error in lottery payment process: $e");
      _showErrorSnackBar("Payment process failed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ Simple Authentication with API Key only (Same as packages)
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

  // ✅ Error SnackBar
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
