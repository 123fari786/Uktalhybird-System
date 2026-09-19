import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uktalhybird/BoottomNavigationlayout.dart';

class MatrixIncomeDepositQrCodeScreen extends StatefulWidget {
  final Map<String, dynamic> paymentData;

  const MatrixIncomeDepositQrCodeScreen({super.key, required this.paymentData});

  @override
  State<MatrixIncomeDepositQrCodeScreen> createState() =>
      _MatrixIncomeDepositQrCodeScreenState();
}

class _MatrixIncomeDepositQrCodeScreenState
    extends State<MatrixIncomeDepositQrCodeScreen> {
  late Map<String, dynamic> _paymentData;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  final primaryBlue = const Color(0xFF0000FF);
  final lightBlue = const Color(0xFFE6E6FF);
  bool _paymentCompleted = false;
  bool _isProcessingCompletion = false;
  bool _successDialogShown = false;

  @override
  void initState() {
    super.initState();
    _paymentData = widget.paymentData;

    print('🎯 Initial Payment Data: $_paymentData');
    print('🎯 Payment ID: ${_paymentData['payment_id']}');

    // Start listening to Firestore for real-time updates
    _startFirestoreListening();

    // Start polling for payment status every 10 seconds (as backup)
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _checkPaymentStatus();
    });
  }

  void _startFirestoreListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User not logged in');
      return;
    }

    final paymentId = _paymentData['payment_id'].toString();
    print('🎯 Starting Firestore listening for payment: $paymentId');

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('matrix_payments')
        .doc(paymentId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            print('📡 Firestore snapshot received: ${snapshot.exists}');

            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              print('📡 Firestore data: $data');

              // Check status with multiple possible field names
              final status =
                  data['status'] ?? data['payment_status'] ?? 'waiting';
              print('📡 Detected status: $status');

              // ✅ UPDATE: Add completion checks
              if (!_paymentCompleted && !_isProcessingCompletion) {
                if (status == 'finished' || status == 'completed') {
                  print('✅ Payment completed detected from Firestore');
                  _handlePaymentCompletion();
                } else if (status == 'failed' || status == 'error') {
                  print('❌ Payment failed detected from Firestore');
                  _handlePaymentFailure();
                }
              }

              // Update UI with latest data from Firestore
              setState(() {
                _paymentData = {
                  ..._paymentData,
                  'payment_status': status,
                  'pay_amount':
                      data['pay_amount'] ??
                      data['amount'] ??
                      _paymentData['pay_amount'],
                  'price_amount':
                      data['price_amount'] ??
                      data['amount'] ??
                      _paymentData['price_amount'],
                  'pay_currency':
                      data['pay_currency'] ??
                      data['currency'] ??
                      _paymentData['pay_currency'],
                  'pay_address':
                      data['pay_address'] ??
                      data['address'] ??
                      _paymentData['pay_address'],
                };
              });
            } else {
              print('📡 Firestore document does not exist yet');
            }
          },
          onError: (error) {
            print("❌ Firestore listening error: $error");
          },
        );
  }

  void _handlePaymentFailure() {
    print('🛑 Handling payment failure');
    _timer?.cancel();
    _firestoreSubscription?.cancel();

    // ✅ ADD: Check if already showing something
    if (mounted && !_paymentCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Matrix Payment Failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    // ✅ ADD: Don't check if already completed
    if (_paymentCompleted || _isProcessingCompletion) {
      return;
    }

    try {
      print('🔄 Checking payment status via API');
      final response = await http.get(
        Uri.parse(
          'https://crypto-api-pi.vercel.app/api/payments/status/${_paymentData['payment_id']}',
        ),
      );

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        setState(() {
          _paymentData = responseData['data'];
        });

        // ✅ ADD: Completion checks
        if (!_paymentCompleted && !_isProcessingCompletion) {
          if (_paymentData['payment_status'] == 'finished') {
            print('✅ Payment completed detected from API');
            _handlePaymentCompletion();
          } else if (_paymentData['payment_status'] == 'failed') {
            print('❌ Payment failed detected from API');
            _handlePaymentFailure();
          }
        }
      }
    } catch (e) {
      print("❌ Error checking payment status: $e");
    }
  }

  void _handlePaymentCompletion() {
    // ✅ UPDATE: Prevent multiple executions
    if (_paymentCompleted || _isProcessingCompletion || _successDialogShown) {
      print('🛑 Payment completion already processed, skipping...');
      return;
    }

    print('🎉 Handling payment completion');
    _isProcessingCompletion = true;

    _timer?.cancel();
    _firestoreSubscription?.cancel();

    setState(() {
      _paymentCompleted = true;
    });

    // ✅ UPDATE: Store payment data first, then show success
    _storeMatrixPaymentData()
        .then((_) {
          _showSuccessDialogAndRedirect();
        })
        .catchError((error) {
          print('❌ Error storing matrix payment data: $error');
          _showSuccessDialogAndRedirect(); // Still show success even if storage fails
        });

    _isProcessingCompletion = false;
  }

  // ✅ NEW: Function to store matrix payment data
  Future<void> _storeMatrixPaymentData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final paymentId = _paymentData['payment_id'].toString();
      final amount =
          double.tryParse(_paymentData['price_amount'].toString()) ?? 0.0;

      // Store in user's matrix payments collection
      await FirebaseFirestore.instance
          .collection('Matric_payment_deposit')
          .doc(user.uid)
          .collection('matrix_payments')
          .doc(paymentId)
          .set({
            'paymentId': paymentId,
            'amount': amount,
            'currency': _paymentData['pay_currency'],
            'status': 'completed',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'matrix_income_deposit',
          });

      print('✅ Matrix payment data stored for user: ${user.uid}');
    } catch (e) {
      print('❌ Error storing matrix payment data: $e');
      rethrow;
    }
  }

  // ✅ UPDATED: Improved success handler with redirect to Matrix screen
  void _showSuccessDialogAndRedirect() {
    if (!mounted || _successDialogShown) {
      return;
    }

    _successDialogShown = true;
    print('🔄 Showing success dialog');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 15),
                Text(
                  "Payment Successful!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Your matrix income deposit of \$${_paymentData['price_amount']} has been completed successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      _redirectToMatrixScreen(); // ✅ CHANGED: Redirect to Matrix screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Successfully Done",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((value) {
      // If dialog is dismissed without pressing button, still redirect to Matrix screen
      if (mounted) {
        _redirectToMatrixScreen();
      }
    });
  }

  // ✅ UPDATED: Redirect to Matrix screen instead of Main screen
  void _redirectToMatrixScreen() {
    if (!mounted) return;

    print('🔄 Redirecting to Matrix Screen');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(),
      ), // ✅ CHANGED: MatrixScreen
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentCompleted) {
      return _buildSuccessScreen();
    }

    return _buildPaymentScreen();
  }

  Widget _buildPaymentScreen() {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Complete Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 Payment Header
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
              child: Column(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "Scan QR Code to Pay",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Send exact amount to activate matrix system",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 🔹 QR Code Card
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
                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryBlue, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.2),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _paymentData['pay_address'],
                          version: QrVersions.auto,
                          size: size.width * 0.5,
                          eyeStyle: QrEyeStyle(
                            color: primaryBlue,
                            eyeShape: QrEyeShape.square,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            color: primaryBlue,
                            dataModuleShape: QrDataModuleShape.square,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Payment Amount
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.attach_money, color: Colors.green[800]),
                            SizedBox(width: 8),
                            Text(
                              "Send: ${_paymentData['pay_amount']} ${_paymentData['pay_currency'].toUpperCase()}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
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
                          children: [
                            _buildPaymentDetail(
                              "Payment ID:",
                              _paymentData['payment_id'].toString(),
                            ),
                            _buildPaymentDetail(
                              "USD Amount:",
                              "\$${_paymentData['price_amount']}",
                            ),
                            _buildPaymentDetail(
                              "Status:",
                              _paymentData['payment_status'],
                              isStatus: true,
                            ),
                            _buildPaymentDetail(
                              "Network:",
                              "Binance Smart Chain",
                            ),
                            _buildPaymentDetail(
                              "Real-time Monitoring:",
                              "Active",
                              isStatus: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Wallet Address
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryBlue.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wallet,
                                  color: primaryBlue,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Wallet Address",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: primaryBlue.withOpacity(0.2),
                                ),
                              ),
                              child: SelectableText(
                                _paymentData['pay_address'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Copy Address Button
                      Container(
                        width: double.infinity,
                        height: 50,
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
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _paymentData['pay_address']),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Address copied to clipboard!",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          icon: Icon(Icons.copy, color: Colors.white, size: 20),
                          label: Text(
                            "Copy Wallet Address",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // 🔹 Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange[800]),
                      SizedBox(width: 8),
                      Text(
                        "Important Instructions",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildInstruction(
                    "Send exactly ${_paymentData['pay_amount']} ${_paymentData['pay_currency'].toUpperCase()}",
                  ),
                  _buildInstruction("Use only Binance Smart Chain network"),
                  _buildInstruction("Do not send other cryptocurrencies"),
                  _buildInstruction("Payment will confirm automatically"),
                  _buildInstruction("Contact support if issues occur"),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Status Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.blue[700], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Real-time Monitoring Active",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Listening to Firestore + API polling every 10 seconds",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
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

  // ✅ UPDATED: Success screen with Matrix screen redirect
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Payment Successful',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 60),
              ),
              SizedBox(height: 20),
              Text(
                "Payment Completed!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                "Your matrix income deposit has been processed successfully.",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSuccessDetail(
                        "Amount",
                        "\$${_paymentData['price_amount']}",
                      ),
                      _buildSuccessDetail(
                        "Currency",
                        _paymentData['pay_currency'].toUpperCase(),
                      ),
                      _buildSuccessDetail(
                        "Payment ID",
                        _paymentData['payment_id'].toString(),
                      ),
                      _buildSuccessDetail(
                        "Status",
                        "Completed",
                        isSuccess: true,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green, Color(0xFF00C853)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _redirectToMatrixScreen(); // ✅ CHANGED: Redirect to Matrix screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Go to Matrix Screen", // ✅ CHANGED: Button text
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
    );
  }

  Widget _buildPaymentDetail(
    String label,
    String value, {
    bool isStatus = false,
  }) {
    Color statusColor = Colors.orange;
    if (isStatus) {
      if (value == 'finished' || value == 'completed')
        statusColor = Colors.green;
      else if (value == 'failed' || value == 'error')
        statusColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isStatus ? statusColor : primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: Colors.orange[800]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessDetail(
    String label,
    String value, {
    bool isSuccess = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSuccess ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
