import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PassiveWithScreen extends StatefulWidget {
  final double claimAmount;

  const PassiveWithScreen({Key? key, required this.claimAmount})
    : super(key: key);

  @override
  State<PassiveWithScreen> createState() => _PassiveWithScreenState();
}

class _PassiveWithScreenState extends State<PassiveWithScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;
  String _selectedCurrency = 'usdtbsc';

  // Make these mutable instead of getters
  double _withdrawalFee = 0.0;
  double _netAmount = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize with calculated values
    _withdrawalFee = widget.claimAmount * 0.10;
    _netAmount = widget.claimAmount - _withdrawalFee;
    _amountController.text = _netAmount.toStringAsFixed(2);
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
          "Withdraw Passive Income",
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
                    "Passive Income Withdrawal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: w * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: h * 0.005),
                  Text(
                    "Withdraw your passive rewards to your wallet",
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
                    "Gross Amount:",
                    "\$${widget.claimAmount.toStringAsFixed(2)}",
                    w,
                  ),
                  _buildDetailRow(
                    "Withdrawal Fee (10%):",
                    "-\$${_withdrawalFee.toStringAsFixed(2)}",
                    w,
                    isRed: true,
                  ),
                  _buildDetailRow(
                    "Net Amount:",
                    "\$${_netAmount.toStringAsFixed(2)}",
                    w,
                    isBold: true,
                    isGreen: true,
                  ),
                  _buildDetailRow("Currency:", "USDT (BSC)", w),
                  _buildDetailRow("Category:", "Passive Income", w),
                  _buildDetailRow("Description:", "Passive Pool Packages", w),

                  // Minimum amount warning
                  if (_netAmount <= 0)
                    Container(
                      margin: EdgeInsets.only(top: 10),
                      padding: EdgeInsets.all(10),
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
                ],
              ),
            ),

            SizedBox(height: h * 0.03),

            // Editable Amount Field
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
                    "Withdrawal Amount (Net)",
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
                      // Update the net amount when user edits the field
                      if (value.isNotEmpty) {
                        double editedAmount = double.tryParse(value) ?? 0.0;
                        if (editedAmount > 0 &&
                            editedAmount <= widget.claimAmount) {
                          setState(() {
                            // Recalculate based on edited amount
                            _netAmount = editedAmount;
                            _withdrawalFee = editedAmount * 0.10; // 10% fee
                          });
                        }
                      }
                    },
                  ),
                  SizedBox(height: h * 0.01),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: w * 0.04,
                      ),
                      SizedBox(width: w * 0.02),
                      Expanded(
                        child: Text(
                          "Net amount after 10% withdrawal fee. Maximum: \$${widget.claimAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: w * 0.03,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
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
                      onPressed: _netAmount > 0 ? _processWithdrawal : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _netAmount > 0
                            ? Color(0xFF0000FF)
                            : Colors.grey,
                        padding: EdgeInsets.symmetric(vertical: h * 0.02),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        _netAmount > 0
                            ? "Process Withdrawal"
                            : "Insufficient amount after fees",
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
            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(false); // ✅ false return karein for cancellation
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF0000FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: h * 0.018),
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

  void _processWithdrawal() async {
    // Check if net amount is positive
    if (_netAmount <= 0) {
      _showErrorDialog("Withdrawal amount must be greater than withdrawal fee");
      return;
    }

    if (_addressController.text.isEmpty) {
      _showErrorDialog("Please enter withdrawal address");
      return;
    }

    // Validate USDT address format
    if (!_addressController.text.startsWith('0x') ||
        _addressController.text.length != 42) {
      _showErrorDialog(
        "Please enter a valid USDT (BSC) address starting with 0x",
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      print("💰 Passive Withdrawal Details:");
      print("📊 Gross Amount: \$${widget.claimAmount.toStringAsFixed(2)}");
      print("📊 Withdrawal Fee (10%): \$${_withdrawalFee.toStringAsFixed(2)}");
      print("📊 Net Amount: \$${_netAmount.toStringAsFixed(2)}");

      // Calculate remaining balance
      double remainingBalance =
          widget.claimAmount - _netAmount - _withdrawalFee;
      print("📊 Remaining Balance: \$${remainingBalance.toStringAsFixed(2)}");

      // ✅ CORRECTED: Use "passive_income" for category
      final withdrawalData = {
        "amount": _netAmount.toStringAsFixed(
          2,
        ), // Send net amount after 10% fee
        "originalAmount": widget.claimAmount.toStringAsFixed(2),
        "withdrawalFee": _withdrawalFee.toStringAsFixed(2), // 10% fee
        "currency": _selectedCurrency,
        "withdrawalAddress": _addressController.text.trim(),
        "userId": user.uid,
        "category":
            "passive_income", // ✅ CORRECTED: Changed to "passive_income"
        "orderDescription": "Passive Pool Packages", // ✅ CORRECTED description
        "feePercentage": "10%",
        "timestamp": DateTime.now().toIso8601String(),
        "status": "pending",
      };

      print("📤 Sending passive withdrawal request...");

      // ✅ Step 1: Authenticate and get JWT token
      final token = await _authenticate();
      if (token == null) {
        _showErrorDialog("Authentication failed. Please try again.");
        return;
      }

      // ✅ Step 2: Make API call with API Key + JWT token
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

      print("📥 API Response: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ Payment created successfully - Store 10% fee in Firebase and update passive rewards
        await _updatePassiveRewardsAfterWithdrawal(
          _withdrawalFee,
          user.uid,
          _netAmount,
          remainingBalance,
          widget.claimAmount,
        );
        _showSuccessDialog(_netAmount, _withdrawalFee, remainingBalance);
      } else if (response.statusCode == 308) {
        // Consider success for user experience - Also update passive rewards
        await _updatePassiveRewardsAfterWithdrawal(
          _withdrawalFee,
          user.uid,
          _netAmount,
          remainingBalance,
          widget.claimAmount,
        );
        _showSuccessDialog(_netAmount, _withdrawalFee, remainingBalance);
      } else {
        // Parse error message for better user feedback
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['error'] ?? 'Withdrawal failed';
          final details = errorData['details'] ?? [];

          String detailedMessage = errorMessage.toString();
          if (details.isNotEmpty) {
            detailedMessage += '\n${details[0]['message'] ?? ''}';
          }

          _showErrorDialog(detailedMessage);
        } catch (e) {
          _showErrorDialog("Withdrawal failed: ${response.statusCode}");
        }
      }
    } on TimeoutException catch (_) {
      _showErrorDialog("Request timeout. Please try again later.");
    } catch (e) {
      print("❌ Passive withdrawal error: $e");
      _showErrorDialog("Network error: Please check your connection");
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Updated method to handle passive rewards after withdrawal
  Future<void> _updatePassiveRewardsAfterWithdrawal(
    double fee,
    String userId,
    double netAmount,
    double remainingBalance,
    double originalAmount,
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
        'type': 'passive_withdrawal',
        'timestamp': FieldValue.serverTimestamp(),
        'originalAmount': originalAmount,
        'netAmount': netAmount,
        'remainingBalance': remainingBalance,
        'currency': 'usdtbsc',
        'category': 'passive_income',
        'feePercentage': 10,
      });

      // 2. Update global withdrawal fees
      DocumentReference globalFeesRef = firestore
          .collection('globalWithdrawalFees')
          .doc('totalFees');

      batch.set(globalFeesRef, {
        'balance': FieldValue.increment(fee),
        'lastUpdated': FieldValue.serverTimestamp(),
        'currency': 'USD',
      }, SetOptions(merge: true));

      // 3. Update passive_rewards collection - mark withdrawn amount and keep remaining
      if (remainingBalance > 0) {
        // If there's remaining balance, create a new passive reward document for the remaining amount
        DocumentReference remainingRewardRef = firestore
            .collection('passive_rewards')
            .doc();
        batch.set(remainingRewardRef, {
          'userId': userId,
          'rewardAmount': remainingBalance,
          'status': 'credited',
          'type': 'remaining_after_withdrawal',
          'originalAmount': originalAmount,
          'withdrawnAmount': netAmount + fee,
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Remaining balance after partial withdrawal',
        });
      }

      // 4. Update existing passive rewards to mark them as partially withdrawn
      final existingRewards = await firestore
          .collection('passive_rewards')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'credited')
          .get();

      for (var doc in existingRewards.docs) {
        batch.update(doc.reference, {
          'status': 'partially_withdrawn',
          'withdrawnAt': FieldValue.serverTimestamp(),
          'withdrawnAmount': netAmount + fee,
          'remainingBalance': remainingBalance,
        });
      }

      // Commit all operations
      await batch.commit();

      print("✅ Passive withdrawal processed successfully");
      print(
        "✅ Withdrawn: \$${netAmount.toStringAsFixed(2)} + Fee: \$${fee.toStringAsFixed(2)}",
      );
      print("✅ Remaining Balance: \$${remainingBalance.toStringAsFixed(2)}");
    } catch (e) {
      print("❌ Error updating passive rewards after withdrawal: $e");
      // Don't show error to user as withdrawal was successful
    }
  }

  // Store 10% withdrawal fee in Firebase and reset the passive wallet amount
  Future<void> _storeWithdrawalFeeAndResetPassiveWallet(
    double fee,
    String userId,
    double netAmount,
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
        'type': 'passive_withdrawal',
        'timestamp': FieldValue.serverTimestamp(),
        'originalAmount': widget.claimAmount,
        'netAmount': netAmount,
        'currency': _selectedCurrency,
        'category': 'passive_income',
        'feePercentage': 10,
      });

      // 2. Update global withdrawal fees - SAME ADDRESS AS PACKAGE WITHDRAWAL
      DocumentReference globalFeesRef = firestore
          .collection('globalWithdrawalFees')
          .doc('totalFees');

      batch.set(globalFeesRef, {
        'balance': FieldValue.increment(fee),
        'lastUpdated': FieldValue.serverTimestamp(),
        'currency': 'USD',
      }, SetOptions(merge: true));

      // 3. Reset the passiveWallet amount to 0 in user's document
      DocumentReference userRef = firestore
          .collection('Signup_Data')
          .doc(userId);
      batch.update(userRef, {
        'passiveWallet':
            0.0, // ✅ Reset passive wallet instead of package wallet
        'lastWithdrawal': FieldValue.serverTimestamp(),
        'lastWithdrawalAmount': widget.claimAmount,
        'lastWithdrawalType': 'passive_income',
      });

      // Commit all operations
      await batch.commit();

      print(
        "✅ Passive withdrawal fee of \$${fee.toStringAsFixed(2)} (10%) added to global fees",
      );
      print("✅ Passive wallet reset to 0 for user: $userId");
    } catch (e) {
      print("❌ Error storing passive withdrawal fee: $e");
      // Don't show error to user as withdrawal was successful
    }
  }

  void _showSuccessDialog(
    double netAmount,
    double fee,
    double remainingBalance,
  ) {
    showDialog(
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

                // Fee information
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
                        "Gross Amount:",
                        "\$${widget.claimAmount.toStringAsFixed(2)}",
                        w,
                      ),
                      _buildFeeRow(
                        "Withdrawn Amount:",
                        "-\$${netAmount.toStringAsFixed(2)}",
                        w,
                      ),
                      _buildFeeRow(
                        "Withdrawal Fee (10%):",
                        "-\$${fee.toStringAsFixed(2)}",
                        w,
                      ),
                      Divider(),
                      _buildFeeRow(
                        "Remaining Balance:",
                        "\$${remainingBalance.toStringAsFixed(2)}",
                        w,
                        isBold: true,
                        isGreen: true,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15),
                Text(
                  "Your partial withdrawal has been processed successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: w * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
                if (remainingBalance > 0)
                  Text(
                    "Remaining balance of \$${remainingBalance.toStringAsFixed(2)} is still available for withdrawal.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: w * 0.032,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        true,
                      ); // ✅ true return karein for successful withdrawal
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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

  // Helper widget for fee rows
  // Helper widget for fee rows
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
