import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uktalhybird/Metrixcreen/metricincomedeposit.dart';
import 'package:uktalhybird/Withdrawal/MetricWithdrawal/metricwithdrawl.dart';

class MatrixIncomeScreen extends StatefulWidget {
  const MatrixIncomeScreen({super.key});

  @override
  State<MatrixIncomeScreen> createState() => _MatrixIncomeScreenState();
}

class _MatrixIncomeScreenState extends State<MatrixIncomeScreen> {
  final Color primaryBlue = const Color(0xFF0000FF);
  final Color lightBlue = const Color(0xFFE6E6FF);
  final Color accentRed = const Color(0xFFFF5252);
  final Color accentGreen = const Color(0xFF0000FF);
  final Color textColor = const Color(0xFF333333);
  final Color lightText = const Color(0xFF666666);
  final Color golden = const Color(0xFFFFD700);
  final Color silver = const Color(0xFFC0C0C0);
  final Color bronze = const Color(0xFFCD7F32);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _directMembersCount = 0;
  double _totalMatrixEarnings = 0.0;
  bool _hasCompletedDeposit = false;
  List<int> _filledCircles = List.filled(8, 0);
  List<bool> _userDepositStatus = [];
  double _walletBalance = 0.0;
  List<double> _matrixActivationFunds = List.filled(8, 0.0);

  @override
  void initState() {
    super.initState();
    _loadDirectMembersCount();
    _checkDepositStatus();
    _loadFilledCircles();
  }

  Future<void> _checkDepositStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final matrixPayments = await _firestore
          .collection('Matric_payment_deposit')
          .doc(user.uid)
          .collection('matrix_payments')
          .where('status', isEqualTo: 'completed')
          .get();

      setState(() {
        _hasCompletedDeposit = matrixPayments.docs.isNotEmpty;
      });

