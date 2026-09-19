import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uktalhybird/Deposit.dart';
import 'package:uktalhybird/Taskscree.dart';
import 'package:uktalhybird/Withdrawal/Passivess/passivewithdrawal.dart';

// Define colors for the bonus level section
const Color primaryBlue = Color(0xFF0000FF);
const Color accentGreen = Colors.green;
const Color textColor = Colors.black;
const Color lightText = Colors.grey;

class PackageScreen extends StatefulWidget {
  PackageScreen({super.key});

  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  // Package details with multipliers and tasks
  final List<Map<String, dynamic>> packages = [
    {
      "icon": Icons.school,
      "title": "Starter Package",
      "price": "\$5",
      "activationFee": "\$1",
      "progress": 0.0,
      "multiplier": "2X",
      "multiplierText": "2X (200%) Passive Reward",
      "dailyTasks": "15 tasks × 15 days = 225",
      "dailyTaskCount": 15,
      "baseTasks": 15, // ✅ NEW: Base tasks for this package
    },
    {
      "icon": Icons.trending_up,
      "title": "Basic Package",
      "price": "\$10",
      "activationFee": "\$1",
      "progress": 0.0,
      "multiplier": "2X",
      "multiplierText": "2X (200%) Passive Reward",
      "dailyTasks": "20 tasks × 15 days = 300", // ✅ Updated: 15+5=20
      "dailyTaskCount": 20,
      "baseTasks": 5, // ✅ NEW: Additional tasks for this package
    },
    {
      "icon": Icons.explore,
      "title": "Standard Package",
      "price": "\$25",
      "activationFee": "\$2",
      "progress": 0.0,
      "multiplier": "2X",
      "multiplierText": "2X (200%) Passive Reward",
      "dailyTasks": "25 tasks × 15 days = 375", // ✅ Updated: 20+5=25
      "dailyTaskCount": 25,
      "baseTasks": 5, // ✅ NEW: Additional tasks for this package
    },
    {
      "icon": Icons.star_half,
      "title": "Pro Package",
      "price": "\$50",
      "activationFee": "\$3",
      "progress": 0.0,
      "multiplier": "2X",
      "multiplierText": "2X (200%) Passive Reward",
      "dailyTasks": "30 tasks × 15 days = 450", // ✅ Updated: 25+5=30
      "dailyTaskCount": 30,
      "baseTasks": 5, // ✅ NEW: Additional tasks for this package
    },
    {
      "icon": Icons.workspace_premium,
      "title": "Elite Package",
      "price": "\$100",
      "activationFee": "\$5",
      "progress": 0.0,
      "multiplier": "3X",
      "multiplierText": "3X (300%) Passive Reward",
      "dailyTasks": "35 tasks × 15 days = 525", // ✅ Updated: 30+5=35
      "dailyTaskCount": 35,
      "baseTasks": 5, // ✅ NEW: Additional tasks for this package
    },
    {
      "icon": Icons.diamond,
      "title": "Premium Package",
      "price": "\$250",
      "activationFee": "\$15",
      "progress": 0.0,
      "multiplier": "3X",
      "multiplierText": "3X (300%) Passive Reward",
      "dailyTasks": "40 tasks × 15 days = 600", // ✅ Updated: 35+5=40
      "dailyTaskCount": 40,
      "baseTasks": 5, // ✅ NEW: Additional tasks for this package
    },
    {
      "icon": Icons.emoji_events,
      "title": "Ultimate Package",
      "price": "\$500",
      "activationFee": "\$25",
      "progress": 0.0,
      "multiplier": "3X",
      "multiplierText": "3X (300%) Passive Reward",
      "dailyTasks": "45 tasks × 15 days = 675", // ✅ Updated: 40+5=45
      "dailyTaskCount": 45,
      "baseTasks": 5, // ✅ NEW: Additional tasks for this package
    },
  ];

