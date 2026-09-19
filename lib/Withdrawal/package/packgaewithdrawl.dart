import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PackageWithdrawalScreen extends StatefulWidget {
  final double claimAmount;

  const PackageWithdrawalScreen({Key? key, required this.claimAmount})
    : super(key: key);

  @override
  State<PackageWithdrawalScreen> createState() =>
      _PackageWithdrawalScreenState();
}

class _PackageWithdrawalScreenState extends State<PackageWithdrawalScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;
  String _selectedCurrency = 'usdtbsc';

  @override
  void initState() {
    super.initState();
    // Initialize amount controller with available amount
    _amountController.text = widget.claimAmount.toStringAsFixed(2);
  }

  // Get current withdrawal amount from text field
  double get _currentWithdrawalAmount {
    try {
      return double.parse(_amountController.text);
    } catch (e) {
      return 0.0;
    }
  }

  // Calculate current withdrawal fee (10% of entered amount)
  double get _currentWithdrawalFee {
    try {
      return _currentWithdrawalAmount * 0.10;
    } catch (e) {
      return 0.0;
    }
  }

  // Calculate current net amount after fee
  double get _currentNetAmount {
    try {
      return _currentWithdrawalAmount - _currentWithdrawalFee;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Withdraw Package Income",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: w * 0.045,
          ),
        ),
        backgroundColor: Color(0xFF0000FF),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0000FF), Color(0xFF4169E1)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: w * 0.1,
                  ),
                  SizedBox(height: h * 0.01),
                  Text(
                    "Package Income Withdrawal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: w * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: h * 0.005),
                  Text(
                    "Withdraw your package earnings to your wallet",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: w * 0.035,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.03),

            // Transaction Details
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Transaction Details",
                    style: TextStyle(
                      fontSize: w * 0.04,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0000FF),
                    ),
                  ),
                  SizedBox(height: h * 0.02),

                  _buildDetailRow(
                    "Available Amount:",
                    "\$${widget.claimAmount.toStringAsFixed(2)}",
                    w,
                  ),
                  _buildDetailRow(
                    "Withdrawal Fee:",
                    "10% of entered amount",
                    w,
                  ),
                  _buildDetailRow("Currency:", "USDT (BSC)", w),
                  _buildDetailRow("Category:", "Packages", w),
                  _buildDetailRow(
                    "Description:",
                    "Packages Wallet Earnings",
                    w,
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.03),

            // Withdrawal Amount Input
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Withdrawal Amount",
                    style: TextStyle(
                      fontSize: w * 0.038,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: h * 0.01),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter withdrawal amount",
                      hintStyle: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.grey[500],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF0000FF)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.018,
                      ),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: Color(0xFF0000FF),
                      ),
                      suffixText: "USD",
                      suffixStyle: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextStyle(fontSize: w * 0.038),
                    onChanged: (value) {
                      setState(() {
                        // Trigger UI update when amount changes
                      });
                    },
                  ),
                  SizedBox(height: h * 0.01),

                  // Real-time calculation display
                  Container(
                    padding: EdgeInsets.all(w * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        _buildCalculationRow(
                          "Withdrawal Amount:",
                          "\$${_currentWithdrawalAmount.toStringAsFixed(2)}",
                          w,
                        ),
                        _buildCalculationRow(
                          "Fee (10%):",
                          "-\$${_currentWithdrawalFee.toStringAsFixed(2)}",
                          w,
                        ),
                        Divider(),
                        _buildCalculationRow(
                          "You Will Receive:",
                          "\$${_currentNetAmount.toStringAsFixed(2)}",
                          w,
                          isBold: true,
                          isGreen: true,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: h * 0.01),
                  Text(
                    "Enter the amount you want to withdraw (max: \$${widget.claimAmount.toStringAsFixed(2)})",
                    style: TextStyle(
                      fontSize: w * 0.03,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.03),

            // Withdrawal Address Input
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Withdrawal Address",
                    style: TextStyle(
                      fontSize: w * 0.038,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: h * 0.01),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: "Enter your USDT (BSC) address",
                      hintStyle: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.grey[500],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF0000FF)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.018,
                      ),
                      prefixIcon: Icon(
                        Icons.account_balance_wallet,
                        color: Color(0xFF0000FF),
                      ),
                    ),
                    style: TextStyle(fontSize: w * 0.038),
                  ),
                  SizedBox(height: h * 0.01),
                  Text(
                    "Make sure to enter correct USDT (BSC) address starting with 0x",
                    style: TextStyle(
                      fontSize: w * 0.03,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.04),

            // Validation messages
            if (_currentWithdrawalAmount > widget.claimAmount)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(w * 0.03),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Amount cannot exceed available balance of \$${widget.claimAmount.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: w * 0.03,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_currentWithdrawalAmount <= 0 &&
                _amountController.text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(w * 0.03),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Please enter a valid amount greater than 0",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: w * 0.03,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_currentNetAmount <= 0 && _currentWithdrawalAmount > 0)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(w * 0.03),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Withdrawal amount must be greater than withdrawal fee",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: w * 0.03,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: h * 0.02),

            // Process Withdrawal Button
            _isProcessing
                ? Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0000FF),
                          ),
                        ),
                        SizedBox(height: h * 0.02),
                        Text(
                          "Processing Withdrawal...",
                          style: TextStyle(
                            fontSize: w * 0.038,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0000FF),
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canProcessWithdrawal
                          ? _processWithdrawal
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProcessWithdrawal
                            ? Color(0xFF0000FF)
                            : Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: h * 0.02),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        _canProcessWithdrawal
                            ? "Process Withdrawal"
                            : _getButtonDisabledReason(),
                        style: TextStyle(
                          fontSize: w * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

            SizedBox(height: h * 0.02),

            // Cancel Button
            // In PackageWithdrawalScreen's _showSuccessDialog method, update the OK button:
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // ✅ Return original amount if cancelled
                  Navigator.of(context).pop(widget.claimAmount);
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF0000FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 0.018),
                ),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    fontSize: w * 0.04,
                    color: Color(0xFF0000FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check if withdrawal can be processed
  bool get _canProcessWithdrawal {
    return _currentWithdrawalAmount > 0 &&
        _currentWithdrawalAmount <= widget.claimAmount &&
        _currentNetAmount > 0 &&
        _addressController.text.isNotEmpty &&
        _addressController.text.startsWith('0x') &&
        _addressController.text.length == 42;
  }

  // Get reason why button is disabled
  String _getButtonDisabledReason() {
    if (_currentWithdrawalAmount <= 0) return "Enter valid amount";
    if (_currentWithdrawalAmount > widget.claimAmount) return "Amount too high";
    if (_currentNetAmount <= 0) return "Amount too low after fees";
    if (_addressController.text.isEmpty) return "Enter withdrawal address";
    if (!_addressController.text.startsWith('0x') ||
        _addressController.text.length != 42) {
      return "Invalid wallet address";
    }
    return "Cannot process withdrawal";
  }

  Widget _buildDetailRow(
    String label,
    String value,
    double w, {
    bool isBold = false,
    bool isRed = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: w * 0.01),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: w * 0.035,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: w * 0.035,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isRed
                  ? Colors.red
                  : (isGreen ? Colors.green : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value,
    double w, {
    bool isBold = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: w * 0.032,
              color: Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: w * 0.032,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGreen ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _processWithdrawal() async {
    if (!_canProcessWithdrawal) return;

    setState(() {
      _isProcessing = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final withdrawalData = {
        "amount": _currentNetAmount.toStringAsFixed(2),
        "originalAmount": _currentWithdrawalAmount.toStringAsFixed(2),
        "withdrawalFee": _currentWithdrawalFee.toStringAsFixed(2),
        "currency": _selectedCurrency,
        "withdrawalAddress": _addressController.text.trim(),
        "userId": user.uid,
        "category": "packages",
        "orderDescription": "Packages Wallet Earnings",
        "feePercentage": "10%",
        "timestamp": DateTime.now().toIso8601String(),
        "status": "pending",
      };

      final token = await _authenticate();
      if (token == null) {
        _showErrorDialog("Authentication failed. Please try again.");
        return;
      }

      final response = await http
          .post(
            Uri.parse('http://72.61.126.198:5000/api/withdrawals/create'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'X-API-Key': 'faad44dba3074301571c2210e453b459',
            },
            body: json.encode(withdrawalData),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 308) {
        // ✅ Store withdrawal fee in Firebase
        await _storeWithdrawalFeeAndUpdateAmount(
          _currentWithdrawalFee,
          user.uid,
          _currentNetAmount,
          _currentWithdrawalAmount,
        );

        // ✅ Calculate remaining balance
        double remainingAmount = widget.claimAmount - _currentWithdrawalAmount;

        // In PackageWithdrawalScreen's _processWithdrawal method, update the success dialog handling:
        _showSuccessDialog(
          _currentNetAmount,
          _currentWithdrawalFee,
          _currentWithdrawalAmount,
          remainingAmount,
        ).then((_) {
          // ✅ Return remaining balance to previous screen as double
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(remainingAmount);
          }
        });
      } else {
        // Error handling...
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? 'Withdrawal failed';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      _showErrorDialog("Network error: Please check your connection");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // ✅ Add this method to PackageWithdrawalScreen
  Future<void> _updateRemainingBalanceInFirebase(
    double remainingBalance,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('Sponsar_wallets')
          .doc(user.uid)
          .update({
            'totalLevelBonus': remainingBalance,
            'levelEarnings': {
              'total': remainingBalance,
              'levels':
                  {}, // You might want to preserve level earnings structure
            },
          });

      print(
        '✅ Updated package wallet balance in Firebase: \$$remainingBalance',
      );
    } catch (e) {
      print('❌ Error updating package wallet in Firebase: $e');
    }
  }

  // Store 10% withdrawal fee in Firebase - BUT DON'T UPDATE PACKAGE WALLET
  Future<void> _storeWithdrawalFeeAndUpdateAmount(
    double fee,
    String userId,
    double netAmount,
    double withdrawalAmount,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Create batch for atomic operations
      WriteBatch batch = firestore.batch();

      // 1. Store withdrawal fee in a separate collection for history
      DocumentReference feeHistoryRef = firestore
          .collection('withdrawal_fees')
          .doc();
      batch.set(feeHistoryRef, {
        'userId': userId,
        'feeAmount': fee,
        'type': 'package_withdrawal',
        'timestamp': FieldValue.serverTimestamp(),
        'originalAmount': withdrawalAmount,
        'netAmount': netAmount,
        'currency': _selectedCurrency,
        'category': 'packages',
        'feePercentage': 10,
      });

      // 2. Update global withdrawal fees - SAME ADDRESS AS PASSIVE WITHDRAWAL
      DocumentReference globalFeesRef = firestore
          .collection('globalWithdrawalFees')
          .doc('totalFees');

      batch.set(globalFeesRef, {
        'balance': FieldValue.increment(fee),
        'lastUpdated': FieldValue.serverTimestamp(),
        'currency': 'USD',
      }, SetOptions(merge: true));

      // ✅ DON'T UPDATE packageWallet in Firestore - Keep it local only
      // Just store withdrawal record for history

      // Commit all operations
      await batch.commit();

      print(
        "✅ Package withdrawal fee of \$${fee.toStringAsFixed(2)} (10%) added to global fees",
      );
      print("✅ Withdrawn amount: \$${withdrawalAmount.toStringAsFixed(2)}");
      print("✅ Package wallet NOT updated in Firebase - kept local only");
    } catch (e) {
      print("❌ Error storing package withdrawal fee: $e");
      // Don't show error to user as withdrawal was successful
    }
  }

  // Updated success dialog to show remaining balance information
  // Updated success dialog that shows remaining balance
  Future<void> _showSuccessDialog(
    double netAmount,
    double fee,
    double withdrawalAmount,
    double remainingAmount,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        final w = size.width;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(w * 0.06),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: w * 0.15),
                SizedBox(height: 20),
                Text(
                  "Withdrawal Request Submitted!",
                  style: TextStyle(
                    fontSize: w * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),

                // Fee information with remaining balance
                Container(
                  padding: EdgeInsets.all(w * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      _buildFeeRow(
                        "Original Amount:",
                        "\$${widget.claimAmount.toStringAsFixed(2)}",
                        w,
                      ),
                      _buildFeeRow(
                        "Withdrawn Amount:",
                        "\$${withdrawalAmount.toStringAsFixed(2)}",
                        w,
                      ),
                      _buildFeeRow(
                        "Withdrawal Fee (10%):",
                        "-\$${fee.toStringAsFixed(2)}",
                        w,
                      ),
                      _buildFeeRow(
                        "Net Received:",
                        "\$${netAmount.toStringAsFixed(2)}",
                        w,
                      ),
                      Divider(),
                      _buildFeeRow(
                        "Remaining Balance:",
                        "\$${remainingAmount.toStringAsFixed(2)}",
                        w,
                        isBold: true,
                        isGreen: remainingAmount > 0,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15),
                Text(
                  "Your package income withdrawal request has been submitted successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: w * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 25),
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // ✅ Return original amount if cancelled
                      Navigator.of(context).pop(widget.claimAmount);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF0000FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 0.018),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: w * 0.04,
                        color: Color(0xFF0000FF),
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
    );
  }

  // Update the helper widget to support green color for positive amounts
  Widget _buildFeeRow(
    String label,
    String value,
    double w, {
    bool isBold = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: w * 0.035,
              color: Colors.grey[700],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: w * 0.035,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGreen
                  ? Colors.green
                  : (isBold ? Colors.green : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Simple Authentication with API Key only
  Future<String?> _authenticate() async {
    try {
      final loginResponse = await http.post(
        Uri.parse('http://72.61.126.198:5000/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': 'faad44dba3074301571c2210e453b459',
        },
        body: jsonEncode({"clientId": "deposit-client"}),
      );

      if (loginResponse.statusCode == 200) {
        final loginData = jsonDecode(loginResponse.body);
        if (loginData['success'] == true) {
          return loginData['data']['accessToken'];
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        final w = size.width;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(w * 0.05),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: w * 0.1),
                SizedBox(height: 15),
                Text(
                  "Withdrawal Failed",
                  style: TextStyle(
                    fontSize: w * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: w * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "OK",
                      style: TextStyle(
                        fontSize: w * 0.04,
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
      },
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