      print('✅ Deposit status: $_hasCompletedDeposit');
      print('✅ Found ${matrixPayments.docs.length} completed payments');
    } catch (e) {
      print('❌ Error checking deposit status: $e');
      setState(() {
        _hasCompletedDeposit = false;
      });
    }
  }

  Future<void> _loadFilledCircles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get ALL users from Signup_Data
      final allUsers = await _firestore.collection('Signup_Data').get();

      List<Map<String, dynamic>> usersWithDeposit = [];
      _userDepositStatus = List.filled(allUsers.docs.length, false);

      // Check deposit status for each user and cache it
      for (int i = 0; i < allUsers.docs.length; i++) {
        final userDoc = allUsers.docs[i];
        final userId = userDoc.id;

        final depositData = await _firestore
            .collection('Matric_payment_deposit')
            .doc(userId)
            .collection('matrix_payments')
            .where('status', isEqualTo: 'completed')
            .get();

        if (depositData.docs.isNotEmpty) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final joinedAt =
              userData['joinedAt'] as Timestamp? ?? Timestamp.now();

          usersWithDeposit.add({
            'userId': userId,
            'joinedAt': joinedAt,
            'userData': userData,
          });
          _userDepositStatus[i] = true;
        }
      }

      // Sort by joinedAt timestamp (earliest first)
      usersWithDeposit.sort((a, b) => a['joinedAt'].compareTo(b['joinedAt']));

      // Find current user's position
      int currentUserIndex = -1;
      for (int i = 0; i < usersWithDeposit.length; i++) {
        if (usersWithDeposit[i]['userId'] == user.uid) {
          currentUserIndex = i;
          break;
        }
      }

      if (currentUserIndex != -1) {
        List<int> filledCircles = List.filled(8, 0);

        // Calculate filled slots for each matrix
        for (int matrixLevel = 1; matrixLevel <= 8; matrixLevel++) {
          filledCircles[matrixLevel - 1] = await _calculateChainFilledSlots(
            currentUserIndex,
            usersWithDeposit.length,
            matrixLevel,
            usersWithDeposit,
          );
        }

        if (mounted) {
          setState(() {
            _filledCircles = filledCircles;
            _totalMatrixEarnings = _calculateTotalEarnings(filledCircles);
          });
        }
        print(
          '🎯 User position: ${currentUserIndex + 1} of ${usersWithDeposit.length}',
        );
        print('🎯 Filled circles: $_filledCircles');

        // Print detailed chain information
        await _printChainInfo(
          currentUserIndex,
          usersWithDeposit.length,
          usersWithDeposit,
        );
      } else {
        print('❌ Current user not found in deposited users list');
      }
    } catch (e) {
      print('❌ Error loading filled circles: $e');
    }
  }

  // Calculate filled slots for a given matrix level
  Future<int> _calculateChainFilledSlots(
    int userIndex,
    int totalUsers,
    int matrixLevel,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    if (matrixLevel == 1) {
      return await _calculateMatrix1Slots(
        userIndex,
        totalUsers,
        usersWithDeposit,
      );
    } else {
      return await _calculateHigherMatrixSlots(
        userIndex,
        totalUsers,
        matrixLevel,
        usersWithDeposit,
      );
    }
  }

  // ✅ Function to handle withdraw with reset
  // ✅ Updated Function to handle withdraw with proper balance update
  void _handleWithdrawNow() {
    if (_totalMatrixEarnings > 0) {
      // Navigate to withdrawal screen and wait for result
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MetricWithdrawScreen(claimAmount: _totalMatrixEarnings),
        ),
      ).then((returnedAmount) {
        // ✅ This will be called when we return from withdrawal screen
        if (returnedAmount != null) {
          setState(() {
            _totalMatrixEarnings = returnedAmount as double;
          });

          print(
            '✅ Updated matrix earnings to: \$${returnedAmount.toStringAsFixed(2)}',
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No matrix earnings available to withdraw"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Add this function to MatrixIncomeScreen.dart
  Future<void> _saveMatrixEarningsToTodayEarnings(double earnings) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get today's date string (YYYY-MM-DD)
      final now = DateTime.now();
      final todayString =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Get existing today earnings document
      final todayEarningsDoc = await FirebaseFirestore.instance
          .collection('Today_Earnings')
          .doc(user.uid)
          .collection('daily_earnings')
          .doc(todayString)
          .get();

      double existingMatrixEarnings = 0.0;

      if (todayEarningsDoc.exists) {
        final data = todayEarningsDoc.data() as Map<String, dynamic>;
        existingMatrixEarnings = (data['matrixEarnings'] ?? 0.0).toDouble();
      }

      // Only add new earnings if they're higher than existing (prevent duplicates)
      double newMatrixEarnings = earnings > existingMatrixEarnings
          ? earnings
          : existingMatrixEarnings;

      // ✅ Save to Today_Earnings collection - ONLY matrixEarnings
      await FirebaseFirestore.instance
          .collection('Today_Earnings')
          .doc(user.uid)
          .collection('daily_earnings')
          .doc(todayString)
          .set({
            'matrixEarnings': newMatrixEarnings, // ✅ Only this field
            'lastUpdated': FieldValue.serverTimestamp(),
            'userId': user.uid,
            'date': todayString,
            'type': 'matrix_income',
            'description': 'Matrix Income Earnings',
          }, SetOptions(merge: true));

      print('✅ Saved matrix earnings to Today_Earnings: \$$newMatrixEarnings');
    } catch (e) {
      print('❌ Error saving matrix earnings to Today_Earnings: $e');
    }
  }

  // ✅ Update MetricWallet in Firebase
  Future<void> _updateMetricWalletInFirebase(double newBalance) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('Signup_Data')
          .doc(user.uid)
          .update({'MetricWallet': newBalance});

      print('✅ Updated MetricWallet in Firebase: \$$newBalance');
    } catch (e) {
      print('❌ Error updating MetricWallet: $e');
    }
  }

  // ✅ Function to reset matrix earnings to 0
  Future<void> _resetMatrixEarnings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🔄 Resetting matrix earnings to 0');

      // ✅ Update MetricWallet in Signup_Data to 0
      await FirebaseFirestore.instance
          .collection('Signup_Data')
          .doc(user.uid)
          .update({'MetricWallet': 0.0});

      // ✅ Reset local state
      setState(() {
        _totalMatrixEarnings = 0.0;
      });

      print('✅ Matrix earnings reset successfully');

      // ✅ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Matrix earnings withdrawn successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error resetting matrix earnings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error withdrawing matrix earnings: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calculate Matrix 1 slots
  Future<int> _calculateMatrix1Slots(
    int userIndex,
    int totalUsers,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    if (!_hasCompletedDeposit) return 0;

    int filledSlots = 0;
    for (int i = 1; i <= 4; i++) {
      if (userIndex + i < totalUsers) filledSlots++;
    }
    return filledSlots;
  }

  // Check if a specific user has completed their deposit
  Future<bool> _hasUserCompletedDeposit(int userIndex) async {
    try {
      if (userIndex < _userDepositStatus.length) {
        return _userDepositStatus[userIndex];
      }
      return false;
    } catch (e) {
      print('❌ Error checking deposit status for user index $userIndex: $e');
      return false;
    }
  }

  // Calculate higher matrix slots
  Future<int> _calculateHigherMatrixSlots(
    int userIndex,
    int totalUsers,
    int matrixLevel,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    int previousMatrixSlots = await _calculateChainFilledSlots(
      userIndex,
      totalUsers,
      matrixLevel - 1,
      usersWithDeposit,
    );
    if (previousMatrixSlots < 4) {
      return 0;
    }

    int level = 0;
    int startIndex = 0;
    int accumulatedUsers = 0;
    for (int i = 0; i < 8; i++) {
      int usersAtLevel = pow(4, i).toInt();
      accumulatedUsers += usersAtLevel;
      if (userIndex < accumulatedUsers) {
        level = i;
        startIndex = accumulatedUsers - usersAtLevel;
        break;
      }
    }

    int downlineLevel = level + matrixLevel - 1;
    int downlineStartIndex = 0;
    int downlineUsersAtLevel = pow(4, downlineLevel).toInt();
    int previousUsers = 0;
    for (int i = 0; i < downlineLevel; i++) {
      previousUsers += pow(4, i).toInt();
    }
    downlineStartIndex =
        previousUsers + (userIndex - startIndex) * downlineUsersAtLevel;

    int filledSlots = 0;
    for (int i = 0; i < 4; i++) {
      int downlineIndex = downlineStartIndex + i;
      if (downlineIndex < totalUsers) {
        int downlineMatrixSlots = await _calculateChainFilledSlots(
          downlineIndex,
          totalUsers,
          matrixLevel - 1,
          usersWithDeposit,
        );
        if (downlineMatrixSlots >= 4) {
          filledSlots++;
        }
      }
    }

    return filledSlots;
  }

  // Calculate total earnings
  // Calculate total earnings - UPDATED: Progressive payout on first 2 slots only
  double _calculateTotalEarnings(List<int> filledCircles) {
    List<double> incomes = [40, 80, 160, 320, 640, 1280, 2560, 5120];
    double totalWallet = 0.0;

    for (int i = 0; i < filledCircles.length; i++) {
      int slotsFilled = filledCircles[i];
      double matrixIncome = incomes[i];

      // Each slot = 25% of matrix income
      double perSlot = matrixIncome / 4.0;

      // Only first 2 slots give money to wallet
      if (slotsFilled >= 1) {
        totalWallet += perSlot; // $10 for Matrix 1, $20 for Matrix 2, etc.
      }
      if (slotsFilled >= 2) {
        totalWallet += perSlot; // Another $10 / $20
      }

      // Last 2 slots → used only for activation (no wallet credit)
      double activationShare = 0.0;
      if (slotsFilled >= 3) {
        activationShare += perSlot;
      }
      if (slotsFilled >= 4) {
        activationShare += perSlot;
      }

      if (activationShare > 0 && i < 7) {
        _matrixActivationFunds[i + 1] += activationShare;
        print(
          '🔑 Matrix ${i + 1}: Activation Funds +\$ $activationShare for next matrix unlock',
        );
      }
      if (totalWallet > 0) {
        // ✅ Save to Today_Earnings collection
        _saveMatrixEarningsToTodayEarnings(totalWallet);
      }
    }

    // Update local wallet (for display)
    if (mounted) {
      setState(() {
        _walletBalance = totalWallet;
      });
    }

    return totalWallet;
  }
  //   return total;

  void _updateWalletAndActivateMatrix(
    int matrixIndex,
    double walletShare,
    double activationShare,
  ) {
    // Update wallet balance
    _walletBalance += walletShare;

    // Use activation share to unlock the next matrix
    if (matrixIndex < 7) {
      // Ensure we don't try to activate beyond Matrix 8
      _matrixActivationFunds[matrixIndex + 1] += activationShare;
    }

    print(
      '💸 Matrix ${matrixIndex + 1}: Wallet +\$ $walletShare, Activation Funds +\$ $activationShare for Matrix ${matrixIndex + 2}',
    );
  }

  // Print detailed chain information
  Future<void> _printChainInfo(
    int currentUserIndex,
    int totalUsers,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    print('\n🔗 COMPLETE SEQUENTIAL PROGRESSION:');
    print('   Current User: U${currentUserIndex + 1}');
    print('   Total Users: $totalUsers');
    print('   Users After Current: ${totalUsers - currentUserIndex - 1}');

    for (int matrixLevel = 1; matrixLevel <= 8; matrixLevel++) {
      int slotsFilled = await _calculateChainFilledSlots(
        currentUserIndex,
        totalUsers,
        matrixLevel,
        usersWithDeposit,
      );
      String status = '';

      if (matrixLevel == 1) {
        status = _hasCompletedDeposit ? '🟡 IN PROGRESS' : '⏳ WAITING';
        if (!_hasCompletedDeposit) {
          print('   Matrix 1: ⏳ Waiting for deposit');
        }
      } else {
        int previousMatrix = await _calculateChainFilledSlots(
          currentUserIndex,
          totalUsers,
          matrixLevel - 1,
          usersWithDeposit,
        );
        status = previousMatrix >= 4 ? '🟡 IN PROGRESS' : '🔒 LOCKED';
      }

      print('   Matrix $matrixLevel: $slotsFilled/4 - $status');

      if (slotsFilled > 0) {
        await _printMatrixFillers(
          currentUserIndex,
          totalUsers,
          matrixLevel,
          slotsFilled,
          usersWithDeposit,
        );
      }
    }

    await _printCompleteProgressionStructure(
      currentUserIndex,
      totalUsers,
      usersWithDeposit,
    );
  }

  // Print which users fill each matrix slot
  Future<void> _printMatrixFillers(
    int userIndex,
    int totalUsers,
    int matrixLevel,
    int slotsFilled,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    print('     Filled by:');
    // For Matrix 1: all downline users in the list have deposited → always true
    // For higher matrices: check if they completed previous matrix
    for (int i = 0; i < slotsFilled; i++) {
      int fillerIndex = userIndex + i + 1; // Simple sequential for printing
      if (fillerIndex < totalUsers) {
        String statusText = matrixLevel == 1
            ? '🟡 HAS DEPOSITED' // All in list have deposited
            : (await _calculateChainFilledSlots(
                        fillerIndex,
                        totalUsers,
                        matrixLevel - 1,
                        usersWithDeposit,
                      ) >=
                      4
                  ? '✅ COMPLETED Matrix ${matrixLevel - 1}'
                  : '🟡 Matrix ${matrixLevel - 1} in progress');
        print('       U${fillerIndex + 1} - $statusText');
      }
    }
  }

  // Print complete progression structure
  Future<void> _printCompleteProgressionStructure(
    int currentUserIndex,
    int totalUsers,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    print(
      '\n🏗️  COMPLETE PROGRESSION STRUCTURE FOR U${currentUserIndex + 1}:',
    );

    for (int matrixLevel = 1; matrixLevel <= 8; matrixLevel++) {
      int slotsFilled = await _calculateChainFilledSlots(
        currentUserIndex,
        totalUsers,
        matrixLevel,
        usersWithDeposit,
      );
      String matrixStatus = matrixLevel == 1 && _hasCompletedDeposit
          ? '🟡 ACTIVE'
          : (slotsFilled > 0 ? '🟡 ACTIVE' : '🔒 LOCKED');

      print('   Matrix $matrixLevel: $slotsFilled/4 - $matrixStatus');

      if (slotsFilled > 0) {
        await _printMatrixFillers(
          currentUserIndex,
          totalUsers,
          matrixLevel,
          slotsFilled,
          usersWithDeposit,
        );
      }
    }

    await _printEarningPotential(
      currentUserIndex,
      totalUsers,
      usersWithDeposit,
    );
  }

  // Print earning potential
  Future<void> _printEarningPotential(
    int currentUserIndex,
    int totalUsers,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    print('\n💰 EARNING POTENTIAL:');

    List<double> incomes = [40, 80, 160, 320, 640, 1280, 2560, 5120];
    double totalPotential = 0.0;

    for (int matrixLevel = 1; matrixLevel <= 8; matrixLevel++) {
      int slotsFilled = await _calculateChainFilledSlots(
        currentUserIndex,
        totalUsers,
        matrixLevel,
        usersWithDeposit,
      );

      if (slotsFilled >= 4) {
        double matrixIncome = incomes[matrixLevel - 1];
        totalPotential += matrixIncome;
        print('   Matrix $matrixLevel: $slotsFilled/4 = \$$matrixIncome');
      } else {
        print(
          '   Matrix $matrixLevel: $slotsFilled/4 = \$0 (Potential: \$${incomes[matrixLevel - 1]})',
        );
      }
    }

    print('   📊 Total Potential Earnings: \$$totalPotential');

    await _printUnlockRequirements(
      currentUserIndex,
      totalUsers,
      usersWithDeposit,
    );
  }

  // Print unlock requirements
  Future<void> _printUnlockRequirements(
    int currentUserIndex,
    int totalUsers,
    List<Map<String, dynamic>> usersWithDeposit,
  ) async {
    print('\n🎯 UNLOCK REQUIREMENTS:');

    for (int matrixLevel = 1; matrixLevel <= 8; matrixLevel++) {
      int currentSlots = await _calculateChainFilledSlots(
        currentUserIndex,
        totalUsers,
        matrixLevel,
        usersWithDeposit,
      );

      if (currentSlots < 4) {
        int needed = 4 - currentSlots;

        if (matrixLevel == 1) {
          if (!_hasCompletedDeposit) {
            print('   Matrix 1: ⏳ Waiting for your deposit');
          } else {
            print('   Matrix 1: Need $needed more users to deposit');
          }
        } else {
          int previousMatrix = await _calculateChainFilledSlots(
            currentUserIndex,
            totalUsers,
            matrixLevel - 1,
            usersWithDeposit,
          );
          if (previousMatrix < 4) {
            print(
              '   Matrix $matrixLevel: 🔒 Complete Matrix ${matrixLevel - 1} first',
            );
          } else {
            print(
              '   Matrix $matrixLevel: Need $needed more downline completions for Matrix ${matrixLevel - 1}',
            );
          }
        }
      } else {
        print('   Matrix $matrixLevel: ✅ COMPLETE');
      }
    }
  }

  // Helper function to get today's date string
  String _getTodayDateString() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }

  // Function to reset today earnings
  Future<void> _resetTodayEarnings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final todayString = _getTodayDateString();

      await FirebaseFirestore.instance
          .collection('Today_Earnings')
          .doc(user.uid)
          .collection('daily_earnings')
          .doc(todayString)
          .set({
            'matrixEarnings': 0.0,
            'levelEarnings': {'levels': {}, 'total': 0.0},
            'passiveEarnings': 0.0,
            'totalEarnings': 0.0,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userId': user.uid,
            'date': todayString,
            'type': 'daily_total',
            'description': 'Daily Earnings - Reset at midnight',
          }, SetOptions(merge: true));

      print('✅ Today earnings reset to 0 for new day');
    } catch (e) {
      print('❌ Error resetting today earnings: $e');
    }
  }

  Future<void> _loadDirectMembersCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final referralCode = userData['referralCode'];

        final directMembersQuery = await _firestore
            .collection('Signup_Data')
            .where('sponsorId', isEqualTo: referralCode)
            .get();

        setState(() {
          _directMembersCount = directMembersQuery.docs.length;
        });
      }
    } catch (e) {
      print('Error loading direct members count: $e');
    }
  }

  // Matrix unlocking logic
  List<bool> _getUnlockedMatrices() {
    List<bool> unlocked = List.filled(8, false);
    if (!_hasCompletedDeposit) {
      return unlocked;
    }

    unlocked[0] = true; // Matrix 1 is unlocked if deposit is completed
    // for (int i = 1; i < 8; i++) {
    //   if (_filledCircles[i - 1] >= 4) {
    //     unlocked[i] = true;
    //   } else {
    //     break;
    //   }
    // }
    // return unlocked;
    for (int i = 1; i < 8; i++) {
      if (_filledCircles[i - 1] >= 4 &&
          _matrixActivationFunds[i] >=
              (i == 0
                  ? 0
                  : [40, 80, 160, 320, 640, 1280, 2560, 5120][i - 1] / 2)) {
        unlocked[i] = true;
      } else {
        break;
      }
    }
    return unlocked;
  }

  // Get income for each matrix
  String _getMatrixIncome(int index) {
    List<String> incomes = [
      '\$40',
      '\$80',
      '\$160',
      '\$320',
      '\$640',
      '\$1280',
      '\$2560',
      '\$5120',
    ];
    return incomes[index];
  }

  // Handle deposit button press
  void _handleDeposit() {
    _checkPackageStatusAndNavigate();
  }

  // Check if user has any active package before allowing matrix deposit
  Future<void> _checkPackageStatusAndNavigate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user has any active package
      final purchasedPackages = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('purchasedPackages')
          .where('status', isEqualTo: 'finished')
          .where('isActive', isEqualTo: true)
          .get();

      bool hasActivePackage = purchasedPackages.docs.isNotEmpty;

      if (hasActivePackage) {
        // User has active package, navigate to deposit screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MatrixIncomeDepositScreen()),
        );
      } else {
        // Show dialog if no active package
        _showNoPackageDialog();
      }
    } catch (e) {
      print('❌ Error checking package status: $e');
      _showErrorSnackBar("Error checking package status");
    }
  }

  // Show dialog when user doesn't have any active package
  void _showNoPackageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                "Package Required",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You need to purchase and activate a package first before accessing Matrix Income.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                "Please go to Packages section and buy your first package.",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "OK",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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

  // Handle claim now button press
  void _handleClaimNow() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Claim Earnings",
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Your matrix earnings of \$$_totalMatrixEarnings are ready to claim! Contact support to process your withdrawal.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK", style: TextStyle(color: primaryBlue)),
            ),
          ],
        );
      },
    );
  }

  void _showWithdrawalPendingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.hourglass_empty, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                "Please Wait",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "Withdrawal API is currently pending. Please try again later.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "OK",
                style: TextStyle(
                  color: const Color(0xFF0000FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Refresh data
  Future<void> _refreshData() async {
    await _checkDepositStatus();
    await _loadDirectMembersCount();
    await _loadFilledCircles();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final isPortrait = h > w;

    final unlockedMatrices = _getUnlockedMatrices();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Center(
          child: Text(
            'Matrix Income',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.04,
          vertical: isPortrait ? h * 0.02 : w * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Earnings
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryBlue, primaryBlue.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: w * 0.02),
                      Text(
                        "Total Matrix Earnings",
                        style: TextStyle(
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
                  // StreamBuilder<DocumentSnapshot>(
                  //   stream: FirebaseFirestore.instance
                  //       .collection('Signup_Data')
                  //       .doc(FirebaseAuth.instance.currentUser?.uid)
                  //       .snapshots(),
                  //   builder: (context, snapshot) {
                  //     double totalEarnings =
                  //         _totalMatrixEarnings; // Previous earnings

                  //     if (snapshot.hasData && snapshot.data!.exists) {
                  //       var data =
                  //           snapshot.data!.data() as Map<String, dynamic>;
                  //       var metricWallet = (data["MetricWallet"] ?? 0.0)
                  //           .toDouble();

                  //       // Add MetricWallet earnings to total
                  //       totalEarnings += metricWallet;
                  //     }

                  //     return Text(
                  //       "\$${totalEarnings.toStringAsFixed(2)}",
                  //       style: TextStyle(
                  //         fontSize: w * 0.08,
                  //         fontWeight: FontWeight.bold,
                  //         color: Colors.white,
                  //       ),
                  //     );
                  //   },
                  // ),// In the StreamBuilder section, update to show proper total
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Signup_Data')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      double totalEarnings =
                          _totalMatrixEarnings; // This now gets updated properly

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('Today_Earnings')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection('daily_earnings')
                            .doc(_getTodayDateString())
                            .get(),
                        builder: (context, todaySnapshot) {
                          double todayMatrixEarnings = 0.0;

                          if (todaySnapshot.hasData &&
                              todaySnapshot.data!.exists) {
                            final todayData =
                                todaySnapshot.data!.data()
                                    as Map<String, dynamic>;
                            todayMatrixEarnings =
                                (todayData['matrixEarnings'] ?? 0.0).toDouble();
                          }

                          // Show whichever is higher
                          double displayEarnings =
                              todayMatrixEarnings > totalEarnings
                              ? todayMatrixEarnings
                              : totalEarnings;

                          return Text(
                            "\$${displayEarnings.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: w * 0.08,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  SizedBox(height: isPortrait ? h * 0.01 : w * 0.01),
                  Text(
                    "Direct Members: $_directMembersCount",
                    style: TextStyle(
                      fontSize: w * 0.035,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.04,
                      vertical: isPortrait ? h * 0.02 : w * 0.02,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Pending Withdrawal:",
                              style: TextStyle(
                                fontSize: w * 0.035,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "\$$_totalMatrixEarnings",
                              style: TextStyle(
                                fontSize: w * 0.035,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
                        if (_hasCompletedDeposit)
                          Container(
                            width: double.infinity,
                            height: isPortrait ? h * 0.06 : w * 0.06,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFA000), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF8C00).withOpacity(0.4),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _handleWithdrawNow,

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.monetization_on,
                                    color: Colors.white,
                                    size: w * 0.05,
                                  ),
                                  SizedBox(width: w * 0.02),
                                  Text(
                                    "WITHDRAW NOW",
                                    style: TextStyle(
                                      fontSize: w * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: isPortrait ? h * 0.06 : w * 0.06,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF00FF00), Color(0xFF00CC00)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF00CC00).withOpacity(0.4),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _handleDeposit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: w * 0.05,
                                  ),
                                  SizedBox(width: w * 0.02),
                                  Text(
                                    "DEPOSIT NOW",
                                    style: TextStyle(
                                      fontSize: w * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.03 : w * 0.03),

            // Current Matrix Level
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Matrix Level",
                    style: TextStyle(
                      fontSize: w * 0.045,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
                  Container(
                    padding: EdgeInsets.all(w * 0.04),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _hasCompletedDeposit
                            ? [
                                accentGreen.withOpacity(0.1),
                                accentGreen.withOpacity(0.2),
                              ]
                            : [Colors.grey[200]!, Colors.grey[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasCompletedDeposit
                                  ? "Matrix 1 (Active)"
                                  : "Matrix 1 (Locked)",
                              style: TextStyle(
                                fontSize: w * 0.05,
                                fontWeight: FontWeight.bold,
                                color: _hasCompletedDeposit
                                    ? accentGreen
                                    : lightText,
                              ),
                            ),
                            SizedBox(
                              height: isPortrait ? h * 0.005 : w * 0.005,
                            ),
                            Text(
                              "Progress: ${_filledCircles[0]}/4 slots filled",
                              style: TextStyle(
                                fontSize: w * 0.035,
                                color: _hasCompletedDeposit
                                    ? textColor
                                    : lightText,
                              ),
                            ),
                            Text(
                              "Income: \$40",
                              style: TextStyle(
                                fontSize: w * 0.03,
                                color: _hasCompletedDeposit
                                    ? textColor
                                    : lightText,
                              ),
                            ),
                            if (!_hasCompletedDeposit)
                              Text(
                                "Make deposit to unlock",
                                style: TextStyle(
                                  fontSize: w * 0.03,
                                  color: accentRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (_hasCompletedDeposit)
                              Text(
                                "Matrix is active - start filling slots!",
                                style: TextStyle(
                                  fontSize: w * 0.03,
                                  color: accentGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: w * 0.2,
                              height: w * 0.2,
                              child: CircularProgressIndicator(
                                value: _filledCircles[0] / 4,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _hasCompletedDeposit
                                      ? accentGreen
                                      : Colors.grey,
                                ),
                                strokeWidth: 8,
                              ),
                            ),
                            Column(
                              children: [
                                Icon(
                                  _hasCompletedDeposit
                                      ? Icons.check
                                      : Icons.lock,
                                  color: _hasCompletedDeposit
                                      ? accentGreen
                                      : Colors.grey,
                                  size: w * 0.05,
                                ),
                                Text(
                                  "${((_filledCircles[0] / 4) * 100).toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    fontSize: w * 0.04,
                                    fontWeight: FontWeight.bold,
                                    color: _hasCompletedDeposit
                                        ? accentGreen
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.03 : w * 0.03),

            // Matrix Structure
            Text(
              "Matrix Structure",
              style: TextStyle(
                fontSize: w * 0.045,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < 8; i++) ...[
                    _buildMatrixStructureItem(
                      w,
                      "Matrix ${i + 1}",
                      _getMatrixIncome(i),
                      unlocked: unlockedMatrices[i],
                      filledCircles: _filledCircles[i],
                      matrixIndex: i,
                    ),
                    if (i < 7)
                      SizedBox(height: isPortrait ? h * 0.02 : w * 0.02),
                  ],
                ],
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.03 : w * 0.03),

            // Matrix Progress
            Text(
              "Matrix Progress",
              style: TextStyle(
                fontSize: w * 0.045,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < 8; i++)
                    _buildMatrixLevel(
                      w,
                      "Matrix ${i + 1}",
                      _getMatrixIncome(i),
                      completed: _filledCircles[i] >= 4,
                      current: i == 0 && _hasCompletedDeposit,
                      unlocked: unlockedMatrices[i],
                      filledCircles: _filledCircles[i],
                      badgeColor: _getBadgeColor(i),
                    ),
                ],
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.03 : w * 0.03),

            // Matrix Explanation
            Text(
              "How Matrix Works",
              style: TextStyle(
                fontSize: w * 0.045,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lightBlue, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: primaryBlue, size: w * 0.06),
                      SizedBox(width: w * 0.02),
                      Expanded(
                        child: Text(
                          "Global Matrix Explanation",
                          style: TextStyle(
                            fontSize: w * 0.04,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
                  Text(
                    "Global Matrix is the very fastest big automatic earning program of OUKTAL SYSTEM. In this Program Global Matrix 1x4 is used, You will get 400% (non working) profit on every Matrix.",
                    style: TextStyle(
                      fontSize: w * 0.035,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: isPortrait ? h * 0.01 : w * 0.01),
                  Text(
                    "When all 4 circles fill globally, you earn the matrix income and automatically unlock the next matrix.",
                    style: TextStyle(
                      fontSize: w * 0.035,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: isPortrait ? h * 0.01 : w * 0.01),
                  Text(
                    "GLOBAL EARNING DEPENDS UPON GLOBAL ENTRIES. FIRST COME, FIRST SERVE.",
                    style: TextStyle(
                      fontSize: w * 0.035,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: isPortrait ? h * 0.015 : w * 0.015),
                  if (!_hasCompletedDeposit)
                    Container(
                      padding: EdgeInsets.all(w * 0.03),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: primaryBlue,
                            size: w * 0.05,
                          ),
                          SizedBox(width: w * 0.02),
                          Expanded(
                            child: Text(
                              "Make a deposit to unlock all matrices and start earning!",
                              style: TextStyle(
                                fontSize: w * 0.035,
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_hasCompletedDeposit)
                    Container(
                      padding: EdgeInsets.all(w * 0.03),
                      decoration: BoxDecoration(
                        color: accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: accentGreen,
                            size: w * 0.05,
                          ),
                          SizedBox(width: w * 0.02),
                          Expanded(
                            child: Text(
                              "Your Matrix 1 is now active! Start inviting members to fill your slots.",
                              style: TextStyle(
                                fontSize: w * 0.035,
                                color: accentGreen,
                                fontWeight: FontWeight.bold,
                              ),
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

  // Helper methods
  Color _getBadgeColor(int index) {
    if (index == 0) return bronze;
    if (index == 1) return silver;
    if (index == 2) return golden;
    return primaryBlue;
  }

  Widget _buildMatrixLevel(
    double w,
    String level,
    String income, {
    bool completed = false,
    bool current = false,
    bool unlocked = false,
    int filledCircles = 0,
    Color badgeColor = Colors.grey,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: w * 0.03),
      padding: EdgeInsets.all(w * 0.03),
      decoration: BoxDecoration(
        color: unlocked ? accentGreen.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: unlocked ? accentGreen : Colors.grey[400]!,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: w * 0.1,
            height: w * 0.1,
            decoration: BoxDecoration(
              color: completed
                  ? badgeColor
                  : (unlocked ? accentGreen : Colors.grey),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                level.split(' ')[1],
                style: TextStyle(
                  fontSize: w * 0.04,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: w * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TextStyle(
                    fontSize: w * 0.04,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? textColor : lightText,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Income: $income",
                  style: TextStyle(fontSize: w * 0.03, color: Colors.black),
                ),
                Text(
                  "Filled: $filledCircles/4 circles",
                  style: TextStyle(fontSize: w * 0.028, color: Colors.black),
                ),
                Text(
                  completed
                      ? "Status: Completed"
                      : (unlocked
                            ? "Status: Active - Ready to earn!"
                            : "Status: Locked - Complete previous matrix"),
                  style: TextStyle(
                    fontSize: w * 0.025,
                    color: completed
                        ? badgeColor
                        : (unlocked ? accentGreen : accentRed),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                completed ? Icons.star : (unlocked ? Icons.check : Icons.lock),
                color: completed
                    ? badgeColor
                    : (unlocked ? accentGreen : Colors.grey),
                size: w * 0.05,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixStructureItem(
    double w,
    String matrixName,
    String income, {
    bool unlocked = false,
    int filledCircles = 0,
    required int matrixIndex,
  }) {
    return Container(
      padding: EdgeInsets.all(w * 0.03),
      decoration: BoxDecoration(
        color: unlocked ? Color(0xFFF0FFF0) : Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: unlocked ? accentGreen : Color(0xFFCCCCCC),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                matrixName,
                style: TextStyle(
                  fontSize: w * 0.04,
                  fontWeight: FontWeight.bold,
                  color: unlocked ? textColor : lightText,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.03,
                  vertical: w * 0.01,
                ),
                decoration: BoxDecoration(
                  color: unlocked
                      ? accentGreen.withOpacity(0.2)
                      : lightText.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      unlocked ? Icons.check : Icons.lock,
                      size: w * 0.035,
                      color: unlocked ? accentGreen : lightText,
                    ),
                    SizedBox(width: w * 0.01),
                    Text(
                      unlocked ? "Active" : "Locked",
                      style: TextStyle(
                        fontSize: w * 0.03,
                        fontWeight: FontWeight.w600,
                        color: unlocked ? accentGreen : lightText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: w * 0.02),
          Container(
            width: w * 0.2,
            height: w * 0.08,
            decoration: BoxDecoration(
              color: unlocked ? primaryBlue : lightText,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(w * 0.02),
                topRight: Radius.circular(w * 0.02),
              ),
            ),
            child: Center(
              child: Text(
                "You",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: w * 0.03,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: w * 0.04),
          Icon(
            Icons.arrow_downward,
            color: unlocked ? accentGreen : lightText,
            size: w * 0.09,
          ),
          SizedBox(height: w * 0.04),
          Column(
            children: [
              _buildMatrixSlot(
                w,
                "1",
                filled: filledCircles >= 1,
                level: matrixIndex + 1,
                unlocked: unlocked,
              ),
              SizedBox(height: w * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(width: w * 0.1),
                  _buildMatrixSlot(
                    w,
                    "2",
                    filled: filledCircles >= 2,
                    level: matrixIndex + 1,
                    unlocked: unlocked,
                  ),
                  SizedBox(width: w * 0.1),
                  _buildMatrixSlot(
                    w,
                    "3",
                    filled: filledCircles >= 3,
                    level: matrixIndex + 1,
                    unlocked: unlocked,
                  ),
                  SizedBox(width: w * 0.1),
                ],
              ),
              SizedBox(height: w * 0.01),
              _buildMatrixSlot(
                w,
                "4",
                filled: filledCircles >= 4,
                level: matrixIndex + 1,
                unlocked: unlocked,
              ),
            ],
          ),
          SizedBox(height: w * 0.02),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.03,
              vertical: w * 0.015,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progress: $filledCircles/4",
                  style: TextStyle(fontSize: w * 0.03, color: Colors.black),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Income: $income",
                      style: TextStyle(
                        fontSize: w * 0.035,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (!unlocked)
                      Text(
                        "Complete previous matrix to unlock",
                        style: TextStyle(fontSize: w * 0.025, color: accentRed),
                      ),
                    if (unlocked)
                      Text(
                        filledCircles >= 4
                            ? "Completed"
                            : "Active - Start earning!",
                        style: TextStyle(
                          fontSize: w * 0.025,
                          color: accentGreen,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixSlot(
    double w,
    String text, {
    bool filled = false,
    required int level,
    bool unlocked = false,
  }) {
    double size = w * 0.15;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? accentGreen : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: unlocked ? accentGreen : Colors.grey,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: filled ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: w * 0.035,
          ),
        ),
      ),
    );
  }
}
