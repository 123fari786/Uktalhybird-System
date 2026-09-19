import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uktalhybird/Withdrawal/Lottery/lotterwithdrawal.dart';
import 'package:uktalhybird/lotterydeposit/lotterydepositincome.dart';

class LotteryScreen extends StatefulWidget {
  const LotteryScreen({super.key});

  @override
  State<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends State<LotteryScreen> {
  // Countdown Timer
  Duration remainingTime = const Duration(
    days: 0,
    hours: 0,
    minutes: 0,
    seconds: 0,
  );
  Timer? countdownTimer;
  bool _timerRunning = false;
  StreamSubscription<DocumentSnapshot>? _timerSubscription;

  // Ticket Count
  int ticketCount = 1;
  final double ticketPrice = 1.00;
  bool hasPurchasedTicket = false;
  String? userLotteryNumber;
  int totalTicketsSold = 0;
  int maxTickets = 1000;

  @override
  void initState() {
    super.initState();
    _startTimerListener(); // ✅ REAL-TIME LISTENER ADD KAREIN
    _loadTimerSettings();
    _checkUserTicketPurchase();
    _loadTotalTickets();
  }

  // ✅ REAL-TIME TIMER LISTENER
  void _startTimerListener() {
    _timerSubscription = FirebaseFirestore.instance
        .collection('lottery_settings')
        .doc('current_draw')
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              final int days = data['days'] ?? 0;
              final int hours = data['hours'] ?? 0;
              final int minutes = data['minutes'] ?? 0;
              final int seconds = data['seconds'] ?? 0;
              final bool isRunning = data['isRunning'] ?? false;

              print('🎯 Timer update received from Firestore:');
              print(
                '📅 Days: $days, Hours: $hours, Minutes: $minutes, Seconds: $seconds',
              );
              print('⏱️ Is Running: $isRunning');

              // Update local state
              setState(() {
                remainingTime = Duration(
                  days: days,
                  hours: hours,
                  minutes: minutes,
                  seconds: seconds,
                );
              });

              // Handle timer state
              if (isRunning && !_timerRunning) {
                print('🚀 Starting timer from Firestore update');
                startTimer();
              } else if (!isRunning && _timerRunning) {
                print('🛑 Stopping timer from Firestore update');
                stopTimer();
              }
            }
          },
          onError: (error) {
            print("❌ Timer listener error: $error");
          },
        );
  }

  void _loadTimerSettings() async {
    try {
      final timerDoc = await FirebaseFirestore.instance
          .collection('lottery_settings')
          .doc('current_draw')
          .get();

      if (timerDoc.exists) {
        final data = timerDoc.data() as Map<String, dynamic>;
        final int days = data['days'] ?? 0;
        final int hours = data['hours'] ?? 0;
        final int minutes = data['minutes'] ?? 0;
        final int seconds = data['seconds'] ?? 0;
        final bool isRunning = data['isRunning'] ?? false;

        setState(() {
          remainingTime = Duration(
            days: days,
            hours: hours,
            minutes: minutes,
            seconds: seconds,
          );
          _timerRunning = isRunning;
        });

        if (isRunning && !_timerRunning) {
          startTimer();
        }
      }
    } catch (e) {
      print("Error loading timer settings: $e");
    }
  }

  void _checkUserTicketPurchase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final lotteryWalletDoc = await FirebaseFirestore.instance
          .collection("wallets")
          .doc("lotteryWallet")
          .get();

      if (lotteryWalletDoc.exists) {
        final data = lotteryWalletDoc.data() as Map<String, dynamic>;
        final ticketsMap = data["tickets"] ?? {};
        final myTickets = ticketsMap[user.uid] ?? 0;

        setState(() {
          hasPurchasedTicket = myTickets > 0;
        });

        // Load user's lottery number if they have a ticket
        if (myTickets > 0) {
          _loadUserLotteryNumber(user.uid);
        }
      }
    } catch (e) {
      print("Error checking user ticket: $e");
    }
  }

  void _loadUserLotteryNumber(String userId) async {
    try {
      final userTicketDoc = await FirebaseFirestore.instance
          .collection('lottery_tickets')
          .doc(userId)
          .get();

      if (userTicketDoc.exists) {
        final data = userTicketDoc.data() as Map<String, dynamic>;
        setState(() {
          userLotteryNumber = data['lottery_number'] ?? 'Not assigned';
        });
      }
    } catch (e) {
      print("Error loading lottery number: $e");
    }
  }

  void _loadTotalTickets() async {
    try {
      final lotteryWalletDoc = await FirebaseFirestore.instance
          .collection("wallets")
          .doc("lotteryWallet")
          .get();

      if (lotteryWalletDoc.exists) {
        final data = lotteryWalletDoc.data() as Map<String, dynamic>;
        final ticketsMap = data["tickets"] ?? {};

        int total = 0;
        ticketsMap.forEach((key, value) {
          total += (value as int);
        });

        setState(() {
          totalTicketsSold = total;
        });
      }
    } catch (e) {
      print("Error loading total tickets: $e");
    }
  }

  void _resetTicketPurchaseStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Reset hasPurchasedTicket for all users when timer completes
      setState(() {
        hasPurchasedTicket = false;
        userLotteryNumber = null;
      });

      // Also reset in Firestore if needed
      await FirebaseFirestore.instance
          .collection("wallets")
          .doc("lotteryWallet")
          .update({"tickets.${user.uid}": FieldValue.delete()});

      print("🎫 Ticket purchase status reset for new draw");
    } catch (e) {
      print("Error resetting ticket status: $e");
    }
  }

  void startTimer() {
    if (_timerRunning) return;

    _timerRunning = true;

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (remainingTime.inSeconds > 0) {
          remainingTime = remainingTime - const Duration(seconds: 1);
          _updateFirestoreTimer();
        } else {
          countdownTimer?.cancel();
          _timerRunning = false;
          _updateFirestoreTimer();
          // Handle timer completion (draw lottery) and reset tickets
          _handleLotteryDraw();
        }
      });
    });
  }

  // ✅ Firestore mein timer update karein
  void _updateFirestoreTimer() async {
    try {
      await FirebaseFirestore.instance
          .collection('lottery_settings')
          .doc('current_draw')
          .update({
            'days': remainingTime.inDays,
            'hours': remainingTime.inHours.remainder(24),
            'minutes': remainingTime.inMinutes.remainder(60),
            'seconds': remainingTime.inSeconds.remainder(60),
            'isRunning': _timerRunning,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error updating timer in Firestore: $e");
    }
  }

  void _saveTimerState() async {
    try {
      await FirebaseFirestore.instance
          .collection('lottery_settings')
          .doc('current_draw')
          .set({
            'days': remainingTime.inDays,
            'hours': remainingTime.inHours.remainder(24),
            'minutes': remainingTime.inMinutes.remainder(60),
            'seconds': remainingTime.inSeconds.remainder(60),
            'isRunning': _timerRunning,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error saving timer state: $e");
    }
  }

  // Update the _handleLotteryDraw method to call reset
  void _handleLotteryDraw() {
    print("Lottery draw time! Implementing draw logic...");

    // Reset ticket purchase status for new draw
    _resetTicketPurchaseStatus();

    // You can add the actual draw logic here
    // Reset total tickets sold for new draw
    setState(() {
      totalTicketsSold = 0;
    });

    // Update Firestore with reset values
    _resetFirestoreForNewDraw();
  }

  // LotteryScreen.dart میں یہ function شامل کریں
  // LotteryScreen.dart میں یہ function شامل کریں - UPDATED: No minimum requirement
  void _processLotteryWithdrawal(double lotteryBalance) {
    // ✅ REMOVED: Minimum amount requirement
    // Allow withdrawal for any amount greater than 0

    if (lotteryBalance <= 0) {
      _showWithdrawalErrorDialog("No funds available for withdrawal.");
      return;
    }

    // Navigate to LotteryWithdrawalScreen regardless of amount
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LotteryWithdrawalScreen(claimAmount: lotteryBalance),
      ),
    );
  }

  void _showWithdrawalErrorDialog(String message) {
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
                  "Withdrawal Not Available",
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

  // Method to reset Firestore for new draw
  void _resetFirestoreForNewDraw() async {
    try {
      await FirebaseFirestore.instance
          .collection("wallets")
          .doc("lotteryWallet")
          .update({
            "tickets": {}, // Clear all tickets
            "balance": 0.0, // Reset balance if needed
          });

      print("🔥 Firestore reset for new lottery draw");
    } catch (e) {
      print("Error resetting Firestore: $e");
    }
  }

  void stopTimer() {
    countdownTimer?.cancel();
    _timerRunning = false;
    _saveTimerState();
  }

  @override
  void dispose() {
    _timerSubscription?.cancel(); // ✅ Listener ko dispose karein
    countdownTimer?.cancel();
    super.dispose();
  }

  String twoDigits(int n) => n.toString().padLeft(2, "0");

  void _showPurchaseDialog() {
    if (totalTicketsSold >= maxTickets) {
      _showTicketLimitReachedDialog();
      return;
    }

    // ✅ Check package status before showing purchase dialog
    _checkPackageStatusForTicketPurchase();
  }

  // Check if user has any active package before allowing ticket purchase
  Future<void> _checkPackageStatusForTicketPurchase() async {
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
        // User has active package, show purchase dialog
        _showPurchaseDialogAfterCheck();
      } else {
        // Show dialog if no active package
        _showNoPackageForTicketDialog();
      }
    } catch (e) {
      print('❌ Error checking package status for ticket: $e');
      _showErrorSnackBar("Error checking package status");
    }
  }

  // Show purchase dialog after package check
  void _showPurchaseDialogAfterCheck() {
    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(size.width * 0.05),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(size.width * 0.04),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0000FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        color: const Color(0xFF0000FF),
                        size: size.width * 0.07,
                      ),
                      SizedBox(width: size.width * 0.03),
                      Expanded(
                        child: Text(
                          "Purchase Lottery Ticket",
                          style: TextStyle(
                            fontSize: size.width * 0.05,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0000FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.03),

                // Ticket Details
                Container(
                  padding: EdgeInsets.all(size.width * 0.04),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDialogRow("Ticket Price:", "\$1.00", size),
                      SizedBox(height: size.height * 0.01),
                      _buildDialogRow("Quantity:", "1", size),
                      SizedBox(height: size.height * 0.01),
                      _buildDialogRow("Total Cost:", "\$1.00", size),
                      SizedBox(height: size.height * 0.01),
                      _buildDialogRow(
                        "Tickets Sold:",
                        "$totalTicketsSold/$maxTickets",
                        size,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.03),

                // Note
                Container(
                  padding: EdgeInsets.all(size.width * 0.03),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Colors.amber[700],
                        size: size.width * 0.05,
                      ),
                      SizedBox(width: size.width * 0.02),
                      Expanded(
                        child: Text(
                          "You can only purchase 1 ticket per draw",
                          style: TextStyle(
                            fontSize: size.width * 0.035,
                            color: Colors.amber[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.03),

                // Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          padding: EdgeInsets.symmetric(
                            vertical: size.height * 0.018,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: size.width * 0.03),

                    // Buy Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LotteryDepositScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0000FF),
                          padding: EdgeInsets.symmetric(
                            vertical: size.height * 0.018,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: Text(
                          "Buy Ticket",
                          style: TextStyle(
                            fontSize: size.width * 0.04,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show dialog when user doesn't have any active package for ticket purchase
  void _showNoPackageForTicketDialog() {
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
                "You need to purchase and activate a package first before buying lottery tickets.",
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
                  color: Color(0xFF0000FF),
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

  void _showTicketLimitReachedDialog() {
    final size = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(size.width * 0.05),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: size.width * 0.1,
                ),
                SizedBox(height: size.height * 0.02),
                Text(
                  "Ticket Limit Reached",
                  style: TextStyle(
                    fontSize: size.width * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: size.height * 0.02),
                Text(
                  "All $maxTickets tickets have been sold for this draw.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size.width * 0.04,
                    color: const Color(0xFF666666),
                  ),
                ),
                SizedBox(height: size.height * 0.03),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(
                        vertical: size.height * 0.018,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "OK",
                      style: TextStyle(
                        fontSize: size.width * 0.04,
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

  Widget _buildDialogRow(String label, String value, Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: size.width * 0.04,
            color: const Color(0xFF666666),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0000FF),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.04;
    final days = twoDigits(remainingTime.inDays);
    final hours = twoDigits(remainingTime.inHours.remainder(24));
    final minutes = twoDigits(remainingTime.inMinutes.remainder(60));
    final seconds = twoDigits(remainingTime.inSeconds.remainder(60));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Center(
          child: Text(
            'Lottery System',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Lottery Fund + My Rewards + My Tickets
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("wallets")
                  .doc("lotteryWallet")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                var balance = (data["balance"] ?? 0.0).toDouble();

                final userId =
                    FirebaseAuth.instance.currentUser?.uid ?? "guest";

                // 🔹 Tickets Map for current user
                var ticketsMap = data["tickets"] ?? {};
                var myTickets = ticketsMap[userId] ?? 0;

                // 🔹 Lottery Earnings for current user
                var earningsMap = data["earnings"] ?? {};
                var myEarnings = (earningsMap[userId] ?? 0.0).toDouble();
                var claimableEarnings = myEarnings > 0;

                // 🔹 Total Earnings
                var totalEarningsMap = data["totalEarnings"] ?? {};
                var myTotalEarnings = (totalEarningsMap[userId] ?? 0.0)
                    .toDouble();

                return Column(
                  children: [
                    // 🔹 Combined Lottery Fund, Rewards and Tickets Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(size.width * 0.05),
                      margin: EdgeInsets.only(bottom: size.height * 0.025),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0000FF),
                            const Color(0xFF4169E1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Lottery Fund
                          // 🔹 Lottery Fund - User's Personal Lottery Wallet from Signup_Data
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Signup_Data')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return _buildInfoRow(
                                  icon: Icons.account_balance_wallet,
                                  title: "Lottery Fund",
                                  value: "\$0.0",
                                  valueColor: Colors.white,
                                  size: size,
                                );
                              }

                              var data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              var lotteryBalance =
                                  (data["lotteryWallet"] ?? 0.0).toDouble();

                              return _buildInfoRow(
                                icon: Icons.account_balance_wallet,
                                title: "Lottery Fund",
                                value: "\$${lotteryBalance.toStringAsFixed(2)}",
                                valueColor: Colors.white,
                                size: size,
                              );
                            },
                          ),

                          Divider(
                            color: Colors.white.withOpacity(0.3),
                            height: size.height * 0.03,
                          ),

                          // 🔹 My Rewards
                          // 🔹 My Rewards - UPDATED to show same data as Lottery Fund
                          Container(
                            padding: EdgeInsets.all(size.width * 0.04),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('Signup_Data')
                                  .doc(FirebaseAuth.instance.currentUser?.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    !snapshot.data!.exists) {
                                  return Column(
                                    children: [
                                      // Main content row
                                      IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            // Left side - Icon and Text
                                            Expanded(
                                              flex: 3,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(
                                                      size.width * 0.025,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          const Color(
                                                            0xFFFFD700,
                                                          ),
                                                          const Color(
                                                            0xFFFFA000,
                                                          ),
                                                        ],
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.amber
                                                              .withOpacity(0.4),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      Icons.emoji_events,
                                                      color: Colors.white,
                                                      size: size.width * 0.055,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: size.width * 0.03,
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          "My Rewards",
                                                          style: TextStyle(
                                                            fontSize:
                                                                size.width *
                                                                0.04,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height:
                                                              size.height *
                                                              0.005,
                                                        ),
                                                        Text(
                                                          "Total: \$0.0",
                                                          style: TextStyle(
                                                            fontSize:
                                                                size.width *
                                                                0.032,
                                                            color: Colors.white
                                                                .withOpacity(
                                                                  0.8,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: size.width * 0.02),
                                            // Right side - Amount
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              size.width * 0.03,
                                                          vertical:
                                                              size.height *
                                                              0.006,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          const Color(
                                                            0xFFFFD700,
                                                          ),
                                                          const Color(
                                                            0xFFFFA000,
                                                          ),
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.amber
                                                              .withOpacity(0.3),
                                                          blurRadius: 6,
                                                          offset: const Offset(
                                                            0,
                                                            2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      "\$0.0",
                                                      style: TextStyle(
                                                        fontSize:
                                                            size.width * 0.038,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // No Rewards Available message
                                      Container(
                                        width: double.infinity,
                                        margin: EdgeInsets.only(
                                          top: size.height * 0.015,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: size.height * 0.015,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "No Rewards Available",
                                            style: TextStyle(
                                              fontSize: size.width * 0.035,
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                var data =
                                    snapshot.data!.data()
                                        as Map<String, dynamic>;
                                var lotteryBalance =
                                    (data["lotteryWallet"] ?? 0.0).toDouble();
                                var hasRewards = lotteryBalance > 0;

                                return Column(
                                  children: [
                                    // Main content row
                                    IntrinsicHeight(
                                      child: Row(
                                        children: [
                                          // Left side - Icon and Text
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(
                                                    size.width * 0.025,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        const Color(0xFFFFD700),
                                                        const Color(0xFFFFA000),
                                                      ],
                                                    ),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.amber
                                                            .withOpacity(0.4),
                                                        blurRadius: 8,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                    Icons.emoji_events,
                                                    color: Colors.white,
                                                    size: size.width * 0.055,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: size.width * 0.03,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        "My Rewards",
                                                        style: TextStyle(
                                                          fontSize:
                                                              size.width * 0.04,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height:
                                                            size.height * 0.005,
                                                      ),
                                                      Text(
                                                        "Total: \$${lotteryBalance.toStringAsFixed(2)}",
                                                        style: TextStyle(
                                                          fontSize:
                                                              size.width *
                                                              0.032,
                                                          color: Colors.white
                                                              .withOpacity(0.8),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: size.width * 0.02),
                                          // Right side - Amount
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal:
                                                        size.width * 0.03,
                                                    vertical:
                                                        size.height * 0.006,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        const Color(0xFFFFD700),
                                                        const Color(0xFFFFA000),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          15,
                                                        ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.amber
                                                            .withOpacity(0.3),
                                                        blurRadius: 6,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    "\$${lotteryBalance.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize:
                                                          size.width * 0.038,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Withdraw Button - Show only if user has rewards
                                    // موجودہ code میں یہ حصہ ڈھونڈیں:
                                    if (hasRewards)
                                      Container(
                                        width: double.infinity,
                                        margin: EdgeInsets.only(
                                          top: size.height * 0.015,
                                        ),
                                        height: size.height * 0.06,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFFA000),
                                              Color(0xFFFF8C00),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(
                                                0xFFFF8C00,
                                              ).withOpacity(0.4),
                                              spreadRadius: 2,
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            // ✅ YAHAN UPDATE KAREIN - Add withdrawal logic here
                                            _processLotteryWithdrawal(
                                              lotteryBalance,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.monetization_on,
                                                color: Colors.white,
                                                size: size.width * 0.05,
                                              ),
                                              SizedBox(
                                                width: size.width * 0.02,
                                              ),
                                              Text(
                                                "WITHDRAW",
                                                style: TextStyle(
                                                  fontSize: size.width * 0.04,
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
                                        margin: EdgeInsets.only(
                                          top: size.height * 0.015,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: size.height * 0.015,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "No Rewards Available",
                                            style: TextStyle(
                                              fontSize: size.width * 0.035,
                                              color: Colors.white.withOpacity(
                                                0.7,
                                              ),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),

                          Divider(
                            color: Colors.white.withOpacity(0.3),
                            height: size.height * 0.03,
                          ),

                          // My Tickets
                          _buildInfoRow(
                            icon: Icons.confirmation_number,
                            title: "My Tickets",
                            value: "$myTickets",
                            valueColor: const Color(0xFF0000FF),
                            size: size,
                            isTicket: true,
                          ),

                          // Show lottery number if user has a ticket
                          if (myTickets > 0 && userLotteryNumber != null)
                            Container(
                              margin: EdgeInsets.only(top: size.height * 0.02),
                              padding: EdgeInsets.all(size.width * 0.04),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.numbers,
                                        color: Colors.white,
                                        size: size.width * 0.06,
                                      ),
                                      SizedBox(width: size.width * 0.03),
                                      Text(
                                        "Your Lottery Number:",
                                        style: TextStyle(
                                          fontSize: size.width * 0.04,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: size.width * 0.04,
                                      vertical: size.height * 0.008,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      userLotteryNumber!,
                                      style: TextStyle(
                                        fontSize: size.width * 0.02,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0000FF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 🔹 Countdown Timer
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(size.width * 0.05),
                      margin: EdgeInsets.only(bottom: size.height * 0.025),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0000FF),
                            const Color(0xFF0000FF).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0000FF).withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Next Draw In:",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: size.width * 0.05,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: size.height * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _timeBox(days, "Days", size),
                              SizedBox(width: size.width * 0.02),
                              _timeBox(hours, "Hours", size),
                              SizedBox(width: size.width * 0.02),
                              _timeBox(minutes, "Minutes", size),
                              SizedBox(width: size.width * 0.02),
                              _timeBox(seconds, "Seconds", size),
                            ],
                          ),
                          SizedBox(height: size.height * 0.02),
                        ],
                      ),
                    ),

                    // 🔹 Purchase Ticket Section - Always show the container, but hide button if user has purchased
                    Container(
                      padding: EdgeInsets.all(size.width * 0.05),
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
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_cart,
                                color: const Color(0xFF0000FF),
                                size: size.width * 0.06,
                              ),
                              SizedBox(width: size.width * 0.02),
                              Text(
                                "Purchase Tickets",
                                style: TextStyle(
                                  fontSize: size.width * 0.05,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: size.height * 0.02),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Price per ticket:",
                                style: TextStyle(
                                  color: const Color(0xFF666666),
                                  fontSize: size.width * 0.04,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: size.width * 0.04,
                                  vertical: size.height * 0.005,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0000FF,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "\$1.00",
                                  style: TextStyle(
                                    fontSize: size.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0000FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: size.height * 0.02),

                          // Ticket Progress
                          Container(
                            padding: EdgeInsets.all(size.width * 0.03),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Tickets Sold:",
                                      style: TextStyle(
                                        fontSize: size.width * 0.045,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "$totalTicketsSold/$maxTickets",
                                      style: TextStyle(
                                        fontSize: size.width * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0000FF),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: size.height * 0.01),
                                LinearProgressIndicator(
                                  value: totalTicketsSold / maxTickets,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    totalTicketsSold >= maxTickets
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),

                          Container(
                            padding: EdgeInsets.all(size.width * 0.03),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total Cost:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: size.width * 0.045,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                Text(
                                  "\$1.00",
                                  style: TextStyle(
                                    fontSize: size.width * 0.045,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00C853),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),

                          // 🔹 Buy Ticket Button - Only show if user hasn't purchased and tickets are available
                          if (!hasPurchasedTicket &&
                              totalTicketsSold < maxTickets)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _showPurchaseDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0000FF),
                                  padding: EdgeInsets.symmetric(
                                    vertical: size.height * 0.02,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart,
                                      color: Colors.white,
                                      size: size.width * 0.05,
                                    ),
                                    SizedBox(width: size.width * 0.02),
                                    Text(
                                      "Purchase Ticket",
                                      style: TextStyle(
                                        fontSize: size.width * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (hasPurchasedTicket)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(size.width * 0.04),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: size.width * 0.06,
                                  ),
                                  SizedBox(height: size.height * 0.01),
                                  Text(
                                    "You have already purchased a ticket for this draw",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: size.width * 0.035,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  if (userLotteryNumber != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: size.height * 0.005,
                                      ),
                                      child: Text(
                                        "Your Lottery Number: $userLotteryNumber",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: size.width * 0.032,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else if (totalTicketsSold >= maxTickets)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(size.width * 0.04),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: size.width * 0.06,
                                  ),
                                  SizedBox(height: size.height * 0.01),
                                  Text(
                                    "All tickets have been sold!",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: size.width * 0.035,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Padding(
                            padding: EdgeInsets.only(top: size.height * 0.015),
                            child: Center(
                              child: Text(
                                "You can only purchase 1 ticket per draw",
                                style: TextStyle(
                                  fontSize: size.width * 0.035,
                                  color: Colors.green,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSettings() {
    final size = MediaQuery.of(context).size;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text("Days", style: TextStyle(fontSize: size.width * 0.04)),
                  SizedBox(height: 5),
                  Container(
                    height: 40,
                    child: TextFormField(
                      initialValue: remainingTime.inDays.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        int days = int.tryParse(value) ?? 0;
                        setState(() {
                          remainingTime = Duration(
                            days: days,
                            hours: remainingTime.inHours.remainder(24),
                            minutes: remainingTime.inMinutes.remainder(60),
                            seconds: remainingTime.inSeconds.remainder(60),
                          );
                        });
                        _saveTimerState();
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Text("Hours", style: TextStyle(fontSize: size.width * 0.04)),
                  SizedBox(height: 5),
                  Container(
                    height: 40,
                    child: TextFormField(
                      initialValue: remainingTime.inHours
                          .remainder(24)
                          .toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        int hours = int.tryParse(value) ?? 0;
                        setState(() {
                          remainingTime = Duration(
                            days: remainingTime.inDays,
                            hours: hours,
                            minutes: remainingTime.inMinutes.remainder(60),
                            seconds: remainingTime.inSeconds.remainder(60),
                          );
                        });
                        _saveTimerState();
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Text(
                    "Minutes",
                    style: TextStyle(fontSize: size.width * 0.04),
                  ),
                  SizedBox(height: 5),
                  Container(
                    height: 40,
                    child: TextFormField(
                      initialValue: remainingTime.inMinutes
                          .remainder(60)
                          .toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        int minutes = int.tryParse(value) ?? 0;
                        setState(() {
                          remainingTime = Duration(
                            days: remainingTime.inDays,
                            hours: remainingTime.inHours.remainder(24),
                            minutes: minutes,
                            seconds: remainingTime.inSeconds.remainder(60),
                          );
                        });
                        _saveTimerState();
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Text(
                    "Seconds",
                    style: TextStyle(fontSize: size.width * 0.04),
                  ),
                  SizedBox(height: 5),
                  Container(
                    height: 40,
                    child: TextFormField(
                      initialValue: remainingTime.inSeconds
                          .remainder(60)
                          .toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        int seconds = int.tryParse(value) ?? 0;
                        setState(() {
                          remainingTime = Duration(
                            days: remainingTime.inDays,
                            hours: remainingTime.inHours.remainder(24),
                            minutes: remainingTime.inMinutes.remainder(60),
                            seconds: seconds,
                          );
                        });
                        _saveTimerState();
                      },
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: startTimer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  "Start Timer",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: stopTimer,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(
                  "Stop Timer",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
    required Size size,
    bool isTicket = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(size.width * 0.03),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: size.width * 0.06),
            ),
            SizedBox(width: size.width * 0.03),
            Text(
              title,
              style: TextStyle(
                fontSize: size.width * 0.045,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.04,
            vertical: size.height * 0.005,
          ),
          decoration: BoxDecoration(
            color: isTicket ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isTicket
                ? null
                : Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: size.width * 0.045,
              fontWeight: FontWeight.bold,
              color: isTicket ? const Color(0xFF0000FF) : valueColor,
            ),
          ),
        ),
      ],
    );
  }

  // Enhanced function to claim earnings
  void _claimEarnings(
    String userId,
    double earnings,
    double totalEarnings,
  ) async {
    try {
      final lotteryWalletRef = FirebaseFirestore.instance
          .collection("wallets")
          .doc("lotteryWallet");

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(lotteryWalletRef);
        final data = snap.data() as Map<String, dynamic>;

        var earningsMap = Map<String, dynamic>.from(data["earnings"] ?? {});
        var totalEarningsMap = Map<String, dynamic>.from(
          data["totalEarnings"] ?? {},
        );
        var currentBalance = (data["balance"] ?? 0.0).toDouble();

        // Update total earnings
        totalEarningsMap[userId] = totalEarnings + earnings;

        // Reset user's current earnings to 0 and add to lottery wallet balance
        earningsMap[userId] = 0.0;
        currentBalance += earnings;

        tx.update(lotteryWalletRef, {
          "earnings": earningsMap,
          "totalEarnings": totalEarningsMap,
          "balance": currentBalance,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Successfully claimed \$${earnings.toStringAsFixed(2)}!",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text("Error claiming earnings: $e")),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _timeBox(String value, String label, Size size) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(size.width * 0.035),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: size.width * 0.05,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0000FF),
            ),
          ),
        ),
        SizedBox(height: size.height * 0.008),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size.width * 0.035,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
