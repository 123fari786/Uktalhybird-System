import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uktalhybird/Menu_Screen/depoosit_history.dart';
import 'package:uktalhybird/Menu_Screen/withdrawalhistory.dart';
import 'package:uktalhybird/Metrixcreen/setting.dart';
import 'package:uktalhybird/Taskscree.dart';
import 'package:uktalhybird/login.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _progressValue = 2500;
  final double _minValue = 100;
  final double _maxValue = 91000;
  double _totalLevelEarnings = 0.0;
  double _totalMatrixEarnings = 0.0; // NEW: Matrix earnings variable
  Map<int, double> _levelEarnings = {};
  String _referralLink = '';
  int _directMembersCount = 0; // NEW: For matrix calculation

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // ✅ ADD THIS: Declare the _hasCompletedDeposit variable
  bool _hasCompletedDeposit = false;
  @override
  void initState() {
    super.initState();
    // _loadLevelEarnings(); // Same function as TeamScreen
    // _startLevelEarningsListener();
    _debugCheckWalletData(); // ADDED: Debug function
    _loadReferralLink(); // Add this line
    _loadDirectMembersCount(); // NEW: Load direct members for matrix calculation
    _loadTotalTeamCount(); // ADD THIS LINE
    // 🆕 ADD THESE LINES
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 5. باقی چیزیں
      await _checkDepositStatus();
      await _loadReferralLink();
      await _loadDirectMembersCount();
    });
  }

  // ✅ ADD THIS: Force refresh when returning to dashboard
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _checkAndResetTodayEarningsForNewDay().then((_) {
    //   _syncTodayEarningsFromCalculated();
    // });
  }

  @override
  void activate() {
    super.activate();
    // _checkAndResetTodayEarningsForNewDay().then((_) {
    //   _syncTodayEarningsFromCalculated();
    // });
  }

  // Recursive function to count total team members (complete downline) - SAME AS TEAMSCREEN
  Future<int> _getTotalTeamCount(String referralCode) async {
    int totalCount = 0;

    try {
      print('🔍 Dashboard Recursive search for referral: $referralCode');

      // Find all direct members using this referral code
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      totalCount += directMembersQuery.docs.length;
      print(
        '   📊 Dashboard Level count: ${directMembersQuery.docs.length} members',
      );

      // Recursively count members of each direct member
      for (final doc in directMembersQuery.docs) {
        final memberData = doc.data() as Map<String, dynamic>;
        final memberReferralCode = memberData['referralCode'];
        final memberName = memberData['name'] ?? 'Unknown';

        print(
          '   🔄 Dashboard Checking downline of: $memberName ($memberReferralCode)',
        );

        if (memberReferralCode != null && memberReferralCode.isNotEmpty) {
          totalCount += await _getTotalTeamCount(memberReferralCode);
        } else {
          print(
            '   ❌ Dashboard Member $memberName has no referral code, cannot check downline',
          );
        }
      }
    } catch (e) {
      print('❌ Dashboard Error in recursive team count for $referralCode: $e');
    }

    print('📈 Dashboard Total count for $referralCode: $totalCount');
    return totalCount;
  }

  // Load total team count for dashboard
  Future<void> _loadTotalTeamCount() async {
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

        if (referralCode != null && referralCode.isNotEmpty) {
          final totalCount = await _getTotalTeamCount(referralCode);
          // You can store this in a variable if needed for other parts of the dashboard
          print('🏆 Dashboard Total Team Count: $totalCount');
        }
      }
    } catch (e) {
      print('Error loading total team count for dashboard: $e');
    }
  }

  // ✅ UPDATED: Calculate total business from ALL team members' packages (recursive)
  // ✅ UPDATED: Calculate total business from ALL team members' packages (EXCLUDING admin-activated packages)
  Future<double> _calculateTotalBusiness() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0.0;

      // Get user's referral code
      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return 0.0;

      final userData = userDoc.data() as Map<String, dynamic>;
      final referralCode = userData['referralCode'];

      if (referralCode == null || referralCode.isEmpty) return 0.0;

      // Recursively get ALL team members and calculate their VALID package purchases
      double totalBusiness = await _getTotalBusinessRecursive(referralCode);

      print(
        '💰 Total Business Calculation (Excluding Admin): \$$totalBusiness',
      );
      return totalBusiness;
    } catch (e) {
      print('❌ Error calculating total business: $e');
      return 0.0;
    }
  }

  // ✅ UPDATED: Recursive function to calculate business from ALL team members (EXCLUDING admin-activated packages)
  Future<double> _getTotalBusinessRecursive(String referralCode) async {
    double totalBusiness = 0.0;

    try {
      // Find all direct members using this referral code
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      // For each direct member, calculate their VALID package purchases
      for (final doc in directMembersQuery.docs) {
        final memberId = doc.id;

        // Get all purchased packages for this member from both collections
        final userPackages = await _firestore
            .collection('users')
            .doc(memberId)
            .collection('purchasedPackages')
            .get();

        final signupPackages = await _firestore
            .collection('Signup_Data')
            .doc(memberId)
            .collection('purchasedPackages')
            .get();

        // Combine packages from both collections
        final allPackages = [...userPackages.docs, ...signupPackages.docs];

        // Sum up all VALID package amounts for this member (excluding admin-activated)
        for (final packageDoc in allPackages) {
          final packageData = packageDoc.data() as Map<String, dynamic>;

          // ✅ SKIP if package is activated by admin
          if (_isPackageActivatedByAdmin(packageData)) {
            print('🔄 Skipping admin-activated package for member: $memberId');
            continue;
          }

          final totalAmount = (packageData['totalAmount'] ?? 0.0).toDouble();
          totalBusiness += totalAmount;

          print(
            '✅ Added user-purchased package: \$$totalAmount for member: $memberId',
          );
        }

        // Recursively calculate business from this member's downline
        final memberData = doc.data() as Map<String, dynamic>;
        final memberReferralCode = memberData['referralCode'];

        if (memberReferralCode != null && memberReferralCode.isNotEmpty) {
          totalBusiness += await _getTotalBusinessRecursive(memberReferralCode);
        }
      }
    } catch (e) {
      print('❌ Error in recursive business calculation for $referralCode: $e');
    }

    return totalBusiness;
  }

  // ✅ ADD THIS: Helper method to check if package is activated by admin
  bool _isPackageActivatedByAdmin(Map<String, dynamic> packageData) {
    final activatedBy = packageData['activatedBy']?.toString().toLowerCase();
    return activatedBy == 'admin';
  }

  Future<void> _loadReferralLink() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final referralCode = userData['referralCode'] ?? '';

        // Update this with your actual app download link
        setState(() {
          _referralLink = 'https://uktalhybrid.com/signup?ref=$referralCode';
        });
      }
    } catch (e) {
      print('Error loading referral link: $e');
    }
  }

  String _getTodayDateString() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }

  // 🆕 NEW: Load total level earnings from my_total_earning collection
  Future<double> _loadTotalLevelEarningsFromMyTotalEarning() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0.0;

      final totalEarningDoc = await _firestore
          .collection('my_total_earning')
          .doc(user.uid)
          .get();

      double totalEarnings = 0.0;

      if (totalEarningDoc.exists) {
        final totalData = totalEarningDoc.data() as Map<String, dynamic>;

        // Get total earnings from my_total_earning
        totalEarnings = (totalData['totalLevelEarnings'] ?? 0.0).toDouble();

        // Alternative: Get from levelEarnings.total if available
        final levelEarningsData =
            totalData['levelEarnings'] as Map<String, dynamic>?;
        if (levelEarningsData != null) {
          totalEarnings = (levelEarningsData['total'] ?? totalEarnings)
              .toDouble();
        }

        print(
          '✅ Loaded TOTAL earnings from my_total_earning: \$$totalEarnings',
        );
      } else {
        print('📭 No my_total_earning document found, returning 0');
      }

      return totalEarnings;
    } catch (e) {
      print('❌ Error loading total earnings from my_total_earning: $e');
      return 0.0;
    }
  }

  Widget _buildTotalEarningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildTotalEarningSection()],
    );
  }

  // ✅ UPDATED: Total Earning calculation - Now uses my_total_earning collection
  Widget _buildTotalEarningAmount() {
    return FutureBuilder<double>(
      future: _loadTotalLevelEarningsFromMyTotalEarning(),
      builder: (context, snapshot) {
        double totalLevelEarnings = 0.0;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TOTAL EARNING",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "\$0.000",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }

        if (snapshot.hasData) {
          totalLevelEarnings = snapshot.data!;
        }

        // Now calculate TOTAL EARNING with all components including my_total_earning
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Signup_Data')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('passive_rewards')
                  .where(
                    'userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .where('status', isEqualTo: 'credited')
                  .snapshots(),
              builder: (context, passiveSnapshot) {
                double totalEarnings = 0.0;

                // 1. Add passive rewards from passive_rewards collection
                if (passiveSnapshot.hasData) {
                  for (var doc in passiveSnapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    totalEarnings += (data['rewardAmount'] ?? 0.0).toDouble();
                  }
                }

                // 2. Add passiveWallet from Signup_Data
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var data = userSnapshot.data!.data() as Map<String, dynamic>;
                  var passiveWallet = (data["passiveWallet"] ?? 0.0).toDouble();
                  totalEarnings += passiveWallet;
                }

                // 3. Add MetricWallet from Signup_Data (matrix earnings)
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var data = userSnapshot.data!.data() as Map<String, dynamic>;
                  var metricWallet = (data["MetricWallet"] ?? 0.0).toDouble();
                  totalEarnings += metricWallet;
                }

                // 4. Add Matrix Earnings from _totalMatrixEarnings
                totalEarnings += _totalMatrixEarnings;

                // ✅ UPDATED: 5. Add Level Earnings from my_total_earning collection
                totalEarnings += totalLevelEarnings;

                // 6. Add Lottery Earnings from lotteryWallet collection
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("wallets")
                      .doc("lotteryWallet")
                      .snapshots(),
                  builder: (context, lotterySnapshot) {
                    if (lotterySnapshot.hasData &&
                        lotterySnapshot.data!.exists) {
                      final lotteryData =
                          lotterySnapshot.data!.data() as Map<String, dynamic>;
                      final userId =
                          FirebaseAuth.instance.currentUser?.uid ?? "guest";

                      // Add lottery earnings
                      var earningsMap = lotteryData["earnings"] ?? {};
                      var lotteryEarnings = (earningsMap[userId] ?? 0.0)
                          .toDouble();
                      totalEarnings += lotteryEarnings;

                      // Add lottery fund from Signup_Data
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        var userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        var lotteryFund = (userData["lotteryWallet"] ?? 0.0)
                            .toDouble();
                        totalEarnings += lotteryFund;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TOTAL EARNING",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "\$${totalEarnings.toStringAsFixed(3)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.of(context).size.width * 0.05,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // NEW: Load direct members count for matrix calculation
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
        _calculateMatrixEarnings(); // Calculate matrix earnings after loading members
      }
    } catch (e) {
      print('Error loading direct members count: $e');
    }
  }

  // ✅ UPDATED: Matrix earnings calculation - Fixed $10 when deposit is completed
  void _calculateMatrixEarnings() {
    double total = 0.0;

    // Check if user has completed matrix deposit
    if (_hasCompletedDeposit) {
      total = 10.0; // Fixed $10 when deposit is completed
    } else {
      total = 0.0; // $0 when no deposit
    }

    setState(() {
      _totalMatrixEarnings = total;
    });

    print('💰 Matrix Earnings: \$$total');
    print('✅ Deposit Status: $_hasCompletedDeposit');
  }

  // ✅ UPDATED: Check deposit status function
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

      // Recalculate earnings after checking deposit status
      _calculateMatrixEarnings();

      print('✅ Deposit status: $_hasCompletedDeposit');
      print('✅ Found ${matrixPayments.docs.length} completed payments');
    } catch (e) {
      print('❌ Error checking deposit status: $e');
      setState(() {
        _hasCompletedDeposit = false;
      });
    }
  }

  // NEW: Same filled circles calculation as MatrixIncomeScreen
  List<int> _getFilledCircles() {
    List<int> filledCircles = List.filled(8, 0);

    // Matrix 1: Fill circles based on direct members (max 4)
    filledCircles[0] = _directMembersCount >= 4 ? 4 : _directMembersCount;

    // Matrix 2: Fill circles based on direct members beyond 4 (max 4)
    if (_directMembersCount > 4) {
      filledCircles[1] = _directMembersCount >= 8 ? 4 : _directMembersCount - 4;
    }

    // Matrix 3: Fill circles based on direct members beyond 8 (max 4)
    if (_directMembersCount > 8) {
      filledCircles[2] = _directMembersCount >= 12
          ? 4
          : _directMembersCount - 8;
    }

    // Matrix 4: Fill circles based on direct members beyond 12 (max 4)
    if (_directMembersCount > 12) {
      filledCircles[3] = _directMembersCount >= 16
          ? 4
          : _directMembersCount - 12;
    }

    // Matrix 5: Fill circles based on direct members beyond 16 (max 4)
    if (_directMembersCount > 16) {
      filledCircles[4] = _directMembersCount >= 20
          ? 4
          : _directMembersCount - 16;
    }

    // Matrix 6: Fill circles based on direct members beyond 20 (max 4)
    if (_directMembersCount > 20) {
      filledCircles[5] = _directMembersCount >= 24
          ? 4
          : _directMembersCount - 20;
    }

    // Matrix 7: Fill circles based on direct members beyond 24 (max 4)
    if (_directMembersCount > 24) {
      filledCircles[6] = _directMembersCount >= 28
          ? 4
          : _directMembersCount - 24;
    }

    // Matrix 8: Fill circles based on direct members beyond 28 (max 4)
    if (_directMembersCount > 28) {
      filledCircles[7] = _directMembersCount >= 32
          ? 4
          : _directMembersCount - 28;
    }

    return filledCircles;
  }

  StreamSubscription<DocumentSnapshot>? _levelEarningsSubscription;

  // ADDED: Debug function to check wallet data structure
  Future<void> _debugCheckWalletData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('\n=== DASHBOARD WALLET DEBUG ===');

      // Check all documents in Sponsar_wallets for this user
      final walletDoc = await _firestore
          .collection('Sponsar_wallets')
          .doc(user.uid)
          .get();

      if (walletDoc.exists) {
        print('✅ Sponsar_wallets document exists');
        final data = walletDoc.data();
        print('📊 Document data: $data');

        // Check specific fields
        if (data != null) {
          print('🔍 levelEarnings field: ${data['levelEarnings']}');
          print('🔍 totalLevelBonus field: ${data['totalLevelBonus']}');
        }
      } else {
        print('❌ No Sponsar_wallets document for user ${user.uid}');
      }

      print('=== END DEBUG ===\n');
    } catch (e) {
      print('❌ Debug check error: $e');
    }
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

  @override
  void dispose() {
    _levelEarningsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      endDrawer: _DashboardDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile Section
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Signup_Data')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;

                  final userName = userData?['name'] ?? 'User';
                  final userEmail = userData?['email'] ?? 'No email';

                  // Get first letter of name for circle avatar
                  final firstLetter = userName.isNotEmpty
                      ? userName[0].toUpperCase()
                      : 'U';

                  // Get joining date (if available)
                  final joinedDate = userData?['joinedAt'] != null
                      ? (userData?['joinedAt'] as Timestamp).toDate()
                      : DateTime.now();
                  final formattedDate =
                      "${joinedDate.day}-${joinedDate.month}-${joinedDate.year}";

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.08,
                        backgroundColor: const Color(0xFF0000FF),
                        child: Text(
                          firstLetter,
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.04,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            "JOINED: $formattedDate",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: screenWidth * 0.032,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                        icon: Icon(
                          Icons.menu,
                          size: screenWidth * 0.06,
                          color: const Color(0xFF0000FF),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                    ],
                  );
                },
              ),

              SizedBox(height: screenHeight * 0.02),

              // Total Earning with Overlay White Box (Compact Version)
              // Total Earning with Overlay White Box (Compact Version)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Blue Box
                  Container(
                    width: double.infinity,
                    height: 160,
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0000FF),
                      borderRadius: BorderRadius.circular(screenWidth * 0.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        GestureDetector(
                          onTap: () {
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => const MyWallet(),
                            //   ),
                            // );
                          },
                          child: _buildTotalEarningAmount(),
                        ),
                        SizedBox(height: screenHeight * 0.05),
                      ],
                    ),
                  ),
                  // White Box overlay
                  Positioned(
                    bottom: -screenHeight * 0.04,
                    left: screenWidth * 0.06,
                    right: screenWidth * 0.06,
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.035),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          screenWidth * 0.035,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Total Withdraw
                          // DashboardScreen میں TOTAL WITHDRAW والٹ کو یہ کوڈ سے تبدیل کریں:

                          // Total Withdraw
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL WITHDRAW",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: screenWidth * 0.03,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.004),

                              // ✅ TOTAL WITHDRAW AMOUNT - Real-time sum of all withdrawal amounts
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('withdrawal_fees')
                                    .where(
                                      'userId',
                                      isEqualTo: FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid,
                                    )
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  double totalWithdrawn = 0.0;

                                  if (snapshot.hasData) {
                                    for (var doc in snapshot.data!.docs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;

                                      // ✅ Use netAmount if available, otherwise calculate from originalAmount and feeAmount
                                      final netAmount =
                                          (data['netAmount'] ?? 0.0).toDouble();
                                      final originalAmount =
                                          (data['originalAmount'] ?? 0.0)
                                              .toDouble();
                                      final feeAmount =
                                          (data['feeAmount'] ?? 0.0).toDouble();

                                      // Use netAmount if it's greater than 0, otherwise calculate
                                      final withdrawalAmount = netAmount > 0
                                          ? netAmount
                                          : (originalAmount - feeAmount);

                                      totalWithdrawn += withdrawalAmount;
                                    }
                                  }

                                  return Text(
                                    "\$${totalWithdrawn.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),

                              SizedBox(height: screenHeight * 0.008),
                              ElevatedButton(
                                onPressed: () {
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) => const DepositScreen(),
                                  //   ),
                                  // );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.05,
                                    vertical: screenHeight * 0.008,
                                  ),
                                  backgroundColor: const Color(0xFF0000FF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.02,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "Deposit",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ✅ UPDATED: Combine Matrix Earnings + Level Earnings
                          // ✅ UPDATED: Show ONLY Matrix Earnings for Today Earning
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TODAY EARNING",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: screenWidth * 0.03,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.004),

                              // ✅ SHOW ONLY MATRIX EARNINGS
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('Today_Earnings')
                                    .doc(FirebaseAuth.instance.currentUser?.uid)
                                    .collection('daily_earnings')
                                    .doc(_getTodayDateString())
                                    .get(),
                                builder: (context, todaySnapshot) {
                                  double matrixEarnings = 0.0;

                                  if (todaySnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      "Loading...",
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.04,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    );
                                  }

                                  if (todaySnapshot.hasData &&
                                      todaySnapshot.data!.exists) {
                                    final todayData =
                                        todaySnapshot.data!.data()
                                            as Map<String, dynamic>;

                                    // ✅ ONLY get matrixEarnings, ignore everything else
                                    matrixEarnings =
                                        (todayData['matrixEarnings'] ?? 0.0)
                                            .toDouble();

                                    print(
                                      '📊 Today Matrix Earnings Only: \$$matrixEarnings',
                                    );
                                  }

                                  return Text(
                                    "+\$${matrixEarnings.toStringAsFixed(3)}",
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  );
                                },
                              ),

                              SizedBox(height: screenHeight * 0.07),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.04),

              // Updated Referral Link Bar
              // Updated Referral Link Bar
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                margin: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('purchasedPackages')
                      .where('status', isEqualTo: 'finished')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, activePackagesSnapshot) {
                    bool hasActivePackage = false;
                    List<String> purchasedPackageTitles = [];

                    if (activePackagesSnapshot.hasData) {
                      purchasedPackageTitles = activePackagesSnapshot.data!.docs
                          .where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final status = data['status'] ?? '';
                            final isActive = data['isActive'] ?? false;
                            final title =
                                data['packageTitle']?.toString().trim() ?? '';
                            return status == 'finished' &&
                                isActive == true &&
                                title.isNotEmpty;
                          })
                          .map(
                            (doc) =>
                                (doc['packageTitle']?.toString().trim() ?? ''),
                          )
                          .where((title) => title.isNotEmpty)
                          .toList();

                      hasActivePackage = purchasedPackageTitles.isNotEmpty;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Link and Copy Button Row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.03,
                                  vertical: screenHeight * 0.01,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  hasActivePackage
                                      ? _referralLink
                                      : "Buy a package first to get referral link",
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.032,
                                    color: hasActivePackage
                                        ? Colors.black
                                        : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            SizedBox(
                              height: screenHeight * 0.045,
                              child: ElevatedButton(
                                onPressed: hasActivePackage
                                    ? () {
                                        if (_referralLink.isNotEmpty) {
                                          Clipboard.setData(
                                            ClipboardData(text: _referralLink),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Referral link copied successfully!',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );

                                          // Optional: Show the link briefly when copied
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Your referral link:',
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.03,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    _referralLink,
                                                    style: TextStyle(
                                                      fontSize:
                                                          screenWidth * 0.028,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Color(
                                                0xFF0000FF,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              duration: Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasActivePackage
                                      ? Color(0xFF0000FF)
                                      : Colors.grey,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.04,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "COPY",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.032,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Optional: Add a small info text
                        if (!hasActivePackage)
                          Padding(
                            padding: EdgeInsets.only(top: screenHeight * 0.008),
                            child: Text(
                              "Purchase any package to unlock your referral link",
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                color: Colors.orange,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: screenHeight * 0.01),

              // Package, Matrix, Lottery
              // Package, Matrix, Lottery
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('purchasedPackages')
                          .snapshots(),
                      builder: (context, snapshot) {
                        // ✅ FIXED: ALWAYS use these prices (ignore database prices)
                        final Map<String, double> fixedPackagePrices = {
                          "Starter Package": 5.0,
                          "Basic Package": 10.0,
                          "Standard Package": 25.0,
                          "Pro Package": 50.0,
                          "Elite Package": 100.0,
                          "Premium Package": 250.0,
                          "Ultimate Package": 500.0,
                        };

                        // ✅ Track active packages
                        Set<String> activePackageTitles =
                            {}; // Use Set to avoid duplicates

                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final status = data['status'] ?? '';
                            final isActive = data['isActive'] ?? false;
                            final packageTitle =
                                data['packageTitle']?.toString().trim() ?? '';
                            final activatedBy = data['activatedBy'] ?? '';

                            // Check if package is active
                            bool isActiveByAdmin =
                                activatedBy == 'admin' && status == 'finished';
                            bool isActiveByPurchase =
                                status == 'finished' && isActive == true;

                            if ((isActiveByAdmin || isActiveByPurchase) &&
                                packageTitle.isNotEmpty) {
                              activePackageTitles.add(packageTitle);
                            }
                          }
                        }

                        // ✅ Also check Signup_Data collection
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Signup_Data')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('purchasedPackages')
                              .snapshots(),
                          builder: (context, signupPackagesSnapshot) {
                            if (signupPackagesSnapshot.hasData) {
                              for (var doc
                                  in signupPackagesSnapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final status = data['status'] ?? '';
                                final isActive = data['isActive'] ?? false;
                                final packageTitle =
                                    data['packageTitle']?.toString().trim() ??
                                    '';
                                final activatedBy = data['activatedBy'] ?? '';

                                // Check if package is active
                                bool isActiveByAdmin =
                                    activatedBy == 'admin' &&
                                    status == 'finished';
                                bool isActiveByPurchase =
                                    status == 'finished' && isActive == true;

                                if ((isActiveByAdmin || isActiveByPurchase) &&
                                    packageTitle.isNotEmpty) {
                                  activePackageTitles.add(packageTitle);
                                }
                              }
                            }

                            // ✅ Calculate CUMULATIVE SUM using FIXED prices
                            double cumulativeTotal = 0.0;
                            bool hasActivePackage =
                                activePackageTitles.isNotEmpty;

                            if (hasActivePackage) {
                              // Sort packages in correct order for calculation
                              final List<String> packageOrder = [
                                "Starter Package",
                                "Basic Package",
                                "Standard Package",
                                "Pro Package",
                                "Elite Package",
                                "Premium Package",
                                "Ultimate Package",
                              ];

                              // Calculate sum of all active packages
                              for (var packageTitle in activePackageTitles) {
                                final double packagePrice =
                                    fixedPackagePrices[packageTitle] ?? 0.0;
                                cumulativeTotal += packagePrice;

                                print(
                                  '➕ Adding $packageTitle: \$$packagePrice',
                                );
                              }

                              print(
                                '📊 Active Packages: ${activePackageTitles.toList()}',
                              );
                              print('💰 CUMULATIVE TOTAL: \$$cumulativeTotal');
                            }

                            return _PackageBox(
                              title: "MY PACKAGE",
                              value: "\$${cumulativeTotal.toStringAsFixed(2)}",
                              active: hasActivePackage,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Matrix Package Box - Updated Version
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Matric_payment_deposit')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .snapshots(),
                      builder: (context, matrixSnapshot) {
                        bool hasMatrixDeposit = false;

                        if (matrixSnapshot.hasData &&
                            matrixSnapshot.data!.exists) {
                          final matrixData =
                              matrixSnapshot.data!.data()
                                  as Map<String, dynamic>;

                          // Check if user has any completed matrix payments
                          final matrixPayments =
                              matrixData['matrix_payments']
                                  as Map<String, dynamic>?;
                          if (matrixPayments != null) {
                            matrixPayments.forEach((key, value) {
                              if (value is Map<String, dynamic> &&
                                  value['status'] == 'completed') {
                                hasMatrixDeposit = true;
                              }
                            });
                          }
                        }

                        // Alternative: Check the matrix_payments subcollection
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Matric_payment_deposit')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('matrix_payments')
                              .where('status', isEqualTo: 'completed')
                              .snapshots(),
                          builder: (context, paymentsSnapshot) {
                            if (paymentsSnapshot.hasData &&
                                paymentsSnapshot.data!.docs.isNotEmpty) {
                              hasMatrixDeposit = true;
                            }

                            return _PackageBox(
                              title: "MATRIX",
                              value: hasMatrixDeposit
                                  ? "\$10"
                                  : "\$0", // Fixed $10 when deposit completed
                              active: hasMatrixDeposit,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // Updated Lottery Package Box - Shows active/inactive based on ticket purchase and displays lottery fund
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("wallets")
                          .doc("lotteryWallet")
                          .snapshots(),
                      builder: (context, lotterySnapshot) {
                        // Check if user has purchased ticket
                        bool hasTicket = false;
                        int myTickets = 0;

                        if (lotterySnapshot.hasData &&
                            lotterySnapshot.data!.exists) {
                          final data =
                              lotterySnapshot.data!.data()
                                  as Map<String, dynamic>;
                          final userId =
                              FirebaseAuth.instance.currentUser?.uid ?? "guest";

                          var ticketsMap = data["tickets"] ?? {};
                          myTickets = ticketsMap[userId] ?? 0;
                          hasTicket = myTickets > 0;
                        }

                        // Get lottery fund from Signup_Data
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Signup_Data')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            double lotteryFund = 0.0;

                            if (userSnapshot.hasData &&
                                userSnapshot.data!.exists) {
                              final userData =
                                  userSnapshot.data!.data()
                                      as Map<String, dynamic>;
                              lotteryFund = (userData["lotteryWallet"] ?? 0.0)
                                  .toDouble();
                            }

                            // ✅ UPDATED: Show fixed $1 when active, otherwise show lottery fund
                            return _PackageBox(
                              title: "LOTTERY",
                              value: hasTicket
                                  ? "\$1"
                                  : "\$${lotteryFund.toStringAsFixed(2)}", // Fixed $1 when active
                              active: hasTicket,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.02),

              // Wallet Balance, Total Team, Total Referral
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // My Task box
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .collection('purchasedPackages')
                        .snapshots(),
                    builder: (context, packageSnapshot) {
                      int totalDailyTasksFromPackages = 0;

                      if (packageSnapshot.hasData) {
                        final List<Map<String, dynamic>> packages = [
                          {"title": "Starter Package", "dailyTaskCount": 15},
                          {"title": "Basic Package", "dailyTaskCount": 15},
                          {"title": "Standard Package", "dailyTaskCount": 20},
                          {"title": "Pro Package", "dailyTaskCount": 20},
                          {"title": "Elite Package", "dailyTaskCount": 25},
                          {"title": "Premium Package", "dailyTaskCount": 27},
                          {"title": "Ultimate Package", "dailyTaskCount": 30},
                        ];

                        for (var doc in packageSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = data['status'] ?? '';
                          final isActive = data['isActive'] ?? false;
                          final packageTitle =
                              data['packageTitle']?.toString().trim() ?? '';

                          if (status == 'finished' &&
                              isActive == true &&
                              packageTitle.isNotEmpty) {
                            final package = packages.firstWhere(
                              (pkg) =>
                                  pkg["title"]?.toString().trim() ==
                                  packageTitle,
                              orElse: () => {"dailyTaskCount": 0},
                            );

                            final dailyTaskCount =
                                (package["dailyTaskCount"] ?? 0) as int;
                            totalDailyTasksFromPackages += dailyTaskCount;
                          }
                        }
                      }

                      return _InfoBox(
                        title: "My Task",
                        value: "$totalDailyTasksFromPackages",
                        icon: Icons.account_balance_wallet,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TaskScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // Total Team box
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Signup_Data')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                        return _InfoBox(
                          title: "Total Team",
                          value: "0",
                          icon: Icons.group,
                          onTap: () {
                            // Navigate to team screen
                          },
                        );
                      }

                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final referralCode = userData['referralCode'];

                      if (referralCode == null || referralCode.isEmpty) {
                        return _InfoBox(
                          title: "Total Team",
                          value: "0",
                          icon: Icons.group,
                          onTap: () {
                            // Navigate to team screen
                          },
                        );
                      }

                      return FutureBuilder<int>(
                        future: _getTotalTeamCount(referralCode),
                        builder: (context, snapshot) {
                          final totalTeamCount = snapshot.data ?? 0;

                          return _InfoBox(
                            title: "Total Team",
                            value: "$totalTeamCount",
                            icon: Icons.group,
                            onTap: () {
                              // Navigate to team screen
                            },
                          );
                        },
                      );
                    },
                  ),
                  // Total Referral box
                  _InfoBox(
                    title: "Total Referral",
                    value: "$_directMembersCount",
                    icon: Icons.person_add,
                    onTap: () {
                      // You can add navigation to referral screen if needed
                    },
                  ),
                ],
              ),

              // Total Business, Rank Income, Current Rank
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Total Business box
                  FutureBuilder<double>(
                    future: _calculateTotalBusiness(),
                    builder: (context, snapshot) {
                      final totalBusiness = snapshot.data ?? 0.0;

                      return _InfoBox(
                        title: "Total Business",
                        value: "\$${totalBusiness.toStringAsFixed(2)}",
                        icon: Icons.business,
                        onTap: () {
                          // You can add navigation to business details if needed
                        },
                      );
                    },
                  ),
                  _InfoBox(
                    title: "Rank Income",
                    value: "\$0",
                    icon: Icons.monetization_on,
                  ),
                  _InfoBox(
                    title: "Current Rank",
                    value: "Member",
                    icon: Icons.emoji_events,
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.025),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Slider (with values below) + Claim Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side → Slider + Values
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.9,
                                child: Stack(
                                  children: [
                                    // Background track (inactive part)
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.01,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    // Fixed active track (25% of the total width)
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.01,
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.9 *
                                          0.0,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0000FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "\$0",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    "\$91000",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: screenWidth * 0.02),

                      // Right side → Claim Button
                      SizedBox(
                        width: screenWidth * 0.25,
                        height: screenHeight * 0.04,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0000FF),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            "CLAIM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.03,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.015),
              Center(child: Text("ADD BOX", style: TextStyle(fontSize: 30))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Drawer(
      width: screenWidth * 0.78,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0000FF).withOpacity(0.9),
              const Color(0xFF0000FF).withOpacity(0.7),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header with User Info
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.06),
                decoration: BoxDecoration(
                  color: const Color(0xFF0000FF),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Signup_Data')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      final userName = userData['name'] ?? 'User';
                      final userEmail = userData['email'] ?? 'No email';
                      final firstLetter = userName.isNotEmpty
                          ? userName[0].toUpperCase()
                          : 'U';

                      return Column(
                        children: [
                          // Profile Avatar with gradient border
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.015),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.blue.shade100],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: screenWidth * 0.08,
                              backgroundColor: Colors.white,
                              child: Text(
                                firstLetter,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.06,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0000FF),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          Text(
                            userName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: screenHeight * 0.008),
                          Text(
                            userEmail,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: screenWidth * 0.032,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: screenHeight * 0.008),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: screenWidth * 0.08,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: screenWidth * 0.06,
                            color: const Color(0xFF0000FF),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),
                        Text(
                          "User",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Drawer Menu Items
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(height: screenHeight * 0.02),
                      _DrawerItem(
                        icon: Icons.account_balance_wallet,
                        title: "Deposit History",
                        subtitle: "View your deposit transactions",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DepositHistory(),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.money_off,
                        title: "Withdrawal History",
                        subtitle: "Check your withdrawal records",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Withdrawalhistory(),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.newspaper,
                        title: "News and Updates",
                        subtitle: "Latest announcements",
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Please Wait for Next Updates",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                          // Add navigation to News and Updates screen here
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.thumb_up,
                        title: "Social Media & Support",
                        subtitle: "Connect with us",
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Coming Soon",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                          // Add navigation to Social Media & Support screen here
                        },
                      ),

                      _DrawerItem(
                        icon: Icons.settings,
                        title: "Settings",
                        subtitle: "App preferences",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Setting()),
                          );
                        },
                      ),
                      // _DrawerItem(
                      //   icon: Icons.help,
                      //   title: "Help & FAQ",
                      //   subtitle: "Get assistance",
                      //   onTap: () {
                      //     Navigator.pop(context);
                      //     // Add navigation to Help & FAQ screen here
                      //   },
                      // ),

                      // Divider with decorative element
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.05,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.03,
                              ),
                              child: Icon(
                                Icons.star,
                                color: const Color(0xFF0000FF),
                                size: screenWidth * 0.04,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                ),
              ),

              // Logout Button
              Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                              "Logout",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text("Are you sure you want to logout?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: const Color(0xFF0000FF),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Login(),
                                    ),
                                    (route) => false,
                                  );
                                },
                                child: Text(
                                  "Logout",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, screenHeight * 0.065),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: screenWidth * 0.045),
                        SizedBox(width: screenWidth * 0.03),
                        Text(
                          "LOGOUT",
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
}

// Drawer Item Widget
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.03, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(
            width: screenWidth * 0.12,
            height: screenWidth * 0.12,
            decoration: BoxDecoration(
              color: const Color(0xFF0000FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0000FF),
              size: screenWidth * 0.055,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: screenWidth * 0.038,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: screenWidth * 0.03,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            color: const Color(0xFF0000FF),
            size: screenWidth * 0.04,
          ),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.008,
          ),
        ),
      ),
    );
  }
}

