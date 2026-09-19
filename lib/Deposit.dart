import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uktalhybird/DepositQrCode.dart';

class DepositScreen extends StatefulWidget {
  final String packageTitle;
  final String packagePrice;
  final String packageActivationFee;
  final double totalAmount;

  const DepositScreen({
    super.key,
    required this.packageTitle,
    required this.packagePrice,
    required this.packageActivationFee,
    required this.totalAmount,
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedCurrency = 'usdtbsc';
  String _selectedPackage = '';
  final primaryBlue = const Color(0xFF0000FF);
  final lightBlue = const Color(0xFFE6E6FF);
  bool _isLoading = false;

  // Map to store fixed total amounts for each package
  final Map<String, double> _packageTotalAmounts = {
    "Starter Package": 6.15,
    "Basic Package": 11.20,
    "Standard Package": 27.30,
    "Pro Package": 53.50,
    "Elite Package": 106.0,
    "Premium Package": 267.0,
    "Ultimate Package": 528.0,
  };

  @override
  void initState() {
    super.initState();
    _selectedPackage = widget.packageTitle;

    // Set the fixed total amount based on package title
    final fixedAmount =
        _packageTotalAmounts[widget.packageTitle] ?? widget.totalAmount;
    _amountController.text = fixedAmount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fixedTotalAmount =
        _packageTotalAmounts[widget.packageTitle] ?? widget.totalAmount;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Center(
          child: Padding(
            padding: EdgeInsets.only(right: 30),
            child: Text(
              'Deposit Funds',
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
            // 🔹 Package Information Card
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
                        "Package Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildDetailRow("Package:", widget.packageTitle),
                      _buildDetailRow("Price:", widget.packagePrice),
                      _buildDetailRow(
                        "Activation Fee:",
                        widget.packageActivationFee,
                      ),
                      _buildDetailRow(
                        "Total Amount:",
                        "\$${fixedTotalAmount.toStringAsFixed(2)}",
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Deposit Form Card
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
                        "Create Payment",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Amount Input (pre-filled with fixed total amount)
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

                      // Package Type (Read-only, showing selected package title)
                      TextFormField(
                        readOnly: true,
                        initialValue: _selectedPackage,
                        decoration: InputDecoration(
                          labelText: "Package Type",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.card_membership),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Create Payment Button
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _createPayment,
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
                                  "Create Payment",
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
                      "Please pay exactly \$${fixedTotalAmount.toStringAsFixed(2)} for ${widget.packageTitle}. Only send USDT (BEP20) to the provided address.",
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

  Future<void> _createPayment() async {
    final fixedTotalAmount =
        _packageTotalAmounts[widget.packageTitle] ?? widget.totalAmount;
    final amount = fixedTotalAmount.toString();

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar("Please login first");
        return;
      }

      final packageTitle = widget.packageTitle;

      print('🚀 Starting Crypto Payment API Flow');

      // ✅ Step 1: Authenticate
      final accessToken = await _authenticate();
      if (accessToken == null) {
        _showErrorSnackBar("Authentication failed. Please try again.");
        return;
      }

      // ✅ Step 2: Create Payment
      final paymentBody = {
        "amount": amount,
        "payCurrency": _selectedCurrency,
        "userId": user.uid,
        "category": "packages",
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
        // ✅ Accept both 200 and 201
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final payment = responseData['data'];
          print('✅ Payment Created Successfully!');
          print('Payment ID: ${payment['payment_id']}');
          print('Pay Address: ${payment['pay_address']}');

          // ✅ Navigate to QR Code Screen after success
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DepositQrCodeScreen(
                paymentData: payment,
                packageTitle: packageTitle,
                packagePrice: widget.packagePrice,
                packageActivationFee: widget.packageActivationFee,
                totalAmount: fixedTotalAmount,
              ),
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
      print("Error in payment process: $e");
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