  // ✅ Function to withdraw passive rewards (with cancellation support)
  Future<void> _withdrawPassiveRewards(double amount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('💰 Withdrawing passive rewards: \$$amount');

      // ✅ Navigate to withdrawal screen and wait for result
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PassiveWithScreen(claimAmount: amount),
        ),
      );

      // ✅ Only reset if withdrawal was actually processed (not cancelled)
      if (result == true) {
        print('✅ Withdrawal processed successfully');
        // Yahan aap UI refresh kar saktay hain agar needed ho
        setState(() {});
      } else {
        print('❌ Withdrawal cancelled by user');
        // Kuch nahi karna - amount waisi hi rehne dena hai
      }
    } catch (e) {
      print('❌ Error in withdraw passive rewards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Withdrawal failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetPassiveRewards() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('🔄 Resetting passive rewards to 0');

      // ✅ Get all credited passive rewards documents
      final snapshot = await FirebaseFirestore.instance
          .collection('passive_rewards')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'credited')
          .get();

      if (snapshot.docs.isEmpty) {
        print('ℹ️ No passive rewards found to reset');
        return;
      }

      // ✅ Batch update to set status to 'withdrawn'
      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'withdrawn',
          'withdrawnAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      print(
        '✅ Passive rewards reset successfully - ${snapshot.docs.length} documents updated',
      );

      // ✅ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Passive rewards withdrawn successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error resetting passive rewards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error resetting rewards: $e"),
          backgroundColor: Colors.red,
        ),
      );
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupEmptyPackageTitles();
      _cleanupUnknownPackages();
    });
  }

  void _debugNavigateToPassiveWithdrawal(BuildContext context, double amount) {
    print("=== DEBUG NAVIGATION START ===");
    print("🎯 Claim button CLICKED");
    print("💰 Amount: $amount");
    print("📱 Context: $context");
    print("🚀 Attempting navigation...");

    try {
      // Test 1: Check if PassiveWithdrawalScreen can be instantiated
      print("🔧 Testing PassiveWithdrawalScreen instantiation...");
      final testScreen = PassiveWithScreen(claimAmount: amount);
      print("✅ Screen instantiation successful");

      // Test 2: Check if Navigator is available
      print("🧭 Checking Navigator state...");
      if (Navigator.canPop(context)) {
        print("✅ Navigator can pop");
      } else {
        print("ℹ️ Navigator cannot pop (might be root)");
      }

      // Test 3: Attempt navigation
      print("🔄 Starting navigation...");
      Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => testScreen),
          )
          .then((value) {
            print("🔄 Navigation completed, returned: $value");
          })
          .catchError((error) {
            print("❌ Navigation error: $error");
          });

      print("📋 Navigation command sent");
    } catch (e) {
      print("❌ CRITICAL ERROR: $e");
      print("📋 Stack trace: ${e.toString()}");

      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Navigation error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }

    print("=== DEBUG NAVIGATION END ===");
  }

  void _cleanupEmptyPackageTitles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('purchasedPackages')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final title = data['packageTitle']?.toString().trim() ?? '';
        if (title.isEmpty) {
          print('🗑️ Deleting document with empty title: ${doc.id}');
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
      print('✅ Cleanup completed');
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  }

  void _cleanupUnknownPackages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('purchasedPackages')
          .where('packageTitle', isEqualTo: 'Unknown Package')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        print('🗑️ Deleting Unknown Package document: ${doc.id}');
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ Unknown Package cleanup completed');
    } catch (e) {
      print('❌ Unknown Package cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Stack Section (Blue Box + White Overlay)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Blue Box
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0000FF),
                        borderRadius: BorderRadius.circular(w * 0.05),
                      ),
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Signup_Data')
                            .doc(currentUserId)
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Row(
                              children: [
                                // Loading state for profile picture
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    bottom: 60,
                                  ),
                                  child: CircleAvatar(
                                    radius: w * 0.08,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      "?",
                                      style: TextStyle(
                                        fontSize: w * 0.06,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0000FF),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: w * 0.04),
                                // Loading state for name & email
                                Padding(
                                  padding: const EdgeInsets.only(top: 23),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Loading...",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: w * 0.05,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Loading...",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: w * 0.035,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          if (userSnapshot.hasError) {
                            return Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    bottom: 60,
                                  ),
                                  child: CircleAvatar(
                                    radius: w * 0.08,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      "!",
                                      style: TextStyle(
                                        fontSize: w * 0.06,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: w * 0.04),
                                Padding(
                                  padding: const EdgeInsets.only(top: 23),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Error",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: w * 0.05,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Failed to load",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: w * 0.035,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          final userData =
                              userSnapshot.data!.data()
                                  as Map<String, dynamic>?;

                          final userName = userData?['name'] ?? 'User';
                          final userEmail = userData?['email'] ?? 'No email';

                          // Get first letter of name for circle avatar
                          final firstLetter = userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U';

                          return Row(
                            children: [
                              // Profile Picture with first letter
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  bottom: 60,
                                ),
                                child: CircleAvatar(
                                  radius: w * 0.08,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    firstLetter,
                                    style: TextStyle(
                                      fontSize: w * 0.06,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0000FF),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: w * 0.04),
                              // Name & Email
                              Padding(
                                padding: const EdgeInsets.only(top: 23),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: w * 0.05,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: w * 0.035,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // White Box Overlay
                    // 🔹 White Box Overlay - ONLY passive_rewards collection
                    Positioned(
                      bottom: -h * 0.095,
                      left: w * 0.06,
                      right: w * 0.06,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(w * 0.03),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(w * 0.03),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Passive Reward",
                              style: TextStyle(
                                color: Color(0xFF0000FF),
                                fontSize: w * 0.04,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: h * 0.004),

                            // ✅ ONLY passive_rewards collection - No Signup_Data
                            // ✅ ONLY passive_rewards collection - No Signup_Data
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('passive_rewards')
                                  .where(
                                    'userId',
                                    isEqualTo:
                                        FirebaseAuth.instance.currentUser?.uid,
                                  )
                                  .where('status', isEqualTo: 'credited')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                double totalPassiveRewards = 0.0;

                                if (snapshot.hasData) {
                                  for (var doc in snapshot.data!.docs) {
                                    var data =
                                        doc.data() as Map<String, dynamic>;
                                    totalPassiveRewards +=
                                        (data['rewardAmount'] ?? 0.0)
                                            .toDouble();
                                  }
                                }

                                return Row(
                                  children: [
                                    Text(
                                      "\$${totalPassiveRewards.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: w * 0.049,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(width: 70),
                                    SizedBox(
                                      height: h * 0.04,
                                      child: ElevatedButton(
                                        onPressed: totalPassiveRewards > 0
                                            ? () {
                                                _withdrawPassiveRewards(
                                                  totalPassiveRewards,
                                                );
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              totalPassiveRewards > 0
                                              ? const Color.fromARGB(
                                                  255,
                                                  45,
                                                  0,
                                                  207,
                                                )
                                              : Colors.grey,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: w * 0.03,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: Text(
                                          "Withdraw",
                                          style: TextStyle(
                                            fontSize: w * 0.028,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(vertical: h * 0.01),
                              height: 1,
                              color: Colors.black,
                            ),

                            // 🔹 Claim Income Section - ONLY passive_rewards
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        "Deposit Balance",
                                        style: TextStyle(
                                          color: Color(0xFF0000FF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: w * 0.032,
                                        ),
                                      ),
                                      SizedBox(height: h * 0.004),

                                      // ✅ CORRECT: Calculate ONLY from active packages (ignore wallet amount)
                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(currentUserId)
                                            .collection('purchasedPackages')
                                            .snapshots(),
                                        builder: (context, packageSnapshot) {
                                          if (packageSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Text(
                                              "Loading...",
                                              style: TextStyle(
                                                fontSize: w * 0.04,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          }

                                          // ✅ Fixed package prices
                                          final Map<String, double>
                                          correctPackagePrices = {
                                            "Starter Package": 5.0,
                                            "Basic Package": 10.0,
                                            "Standard Package": 25.0,
                                            "Pro Package": 50.0,
                                            "Elite Package": 100.0,
                                            "Premium Package": 250.0,
                                            "Ultimate Package": 500.0,
                                          };

                                          // Track active packages (use Set to avoid duplicates)
                                          Set<String> activePackageTitles = {};

                                          if (packageSnapshot.hasData) {
                                            print(
                                              '🔍 Checking packages for deposit balance...',
                                            );

                                            for (var doc
                                                in packageSnapshot.data!.docs) {
                                              final data =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              final packageTitle =
                                                  data['packageTitle']
                                                      ?.toString()
                                                      .trim() ??
                                                  '';
                                              final status =
                                                  data['status'] ?? '';
                                              final isActive =
                                                  data['isActive'] ?? false;
                                              final activatedBy =
                                                  data['activatedBy'] ?? '';

                                              print(
                                                '   📦 Package: $packageTitle',
                                              );
                                              print(
                                                '      Status: $status, isActive: $isActive, activatedBy: $activatedBy',
                                              );

                                              // Check if package is active
                                              bool isActiveByAdmin =
                                                  activatedBy == 'admin' &&
                                                  status == 'finished';
                                              bool isActiveByPurchase =
                                                  status == 'finished' &&
                                                  isActive == true;

                                              if ((isActiveByAdmin ||
                                                      isActiveByPurchase) &&
                                                  packageTitle.isNotEmpty) {
                                                activePackageTitles.add(
                                                  packageTitle,
                                                );
                                                print(
                                                  '      ✅ Marked as ACTIVE',
                                                );
                                              } else {
                                                print(
                                                  '      ❌ NOT active (skipping)',
                                                );
                                              }
                                            }
                                          }

                                          // Also check Signup_Data collection
                                          return StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('Signup_Data')
                                                .doc(currentUserId)
                                                .collection('purchasedPackages')
                                                .snapshots(),
                                            builder: (context, signupSnapshot) {
                                              if (signupSnapshot.hasData) {
                                                for (var doc
                                                    in signupSnapshot
                                                        .data!
                                                        .docs) {
                                                  final data =
                                                      doc.data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  final packageTitle =
                                                      data['packageTitle']
                                                          ?.toString()
                                                          .trim() ??
                                                      '';
                                                  final status =
                                                      data['status'] ?? '';
                                                  final isActive =
                                                      data['isActive'] ?? false;
                                                  final activatedBy =
                                                      data['activatedBy'] ?? '';

                                                  // Check if package is active
                                                  bool isActiveByAdmin =
                                                      activatedBy == 'admin' &&
                                                      status == 'finished';
                                                  bool isActiveByPurchase =
                                                      status == 'finished' &&
                                                      isActive == true;

                                                  if ((isActiveByAdmin ||
                                                          isActiveByPurchase) &&
                                                      packageTitle.isNotEmpty) {
                                                    activePackageTitles.add(
                                                      packageTitle,
                                                    );
                                                  }
                                                }
                                              }

                                              // ✅ Calculate cumulative deposit ONLY from packages
                                              double cumulativeDeposit = 0.0;

                                              print(
                                                '📊 Active packages found: ${activePackageTitles.length}',
                                              );
                                              print(
                                                '📦 Active packages: ${activePackageTitles.toList()}',
                                              );

                                              for (var packageTitle
                                                  in activePackageTitles) {
                                                final double packagePrice =
                                                    correctPackagePrices[packageTitle] ??
                                                    0.0;
                                                cumulativeDeposit +=
                                                    packagePrice;

                                                print(
                                                  '   ➕ Adding $packageTitle: \$$packagePrice',
                                                );
                                              }

                                              print(
                                                '💰 TOTAL DEPOSIT BALANCE: \$${cumulativeDeposit.toStringAsFixed(2)}',
                                              );

                                              return Text(
                                                "\$${cumulativeDeposit.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontSize: w * 0.04,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: h * 0.05,
                                  color: Colors.black,
                                ),

                                // ✅ ONLY passive_rewards collection for Claim Income
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        "Claim Income",
                                        style: TextStyle(
                                          color: Color(0xFF0000FF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: w * 0.032,
                                        ),
                                      ),
                                      SizedBox(height: h * 0.004),

                                      StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('passive_rewards')
                                            .where(
                                              'userId',
                                              isEqualTo: FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid,
                                            )
                                            .where(
                                              'status',
                                              isEqualTo: 'credited',
                                            )
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          double totalPassiveRewards = 0.0;

                                          if (snapshot.hasData) {
                                            for (var doc
                                                in snapshot.data!.docs) {
                                              var data =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              totalPassiveRewards +=
                                                  (data['rewardAmount'] ?? 0.0)
                                                      .toDouble();
                                            }
                                          }

                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "\$${totalPassiveRewards.toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontSize: w * 0.04,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: h * 0.10),
              // ✅ Transparent Add Box Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.07),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0000FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: h * 0.014),
                      backgroundColor: Colors.transparent,
                    ),
                    child: Text(
                      "Add Box",
                      style: TextStyle(
                        fontSize: w * 0.04,
                        color: const Color(0xFF0000FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: h * 0.01),
              // 🔹 Four Info Boxes - FIXED DESIGN
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: w * 0.025,
                  mainAxisSpacing: h * 0.015,
                  childAspectRatio: 1.4, // Adjusted aspect ratio
                  children: [
                    _buildMyTotalTasksBox(w, h),
                    // ✅ ONLY passive_rewards collection for Info Box
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('passive_rewards')
                          .where(
                            'userId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                          )
                          .where('status', isEqualTo: 'credited')
                          .snapshots(),
                      builder: (context, snapshot) {
                        double totalPassiveRewards = 0.0;

                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            var data = doc.data() as Map<String, dynamic>;
                            totalPassiveRewards += (data['rewardAmount'] ?? 0.0)
                                .toDouble();
                          }
                        }

                        return _buildInfoBox(
                          "Passive Pool Income",
                          "\$${totalPassiveRewards.toStringAsFixed(2)}", // ✅ Only from passive_rewards
                          w,
                          Icons.attach_money,
                          Colors.orange,
                        );
                      },
                    ),
                    // StreamBuilder<DocumentSnapshot>(
                    //   stream: FirebaseFirestore.instance
                    //       .collection('Signup_Data')
                    //       .doc(FirebaseAuth.instance.currentUser?.uid)
                    //       .snapshots(),
                    //   builder: (context, snapshot) {
                    //     if (!snapshot.hasData || !snapshot.data!.exists) {
                    //       return _buildInfoBox(
                    //         "Activation Fee Income",
                    //         "\$0.0",
                    //         w,
                    //         Icons.account_balance_wallet,
                    //         Colors.green,
                    //       );
                    //     }

                    //     var data =
                    //         snapshot.data!.data() as Map<String, dynamic>;
                    //     var activationWallet =
                    //         (data["activationWalletBalance"] ?? 0.0).toDouble();

                    //     return _buildInfoBox(
                    //       "Activation Fee Income",
                    //       "\$${activationWallet.toStringAsFixed(2)}",
                    //       w,
                    //       Icons.account_balance_wallet,
                    //       Colors.green,
                    //     );
                    //   },
                    // ),
                    // // 🔹 Withdrawal Fee Income Box - Only from withdrawalWalletBalance
                    // StreamBuilder<DocumentSnapshot>(
                    //   stream: FirebaseFirestore.instance
                    //       .collection('Signup_Data')
                    //       .doc(FirebaseAuth.instance.currentUser?.uid)
                    //       .snapshots(),
                    //   builder: (context, snapshot) {
                    //     double withdrawalWallet = 0.0;

                    //     if (snapshot.connectionState ==
                    //         ConnectionState.waiting) {
                    //       return _buildInfoBox(
                    //         "Withdraw Fee Income",
                    //         "Loading...",
                    //         w,
                    //         Icons.trending_up,
                    //         Colors.blue,
                    //       );
                    //     }

                    //     if (snapshot.hasError) {
                    //       return _buildInfoBox(
                    //         "Withdraw Fee Income",
                    //         "Error",
                    //         w,
                    //         Icons.trending_up,
                    //         Colors.blue,
                    //       );
                    //     }

                    //     if (snapshot.hasData && snapshot.data!.exists) {
                    //       var userData =
                    //           snapshot.data!.data() as Map<String, dynamic>;
                    //       withdrawalWallet =
                    //           (userData["withdrawalWalletBalance"] ?? 0.0)
                    //               .toDouble();
                    //     }

                    //     return _buildInfoBox(
                    //       "Withdraw Fee Income",
                    //       "\$${withdrawalWallet.toStringAsFixed(2)}",
                    //       w,
                    //       Icons.trending_up,
                    //       Colors.blue,
                    //     );
                    //   },
                    // ),
                  ],
                ),
              ),
              SizedBox(height: h * 0.02),
              // 🔹 Packages List with purchased packages check
              // 🔹 Packages List with purchased packages check - REPLACE THIS WHOLE SECTION
              Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .collection('purchasedPackages')
                      .snapshots(),
                  builder: (context, purchasedSnapshot) {
                    if (purchasedSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (purchasedSnapshot.hasError) {
                      return Center(
                        child: Text('Error: ${purchasedSnapshot.error}'),
                      );
                    }

                    List<String> purchasedPackageTitles = [];
                    if (purchasedSnapshot.hasData) {
                      purchasedPackageTitles = purchasedSnapshot.data!.docs
                          .where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final status = data['status'] ?? '';
                            final isActive = data['isActive'] ?? false;
                            // new add ke
                            final activatedBy =
                                data['activatedBy'] ?? ''; // ✅ نیا فیلڈ

                            final title =
                                data['packageTitle']?.toString().trim() ?? '';
                            // new add ke hai
                            bool isActiveByAdmin =
                                activatedBy == 'admin' && status == 'finished';
                            bool isActiveByPurchase =
                                status == 'finished' && isActive == true;

                            //   final isValidPackage =
                            //       status == 'finished' &&
                            //       isActive == true &&
                            //       title.isNotEmpty;
                            //   return isValidPackage;
                            // })
                            // .map(
                            //   (doc) =>
                            //       (doc['packageTitle']?.toString().trim() ?? ''),
                            // )
                            // .where((title) => title.isNotEmpty)
                            // .toList();
                            final isValidPackage =
                                (isActiveByAdmin || isActiveByPurchase) &&
                                title.isNotEmpty;

                            return isValidPackage;
                          })
                          .map(
                            (doc) =>
                                (doc['packageTitle']?.toString().trim() ?? ''),
                          )
                          .where((title) => title.isNotEmpty)
                          .toList();
                    }

                    // 🔹 NEW: Smart Package Unlocking Logic
                    List<Map<String, dynamic>> visiblePackages = [];
                    int lastPurchasedIndex = -1;

                    // Find the last purchased package index
                    for (int i = 0; i < packages.length; i++) {
                      final packageTitle =
                          packages[i]["title"]?.toString().trim() ?? '';
                      if (purchasedPackageTitles.contains(packageTitle)) {
                        lastPurchasedIndex = i;
                      }
                    }

                    // Show packages up to next one after last purchased
                    for (int i = 0; i < packages.length; i++) {
                      if (i <= lastPurchasedIndex + 1) {
                        // Show package as unlocked
                        visiblePackages.add(packages[i]);
                      } else {
                        // Show package as locked
                        visiblePackages.add({...packages[i], "isLocked": true});
                      }
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visiblePackages.length,
                      itemBuilder: (context, index) {
                        final package = visiblePackages[index];
                        final packageTitle =
                            package["title"]?.toString().trim() ?? '';
                        final isLocked = package["isLocked"] == true;
                        final isPurchased = purchasedPackageTitles.contains(
                          packageTitle,
                        );

                        if (isLocked) {
                          return _buildLockedPackageCard(
                            context,
                            package: package,
                            w: w,
                            h: h,
                          );
                        }

                        return _buildPackageCard(
                          context,
                          package: package,
                          isActive: isPurchased,
                          progress: isPurchased
                              ? 0.0
                              : (package["progress"] ?? 0.0),
                          w: w,
                          h: h,
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: h * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 NEW: Locked Package Card with transparent design
  Widget _buildLockedPackageCard(
    BuildContext context, {
    required Map<String, dynamic> package,
    required double w,
    required double h,
  }) {
    final String title = package["title"];
    final String price = package["price"];
    final IconData image = package["icon"];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: w * 0.04),
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: Colors.grey[100]!.withOpacity(0.5), // Transparent grey
        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // 🔹 Main Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: w * 0.045,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: w * 0.02),

              Row(
                children: [
                  // Lock Icon instead of package icon
                  CircleAvatar(
                    radius: w * 0.05,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    child: Icon(
                      Icons.lock, // Lock icon
                      size: w * 0.05,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Price: $price",
                          style: TextStyle(
                            fontSize: w * 0.035,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          "Complete previous package to unlock",
                          style: TextStyle(
                            fontSize: w * 0.028,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: w * 0.03),

              // 🔹 Locked Message
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(w * 0.03),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: w * 0.04, color: Colors.grey[600]),
                    SizedBox(width: w * 0.02),
                    Text(
                      "Locked - Buy previous package first",
                      style: TextStyle(
                        fontSize: w * 0.03,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 🔹 Locked Tag at Top Right
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Text(
                "Locked",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.03,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 FIXED: My Total Tasks Box with proper cumulative calculation
  Widget _buildMyTotalTasksBox(double w, double h) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaskScreen()),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('purchasedPackages')
            .snapshots(),
        builder: (context, packageSnapshot) {
          if (packageSnapshot.connectionState == ConnectionState.waiting) {
            return _buildInfoBoxContent(
              "My Total Tasks",
              "Loading...",
              w,
              Icons.task_alt,
              Colors.purple,
            );
          }

          int totalDailyTasksFromAllPackages =
              15; // Start with minimum 15 tasks

          if (packageSnapshot.hasData) {
            // Get all purchased packages
            List<String> purchasedPackageTitles = [];
            for (var doc in packageSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? '';
              final isActive = data['isActive'] ?? false;
              final packageTitle =
                  data['packageTitle']?.toString().trim() ?? '';
              final activatedBy = data['activatedBy'] ?? '';

              bool isActiveByAdmin =
                  activatedBy == 'admin' && status == 'finished';
              bool isActiveByPurchase =
                  status == 'finished' && isActive == true;

              if ((isActiveByAdmin || isActiveByPurchase) &&
                  packageTitle.isNotEmpty) {
                purchasedPackageTitles.add(packageTitle);
              }
            }

            // Calculate total daily tasks from ALL purchased packages (cumulative)
            if (purchasedPackageTitles.isNotEmpty) {
              totalDailyTasksFromAllPackages = 0;

              // For each package in order, add its tasks
              for (int i = 0; i < packages.length; i++) {
                final packageTitle =
                    packages[i]["title"]?.toString().trim() ?? '';

                if (purchasedPackageTitles.contains(packageTitle)) {
                  if (i == 0) {
                    // First package: 15 tasks
                    totalDailyTasksFromAllPackages += 15;
                  } else {
                    // Subsequent packages: add 5 tasks each
                    totalDailyTasksFromAllPackages += 5;
                  }
                }
              }
            }
          }

          // Calculate total tasks for 15 days
          int totalTasksFor15Days = totalDailyTasksFromAllPackages * 15;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('dailyTasks')
                .snapshots(),
            builder: (context, allTasksSnapshot) {
              int totalCompletedAllTime = 0;

              if (allTasksSnapshot.hasData) {
                totalCompletedAllTime = allTasksSnapshot.data!.docs
                    .where((doc) => doc['isCompleted'] == true)
                    .length;
              }

              // Show cumulative progress for 15 days
              String displayText =
                  "$totalCompletedAllTime/$totalTasksFor15Days";

              return _buildInfoBoxContent(
                "My Total Tasks",
                displayText,
                w,
                Icons.task_alt,
                Colors.purple,
              );
            },
          );
        },
      ),
    );
  }

  // PackageScreen میں یہ function بھی شامل کریں
  String _getTodayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Widget _buildInfoBox(
    String title,
    String value,
    double w,
    IconData icon,
    Color color,
  ) {
    // if (title == "Activation Fee Income") {
    //   return StreamBuilder<DocumentSnapshot>(
    //     stream: FirebaseFirestore.instance
    //         .collection('activationFees')
    //         .doc(FirebaseAuth.instance.currentUser!.uid)
    //         .snapshots(),
    //     builder: (context, snapshot) {
    //       String displayValue = "\$0";

    //       if (snapshot.connectionState == ConnectionState.waiting) {
    //         displayValue = "Loading...";
    //       } else if (snapshot.hasError) {
    //         displayValue = "Error";
    //       } else if (snapshot.hasData && snapshot.data!.exists) {
    //         final data = snapshot.data!.data() as Map<String, dynamic>;
    //         final totalFees = (data['totalActivationFees'] ?? 0).toDouble();
    //         displayValue = "\$${totalFees.toStringAsFixed(2)}";
    //       }

    //       return _buildInfoBoxContent(title, displayValue, w, icon, color);
    //     },
    //   );
    // }

    return _buildInfoBoxContent(title, value, w, icon, color);
  }

  void _debugWithdrawButton(double amount) {
    print("=== 🚨 WITHDRAW BUTTON DEBUG START ===");
    print("💰 Amount: $amount");
    print("📱 Context available: ${context != null}");
    print("🧭 Navigator state: ${Navigator.of(context).toString()}");

    try {
      // Test 1: Check if PassiveWithScreen exists and can be created
      print("🔧 Testing PassiveWithScreen...");

      // اگر آپ کا اصل کلاس نام PassiveWithScreen ہے
      final testScreen = PassiveWithScreen(claimAmount: amount);
      print("✅ PassiveWithScreen instantiation successful");

      // Test 2: Check navigation
      print("🔄 Attempting navigation...");

      Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => testScreen),
          )
          .then((value) {
            print("✅ Navigation completed successfully");
          })
          .catchError((error) {
            print("❌ Navigation error: $error");
            _showErrorDialog(context, "Navigation Error: $error");
          });
    } catch (e) {
      print("❌ CRITICAL ERROR: $e");
      print("📋 Stack trace: ${e.toString()}");

      _showErrorDialog(context, "Failed to open withdrawal: $e");
    }

    print("=== 🚨 WITHDRAW BUTTON DEBUG END ===");
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  // FIXED: Beautiful Info Box Design with proper constraints
  Widget _buildInfoBoxContent(
    String title,
    String value,
    double w,
    IconData icon,
    Color color,
  ) {
    return Container(
      constraints: BoxConstraints(minHeight: 0),
      decoration: BoxDecoration(
        color: Colors.white, // White background
        border: Border.all(
          color: primaryBlue, // Primary blue border
          width: 2, // Border width
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      padding: EdgeInsets.all(w * 0.03),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(w * 0.02),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(
                0.2,
              ), // Primary blue background with opacity
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: w * 0.045,
              color: primaryBlue,
            ), // Primary blue icon
          ),
          SizedBox(height: w * 0.02),
          Text(
            title,
            style: TextStyle(
              fontSize: w * 0.03,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: w * 0.008),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: w * 0.035,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: w * 0.01),
          Container(
            height: 2,
            width: w * 0.08,
            decoration: BoxDecoration(
              color: color.withOpacity(0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    BuildContext context, {
    required Map<String, dynamic> package,
    required bool isActive,
    required double progress,
    required double w,
    required double h,
  }) {
    final String title = package["title"];
    final String price = package["price"];
    final String activationFee = package["activationFee"];
    final String multiplier = package["multiplier"];
    final String multiplierText = package["multiplierText"];
    final String dailyTasks = package["dailyTasks"];
    final IconData image = package["icon"];
    final int dailyTaskCount = package["dailyTaskCount"] ?? 15;
    final int totalDays = 15;
    double priceValue = double.parse(price.replaceAll('\$', '').trim());
    double activationFeeValue = double.parse(
      activationFee.replaceAll('\$', '').trim(),
    );
    double totalAmount = priceValue + activationFeeValue;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('purchasedPackages')
          .where('status', isEqualTo: 'finished')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, activePackagesSnapshot) {
        // ✅ FIX: Get purchased packages inside this builder
        List<String> purchasedPackageTitles = [];
        if (activePackagesSnapshot.hasData) {
          purchasedPackageTitles = activePackagesSnapshot.data!.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? '';
                final isActive = data['isActive'] ?? false;
                final title = data['packageTitle']?.toString().trim() ?? '';
                return status == 'finished' &&
                    isActive == true &&
                    title.isNotEmpty;
              })
              .map((doc) => (doc['packageTitle']?.toString().trim() ?? ''))
              .where((title) => title.isNotEmpty)
              .toList();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: isActive
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('dailyTasks')
                    .snapshots()
              : null,
          builder: (context, taskSnapshot) {
            double calculatedProgress = 0.0;
            int completedTasksForThisPackage = 0;
            int totalTasksForPackage = dailyTaskCount * totalDays;
            bool isPackageCompleted = false;

            // ✅ FIXED: Progress calculation with purchasedPackageTitles now available
            if (isActive &&
                taskSnapshot.hasData &&
                activePackagesSnapshot.hasData) {
              // Calculate total daily tasks from ALL purchased packages (cumulative)
              int totalDailyTasksFromAllPackages = 0;
              int highestPurchasedIndex = -1;

              // Find highest purchased package index
              for (int i = 0; i < packages.length; i++) {
                final pkgTitle = packages[i]["title"]?.toString().trim() ?? '';
                if (purchasedPackageTitles.contains(pkgTitle)) {
                  highestPurchasedIndex = i;
                }
              }

              // Calculate cumulative tasks up to highest purchased package
              for (int i = 0; i <= highestPurchasedIndex; i++) {
                if (i < packages.length) {
                  if (i == 0) {
                    totalDailyTasksFromAllPackages +=
                        (packages[i]["baseTasks"] ?? 15) as int;
                  } else {
                    totalDailyTasksFromAllPackages +=
                        (packages[i]["baseTasks"] ?? 5) as int;
                  }
                }
              }

              // Calculate total completed tasks
              int totalCompletedTasks = taskSnapshot.data!.docs
                  .where((doc) => doc['isCompleted'] == true)
                  .length;

              // ✅ FIX: Use 'title' variable instead of 'packageTitle'
              // Calculate this package's total tasks (cumulative up to this package)
              int thisPackageCumulativeTasks = 0;
              int thisPackageIndex = packages.indexWhere(
                (p) => p["title"]?.toString().trim() == title,
              ); // ✅ FIX: Changed packageTitle to title

              if (thisPackageIndex != -1) {
                for (int i = 0; i <= thisPackageIndex; i++) {
                  if (i < packages.length) {
                    if (i == 0) {
                      thisPackageCumulativeTasks +=
                          (packages[i]["baseTasks"] ?? 15) as int;
                    } else {
                      thisPackageCumulativeTasks +=
                          (packages[i]["baseTasks"] ?? 5) as int;
                    }
                  }
                }
              }

              totalTasksForPackage = thisPackageCumulativeTasks * totalDays;

              // Calculate completed tasks for this package proportionally
              if (totalDailyTasksFromAllPackages > 0) {
                completedTasksForThisPackage =
                    (totalCompletedTasks * thisPackageCumulativeTasks) ~/
                    totalDailyTasksFromAllPackages;
              }

              // Ensure we don't exceed the total tasks for this package
              completedTasksForThisPackage = completedTasksForThisPackage.clamp(
                0,
                totalTasksForPackage,
              );

              // Calculate progress percentage
              calculatedProgress = totalTasksForPackage > 0
                  ? (completedTasksForThisPackage / totalTasksForPackage).clamp(
                      0.0,
                      1.0,
                    )
                  : 0.0;

              // Check if package is completed
              isPackageCompleted = calculatedProgress >= 1.0;
            }

            // If package is completed, show Buy Now button again
            final bool showBuyNowButton = !isActive || isPackageCompleted;
            final bool showProgressInfo = isActive && !isPackageCompleted;

            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: w * 0.04),
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isActive && !isPackageCompleted
                      ? [Colors.green[100]!, Colors.green[200]!]
                      : isPackageCompleted
                      ? [Colors.blue[100]!, Colors.blue[200]!]
                      : [Colors.grey[300]!, Colors.grey[400]!],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 🔹 Main Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: w * 0.045,
                                fontWeight: FontWeight.bold,
                                color: isPackageCompleted
                                    ? Colors.blue[800]
                                    : isActive
                                    ? Colors.green[800]
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: w * 0.02),

                      Row(
                        children: [
                          CircleAvatar(
                            radius: w * 0.05,
                            backgroundColor: isPackageCompleted
                                ? Colors.blue.withOpacity(0.2)
                                : isActive
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey[200],
                            child: Icon(
                              image,
                              size: w * 0.05,
                              color: isPackageCompleted
                                  ? Colors.blue[800]
                                  : isActive
                                  ? Colors.green[800]
                                  : Colors.black,
                            ),
                          ),
                          SizedBox(width: w * 0.03),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Price: $price",
                                  style: TextStyle(
                                    fontSize: w * 0.035,
                                    fontWeight: FontWeight.bold,
                                    color: isPackageCompleted
                                        ? Colors.blue[800]
                                        : isActive
                                        ? Colors.green[800]
                                        : Colors.black,
                                  ),
                                ),
                                Text(
                                  "Activation Fee: $activationFee",
                                  style: TextStyle(
                                    fontSize: w * 0.03,
                                    color: isPackageCompleted
                                        ? Colors.blue[800]
                                        : isActive
                                        ? Colors.green[800]
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: w * 0.03),

                      // 🔹 Progress Bar (only show for active but not completed packages)
                      // 🔹 Progress calculation میں یہ تبدیلی کریں
                      if (showProgressInfo) ...[
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('dailyTasks')
                              .snapshots(),
                          builder: (context, allTasksSnapshot) {
                            int totalCompletedAllTime = 0;

                            if (allTasksSnapshot.hasData) {
                              totalCompletedAllTime = allTasksSnapshot
                                  .data!
                                  .docs
                                  .where((doc) => doc['isCompleted'] == true)
                                  .length;
                            }

                            // Calculate this package's total tasks
                            int thisPackageTotalTasks = dailyTaskCount * 15;

                            // Use total completed tasks instead of proportional calculation
                            int completedForThisPackage = totalCompletedAllTime
                                .clamp(0, thisPackageTotalTasks);

                            double actualProgress = thisPackageTotalTasks > 0
                                ? (completedForThisPackage /
                                          thisPackageTotalTasks)
                                      .clamp(0.0, 1.0)
                                : 0.0;

                            return Column(
                              children: [
                                LinearProgressIndicator(
                                  value: actualProgress,
                                  backgroundColor: Colors.grey[300],
                                  color: Color(0xFF0000FF),
                                  minHeight: h * 0.012,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                SizedBox(height: w * 0.015),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${(actualProgress * 100).toStringAsFixed(1)}% Completed",
                                      style: TextStyle(
                                        fontSize: w * 0.03,
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      "${(100 - (actualProgress * 100)).toStringAsFixed(1)}% Remaining",
                                      style: TextStyle(
                                        fontSize: w * 0.03,
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: w * 0.01),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Completed: $completedForThisPackage/$thisPackageTotalTasks tasks",
                                      style: TextStyle(
                                        fontSize: w * 0.028,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    Text(
                                      "Daily: $dailyTaskCount tasks",
                                      style: TextStyle(
                                        fontSize: w * 0.028,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: w * 0.02),
                      ],
                      // 🔹 Completion Message (when package is completed)
                      if (isPackageCompleted) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(w * 0.03),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🎉 Package Completed!",
                                style: TextStyle(
                                  fontSize: w * 0.032,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),
                              SizedBox(height: w * 0.01),
                              Text(
                                "You have successfully completed all $totalTasksForPackage tasks",
                                style: TextStyle(
                                  fontSize: w * 0.028,
                                  color: Colors.blue[700],
                                ),
                              ),
                              SizedBox(height: w * 0.005),
                              Text(
                                "Buy again to continue earning",
                                style: TextStyle(
                                  fontSize: w * 0.026,
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: w * 0.02),
                      ],

                      // 🔹 Multiplier and Tasks Information (Only for active but not completed packages)
                      if (showProgressInfo) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(w * 0.03),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Multiplier Text
                              Text(
                                multiplierText,
                                style: TextStyle(
                                  fontSize: w * 0.032,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              SizedBox(height: w * 0.01),

                              // Daily Tasks
                              Text(
                                "Total Daily Tasks: $dailyTasks",
                                style: TextStyle(
                                  fontSize: w * 0.03,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: w * 0.005),

                              // Additional Info
                              Text(
                                "✓ Package Activated Successfully",
                                style: TextStyle(
                                  fontSize: w * 0.028,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: w * 0.02),
                      ],

                      // 🔹 Show Buy Now Button if package is NOT active OR completed
                      if (showBuyNowButton)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DepositScreen(
                                    packageTitle: title,
                                    packagePrice: price,
                                    packageActivationFee: activationFee,
                                    totalAmount: totalAmount,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPackageCompleted
                                  ? Colors.blue
                                  : primaryBlue,
                              padding: EdgeInsets.symmetric(
                                vertical: w * 0.018,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            child: Text(
                              isPackageCompleted ? "Buy Again" : "Buy Now",
                              style: TextStyle(
                                fontSize: w * 0.031,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // 🔹 Tag (Active/Completed/Inactive) at Top Right
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPackageCompleted
                            ? Colors.blue
                            : isActive
                            ? Colors.green
                            : Colors.red,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        isPackageCompleted
                            ? "Completed"
                            : isActive
                            ? "Active"
                            : "Inactive",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.03,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