class _PackageBox extends StatelessWidget {
  final String title;
  final String value;
  final bool active;

  const _PackageBox({
    required this.title,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFF0000FF),
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.02,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.03),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Smaller active/inactive container
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.008, // Reduced horizontal padding
                  vertical: screenWidth * 0.005, // Reduced vertical padding
                ),
                decoration: BoxDecoration(
                  color: active ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(
                    screenWidth * 0.015,
                  ), // Smaller border radius
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active ? "ACTIVE" : "INACTIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.02, // Smaller font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.005), // Reduced spacing
                    Container(
                      width: screenWidth * 0.018, // Smaller circle
                      height: screenWidth * 0.018, // Smaller circle
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap; // 👈 add

  const _InfoBox({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap, // 👈 add
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Expanded(
      child: InkWell(
        // 👈 tap effect ke liye
        onTap: onTap,
        borderRadius: BorderRadius.circular(screenWidth * 0.025),
        child: Container(
          margin: EdgeInsets.all(screenWidth * 0.01),
          padding: EdgeInsets.all(screenWidth * 0.025),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(screenWidth * 0.025),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth * 0.028,
                      ),
                    ),
                  ),
                  Icon(
                    icon,
                    color: const Color(0xFF0000FF),
                    size: screenWidth * 0.05,
                  ),
                ],
              ),
              SizedBox(height: screenWidth * 0.02),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
