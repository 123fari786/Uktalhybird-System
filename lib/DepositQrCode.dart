import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uktalhybird/BoottomNavigationlayout.dart';

class DepositQrCodeScreen extends StatefulWidget {
  final Map<String, dynamic> paymentData;
  final String packageTitle;
  final String packagePrice; // Add this
  final String packageActivationFee; // Add this
  final double totalAmount; // Add this

  const DepositQrCodeScreen({
    super.key,
    required this.paymentData,
    required this.packageTitle,
    required this.packagePrice, // Add this
    required this.packageActivationFee, // Add this
    required this.totalAmount, // Add this
  });

  @override
  State<DepositQrCodeScreen> createState() => _DepositQrCodeScreenState();
}

class _DepositQrCodeScreenState extends State<DepositQrCodeScreen> {
  late Map<String, dynamic> _paymentData;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  final primaryBlue = const Color(0xFF0000FF);
  final lightBlue = const Color(0xFFE6E6FF);
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _paymentData = widget.paymentData;

    // Start listening to Firestore for real-time updates
    _startFirestoreListening();

    // Start polling for payment status every 8 seconds (as backup)
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      await _checkPaymentStatus();
    });
  }

  void _startFirestoreListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('payments')
        .doc(_paymentData['payment_id'].toString())
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              if (data['status'] == 'finished') {
                _handlePaymentCompletion();
              } else if (data['status'] == 'failed') {
                _handlePaymentFailure();
              }

              // Update UI with latest data from Firestore
              setState(() {
                _paymentData = {
                  ..._paymentData,
                  'payment_status': data['status'],
                  'pay_amount': data['pay_amount'],
                  'price_amount': data['amount'],
                  'pay_currency': data['currency'],
                  'pay_address': data['pay_address'],
                };
              });
            }
          },
          onError: (error) {
            print("Firestore listening error: $error");
          },
        );
  }

  Future<void> _updateUserWallet(double amount, String userId) async {
    final userWalletRef = FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId);

    // ✅ UPDATED: Calculate shares with 55% level distribution
    final lotteryShare = amount * 0.10;
    final passiveShare = amount * 0.20;
    final rewardTaskShare = amount * 0.10; // ✅ NEW: 10% for Reward and Task
    final maintenanceShare = amount * 0.05; // ✅ NEW: 5% for Maintenance Fund
    final levelPool = amount * 0.55; // 55% for level distribution
    final remainingBalance =
        amount -
        (lotteryShare +
            passiveShare +
            levelPool +
            maintenanceShare +
            rewardTaskShare); // 15%

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userWalletRef);

      if (!snapshot.exists) {
        transaction.set(userWalletRef, {
          'balance': remainingBalance,
          'totalDeposit': amount,
          'lastDeposit': amount,
          'lotteryShare': lotteryShare,
          'passiveShare': passiveShare,
          'rewardTaskShare': rewardTaskShare, // ✅ ADDED: Reward and Task share
          'maintenanceShare':
              maintenanceShare, // ✅ ADDED: Maintenance fund share
          'levelPool': levelPool, // ✅ ADDED: Level pool amount
          'remainingBalance': remainingBalance,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final currentBalance = (data['balance'] ?? 0.0).toDouble();
        final currentTotalDeposit = (data['totalDeposit'] ?? 0.0).toDouble();
        transaction.update(userWalletRef, {
          'balance': currentBalance + remainingBalance,
          'lastDeposit': amount,
          'totalDeposit': currentTotalDeposit + amount,
          'lotteryShare': lotteryShare,
          'passiveShare': passiveShare,
          'rewardTaskShare': rewardTaskShare, // ✅ ADDED: Reward and Task share
          'maintenanceShare':
              maintenanceShare, // ✅ ADDED: Maintenance fund share
          'levelPool': levelPool, // ✅ ADDED: Level pool amount
          'remainingBalance': remainingBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ✅ UPDATED: Global reward fund
  Future<void> _storeRewardTaskAmount(double amount, String userId) async {
    try {
      final rewardTaskRef = FirebaseFirestore.instance
          .collection('globalRewardFund')
          .doc('mainFund');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(rewardTaskRef);

        if (!snapshot.exists) {
          transaction.set(rewardTaskRef, {
            'balance': amount,
            'totalRewardAmount': amount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data() as Map<String, dynamic>;
          final currentBalance = (data['balance'] ?? 0.0).toDouble();
          final currentTotal = (data['totalRewardAmount'] ?? 0.0).toDouble();

          transaction.update(rewardTaskRef, {
            'balance': currentBalance + amount,
            'totalRewardAmount': currentTotal + amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ 10% added to global reward fund: \$$amount');
    } catch (e) {
      print('❌ Error storing global reward fund: $e');
    }
  }

  // ✅ UPDATED: Global maintenance fund
  Future<void> _storeMaintenanceAmount(double amount, String userId) async {
    try {
      final maintenanceRef = FirebaseFirestore.instance
          .collection('globalMaintenanceFund')
          .doc('mainFund');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(maintenanceRef);

        if (!snapshot.exists) {
          transaction.set(maintenanceRef, {
            'balance': amount,
            'totalMaintenanceAmount': amount,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data() as Map<String, dynamic>;
          final currentBalance = (data['balance'] ?? 0.0).toDouble();
          final currentTotal = (data['totalMaintenanceAmount'] ?? 0.0)
              .toDouble();

          transaction.update(maintenanceRef, {
            'balance': currentBalance + amount,
            'totalMaintenanceAmount': currentTotal + amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ 5% added to global maintenance fund: \$$amount');
    } catch (e) {
      print('❌ Error storing global maintenance fund: $e');
    }
  }

  // ✅ UPDATED: Global passive pool
  Future<void> _updatePassiveWallet(double amount) async {
    final passiveWalletRef = FirebaseFirestore.instance
        .collection('globalPassivePool')
        .doc('mainPool');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(passiveWalletRef);

      if (!snapshot.exists) {
        transaction.set(passiveWalletRef, {
          'balance': amount,
          'totalPoolAmount': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final currentBalance = (data['balance'] ?? 0).toDouble();
        final currentTotal = (data['totalPoolAmount'] ?? 0).toDouble();

        transaction.update(passiveWalletRef, {
          'balance': currentBalance + amount,
          'totalPoolAmount': currentTotal + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    print('✅ 20% added to global passive pool: \$$amount');
  }

  void _handlePaymentFailure() {
    _timer?.cancel();
    _firestoreSubscription?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Payment Failed"),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();

    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://crypto-api-pi.vercel.app/api/payments/status/${_paymentData['payment_id']}',
        ),
      );

      final responseData = jsonDecode(response.body);

      if (responseData['success'] == true) {
        setState(() {
          _paymentData = responseData['data'];
        });

        if (_paymentData['payment_status'] == 'finished') {
          _handlePaymentCompletion();
        } else if (_paymentData['payment_status'] == 'failed') {
          _handlePaymentFailure();
        }
      }
    } catch (e) {
      print("Error checking payment status: $e");
    }
  }

  void _showSuccessDialog() {
    final packagePriceValue =
        double.tryParse(widget.packagePrice.replaceAll('\$', '')) ?? 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    "Payment Successful!",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Congratulations! You have successfully purchased ${widget.packageTitle} for \$$packagePriceValue.", // ✅ Show package price
              ),
              const SizedBox(height: 16),
              const Text(
                "Your payment has been processed and the funds have been added to your account.",
              ),
              const SizedBox(height: 16),
              _buildSuccessInfoRow(
                "Payment ID",
                _paymentData['payment_id'].toString(),
              ),
              _buildSuccessInfoRow(
                "Package Price", // ✅ Change label to Package Price
                "\$$packagePriceValue", // ✅ Show package price
              ),
              _buildSuccessInfoRow(
                "Currency",
                _paymentData['pay_currency'].toUpperCase(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }

  // ✅ UPDATED: Function to update lottery wallet with 10% only (no tickets)
  // ✅ UPDATED: Global lottery fund
  Future<void> _updateLotteryWallet(double amount) async {
    final lotteryWalletRef = FirebaseFirestore.instance
        .collection('globalLotteryFund')
        .doc('mainFund');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(lotteryWalletRef);

      if (!snapshot.exists) {
        transaction.set(lotteryWalletRef, {
          'balance': amount,
          'totalContributions': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data() as Map<String, dynamic>;
        final currentBalance = (data['balance'] ?? 0).toDouble();
        final currentTotal = (data['totalContributions'] ?? 0).toDouble();

        transaction.update(lotteryWalletRef, {
          'balance': currentBalance + amount,
          'totalContributions': currentTotal + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    print('✅ 10% added to global lottery fund: \$$amount');
  }

  void _handlePaymentCompletion() async {
    _timer?.cancel();
    _firestoreSubscription?.cancel();
    setState(() {
      _paymentCompleted = true;
    });
    _showSuccessDialog();
    final packagePriceValue =
        double.tryParse(widget.packagePrice.replaceAll('\$', '')) ?? 0.0;

    final amount = packagePriceValue; // Use package price for calculations

    final userId = FirebaseAuth.instance.currentUser!.uid;
    final activationFee =
        double.tryParse(widget.packageActivationFee.replaceAll('\$', '')) ?? 0;

    String packageTitle = widget.packageTitle;
    await _storeActivationFee(userId, activationFee);

    // ✅ Validate package title
    if (packageTitle.isEmpty) {
      packageTitle = _paymentData['orderDescription']?.toString().trim() ?? '';
      if (packageTitle.isEmpty) {
        packageTitle = _getPackageNameFromAmount(amount);
      }
    }

    print('💾 Saving purchased package: "$packageTitle" for amount: \$$amount');

    // ✅ Save purchased package to Firestore with separate activation fee
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('purchasedPackages')
        .doc(_paymentData['payment_id'].toString())
        .set({
          'packageTitle': packageTitle,
          'packagePrice': widget.packagePrice,
          'activationFee': widget.packageActivationFee,
          'totalAmount': amount,
          'currency': _paymentData['pay_currency'],
          'status': 'finished',
          'paymentId': _paymentData['payment_id'],
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'breakdown': {
            'packagePrice': widget.packagePrice,
            'activationFee': widget.packageActivationFee,
            'totalPaid': amount.toString(),
          },
        });

    // ✅ UPDATED: Update all allocations with new distribution
    await _updateUserWallet(amount, userId);
    await _updateLotteryWallet(amount * 0.10); // 10% to lottery wallet
    await _updatePassiveWallet(amount * 0.20); // 20% to passive wallet

    // ✅ NEW: Store Reward & Task and Maintenance amounts
    await _storeRewardTaskAmount(amount * 0.10, userId); // 10% to Reward & Task
    await _storeMaintenanceAmount(amount * 0.05, userId); // 5% to Maintenance

    // ✅ Distribute level income to 11 uplines with 55% pool
    await _distributeLevelIncome(amount, userId);
  }

  // Updated function to handle level-based income distribution with separate storage
  Future<void> _distributeLevelIncome(double amount, String userId) async {
    try {
      final levelPool = amount * 0.55; // 55% for level distribution
      final levelPercentages = [
        20, // L1: Direct sponsor
        8, // L2: Sponsor's sponsor
        7, // L3: Third upline
        6, // L4: Fourth upline
        5, // L5: Fifth upline
        3, // L6: Sixth upline
        2, // L7: Seventh upline
        1, // L8: Eighth upline
        1, // L9: Ninth upline
        1, // L10: Tenth upline
        1, // L11: Eleventh upline
      ]; // Total = 55%

      double distributedAmount = 0.0;
      int levelsDistributed = 0;

      // ✅ Store main level pool record with remaining balance info
      final mainPoolDocRef = await _storeLevelPoolRecord(
        userId,
        amount,
        levelPool,
      );

      // Start with the current user to find uplines
      String currentUserId = userId;

      for (int level = 0; level < 11; level++) {
        // Changed from 7 to 11
        // Get current user's data to find their sponsor
        final userDoc = await FirebaseFirestore.instance
            .collection('Signup_Data')
            .doc(currentUserId)
            .get();

        if (!userDoc.exists) break;

        final userData = userDoc.data() as Map<String, dynamic>;
        final sponsorId = userData['sponsorId'];

        // If no sponsor found, break the chain
        if (sponsorId == null || sponsorId.isEmpty) break;

        // Find sponsor user by referral code
        final sponsorQuery = await FirebaseFirestore.instance
            .collection('Signup_Data')
            .where('referralCode', isEqualTo: sponsorId)
            .limit(1)
            .get();

        if (sponsorQuery.docs.isEmpty) break;

        final sponsorDoc = sponsorQuery.docs.first;
        final sponsorUserId = sponsorDoc.id;

        // Calculate level bonus for this level
        final levelPercentage = levelPercentages[level];
        final levelBonus = (levelPercentage / 100) * amount;

        // ✅ Store level income under main pool document
        await _storeLevelIncomeRecord(
          mainPoolDocRef, // Main pool document reference
          userId, // depositing user
          sponsorUserId, // receiving user
          level + 1, // Level number (1-11)
          levelBonus,
          levelPercentage,
          amount, // Original deposit amount
          levelPool, // Total level pool amount
        );

        // ✅ UPDATE: Update sponsor's total level bonus with level info
        await _updateLevelBonus(
          sponsorUserId,
          levelBonus,
          level + 1,
        ); // Level number pass karein

        distributedAmount += levelBonus;
        levelsDistributed++;

        // Move to next level (sponsor becomes the current user for next iteration)
        currentUserId = sponsorUserId;
      }

      // Calculate remaining amount if not all 11 levels were distributed
      final remainingAmount = levelPool - distributedAmount;

      // ✅ UPDATED: Update main pool record with distribution summary
      await _updateMainPoolWithSummary(
        mainPoolDocRef,
        levelsDistributed,
        distributedAmount,
        remainingAmount,
      );

      print(
        '✅ Level distribution completed: $levelsDistributed levels, Distributed: \$$distributedAmount, Remaining: \$$remainingAmount',
      );
      // ✅ Store remaining balance if any
      if (remainingAmount > 0) {
        await _storeRemainingLevelBalance(
          userId,
          amount,
          levelsDistributed,
          remainingAmount,
        );
      }
    } catch (e) {
      print('❌ Error in level distribution: $e');
    }
  }

  // UPDATED: Function to store main level pool record with subcollection
  Future<DocumentReference> _storeLevelPoolRecord(
    String userId,
    double depositAmount,
    double levelPool,
  ) async {
    try {
      final levelPoolRef = FirebaseFirestore.instance
          .collection('Level_pool')
          .doc(); // Auto-generated document ID

      await levelPoolRef.set({
        'depositingUserId': userId,
        'depositAmount': depositAmount,
        'levelPoolAmount': levelPool,
        'levelPoolPercentage': 55,
        'calculationMethod': 'percentage_of_original_deposit', // ✅ NEW
        'totalLevelsDistributed': 0, // Will be updated later
        'totalDistributedAmount': 0.0, // Will be updated later
        'remainingAmount': levelPool, // Will be updated later
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'main_pool',
        'status':
            'distribution_pending', // distribution_completed, distribution_partial
      });

      print('✅ Level pool record stored: \$$levelPool for user: $userId');
      return levelPoolRef;
    } catch (e) {
      print('❌ Error storing level pool record: $e');
      rethrow;
    }
  }

  // Function to update level bonus in user's record
  // Function to update level bonus in user's record
  Future<void> _updateLevelBonus(
    String userId,
    double levelBonus,
    int level,
  ) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('Signup_Data')
          .doc(userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);

        if (userSnapshot.exists) {
          final userData = userSnapshot.data() as Map<String, dynamic>;
          final currentLevelBonus = (userData['levelBonus'] ?? 0.0).toDouble();

          transaction.update(userRef, {
            'levelBonus': currentLevelBonus + levelBonus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Level bonus added: \$$levelBonus to user: $userId');
        }
      });

      // Also update level bonus in wallet WITH LEVEL INFO
      await _updateLevelBonusWallet(userId, levelBonus, level);
    } catch (e) {
      print('❌ Error updating level bonus: $e');
    }
  }

  // NEW: Function to update main pool record with distribution summary
  // ✅ CORRECTED: Update main pool record with distribution summary
  Future<void> _updateMainPoolWithSummary(
    DocumentReference mainPoolRef,
    int levelsDistributed,
    double distributedAmount,
    double remainingAmount,
  ) async {
    try {
      // ✅ FIRST: Get the document to access depositAmount
      final mainPoolDoc = await mainPoolRef.get();
      final mainPoolData = mainPoolDoc.data() as Map<String, dynamic>?;

      if (mainPoolData == null) {
        print('❌ Main pool document not found');
        return;
      }

      final depositAmount = (mainPoolData['depositAmount'] ?? 0.0).toDouble();

      // ✅ NOW: Calculate distributed percentage
      double distributedPercentage = 0.0;
      if (depositAmount > 0) {
        distributedPercentage = (distributedAmount / depositAmount) * 100;
      }

      String status = 'distribution_completed';
      if (levelsDistributed == 0) {
        status = 'distribution_pending';
      } else if (levelsDistributed < 11) {
        status = 'distribution_partial';
      }

      await mainPoolRef.update({
        'totalLevelsDistributed': levelsDistributed,
        'totalDistributedAmount': distributedAmount,
        'remainingAmount': remainingAmount,
        'status': status,
        'distributionSummary': {
          'levelsAttempted': 11,
          'levelsSuccessful': levelsDistributed,
          'distributedPercentage':
              distributedPercentage, // ✅ Now properly calculated
          'originalDeposit': depositAmount,
          'distributedAmount': distributedAmount,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Main pool updated: $levelsDistributed levels distributed');
      print('   Distributed: \$$distributedAmount');
      print('   Remaining: \$$remainingAmount');
      print(
        '   Distributed Percentage: ${distributedPercentage.toStringAsFixed(2)}%',
      );
    } catch (e) {
      print('❌ Error updating main pool summary: $e');
    }
  }

  // UPDATED: Function to store individual level income records in subcollection
  Future<void> _storeLevelIncomeRecord(
    DocumentReference mainPoolRef,
    String depositingUserId,
    String receivingUserId,
    int level,
    double levelAmount,
    int levelPercentage,
    double originalDeposit,
    double totalLevelPool,
  ) async {
    try {
      // Store in subcollection under main pool document
      final levelIncomeRef = mainPoolRef
          .collection('level_incomes')
          .doc(); // Auto-generated document ID for level income

      await levelIncomeRef.set({
        'depositingUserId': depositingUserId, // User who made deposit
        'receivingUserId': receivingUserId, // User who received level income
        'level': level, // Level number (1-7)
        'levelAmount': levelAmount, // Amount received for this level
        'levelPercentage': levelPercentage, // Percentage for this level
        'originalDeposit': originalDeposit, // Original deposit amount
        'totalLevelPool': totalLevelPool, // Total level pool (55% of deposit)
        'calculatedFrom':
            'original_deposit', // ✅ NEW: Indicate calculation source
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'level_income',
      });

      print(
        '✅ Level $level income stored: \$$levelAmount for user: $receivingUserId from user: $depositingUserId',
      );
    } catch (e) {
      print('❌ Error storing level income record: $e');
    }
  }

  // ✅ DEBUG: Check why Sponsar_wallets is not creating
  Future<void> _debugSponsarWalletIssue(
    String userId,
    double levelBonus,
    int level,
  ) async {
    try {
      print('\n=== SPONSAR WALLET DEBUG ===');

      // Check if user exists in Signup_Data
      final userDoc = await FirebaseFirestore.instance
          .collection('Signup_Data')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        print('✅ User exists in Signup_Data: ${userDoc.data()}');
      } else {
        print('❌ User NOT found in Signup_Data: $userId');
        return;
      }

      // Check current Sponsar_wallets
      final walletDoc = await FirebaseFirestore.instance
          .collection('Sponsar_wallets')
          .doc(userId)
          .get();

      if (walletDoc.exists) {
        print('✅ Sponsar_wallets exists: ${walletDoc.data()}');
      } else {
        print('❌ Sponsar_wallets NOT found, will create new one');
      }

      print('💰 Level Bonus to add: \$$levelBonus for level $level');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  // ✅ ALTERNATIVE: Update Sponsar_wallets with level earnings
  Future<void> _updateLevelBonusWallet(
    String userId,
    double levelBonus,
    int level,
  ) async {
    try {
      // ✅ ADD: Debug logging
      await _debugSponsarWalletIssue(userId, levelBonus, level);

      final walletRef = FirebaseFirestore.instance
          .collection('Sponsar_wallets')
          .doc(userId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);

        print('🎯 Transaction started for user: $userId');

        if (!walletSnapshot.exists) {
          print('🆕 Creating NEW Sponsar_wallet for user: $userId');

          // ✅ NEW: Initialize with level earnings structure
          Map<String, dynamic> levelsMap = {};
          levelsMap['level_$level'] = levelBonus;

          transaction.set(walletRef, {
            'balance': levelBonus,
            'totalLevelBonus': levelBonus,
            'lastLevelBonus': levelBonus,
            'levelEarnings': {'total': levelBonus, 'levels': levelsMap},
            'userId': userId, // ✅ ADD user ID for reference
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ NEW wallet created with level $level: \$$levelBonus');
        } else {
          print('📝 UPDATING existing wallet for user: $userId');
          final walletData = walletSnapshot.data() as Map<String, dynamic>;
          final currentBalance = (walletData['balance'] ?? 0.0).toDouble();
          final currentTotalLevelBonus = (walletData['totalLevelBonus'] ?? 0.0)
              .toDouble();

          // ✅ Get existing level earnings
          final levelEarnings = Map<String, dynamic>.from(
            walletData['levelEarnings'] ?? {'total': 0.0, 'levels': {}},
          );

          final levelsMap = Map<String, dynamic>.from(
            levelEarnings['levels'] ?? {},
          );

          // ✅ Update specific level earnings
          final currentLevelEarning = (levelsMap['level_$level'] ?? 0.0)
              .toDouble();
          levelsMap['level_$level'] = currentLevelEarning + levelBonus;

          // ✅ Update total level earnings
          final currentTotal = (levelEarnings['total'] ?? 0.0).toDouble();
          levelEarnings['total'] = currentTotal + levelBonus;

          transaction.update(walletRef, {
            'balance': currentBalance + levelBonus,
            'totalLevelBonus': currentTotalLevelBonus + levelBonus,
            'lastLevelBonus': levelBonus,
            'levelEarnings': {
              'total': levelEarnings['total'],
              'levels': levelsMap,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Wallet UPDATED with level $level: \$$levelBonus');
        }
      });

      // ✅ VERIFY: Check if wallet was actually created/updated
      final verifyDoc = await FirebaseFirestore.instance
          .collection('Sponsar_wallets')
          .doc(userId)
          .get();

      if (verifyDoc.exists) {
        print('🎉 SUCCESS: Sponsar_wallet verified for user: $userId');
        print('📊 Final wallet data: ${verifyDoc.data()}');
      } else {
        print('❌ FAILED: Sponsar_wallet still not found after transaction');
      }
    } catch (e) {
      print('❌ Error updating level bonus wallet: $e');
      print('🚨 Stack trace: ${e.toString()}');
    }
  }

  // UPDATED: Function to store remaining level balance in Level_pool collection
  Future<void> _storeRemainingLevelBalance(
    String userId,
    double depositAmount,
    int distributedLevels,
    double remainingAmount,
  ) async {
    try {
      final remainingRef = FirebaseFirestore.instance
          .collection('Level_pool')
          .doc(); // Auto-generated document ID

      await remainingRef.set({
        'depositingUserId': userId,
        'depositAmount': depositAmount,
        'distributedLevels': distributedLevels,
        'remainingAmount': remainingAmount,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'remaining_balance', // To identify remaining balance records
      });

      print(
        '✅ Remaining level balance stored: \$$remainingAmount for user: $userId',
      );
    } catch (e) {
      print('❌ Error storing remaining level balance: $e');
    }
  }

  // ✅ UPDATED: Global activation fees
  Future<void> _storeActivationFee(String userId, double activationFee) async {
    try {
      final activationFeeRef = FirebaseFirestore.instance
          .collection('globalActivationFees')
          .doc('totalFees');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(activationFeeRef);

        if (!snapshot.exists) {
          transaction.set(activationFeeRef, {
            'totalActivationFees': activationFee,
            'totalUsers': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          final data = snapshot.data() as Map<String, dynamic>;
          final currentFees = (data['totalActivationFees'] ?? 0.0).toDouble();
          final currentUsers = (data['totalUsers'] ?? 0);

          transaction.update(activationFeeRef, {
            'totalActivationFees': currentFees + activationFee,
            'totalUsers': currentUsers + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ Activation fee added to global fund: \$$activationFee');
    } catch (e) {
      print('❌ Error storing global activation fee: $e');
    }
  }

  // ✅ Helper method to determine package name from amount
  String _getPackageNameFromAmount(double amount) {
    if (amount <= 5) return "Starter Package";
    if (amount <= 10) return "Basic Package";
    if (amount <= 25) return "Advanced Package";
    if (amount <= 50) return "Pro Package";
    if (amount <= 100) return "Elite Package";
    if (amount <= 250) return "Premium Package";
    return "Ultimate Package";
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
    final packagePriceValue =
        double.tryParse(widget.packagePrice.replaceAll('\$', '')) ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Payment Details',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Payment Details Card
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
                        "Payment Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ✅ QR Code with blue border
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryBlue, width: 2),
                        ),
                        child: QrImageView(
                          data: _paymentData['pay_address'] ?? '', // NULL CHECK
                          version: QrVersions.auto,
                          size: size.width * 0.4,
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
                      const SizedBox(height: 20),

                      // Payment Information
                      _buildInfoRow(
                        "Payment ID",
                        _paymentData['payment_id']?.toString() ??
                            'N/A', // NULL CHECK
                      ),
                      _buildInfoRow(
                        "Amount to Pay",
                        "${_paymentData['pay_amount'] ?? 'N/A'} ${(_paymentData['pay_currency'] ?? 'usdt').toUpperCase()}", // NULL CHECK
                      ),
                      _buildInfoRow(
                        "USD Amount",
                        "\$${_paymentData['price_amount'] ?? 'N/A'}", // NULL CHECK
                      ),
                      _buildInfoRow(
                        "Package Price", // ✅ Changed label
                        "\$${packagePriceValue.toStringAsFixed(2)}", // ✅ Show package price
                      ),
                      _buildInfoRow(
                        "Status",
                        _paymentData['payment_status']?.toString() ??
                            'Unknown', // NULL CHECK
                        isStatus: true,
                      ),

                      const SizedBox(height: 20),

                      // ✅ Address
                      Container(
                        padding: const EdgeInsets.all(12),
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
                            const Text(
                              "Send to this address:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _paymentData['pay_address']?.toString() ??
                                  'Address not available', // NULL CHECK
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ Copy Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final address = _paymentData['pay_address']
                                ?.toString();
                            if (address != null && address.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: address));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    "Address copied to clipboard!",
                                  ),
                                  backgroundColor: primaryBlue,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, color: Colors.white),
                          label: const Text(
                            "Copy Address",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: primaryBlue.withOpacity(0.5),
                            elevation: 5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Pay on Address Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Make payment to the address above",
                                ),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: const Text(
                            "Pay on the Address",
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

            // 🔹 Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Payment Instructions",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInstructionStep(
                    "1. Copy the deposit address above or scan the QR code",
                    primaryBlue,
                  ),
                  _buildInstructionStep(
                    "2. Send exactly ${_paymentData['pay_amount'] ?? 'N/A'} ${(_paymentData['pay_currency'] ?? 'usdt').toUpperCase()} to this address", // NULL CHECK
                    primaryBlue,
                  ),
                  _buildInstructionStep(
                    "3. Do not send any other cryptocurrency to this address",
                    primaryBlue,
                  ),
                  _buildInstructionStep(
                    "4. Wait for network confirmations (usually 1-5 minutes)",
                    primaryBlue,
                  ),
                  _buildInstructionStep(
                    "5. Payment status will update automatically",
                    primaryBlue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status monitoring indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Monitoring payment status in real-time...",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
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

  Widget _buildSuccessScreen() {
    final packagePriceValue =
        double.tryParse(widget.packagePrice.replaceAll('\$', '')) ?? 0.0;

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
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              Text(
                "Congratulations!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "You have successfully purchased ${widget.packageTitle} for \$${packagePriceValue.toStringAsFixed(2)}",
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSuccessInfoRow(
                        "Payment ID",
                        _paymentData['payment_id'].toString(),
                      ),
                      _buildSuccessInfoRow(
                        "Package Price", // ✅ Changed label
                        "\$${packagePriceValue.toStringAsFixed(2)}", // ✅ Show package price
                      ),
                      _buildSuccessInfoRow(
                        "Currency",
                        (_paymentData['pay_currency'] ?? 'usdt')
                            .toUpperCase(), // NULL CHECK
                      ),
                      _buildSuccessInfoRow(
                        "Status",
                        "Completed",
                        isStatus: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => MainScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Continue to Dashboard",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    Color statusColor = Colors.blue;
    if (isStatus) {
      if (value == 'finished') {
        statusColor = Colors.green;
      } else if (value == 'failed') {
        statusColor = Colors.red;
      } else if (value == 'waiting') {
        statusColor = Colors.orange;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Flexible(
            // Add this
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isStatus ? FontWeight.bold : FontWeight.normal,
                color: isStatus ? statusColor : Colors.black,
                overflow: TextOverflow.ellipsis, // Add this
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessInfoRow(
    String label,
    String value, {
    bool isStatus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isStatus ? Colors.green : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String text, Color primaryBlue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 4),
          Text(
            "• ",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
