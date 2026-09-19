import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uktalhybird/TeamSreen/activeandinactivemember.dart';
import 'package:uktalhybird/TeamSreen/bonuslevel.dart';
import 'package:uktalhybird/TeamSreen/directmemeber.dart';
import 'package:uktalhybird/TeamSreen/totalteamanylatic.dart';
import 'package:uktalhybird/Withdrawal/package/packgaewithdrawl.dart';

class TeamDashboardScreen extends StatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  // Define a cohesive color scheme
  final Color primaryBlue = const Color(0xFF0000FF);
  final Color accentGreen = const Color(0xFF00C853);
  final Color accentRed = const Color(0xFFFF5252);
  final Color textColor = const Color(0xFF333333);
  final Color lightText = const Color(0xFF666666);
  Map<int, double> _levelEarnings = {};

  int _activeDirectMembersCount = 0; // 🆕 ACTIVE DIRECT MEMBERS COUNT

  int _directMembersCount = 0;
  int _totalTeamCount = 0;
  int _activeMembersCount = 0;
  int _inactiveMembersCount = 0;
  double _totalLevelEarnings = 0.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<int, double> _levelPackageBonus = {};
  Map<int, int> _levelMemberCounts = {};

  @override
  void initState() {
    super.initState();

    // Load data in proper sequence
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeTodayEarnings(); // 🆕 ADD THIS FIRST (only affects Today Earnings)

      await _loadTeamStatistics();
      await _debugPackageData(); // ✅ ADD THIS
      await _debugCheckAdminPackages(); // ✅ ADD THIS

      await _loadLevelEarnings();
      _debugCheckDataStructure();
      await _loadMyTotalEarnings(); // 🆕 NEW: Load total accumulated earnings
      await _debugCheckMyTotalEarning();

      // ✅ ADDED: Force refresh after initial load
      await _refreshAllData();
    });
  }

  Future<void> _debugCheckMyTotalEarning() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('\n=== MY_TOTAL_EARNING DEBUG ===');

      final totalEarningDoc = await _firestore
          .collection('my_total_earning')
          .doc(user.uid)
          .get();

      if (totalEarningDoc.exists) {
        print('✅ my_total_earning document EXISTS');
        final data = totalEarningDoc.data();
        print('📄 Document data: $data');

        final totalEarnings = data?['totalLevelEarnings'] ?? 'Not found';
        final levelEarnings = data?['levelEarnings'] ?? 'Not found';

        print('💰 Total Earnings in my_total_earning: $totalEarnings');
        print('📊 Level Earnings in my_total_earning: $levelEarnings');
      } else {
        print('❌ my_total_earning document DOES NOT EXIST');
        print('ℹ️ It will be created on next calculation');
      }

      print('=== END MY_TOTAL_EARNING DEBUG ===\n');
    } catch (e) {
      print('❌ Error debugging my_total_earning: $e');
    }
  }

  // 🆕 NEW: Wastage collection for locked levels earnings
  final CollectionReference _wastageCollection = FirebaseFirestore.instance
      .collection('level_wastage');

  // ✅ NEW: Debug method to check package data structure
  Future<void> _debugPackageData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('\n=== PACKAGE DATA DEBUG ===');

      // Check current user's packages
      final userPackages = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('purchasedPackages')
          .get();

      print('📦 Current user packages count: ${userPackages.docs.length}');
      for (final doc in userPackages.docs) {
        print('   Package: ${doc.data()}');
      }

      // Check Signup_Data packages
      final signupPackages = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .collection('purchasedPackages')
          .get();

      print('📦 Signup_Data packages count: ${signupPackages.docs.length}');
      for (final doc in signupPackages.docs) {
        print('   Package: ${doc.data()}');
      }

      print('=== END DEBUG ===\n');
    } catch (e) {
      print('❌ Debug package data error: $e');
    }
  }

  // ✅ NEW: Refresh all data
  // ✅ UPDATED: Refresh all data with level change detection
  Future<void> _refreshAllData() async {
    // Check if we should calculate earnings (prevent unnecessary calculations)
    final shouldCalculate = await _shouldCalculateEarnings();

    if (!shouldCalculate) {
      print('ℹ️ Skipping earnings calculation - recently updated');
      return;
    }

    setState(() {
      _totalLevelEarnings = 0.0;
      _levelEarnings = {};
    });

    await _checkTodayEarningsDayChange(); // 🆕 CHECK FOR DAY CHANGE FIRST
    await _loadTeamStatistics();

    // 🆕 NEW: Check if levels have changed before calculating
    final hasLevelChange = await _checkForLevelChanges();
    if (hasLevelChange) {
      print('🔄 Level changes detected, recalculating earnings');
      await _calculateAndUpdateLevelEarnings();
    } else {
      print('ℹ️ No level changes detected, using existing earnings');
      await _loadLevelEarnings(); // Load existing earnings
    }

    // Force UI update
    setState(() {});
  }

  // 🆕 NEW: Check if levels have changed (unlocked/locked status)
  Future<bool> _checkForLevelChanges() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return true;

      final previousStatus = await _getPreviousUnlockedStatus(user.uid);
      final currentUnlockedLevels = _getUnlockedLevels();

      // If no previous status, consider it as a change
      if (previousStatus.isEmpty) return true;

      // Compare current vs previous status
      for (int i = 0; i < currentUnlockedLevels.length; i++) {
        final levelKey = 'level_${i + 1}';
        final wasUnlocked = previousStatus[levelKey] ?? false;
        final isUnlocked = currentUnlockedLevels[i];

        if (wasUnlocked != isUnlocked) {
          print('🎯 Level ${i + 1} status changed: $wasUnlocked → $isUnlocked');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error checking level changes: $e');
      return true; // If error, recalculate to be safe
    }
  }

  Future<void> _loadTeamStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      print('👤 Current User ID: ${user.uid}');

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('📋 User Data: $userData');

        final referralCode = userData['referralCode'];
        final sponsorId = userData['sponsorId'];

        print('🔑 My Referral Code: $referralCode');
        print('👥 My Sponsor ID: $sponsorId');

        if (referralCode == null || referralCode.isEmpty) {
          print('❌ ERROR: User has no referral code!');
          return;
        }

        // Load counts in parallel for better performance
        await Future.wait([
          _loadDirectMembersCount(referralCode),
          _loadActiveDirectMembersCount(referralCode),
          _loadTotalTeamCount(referralCode),
          _loadActiveInactiveCounts(user.uid),
        ]);

        // ✅ Force earnings calculation after all data is loaded
        await _calculateAndUpdateLevelEarnings();
      } else {
        print('❌ ERROR: User document does not exist in Signup_Data');
      }
    } catch (e) {
      print('❌ Error loading team statistics: $e');
    }
  }

  // 🆕 NEW: Update earnings in Firestore
  // 🆕 UPDATED: Update CALCULATED earnings in separate field (not affecting available balance)
  // 🆕 UPDATED: Update CALCULATED earnings in separate field AND Today Earnings collection

  // 🆕 NEW: Store total level earnings in separate collection
  // 🆕 UPDATED: Store total level earnings in my_total_earning collection with proper structure
  Future<void> _storeInMyTotalEarning(
    String userId,
    Map<int, double> levelEarnings,
    double totalEarnings,
  ) async {
    try {
      print('💾 Storing in my_total_earning for user: $userId');

      // Convert level earnings to Firestore format
      Map<String, dynamic> levelsMap = {};
      levelEarnings.forEach((level, amount) {
        if (amount > 0) {
          // Only store levels with earnings
          levelsMap['level_$level'] = amount;
        }
      });

      // 🆕 UPDATED: Proper data structure for my_total_earning
      final myTotalEarningData = {
        'userId': userId,
        'totalLevelEarnings': totalEarnings,
        'levelEarnings': {'levels': levelsMap, 'total': totalEarnings},
        'lastUpdated': FieldValue.serverTimestamp(),
        'type': 'total_level_earnings',
        'description': 'Total accumulated level earnings from all levels',
        'calculationDate': _getTodayDateString(),
        'activeDirectMembers': _activeDirectMembersCount,
        'totalTeamMembers': _totalTeamCount,
      };

      await _firestore
          .collection('my_total_earning')
          .doc(userId)
          .set(myTotalEarningData, SetOptions(merge: true));

      print('✅ TOTAL Earnings stored in my_total_earning collection');
      print('📊 Levels data stored: $levelsMap');
      print('💰 Total accumulated earnings stored: \$$totalEarnings');

      // ✅ VERIFY: Check if document was created
      final verifyDoc = await _firestore
          .collection('my_total_earning')
          .doc(userId)
          .get();

      if (verifyDoc.exists) {
        print(
          '✅ VERIFIED: my_total_earning document successfully created/updated',
        );
        print('📄 Document data: ${verifyDoc.data()}');
      } else {
        print('❌ VERIFICATION FAILED: my_total_earning document not found');
      }
    } catch (e) {
      print('❌ Error storing total earnings in my_total_earning: $e');
    }
  }

  // 🆕 NEW: Load total level earnings from my_total_earning collection
  Future<void> _loadMyTotalEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print(
        '👤 Loading TOTAL earnings from my_total_earning for user: ${user.uid}',
      );

      final totalEarningDoc = await _firestore
          .collection('my_total_earning')
          .doc(user.uid)
          .get();

      Map<int, double> levelEarnings = {};
      double totalEarnings = 0.0;

      if (totalEarningDoc.exists) {
        final totalData = totalEarningDoc.data() as Map<String, dynamic>;
        print('💰 My Total Earning data: $totalData');

        // Get level earnings from my_total_earning
        final levelEarningsData =
            totalData['levelEarnings'] as Map<String, dynamic>?;

        if (levelEarningsData != null) {
          final levelsMap =
              levelEarningsData['levels'] as Map<String, dynamic>?;
          totalEarnings = (levelEarningsData['total'] ?? 0.0).toDouble();

          if (levelsMap != null && levelsMap.isNotEmpty) {
            // Convert level earnings to Map<int, double>
            levelsMap.forEach((levelKey, amount) {
              final levelNumber =
                  int.tryParse(levelKey.replaceAll('level_', '')) ?? 0;
              if (levelNumber > 0) {
                double levelAmount = 0.0;
                if (amount is double) {
                  levelAmount = amount;
                } else if (amount is int) {
                  levelAmount = amount.toDouble();
                } else if (amount is String) {
                  levelAmount = double.tryParse(amount) ?? 0.0;
                }
                levelEarnings[levelNumber] = levelAmount;
              }
            });

            print(
              '✅ Loaded TOTAL earnings from my_total_earning: $levelEarnings',
            );
          }
        }
      } else {
        print(
          '📭 No my_total_earning document found, will create on next calculation',
        );
      }

      print('🎯 TOTAL Level earnings breakdown: $levelEarnings');
      print('🎉 TOTAL accumulated earnings: \$$totalEarnings');

      // Note: We don't set state here as this is for total accumulated earnings
      // This data is separate from the current calculated earnings
    } catch (e) {
      print('❌ Error loading total earnings from my_total_earning: $e');
    }
  }

  // ✅ NEW: Debug method to check admin-activated packages
  // ✅ IMPROVED: Debug method to check admin-activated packages with level-wise breakdown
  Future<void> _debugCheckAdminPackages() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('\n=== ADMIN PACKAGES DEBUG ===');

      // Check current user's packages
      final userPackages = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('purchasedPackages')
          .get();

      int adminPackagesCount = 0;
      int userPackagesCount = 0;
      double adminPackagesAmount = 0.0;
      double userPackagesAmount = 0.0;

      for (final doc in userPackages.docs) {
        final packageData = doc.data();
        final packageAmount = _extractPackageAmount(packageData);

        if (_isPackageActivatedByAdmin(packageData)) {
          adminPackagesCount++;
          adminPackagesAmount += packageAmount;
          print(
            '   🔧 ADMIN Package: ${packageData['packageTitle']} - \$$packageAmount',
          );
        } else {
          userPackagesCount++;
          userPackagesAmount += packageAmount;
          print(
            '   👤 USER Package: ${packageData['packageTitle']} - \$$packageAmount',
          );
        }
      }

      print('📊 Summary:');
      print('   Admin-activated packages: $adminPackagesCount');
      print('   User-purchased packages: $userPackagesCount');
      print('   Total packages: ${userPackages.docs.length}');
      print('   Admin packages amount: \$$adminPackagesAmount');
      print('   User packages amount: \$$userPackagesAmount');

      print('=== END ADMIN PACKAGES DEBUG ===\n');
    } catch (e) {
      print('❌ Error debugging admin packages: $e');
    }
  }

  // 🆕 UPDATED: Update CALCULATED earnings in separate field AND Today Earnings collection AND my_total_earning
  Future<void> _updateEarningsInFirestore(
    String userId,
    Map<int, double> levelEarnings,
    double totalEarnings,
  ) async {
    try {
      // Convert level earnings to Firestore format
      Map<String, dynamic> levelsMap = {};
      levelEarnings.forEach((level, amount) {
        levelsMap['level_$level'] = amount;
      });

      // ✅ Store calculated earnings in SEPARATE field to avoid conflict
      final walletData = {
        'calculatedLevelEarnings': {
          'levels': levelsMap,
          'total': totalEarnings,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        'userId': userId,
      };

      // Update Firestore with calculated earnings (separate from available balance)
      await _firestore
          .collection('Sponsar_wallets')
          .doc(userId)
          .set(walletData, SetOptions(merge: true));

      print('✅ CALCULATED Earnings updated in Firestore (separate field)');
      print('📊 Calculated Levels data: $levelsMap');
      print('💰 Calculated Total earnings: \$$totalEarnings');

      // ✅ UPDATED: Store in Today Earnings collection
      await _storeInTodayEarnings(userId, totalEarnings, levelEarnings);

      // ✅ ADD THIS: Store in my_total_earning collection
      await _storeInMyTotalEarning(userId, levelEarnings, totalEarnings);
    } catch (e) {
      print('❌ Error updating calculated earnings in Firestore: $e');
    }
  }

  // ✅ SIMPLE: Check if level is locked
  bool _isLevelLocked(int level, int activeDirectMembersCount) {
    // Level 1 is always unlocked
    if (level == 1) return false;

    // Level 2+ requires (level-1) active direct members
    return activeDirectMembersCount < (level - 1);
  }

  // 🆕 UPDATED_isLevelLocked: Store Total Level Earnings in Today Earnings collection with auto-reset at 12 AM
  // 🆕 UPDATED: Store Today Earnings with FIRST-TIME ONLY logic
  Future<void> _storeInTodayEarnings(
    String userId,
    double totalEarnings,
    Map<int, double> levelEarnings,
  ) async {
    try {
      final todayString = _getTodayDateString();
      final todayDocRef = _firestore
          .collection('Today_Earnings')
          .doc(userId)
          .collection('daily_earnings')
          .doc(todayString);

      final todayDoc = await todayDocRef.get();

      double currentTodayEarnings = 0.0;
      double initialEarnings = 0.0;
      bool isInitialized = false;

      if (todayDoc.exists) {
        final data = todayDoc.data() as Map<String, dynamic>;
        currentTodayEarnings = (data['totalLevelEarnings'] ?? 0.0).toDouble();
        initialEarnings = (data['initialLevelEarnings'] ?? 0.0).toDouble();
        isInitialized = data['isInitialized'] ?? false;
      }

      double newEarningsToAdd = 0.0;

      if (!isInitialized) {
        // پہلی بار: ساری رقم ڈالو
        newEarningsToAdd = totalEarnings;
        initialEarnings = totalEarnings;
        isInitialized = true;
        print('FIRST TIME: Adding all: $newEarningsToAdd');
      } else {
        // اگر پہلے سے ہے → صرف نئی رقم
        if (totalEarnings > initialEarnings) {
          newEarningsToAdd = totalEarnings - initialEarnings;
          print('NEW EARNING: Adding $newEarningsToAdd');
        } else {
          print('NO NEW EARNING: $totalEarnings <= $initialEarnings');
          newEarningsToAdd = 0.0;
        }
      }

      // ہر بار initialEarnings کو تازہ ترین totalEarnings سے اپ ڈیٹ کرو
      final updatedInitialEarnings = totalEarnings;

      final updatedTodayEarnings = currentTodayEarnings + newEarningsToAdd;

      Map<String, dynamic> levelsMap = {};
      levelEarnings.forEach((level, amount) {
        levelsMap['level_$level'] = amount;
      });

      await todayDocRef.set({
        'userId': userId,
        'totalLevelEarnings': updatedTodayEarnings,
        'initialLevelEarnings': updatedInitialEarnings, // ہر بار اپ ڈیٹ
        'levelEarnings': {'levels': levelsMap, 'total': updatedTodayEarnings},
        'date': todayString,
        'lastResetDate': todayString,
        'isInitialized': true,
        'lastCalculationTime': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'level_bonus',
        'description': 'Updated with latest earnings',
      }, SetOptions(merge: true));

      print(
        'TODAY EARNINGS: $updatedTodayEarnings | INITIAL: $updatedInitialEarnings',
      );
    } catch (e) {
      print('Error in _storeInTodayEarnings: $e');
    }
  }

  // 🆕 NEW: Track wastage for analytics (UI mein show nahi hoga)
  Future<void> _trackWastage(int level, double amount, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null || amount <= 0) return;

      final wastageRef = _firestore.collection('Level_Wastage').doc(user.uid);

      await wastageRef.set({
        'wastedEarnings.level_$level': FieldValue.arrayUnion([
          {
            'amount': amount,
            'timestamp': FieldValue.serverTimestamp(),
            'level': level,
            'reason': reason,
            'date': _getTodayDateString(),
          },
        ]),
        'totalWasted': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': user.uid,
      }, SetOptions(merge: true));

      print('📊 Wastage Tracked: Level $level - \$$amount - Reason: $reason');
    } catch (e) {
      print('❌ Error tracking wastage: $e');
    }
  }

  // 🆕 NEW: Get wastage summary from Firestore
  Future<Map<String, dynamic>> _getWastageSummary() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'totalWasted': 0.0, 'entries': []};

      final wastageDoc = await _firestore
          .collection('Level_Wastage')
          .doc(user.uid)
          .get();

      if (!wastageDoc.exists) {
        print('📭 No wastage document found');
        return {'totalWasted': 0.0, 'entries': []};
      }

      final data = wastageDoc.data() as Map<String, dynamic>;
      final totalWasted = (data['totalWasted'] ?? 0.0).toDouble();
      final entries = data['wastageEntries'] ?? [];

      print(
        '📊 Wastage Summary - Total: \$$totalWasted, Entries: ${entries.length}',
      );

      return {'totalWasted': totalWasted, 'entries': entries};
    } catch (e) {
      print('❌ Error getting wastage summary: $e');
      return {'totalWasted': 0.0, 'entries': []};
    }
  }

  // 🆕 NEW: Debug function to check wastage data
  Future<void> _debugCheckWastage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('\n=== WASTAGE DEBUG CHECK ===');

      final wastageDoc = await _firestore
          .collection('Level_Wastage')
          .doc(user.uid)
          .get();

      if (!wastageDoc.exists) {
        print('❌ No wastage document found for user ${user.uid}');
        return;
      }

      final data = wastageDoc.data();
      print('✅ Wastage Document Data: $data');

      final totalWasted = data?['totalWasted'] ?? 0.0;
      final entries = data?['wastageEntries'] ?? [];

      print('💰 Total Wasted: \$$totalWasted');
      print('📝 Wastage Entries Count: ${entries.length}');

      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        print('   Entry $i: Level ${entry['level']} - \$${entry['amount']}');
      }

      print('=== END WASTAGE DEBUG ===\n');
    } catch (e) {
      print('❌ Error in wastage debug: $e');
    }
  }

  // 🆕 NEW: Check and reset ONLY Today Earnings at 12 AM (without affecting other earnings)
  // 🆕 UPDATED: Check and reset with proper fields
  Future<void> _checkAndResetTodayEarningsForNewDay(
    String userId,
    DateTime currentTime,
  ) async {
    try {
      // Get today's date string
      final todayString = _getTodayDateString();

      // Get the current document for today
      final todayDoc = await _firestore
          .collection('Today_Earnings')
          .doc(userId)
          .collection('daily_earnings')
          .doc(todayString)
          .get();

      // If document doesn't exist, initialize with proper fields
      if (!todayDoc.exists) {
        print('🔄 New day detected, initializing Today Earnings to 0');
        await _firestore
            .collection('Today_Earnings')
            .doc(userId)
            .collection('daily_earnings')
            .doc(todayString)
            .set({
              'userId': userId,
              'totalLevelEarnings': 0.0,
              'initialLevelEarnings': 0.0,
              'additionalEarningsToday': 0.0,
              'levelEarnings': {'levels': {}, 'total': 0.0},
              'date': todayString,
              'lastResetDate': todayString,
              'isInitialized': false,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'level_bonus',
              'description': 'Team Level Bonus Earnings - Initialized',
            });
        return;
      }

      final data = todayDoc.data();
      if (data != null) {
        final lastResetDate = data['lastResetDate'] as String?;

        // If lastResetDate is not today, reset ONLY Today Earnings to 0
        if (lastResetDate != todayString) {
          print('🔄 New day detected, resetting ONLY Today Earnings to 0');
          await _firestore
              .collection('Today_Earnings')
              .doc(userId)
              .collection('daily_earnings')
              .doc(todayString)
              .update({
                'totalLevelEarnings': 0.0,
                'initialLevelEarnings': 0.0,
                'additionalEarningsToday': 0.0,
                'levelEarnings': {'levels': {}, 'total': 0.0},
                'lastResetDate': todayString,
                'isInitialized': false,
                'timestamp': FieldValue.serverTimestamp(),
              });

          print('✅ Today Earnings reset to 0 for new day');
        }
      }
    } catch (e) {
      print('❌ Error checking and resetting Today Earnings for new day: $e');
    }
  }

  // 🆕 NEW: Initialize Today Earnings at app start (without affecting other earnings)
  // 🆕 UPDATED: Initialize Today Earnings with proper fields
  Future<void> _initializeTodayEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final todayString = _getTodayDateString();

      // Check if today's earnings document exists
      final todayDoc = await _firestore
          .collection('Today_Earnings')
          .doc(user.uid)
          .collection('daily_earnings')
          .doc(todayString)
          .get();

      // If document doesn't exist OR exists but has old date, initialize with proper fields
      if (!todayDoc.exists) {
        await _firestore
            .collection('Today_Earnings')
            .doc(user.uid)
            .collection('daily_earnings')
            .doc(todayString)
            .set({
              'userId': user.uid,
              'totalLevelEarnings': 0.0,
              'initialLevelEarnings': 0.0, // 🆕 Track first calculation
              'additionalEarningsToday': 0.0, // 🆕 Track additional earnings
              'levelEarnings': {'levels': {}, 'total': 0.0},
              'date': todayString,
              'lastResetDate': todayString,
              'isInitialized': false, // 🆕 Not initialized yet
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'level_bonus',
              'description': 'Team Level Bonus Earnings - Initialized',
            });
        print('✅ Today Earnings initialized to 0 for date: $todayString');
      } else {
        // 🆕 Check if it's a new day and needs reset
        final data = todayDoc.data();
        if (data != null) {
          final lastResetDate = data['lastResetDate'] as String?;
          if (lastResetDate != todayString) {
            // Reset for new day
            await _firestore
                .collection('Today_Earnings')
                .doc(user.uid)
                .collection('daily_earnings')
                .doc(todayString)
                .update({
                  'totalLevelEarnings': 0.0,
                  'initialLevelEarnings': 0.0,
                  'additionalEarningsToday': 0.0,
                  'levelEarnings': {'levels': {}, 'total': 0.0},
                  'lastResetDate': todayString,
                  'isInitialized': false, // 🆕 Reset initialization
                  'timestamp': FieldValue.serverTimestamp(),
                });
            print('🔄 Today Earnings reset for new day: $todayString');
          }
        }
      }
    } catch (e) {
      print('❌ Error initializing Today Earnings: $e');
    }
  }

  // 🆕 NEW: Background task to check for day change (call this periodically)
  Future<void> _checkTodayEarningsDayChange() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();

      // Check every time the app becomes active or periodically
      await _checkAndResetTodayEarningsForNewDay(user.uid, now);
    } catch (e) {
      print('❌ Error checking Today Earnings day change: $e');
    }
  }

  // 🆕 OPTIONAL: Method to get today's earnings (if needed elsewhere)
  Future<Map<String, dynamic>?> getTodayLevelEarnings(String userId) async {
    try {
      final today = DateTime.now();
      final todayString =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      final todayEarningsDoc = await _firestore
          .collection('Today_Earnings')
          .doc(userId)
          .collection('daily_earnings')
          .doc(todayString)
          .get();

      if (todayEarningsDoc.exists) {
        return todayEarningsDoc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting today earnings: $e');
      return null;
    }
  }

  Future<void> _loadActiveDirectMembersCount(String referralCode) async {
    try {
      final activeDirectCount = await _getActiveDirectMembersCount(
        referralCode,
      );

      setState(() {
        _activeDirectMembersCount = activeDirectCount;
      });
    } catch (e) {
      print('❌ Error loading active direct members count: $e');
    }
  }

  Future<void> _loadDirectMembersCount(String referralCode) async {
    try {
      print('🔍 Searching for direct members with sponsorId: $referralCode');

      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      print('✅ Found ${directMembersQuery.docs.length} direct members');

      // Print details of each direct member
      for (final doc in directMembersQuery.docs) {
        final memberData = doc.data();
        print(
          '   👤 Member: ${memberData['name']} - ${memberData['username']} - Sponsor: ${memberData['sponsorId']}',
        );
      }

      setState(() {
        _directMembersCount = directMembersQuery.docs.length;
      });
    } catch (e) {
      print('❌ Error loading direct members count: $e');
    }
  }

  // Recursive function to count total team members (complete downline)
  Future<int> _getTotalTeamCount(String referralCode) async {
    int totalCount = 0;

    try {
      print('🔍 Recursive search for referral: $referralCode');

      // Find all direct members using this referral code
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      totalCount += directMembersQuery.docs.length;
      print('   📊 Level count: ${directMembersQuery.docs.length} members');

      // Recursively count members of each direct member
      for (final doc in directMembersQuery.docs) {
        final memberData = doc.data() as Map<String, dynamic>;
        final memberReferralCode = memberData['referralCode'];
        final memberName = memberData['name'] ?? 'Unknown';

        print('   🔄 Checking downline of: $memberName ($memberReferralCode)');

        if (memberReferralCode != null && memberReferralCode.isNotEmpty) {
          totalCount += await _getTotalTeamCount(memberReferralCode);
        } else {
          print(
            '   ❌ Member $memberName has no referral code, cannot check downline',
          );
        }
      }
    } catch (e) {
      print('❌ Error in recursive team count for $referralCode: $e');
    }

    print('📈 Total count for $referralCode: $totalCount');
    return totalCount;
  }

  Future<void> _loadTotalTeamCount(String referralCode) async {
    try {
      final totalCount = await _getTotalTeamCount(referralCode);
      setState(() {
        _totalTeamCount = totalCount;
      });
    } catch (e) {
      print('Error loading total team count: $e');
    }
  }

  Future<void> _debugCheckDataStructure() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('\n=== DATABASE STRUCTURE DEBUG ===');

      // Check current user data
      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        print('✅ Current User Data: ${userDoc.data()}');
      } else {
        print('❌ Current user not found in Signup_Data');
      }

      // Check all users to see data structure
      final allUsers = await _firestore
          .collection('Signup_Data')
          .limit(10)
          .get();
      print('\n📊 Sample of first 10 users:');
      for (final doc in allUsers.docs) {
        final data = doc.data();
        print(
          '   👤 ${data['name']} - Referral: ${data['referralCode']} - Sponsor: ${data['sponsorId']}',
        );
      }

      // Check if any purchasedPackages exist
      final packages = await _firestore
          .collectionGroup('purchasedPackages')
          .limit(5)
          .get();
      print('\n🎁 Sample purchased packages: ${packages.docs.length} found');
    } catch (e) {
      print('❌ Debug check error: $e');
    }
  }

  // ✅ NEW: Calculate level-wise earnings for each member in the chain
  Future<Map<String, dynamic>> _calculateLevelWiseDistribution() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return {};

      final userData = userDoc.data() as Map<String, dynamic>;
      final referralCode = userData['referralCode'];
      if (referralCode == null || referralCode.isEmpty) return {};

      // Get all team members
      final allTeamMemberIds = await _getAllTeamMemberIds(referralCode);

      Map<String, dynamic> levelDistribution = {};
      final levelPercentages = [20, 8, 7, 6, 5, 3, 2, 1, 1, 1, 1];

      for (final memberId in allTeamMemberIds) {
        // Get member data
        final memberDoc = await _firestore
            .collection('Signup_Data')
            .doc(memberId)
            .get();
        if (!memberDoc.exists) continue;

        final memberData = memberDoc.data() as Map<String, dynamic>;
        final memberName = memberData['name'] ?? 'Unknown';
        final memberLevel = await _getMemberLevel(user.uid, memberId);

        // Calculate member's total packages amount
        double memberTotalBusiness = 0.0;

        // Check both collections for packages
        final packages1 = await _firestore
            .collection('users')
            .doc(memberId)
            .collection('purchasedPackages')
            .get();

        final packages2 = await _firestore
            .collection('Signup_Data')
            .doc(memberId)
            .collection('purchasedPackages')
            .get();

        for (final package in packages1.docs) {
          memberTotalBusiness += _extractPackageAmount(package.data());
        }

        for (final package in packages2.docs) {
          memberTotalBusiness += _extractPackageAmount(package.data());
        }

        if (memberTotalBusiness > 0 && memberLevel <= 11) {
          final percentage = levelPercentages[memberLevel - 1];
          final levelEarning = (memberTotalBusiness * percentage) / 100;

          levelDistribution['level_$memberLevel'] = {
            'members':
                (levelDistribution['level_$memberLevel']?['members'] ?? 0) + 1,
            'totalEarning':
                (levelDistribution['level_$memberLevel']?['totalEarning'] ??
                    0.0) +
                levelEarning,
            'memberDetails': [
              ...(levelDistribution['level_$memberLevel']?['memberDetails'] ??
                  []),
              {
                'name': memberName,
                'business': memberTotalBusiness,
                'earning': levelEarning,
                'percentage': percentage,
              },
            ],
          };
        }
      }

      print('📊 Level Distribution: $levelDistribution');
      return levelDistribution;
    } catch (e) {
      print('❌ Error calculating level distribution: $e');
      return {};
    }
  }

  // ✅ NEW: Get member's level in your team
  // ✅ UPDATED: Get member's exact level in your team (Fixed)
  Future<int> _getMemberLevel(String rootUserId, String memberId) async {
    try {
      // If member is the root user, return 0
      if (memberId == rootUserId) return 0;

      String currentId = memberId;
      int level = 1; // Start from level 1 for direct members

      // Maximum levels to check
      int maxLevels = 11;

      for (int i = 1; i <= maxLevels; i++) {
        final currentDoc = await _firestore
            .collection('Signup_Data')
            .doc(currentId)
            .get();

        if (!currentDoc.exists) return 0;

        final currentData = currentDoc.data() as Map<String, dynamic>;
        final sponsorId = currentData['sponsorId'];

        // If no sponsor ID, cannot determine level
        if (sponsorId == null || sponsorId.isEmpty) return 0;

        // Find sponsor user by referral code
        final sponsorQuery = await _firestore
            .collection('Signup_Data')
            .where('referralCode', isEqualTo: sponsorId)
            .limit(1)
            .get();

        if (sponsorQuery.docs.isEmpty) return 0;

        final sponsorDoc = sponsorQuery.docs.first;
        final sponsorUserId = sponsorDoc.id;

        // Check if this sponsor is the root user
        if (sponsorUserId == rootUserId) {
          return level; // Found the level
        } else {
          // Move up to the next level
          currentId = sponsorUserId;
          level++;

          // Safety check to prevent infinite loop
          if (level > maxLevels) return 0;
        }
      }

      return 0; // Not found within max levels
    } catch (e) {
      print('❌ Error getting member level for $memberId: $e');
      return 0;
    }
  }

  // Recursive function to get all team member IDs (for active/inactive check)
  // Recursive function to get all team member IDs (for active/inactive check)
  Future<Set<String>> _getAllTeamMemberIds(String referralCode) async {
    Set<String> memberIds = {};

    try {
      print('🔍 Recursive search for team members with sponsor: $referralCode');

      // Find all direct members using this referral code
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      print('   📊 Found ${directMembersQuery.docs.length} direct members');

      // Add direct members to the set
      for (final doc in directMembersQuery.docs) {
        final memberId = doc.id;
        final memberData = doc.data() as Map<String, dynamic>;
        final memberName = memberData['name'] ?? 'Unknown';
        final memberReferralCode = memberData['referralCode'];

        memberIds.add(memberId);
        print('   👤 Added member: $memberName ($memberId) - Level 1');

        // Recursively get this member's downline IDs
        if (memberReferralCode != null && memberReferralCode.isNotEmpty) {
          print(
            '   🔄 Checking downline of: $memberName ($memberReferralCode)',
          );
          final downlineIds = await _getAllTeamMemberIds(memberReferralCode);

          // ✅ NEW: Print level information for downline members
          for (final downlineId in downlineIds) {
            final downlineDoc = await _firestore
                .collection('Signup_Data')
                .doc(downlineId)
                .get();
            if (downlineDoc.exists) {
              final downlineData = downlineDoc.data() as Map<String, dynamic>;
              final downlineName = downlineData['name'] ?? 'Unknown';
              final downlineLevel = await _getMemberLevel(
                _auth.currentUser!.uid,
                downlineId,
              );
              print('      👥 Downline: $downlineName - Level $downlineLevel');
            }
          }

          memberIds.addAll(downlineIds);
          print('   📈 Added ${downlineIds.length} downline members');
        } else {
          print(
            '   ❌ Member $memberName has no referral code, cannot check downline',
          );
        }
      }
    } catch (e) {
      print('❌ Error getting all team member IDs for $referralCode: $e');
    }

    print(
      '🎯 Total unique team members for $referralCode: ${memberIds.length}',
    );
    return memberIds;
  }

  // Load active and inactive members count for ENTIRE TEAM
  Future<void> _loadActiveInactiveCounts(String userId) async {
    try {
      // Get user's referral code first
      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userReferralCode = userData['referralCode'];

      // Get ALL team member IDs (direct + indirect)
      final allTeamMemberIds = await _getAllTeamMemberIds(userReferralCode);

      int activeCount = 0;
      int inactiveCount = 0;

      // Check each team member for deposits
      for (final memberId in allTeamMemberIds) {
        bool hasValidPackages = false;

        // Check if member has any VALID purchased packages (not admin-activated)
        final packagesQuery = await _firestore
            .collection('users')
            .doc(memberId)
            .collection('purchasedPackages')
            .get();

        for (final packageDoc in packagesQuery.docs) {
          final packageData = packageDoc.data();
          // Skip if package is activated by admin
          if (!_isPackageActivatedByAdmin(packageData)) {
            hasValidPackages = true;
            break; // At least one valid package found
          }
        }

        // Also check Signup_Data collection
        if (!hasValidPackages) {
          final signupPackagesQuery = await _firestore
              .collection('Signup_Data')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          for (final packageDoc in signupPackagesQuery.docs) {
            final packageData = packageDoc.data();
            // Skip if package is activated by admin
            if (!_isPackageActivatedByAdmin(packageData)) {
              hasValidPackages = true;
              break; // At least one valid package found
            }
          }
        }

        if (hasValidPackages) {
          activeCount++;
        } else {
          inactiveCount++;
        }
      }

      setState(() {
        _activeMembersCount = activeCount;
        _inactiveMembersCount = inactiveCount;
      });

      print(
        'Team Stats - Active: $activeCount, Inactive: $inactiveCount, Total Team: ${allTeamMemberIds.length}',
      );
    } catch (e) {
      print('Error loading active/inactive counts: $e');
    }
  }
  // Future<void> _loadLevelEarnings() async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) return;

  //     print('👤 Loading level earnings for user: ${user.uid}');

  //     // Try to get from Sponsar_wallets first
  //     final sponsorWalletDoc = await _firestore
  //         .collection('Sponsar_wallets')
  //         .doc(user.uid)
  //         .get();

  //     Map<int, double> levelEarnings = {};
  //     double totalEarnings = 0.0;

  //     if (sponsorWalletDoc.exists) {
  //       final walletData = sponsorWalletDoc.data() as Map<String, dynamic>;
  //       print('💰 Wallet data: $walletData');

  //       // Get level earnings from wallet
  //       final levelEarningsData =
  //           walletData['levelEarnings'] as Map<String, dynamic>?;

  //       if (levelEarningsData != null) {
  //         final levelsMap =
  //             levelEarningsData['levels'] as Map<String, dynamic>?;
  //         totalEarnings = (levelEarningsData['total'] ?? 0.0).toDouble();

  //         if (levelsMap != null && levelsMap.isNotEmpty) {
  //           // Convert level earnings to Map<int, double>
  //           levelsMap.forEach((levelKey, amount) {
  //             final levelNumber =
  //                 int.tryParse(levelKey.replaceAll('level_', '')) ?? 0;
  //             if (levelNumber > 0) {
  //               // ✅ FIXED: Handle amount conversion properly
  //               double levelAmount = 0.0;
  //               if (amount is double) {
  //                 levelAmount = amount;
  //               } else if (amount is int) {
  //                 levelAmount = amount.toDouble();
  //               } else if (amount is String) {
  //                 levelAmount = double.tryParse(amount) ?? 0.0;
  //               }
  //               levelEarnings[levelNumber] = levelAmount;
  //             }
  //           });

  //           print('✅ Loaded level earnings from Firestore: $levelEarnings');
  //         } else {
  //           print('⚠️ Levels map is empty, calculating fresh earnings');
  //           await _calculateAndUpdateLevelEarnings();
  //           return;
  //         }
  //       } else {
  //         print('⚠️ No levelEarnings data found, calculating fresh earnings');
  //         await _calculateAndUpdateLevelEarnings();
  //         return;
  //       }
  //     } else {
  //       print(
  //         '❌ No Sponsar_wallets document found, calculating fresh earnings',
  //       );
  //       await _calculateAndUpdateLevelEarnings();
  //       return;
  //     }

  //     print('🎯 Level earnings breakdown: $levelEarnings');
  //     print('🎉 Total level earnings: \$$totalEarnings');

  //     setState(() {
  //       _levelEarnings = levelEarnings;
  //       _totalLevelEarnings = totalEarnings;
  //     });
  //   } catch (e) {
  //     print('❌ Error loading level earnings: $e');
  //     // If loading fails, calculate fresh earnings
  //     await _calculateAndUpdateLevelEarnings();
  //   }
  // }
  // ✅ UPDATED: Check if package is activated by admin (should be excluded from team earnings)
  bool _isPackageActivatedByAdmin(Map<String, dynamic> packageData) {
    final activatedBy = packageData['activatedBy']?.toString().toLowerCase();
    return activatedBy == 'admin';
  }

  Future<void> _loadLevelEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('👤 Loading level earnings for user: ${user.uid}');

      // Try to get from Sponsar_wallets first
      final sponsorWalletDoc = await _firestore
          .collection('Sponsar_wallets')
          .doc(user.uid)
          .get();

      Map<int, double> levelEarnings = {};
      double totalEarnings = 0.0;

      if (sponsorWalletDoc.exists) {
        final walletData = sponsorWalletDoc.data() as Map<String, dynamic>;
        print('💰 Wallet data: $walletData');

        // ✅ FIRST: Try to get from calculatedLevelEarnings (TeamDashboard calculations)
        final calculatedEarningsData =
            walletData['calculatedLevelEarnings'] as Map<String, dynamic>?;

        if (calculatedEarningsData != null) {
          final levelsMap =
              calculatedEarningsData['levels'] as Map<String, dynamic>?;
          totalEarnings = (calculatedEarningsData['total'] ?? 0.0).toDouble();

          if (levelsMap != null && levelsMap.isNotEmpty) {
            // Convert level earnings to Map<int, double>
            levelsMap.forEach((levelKey, amount) {
              final levelNumber =
                  int.tryParse(levelKey.replaceAll('level_', '')) ?? 0;
              if (levelNumber > 0) {
                double levelAmount = 0.0;
                if (amount is double) {
                  levelAmount = amount;
                } else if (amount is int) {
                  levelAmount = amount.toDouble();
                } else if (amount is String) {
                  levelAmount = double.tryParse(amount) ?? 0.0;
                }
                levelEarnings[levelNumber] = levelAmount;
              }
            });

            print(
              '✅ Loaded CALCULATED level earnings from Firestore: $levelEarnings',
            );
          } else {
            print(
              '⚠️ Calculated levels map is empty, calculating fresh earnings',
            );
            await _calculateAndUpdateLevelEarnings();
            return;
          }
        }
        // ✅ FALLBACK: If no calculated earnings, check regular levelEarnings
        else {
          final levelEarningsData =
              walletData['levelEarnings'] as Map<String, dynamic>?;

          if (levelEarningsData != null) {
            final levelsMap =
                levelEarningsData['levels'] as Map<String, dynamic>?;
            totalEarnings = (levelEarningsData['total'] ?? 0.0).toDouble();

            if (levelsMap != null && levelsMap.isNotEmpty) {
              levelsMap.forEach((levelKey, amount) {
                final levelNumber =
                    int.tryParse(levelKey.replaceAll('level_', '')) ?? 0;
                if (levelNumber > 0) {
                  double levelAmount = 0.0;
                  if (amount is double) {
                    levelAmount = amount;
                  } else if (amount is int) {
                    levelAmount = amount.toDouble();
                  } else if (amount is String) {
                    levelAmount = double.tryParse(amount) ?? 0.0;
                  }
                  levelEarnings[levelNumber] = levelAmount;
                }
              });
              print(
                '✅ Loaded AVAILABLE level earnings from Firestore: $levelEarnings',
              );
            } else {
              print(
                '⚠️ No level earnings data found, calculating fresh earnings',
              );
              await _calculateAndUpdateLevelEarnings();
              return;
            }
          } else {
            print(
              '⚠️ No level earnings data found, calculating fresh earnings',
            );
            await _calculateAndUpdateLevelEarnings();
            return;
          }
        }
      } else {
        print(
          '❌ No Sponsar_wallets document found, calculating fresh earnings',
        );
        await _calculateAndUpdateLevelEarnings();
        return;
      }

      print('🎯 Level earnings breakdown: $levelEarnings');
      print('🎉 Total level earnings: \$$totalEarnings');

      setState(() {
        _levelEarnings = levelEarnings;
        _totalLevelEarnings = totalEarnings;
      });
    } catch (e) {
      print('❌ Error loading level earnings: $e');
      // If loading fails, calculate fresh earnings
      await _calculateAndUpdateLevelEarnings();
    }
  }

  // NEW: Count only ACTIVE direct members (who have purchased packages)
  // ✅ UPDATED: Count BOTH user-purchased AND admin-activated packages for level unlocking
  Future<int> _getActiveDirectMembersCount(String referralCode) async {
    int activeDirectCount = 0;

    try {
      print(
        '🔍 Searching for ACTIVE direct members with sponsorId: $referralCode',
      );

      // Find all direct members using this referral code
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      print('✅ Found ${directMembersQuery.docs.length} direct members');

      // Check each direct member if they are ACTIVE (have ANY purchased packages - BOTH user AND admin)
      for (final doc in directMembersQuery.docs) {
        final memberId = doc.id;
        final memberData = doc.data() as Map<String, dynamic>;
        final memberName = memberData['name'] ?? 'Unknown';

        bool hasAnyPackages = false;

        // Check if this direct member has ANY purchased packages (BOTH user AND admin)
        final packagesQuery = await _firestore
            .collection('users')
            .doc(memberId)
            .collection('purchasedPackages')
            .get();

        // ✅ CHANGED: Count if ANY packages exist (regardless of admin activation)
        if (packagesQuery.docs.isNotEmpty) {
          hasAnyPackages = true;
        }

        // Also check Signup_Data collection
        if (!hasAnyPackages) {
          final signupPackagesQuery = await _firestore
              .collection('Signup_Data')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          // ✅ CHANGED: Count if ANY packages exist (regardless of admin activation)
          if (signupPackagesQuery.docs.isNotEmpty) {
            hasAnyPackages = true;
          }
        }

        if (hasAnyPackages) {
          activeDirectCount++;
          print('   ✅ ACTIVE Direct Member: $memberName (any packages)');
        } else {
          print('   ❌ INACTIVE Direct Member: $memberName (no packages)');
        }
      }

      print(
        '🎯 Total ACTIVE Direct Members (including admin packages): $activeDirectCount',
      );
    } catch (e) {
      print('❌ Error counting active direct members: $e');
    }

    return activeDirectCount;
  }

  // Function to determine which levels are unlocked based on direct members count
  // ✅ UPDATED: Get unlocked levels based on ACTIVE DIRECT MEMBERS
  List<bool> _getUnlockedLevels() {
    List<bool> unlockedLevels = List.filled(11, false);

    // Level 1: Always unlocked for everyone
    unlockedLevels[0] = true;

    // Level 2-11: Unlocked based on ACTIVE DIRECT MEMBERS count only
    for (int i = 1; i < 11; i++) {
      if (_activeDirectMembersCount >= i) {
        unlockedLevels[i] = true;
      }
    }

    print('🔓 Current Level Unlock Status:');
    print('   Active Direct Members: $_activeDirectMembersCount');
    for (int i = 0; i < unlockedLevels.length; i++) {
      print('   Level ${i + 1}: ${unlockedLevels[i] ? "UNLOCKED" : "LOCKED"}');
    }

    return unlockedLevels;
  }

  // TeamDashboardScreen میں یہ function موجود ہے
  void _handleClaimEarnings() {
    if (_totalLevelEarnings <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No earnings available to withdraw",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: accentRed,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ✅ Open PackageWithdrawalScreen with pending amount
    _openWithdrawalScreen();
  }

  // ✅ ADD THIS: Function to open PackageWithdrawalScreen
  void _openWithdrawalScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PackageWithdrawalScreen(claimAmount: _totalLevelEarnings),
      ),
    ).then((result) {
      // Handle the result returned from PackageWithdrawalScreen
      if (result != null && result is double) {
        print('PackageWithdrawalScreen returned remaining balance: $result');

        // Update the UI with the remaining balance
        setState(() {
          _totalLevelEarnings = result;
        });

        // Also update Firestore if needed
        _updateTodayEarningsWithRemainingBalance(result);

        print('✅ Updated pending amount to: \$$result');
      } else if (result == null) {
        // User cancelled, no changes needed
        print('Withdrawal cancelled by user');
      }
    });
  }

  Future<void> _updateTodayEarningsWithRemainingBalance(
    double remainingBalance,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final todayString = _getTodayDateString();

      // Update Today Earnings collection
      await FirebaseFirestore.instance
          .collection('Today_Earnings')
          .doc(user.uid)
          .collection('daily_earnings')
          .doc(todayString)
          .update({
            'totalLevelEarnings': remainingBalance,
            'levelEarnings': {'levels': {}, 'total': remainingBalance},
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      print(
        '✅ Today Earnings updated to: \$${remainingBalance.toStringAsFixed(3)}',
      );
    } catch (e) {
      print('❌ Error updating today earnings: $e');
    }
  }

  void _processWithdrawal() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Processing withdrawal..."),
            ],
          ),
        ),
      );

      // Transfer earnings to main wallet
      final withdrawalAmount = _totalLevelEarnings;

      // Update wallet balance
      final walletRef = _firestore.collection('Sponsar_wallets').doc(user.uid);

      await walletRef.update({
        'availableBalance': FieldValue.increment(withdrawalAmount),
        'totalWithdrawals': FieldValue.increment(withdrawalAmount),
        'lastWithdrawal': FieldValue.serverTimestamp(),
      });

      // Clear pending earnings
      await walletRef.update({
        'calculatedLevelEarnings': {
          'levels': {},
          'total': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      });

      // Record withdrawal transaction
      final transactionRef = _firestore.collection('wallet_transactions').doc();

      await transactionRef.set({
        'userId': user.uid,
        'amount': withdrawalAmount,
        'type': 'level_earnings_withdrawal',
        'status': 'completed',
        'description': 'Withdrawal of level bonus earnings',
        'timestamp': FieldValue.serverTimestamp(),
        'previousBalance': 0, // You might want to track this
        'newBalance': withdrawalAmount,
      });

      // Close processing dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Successfully withdrawn \$${withdrawalAmount.toStringAsFixed(3)}!",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: accentGreen,
          duration: Duration(seconds: 3),
        ),
      );

      // Reset earnings after withdrawal
      setState(() {
        _totalLevelEarnings = 0.0;
        _levelEarnings.clear();
      });

      // Refresh data
      await _refreshAllData();
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      print('❌ Error processing withdrawal: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error processing withdrawal. Please try again.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: accentRed,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _processClaim() {
    // Here you would implement the actual claim logic
    // For now, we'll just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Successfully claimed \$${_totalLevelEarnings.toStringAsFixed(3)}!",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: accentGreen,
        duration: Duration(seconds: 3),
      ),
    );

    // Reset earnings after claim (in real app, you'd update Firestore)
    setState(() {
      _totalLevelEarnings = 0.0;
      _levelEarnings.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final unlockedLevels = _getUnlockedLevels();
    final levelPercentages = [20, 8, 7, 6, 5, 3, 2, 1, 1, 1, 1];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Center(
          child: Text(
            'Team Statistics',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.015,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Total Pending Earnings Box ----
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
                        Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: w * 0.06,
                        ),
                        SizedBox(width: w * 0.02),
                        Text(
                          "Total Claim Earnings",
                          style: TextStyle(
                            fontSize: w * 0.045,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: h * 0.015),

                    // ✅ IMPROVED: Show loading or actual earnings
                    _totalLevelEarnings > 0
                        ? Text(
                            "\$${_totalLevelEarnings.toStringAsFixed(3)}",
                            style: TextStyle(
                              fontSize: w * 0.08,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            "Calculating...",
                            style: TextStyle(
                              fontSize: w * 0.06,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),

                    SizedBox(height: h * 0.01),
                    Text(
                      "From ${_levelEarnings.length} bonus levels",
                      style: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: h * 0.015),

                    // ---- PENDING STATUS SECTION (MOVED UP) ----
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pending_actions,
                                color: Colors.white,
                                size: w * 0.045,
                              ),
                              SizedBox(width: w * 0.02),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Pending Amount",
                                    style: TextStyle(
                                      fontSize: w * 0.032,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  Text(
                                    "\$${_totalLevelEarnings.toStringAsFixed(3)}",
                                    style: TextStyle(
                                      fontSize: w * 0.04,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_totalLevelEarnings > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: w * 0.03,
                                vertical: h * 0.008,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green[100],
                                    size: w * 0.04,
                                  ),
                                  SizedBox(width: w * 0.01),
                                  Text(
                                    "Ready to withdraw",
                                    style: TextStyle(
                                      fontSize: w * 0.032,
                                      color: Colors.green[100],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: w * 0.03,
                                vertical: h * 0.008,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info,
                                    color: Colors.orange[100],
                                    size: w * 0.04,
                                  ),
                                  SizedBox(width: w * 0.01),
                                  Text(
                                    "No earnings yet",
                                    style: TextStyle(
                                      fontSize: w * 0.032,
                                      color: Colors.orange[100],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: h * 0.015),

                    // ---- BUTTONS SECTION (MOVED DOWN) ----
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _refreshAllData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryBlue,
                              padding: EdgeInsets.symmetric(
                                vertical: h * 0.014,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: primaryBlue,
                                  width: 1.5,
                                ),
                              ),
                              elevation: 3,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: w * 0.05),
                                SizedBox(width: w * 0.02),
                                Text(
                                  "Refresh",
                                  style: TextStyle(
                                    fontSize: w * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: w * 0.02),

                        // ✅ UPDATED: Withdraw Button that opens PackageWithdrawalScreen
                        if (_totalLevelEarnings > 0)
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _handleClaimEarnings, // ✅ Now opens PackageWithdrawalScreen
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: h * 0.014,
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
                                    Icons.account_balance_wallet,
                                    size: w * 0.05,
                                  ),
                                  SizedBox(width: w * 0.02),
                                  Text(
                                    "Withdraw",
                                    style: TextStyle(
                                      fontSize: w * 0.04,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: h * 0.03),

              // ---- Statistics Grid - 2x2 layout ----
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                crossAxisSpacing: w * 0.015,
                mainAxisSpacing: h * 0.012,
                children: [
                  _buildStatCard(
                    w,
                    h,
                    title: "Direct Members",
                    value: _directMembersCount.toString(),
                    icon: Icons.people,
                    color: primaryBlue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DirectMembersScreen(),
                        ),
                      );
                    },
                  ),
                  _buildStatCard(
                    w,
                    h,
                    title: "Total Team",
                    value: _totalTeamCount.toString(),
                    subtitle: "Complete Downline",
                    icon: Icons.groups,
                    color: accentGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TotalTeamScreen(),
                        ),
                      );
                    },
                  ),
                  _buildStatCard(
                    w,
                    h,
                    title: "Active Members",
                    value: _activeMembersCount.toString(),
                    icon: Icons.check_circle,
                    color: accentGreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MembersScreen(showActive: true),
                        ),
                      );
                    },
                  ),
                  _buildStatCard(
                    w,
                    h,
                    title: "Inactive Members",
                    value: _inactiveMembersCount.toString(),
                    icon: Icons.cancel,
                    color: accentRed,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MembersScreen(showActive: false),
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: h * 0.03),

              // ---- Bonus Levels Title ----
              Text(
                "Bonus Levels",
                style: TextStyle(
                  fontSize: w * 0.05,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              SizedBox(height: h * 0.015),

              // ---- Bonus Levels Cards - DYNAMIC BASED ON DIRECT MEMBERS ----
              ...List.generate(11, (index) {
                final levelNumber = index + 1;
                final percentage = levelPercentages[index];
                final isUnlocked = unlockedLevels[index];
                final requiredMembers = levelNumber == 1 ? 0 : levelNumber - 1;
                final levelEarning = _levelEarnings[levelNumber] ?? 0.0;

                return _buildLevelCard(
                  context,
                  w,
                  "Level $levelNumber",
                  "$percentage% Bonus",
                  levelEarning,
                  achieved: isUnlocked,
                  requiredMembers: requiredMembers,
                  levelNumber: levelNumber,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    double w,
    double h, {
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(w * 0.018),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryBlue.withOpacity(0.7), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.016),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: w * 0.055),
            ),
            SizedBox(height: h * 0.004),
            Text(
              value,
              style: TextStyle(
                fontSize: w * 0.055,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            SizedBox(height: h * 0.0015),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: w * 0.022, color: lightText),
            ),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(top: h * 0.001),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: w * 0.02,
                    color: accentGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ CORRECTED: Calculate total package bonus for specific level
  Future<double> _calculateTotalPackageBonusForLevel(int levelNumber) async {
    double totalBonus = 0.0;

    try {
      // Get all team members for current user
      final user = _auth.currentUser;
      if (user == null) return 0.0;

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return 0.0;

      final userData = userDoc.data() as Map<String, dynamic>;
      final referralCode = userData['referralCode'];

      if (referralCode == null || referralCode.isEmpty) return 0.0;

      // Get all team members
      final allTeamMemberIds = await _getAllTeamMemberIds(referralCode);

      // Calculate total package amount for this specific level
      for (final memberId in allTeamMemberIds) {
        final memberLevel = await _getMemberLevel(user.uid, memberId);

        if (memberLevel == levelNumber) {
          double memberBusiness = 0.0;

          // Check both collections for packages
          final packages1 = await _firestore
              .collection('users')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          final packages2 = await _firestore
              .collection('Signup_Data')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          // for (final package in packages1.docs) {
          //   memberBusiness += _extractPackageAmount(package.data());
          // }
          for (final package in packages1.docs) {
            final packageData = package.data();
            // Skip if package is activated by admin
            if (!_isPackageActivatedByAdmin(packageData)) {
              memberBusiness += _extractPackageAmount(packageData);
            }
          }

          // for (final package in packages2.docs) {
          //   memberBusiness += _extractPackageAmount(package.data());
          // }
          for (final package in packages2.docs) {
            final packageData = package.data();
            // Skip if package is activated by admin
            if (!_isPackageActivatedByAdmin(packageData)) {
              memberBusiness += _extractPackageAmount(packageData);
            }
          }
          totalBonus += memberBusiness;
        }
      }
    } catch (e) {
      print(
        '❌ Error calculating total package bonus for level $levelNumber: $e',
      );
    }

    return totalBonus;
  }

  // ✅ CORRECTED: Get member count for specific level
  // ✅ UPDATED: Get member count for specific level (INCLUDING admin-activated packages)
  Future<int> _getMemberCountForLevel(int levelNumber) async {
    int memberCount = 0;

    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return 0;

      final userData = userDoc.data() as Map<String, dynamic>;
      final referralCode = userData['referralCode'];

      if (referralCode == null || referralCode.isEmpty) return 0;

      // Get all team members
      final allTeamMemberIds = await _getAllTeamMemberIds(referralCode);

      // Count members at this specific level (INCLUDING those with admin packages)
      for (final memberId in allTeamMemberIds) {
        final memberLevel = await _getMemberLevel(user.uid, memberId);
        if (memberLevel == levelNumber) {
          bool hasAnyPackages = false;

          // Check if member has ANY purchased packages (BOTH user AND admin)
          final packagesQuery = await _firestore
              .collection('users')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          // ✅ CHANGED: Count if ANY packages exist
          if (packagesQuery.docs.isNotEmpty) {
            hasAnyPackages = true;
          }

          // Also check Signup_Data collection
          if (!hasAnyPackages) {
            final signupPackagesQuery = await _firestore
                .collection('Signup_Data')
                .doc(memberId)
                .collection('purchasedPackages')
                .get();

            // ✅ CHANGED: Count if ANY packages exist
            if (signupPackagesQuery.docs.isNotEmpty) {
              hasAnyPackages = true;
            }
          }

          if (hasAnyPackages) {
            memberCount++;
          }
        }
      }

      print(
        '👥 Level $levelNumber Total Members Count (including admin): $memberCount',
      );
    } catch (e) {
      print('❌ Error getting member count for level $levelNumber: $e');
    }

    return memberCount;
  }

  // ✅ UPDATED: Level card with cumulative earnings
  // ✅ UPDATED: Level card with better earning display
  Widget _buildLevelCard(
    BuildContext context,
    double w,
    String level,
    String bonus,
    double levelEarning, {
    bool achieved = false,
    int requiredMembers = 0,
    int levelNumber = 0,
  }) {
    // Get the actual level earning for this specific level
    final currentLevelEarning = _levelEarnings[levelNumber] ?? 0.0;

    return GestureDetector(
      onTap: () {
        if (achieved) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BonusLevelDetailsScreen(
                level: level,
                bonus: bonus,
                progress: currentLevelEarning,
                achieved: achieved,
                requirements: [
                  if (requiredMembers > 0)
                    "Bring $requiredMembers active direct members",
                  "Earn when your direct members bring their own members",
                  "Maintain active team performance",
                ],
                preloadedData: {
                  'userFullName': 'Current User Name',
                  'userEmail': 'user@email.com',
                  'userName': 'username',
                  'userLevel': '1',
                  'joiningDate': '15 Jan 2024',
                  'userPackage': 'Starter Package',
                  'levelEarning': currentLevelEarning,
                  'cumulativeEarning': currentLevelEarning,
                  'totalBusiness': _totalLevelEarnings,
                },
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: w * 0.04),
        padding: EdgeInsets.all(w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level and Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level Text
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level,
                      style: TextStyle(
                        fontSize: w * 0.05,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    SizedBox(height: w * 0.01),
                    Text(
                      "$bonus from Level $levelNumber members",
                      style: TextStyle(fontSize: w * 0.03, color: lightText),
                    ),
                    if (achieved)
                      Text(
                        "💡 Only user-purchased packages",
                        style: TextStyle(
                          fontSize: w * 0.025,
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),

                // Status Badge with Lock/Unlock Icons
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: w * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: achieved
                        ? accentGreen.withOpacity(0.2)
                        : accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: achieved ? accentGreen : accentRed,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        achieved ? Icons.lock_open : Icons.lock,
                        size: w * 0.035,
                        color: achieved ? accentGreen : accentRed,
                      ),
                      SizedBox(width: w * 0.01),
                      Text(
                        achieved ? "Active" : "Locked",
                        style: TextStyle(
                          color: achieved ? accentGreen : accentRed,
                          fontWeight: FontWeight.w600,
                          fontSize: w * 0.032,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: w * 0.025),

            // Information Container with better styling
            Container(
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Current Level Earnings - ALWAYS SHOW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Level $levelNumber Earnings:",
                        style: TextStyle(
                          fontSize: w * 0.038,
                          color: lightText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "\$${currentLevelEarning.toStringAsFixed(3)}",
                            style: TextStyle(
                              fontSize: w * 0.038,
                              color: currentLevelEarning > 0
                                  ? accentGreen
                                  : lightText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: w * 0.005),
                          Text(
                            "${bonus.split(' ')[0]} from Level $levelNumber",
                            style: TextStyle(
                              fontSize: w * 0.03,
                              color: primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: w * 0.02),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                  SizedBox(height: w * 0.02),

                  // Total Business - ONLY SHOW FOR UNLOCKED LEVELS
                  if (achieved)
                    FutureBuilder<double>(
                      future: _calculateTotalPackageBonusForLevel(levelNumber),
                      builder: (context, snapshot) {
                        double totalBonus = 0.0;
                        int memberCount = 0;

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Business:",
                                style: TextStyle(
                                  fontSize: w * 0.038,
                                  color: lightText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Calculating...",
                                style: TextStyle(
                                  fontSize: w * 0.038,
                                  color: lightText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        }

                        if (snapshot.hasData) {
                          totalBonus = snapshot.data!;
                        }

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total Business:",
                                  style: TextStyle(
                                    fontSize: w * 0.038,
                                    color: lightText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "\$${totalBonus.toStringAsFixed(3)}",
                                      style: TextStyle(
                                        fontSize: w * 0.038,
                                        color: totalBonus > 0
                                            ? accentGreen
                                            : lightText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: w * 0.005),
                                    FutureBuilder<int>(
                                      future: _getMemberCountForLevel(
                                        levelNumber,
                                      ),
                                      builder: (context, countSnapshot) {
                                        if (countSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Text(
                                            "Loading members...",
                                            style: TextStyle(
                                              fontSize: w * 0.03,
                                              color: primaryBlue,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        }

                                        memberCount = countSnapshot.data ?? 0;

                                        return Text(
                                          "From $memberCount members",
                                          style: TextStyle(
                                            fontSize: w * 0.03,
                                            color: primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (totalBonus == 0 && memberCount > 0)
                              Container(
                                margin: EdgeInsets.only(top: w * 0.01),
                                padding: EdgeInsets.all(w * 0.02),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      size: w * 0.035,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: w * 0.01),
                                    Expanded(
                                      child: Text(
                                        "Members have only admin-activated packages",
                                        style: TextStyle(
                                          fontSize: w * 0.025,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  else
                    // LOCKED LEVEL MESSAGE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Status:",
                          style: TextStyle(
                            fontSize: w * 0.038,
                            color: lightText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Locked",
                              style: TextStyle(
                                fontSize: w * 0.038,
                                color: accentRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: w * 0.005),
                            Text(
                              "Complete requirements to unlock",
                              style: TextStyle(
                                fontSize: w * 0.03,
                                color: accentRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(height: w * 0.02),

            Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
            SizedBox(height: w * 0.02),

            // ✅ NEW: Show if level has members but no earnings (ONLY FOR UNLOCKED)
            if (achieved && currentLevelEarning == 0)
              Container(
                padding: EdgeInsets.all(w * 0.02),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange, size: w * 0.04),
                    SizedBox(width: w * 0.02),
                    Expanded(
                      child: Text(
                        "Level unlocked but members haven't purchased packages yet",
                        style: TextStyle(
                          fontSize: w * 0.03,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Tap for details with arrow icon - ONLY FOR UNLOCKED LEVELS
            if (achieved)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "View earning details",
                      style: TextStyle(
                        fontSize: w * 0.032,
                        color: primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: w * 0.01),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: w * 0.035,
                      color: primaryBlue,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Add this method to get total team business
  double _getTotalTeamBusiness() {
    // Calculate total business from level earnings
    if (_levelEarnings.isEmpty) return 0.0;

    double totalBusiness = 0.0;
    final levelPercentages = [20, 8, 7, 6, 5, 3, 2, 1, 1, 1, 1];

    for (int level = 1; level <= 11; level++) {
      final levelEarning = _levelEarnings[level] ?? 0.0;
      final percentage = levelPercentages[level - 1];

      if (levelEarning > 0 && percentage > 0) {
        // Reverse calculate: business = (earning * 100) / percentage
        final levelBusiness = (levelEarning * 100) / percentage;
        totalBusiness =
            levelBusiness; // Since all levels use same total business
        break; // All levels use the same total business, so we can break after first calculation
      }
    }

    return totalBusiness;
  }

  // ✅ UPDATED: Calculate earnings with package bonus caching
  // ✅ UPDATED: Calculate earnings - ONLY NEW EARNINGS, NO WASTAGE RECOVERY
  // ✅ UPDATED: Calculate earnings - Only show earnings for unlocked levels, completely ignore locked levels
  Future<void> _calculateAndUpdateLevelEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🧮 Calculating level earnings for user: ${user.uid}');

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final referralCode = userData['referralCode'];
      if (referralCode == null || referralCode.isEmpty) return;

      // Get active direct members count for level locking
      final activeDirectCount = await _getActiveDirectMembersCount(
        referralCode,
      );

      // Get ALL team members
      final allTeamMemberIds = await _getAllTeamMemberIds(referralCode);

      Map<int, double> levelEarnings = {};
      Map<int, List<Map<String, dynamic>>> levelMembers = {};

      // Reset caches
      _levelPackageBonus.clear();
      _levelMemberCounts.clear();

      print('🔍 Checking packages for ${allTeamMemberIds.length} team members');

      // First pass: Identify members at each level and their business
      for (final memberId in allTeamMemberIds) {
        try {
          final memberLevel = await _getMemberLevel(user.uid, memberId);
          if (memberLevel == 0 || memberLevel > 11) continue;

          double memberBusiness = 0.0;

          // Check packages from both collections
          final packages1 = await _firestore
              .collection('users')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          final packages2 = await _firestore
              .collection('Signup_Data')
              .doc(memberId)
              .collection('purchasedPackages')
              .get();

          // ✅ UPDATED: Calculate business EXCLUDING admin-activated packages
          for (final package in packages1.docs) {
            final packageData = package.data();
            // Skip if package is activated by admin
            if (!_isPackageActivatedByAdmin(packageData)) {
              memberBusiness += _extractPackageAmount(packageData);
            }
          }

          for (final package in packages2.docs) {
            final packageData = package.data();
            // Skip if package is activated by admin
            if (!_isPackageActivatedByAdmin(packageData)) {
              memberBusiness += _extractPackageAmount(packageData);
            }
          }

          if (memberBusiness > 0) {
            final memberDoc = await _firestore
                .collection('Signup_Data')
                .doc(memberId)
                .get();
            if (memberDoc.exists) {
              final memberData = memberDoc.data() as Map<String, dynamic>;
              levelMembers.putIfAbsent(memberLevel, () => []).add({
                'name': memberData['name'] ?? 'Unknown',
                'business': memberBusiness,
                'userId': memberId,
              });
            }
          }

          _levelPackageBonus[memberLevel] =
              (_levelPackageBonus[memberLevel] ?? 0.0) + memberBusiness;
          _levelMemberCounts[memberLevel] =
              (_levelMemberCounts[memberLevel] ?? 0) + 1;
        } catch (e) {
          print('❌ Error processing member $memberId: $e');
        }
      }

      // Define level percentages
      final levelPercentages = [20, 8, 7, 6, 5, 3, 2, 1, 1, 1, 1];
      final List<bool> currentUnlockedLevels = _getUnlockedLevels();

      // ✅ UPDATED: Calculate earnings - COMPLETELY IGNORE locked levels
      for (int level = 1; level <= 11; level++) {
        final isLocked = _isLevelLocked(level, activeDirectCount);

        final membersAtThisLevel = levelMembers[level] ?? [];
        double levelBusiness = 0.0;

        // Sum business from members at this specific level
        for (final member in membersAtThisLevel) {
          levelBusiness += member['business'];
        }

        if (levelBusiness > 0) {
          final percentage = levelPercentages[level - 1];
          final calculatedEarning = (levelBusiness * percentage) / 100;

          if (isLocked) {
            // 🔒 LEVEL LOCKED: COMPLETELY IGNORE - don't store, don't show
            print(
              '   🔒 Level $level LOCKED: \$$calculatedEarning COMPLETELY IGNORED',
            );
            levelEarnings[level] = 0.0; // Show 0 in UI
          } else {
            // ✅ LEVEL UNLOCKED: Show actual earnings
            levelEarnings[level] = calculatedEarning;
            print('   ✅ Level $level UNLOCKED: \$$calculatedEarning');
          }
        } else {
          levelEarnings[level] = 0.0;
          if (isLocked) {
            print('   🔒 Level $level LOCKED: No business available');
          } else {
            print('   ⚠️ Level $level UNLOCKED: No business available');
          }
        }
      }

      // Calculate total earnings (only from unlocked levels)
      final totalEarnings = levelEarnings.values.fold(
        0.0,
        (sum, earning) => sum + earning,
      );

      print('🎯 Final Level Earnings (Only Unlocked): $levelEarnings');
      print('🎉 Total Earnings (Only Unlocked): \$$totalEarnings');
      await _storeCurrentUnlockedStatus(user.uid, currentUnlockedLevels);

      // Update Firestore and UI
      await _updateEarningsInFirestore(user.uid, levelEarnings, totalEarnings);
      await _storeInMyTotalEarning(user.uid, levelEarnings, totalEarnings);

      setState(() {
        _levelEarnings = levelEarnings;
        _totalLevelEarnings = totalEarnings;
      });

      print('🔄 UI Updated with Only Unlocked Level Earnings');
    } catch (e) {
      print('❌ Error calculating level earnings: $e');
    }
  }

  Future<void> _storeCurrentUnlockedStatus(
    String userId,
    List<bool> unlockedLevels,
  ) async {
    try {
      final statusMap = <String, bool>{};
      for (int i = 0; i < unlockedLevels.length; i++) {
        statusMap['level_${i + 1}'] = unlockedLevels[i];
      }

      await _firestore.collection('user_level_status').doc(userId).set({
        'unlockedLevels': statusMap,
        'lastUpdated': FieldValue.serverTimestamp(),
        'activeDirectMembers': _activeDirectMembersCount,
      }, SetOptions(merge: true));

      print('📊 Stored current unlocked levels status: $statusMap');
    } catch (e) {
      print('❌ Error storing level status: $e');
    }
  }

  // 🆕 NEW: Get previous unlocked status to detect changes
  Future<Map<String, bool>> _getPreviousUnlockedStatus(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_level_status')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final unlockedLevels = data['unlockedLevels'] as Map<String, dynamic>?;

        if (unlockedLevels != null) {
          final Map<String, bool> result = {};
          unlockedLevels.forEach((key, value) {
            result[key] = value == true;
          });
          return result;
        }
      }
    } catch (e) {
      print('❌ Error getting previous unlocked status: $e');
    }

    return {};
  }

  // 🆕 NEW: Store wastage data in Firestore
  Future<void> _storeWastageInFirestore(
    int level,
    double amount,
    double business,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || amount <= 0) return;

      final wastageRef = _firestore.collection('Level_Wastage').doc(user.uid);
      final todayString = _getTodayDateString();

      final wastageEntry = {
        'amount': amount,
        'business': business,
        'level': level,
        'date': todayString,
        'timestamp': FieldValue.serverTimestamp(),
        'reason': 'Level $level is locked',
        'userId': user.uid,
      };

      await wastageRef.set({
        'totalWasted': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'wastageEntries': FieldValue.arrayUnion([wastageEntry]),
      }, SetOptions(merge: true));

      print('Wastage stored: Level $level - \$$amount (Business \$$business)');
    } catch (e) {
      print('Error storing wastage: $e');
    }
  }

  // 🆕 OPTIONAL: Show wastage summary in UI
  Widget _buildWastageSummary(double w, double h) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('Level_Wastage')
          .doc(_auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final totalWasted = (data['totalWasted'] ?? 0.0).toDouble();

        if (totalWasted == 0) return SizedBox.shrink();

        return Container(
          padding: EdgeInsets.all(w * 0.03),
          margin: EdgeInsets.only(bottom: h * 0.02),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            children: [
              Icon(Icons.money_off, color: Colors.orange, size: w * 0.05),
              SizedBox(width: w * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Locked Level Earnings",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    Text(
                      "\$${totalWasted.toStringAsFixed(2)} waiting in locked levels",
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: w * 0.035,
                      ),
                    ),
                    Text(
                      "Complete levels to unlock these earnings",
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontSize: w * 0.03,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🆕 NEW: Method to check if we should calculate earnings (prevent unnecessary calculations)
  Future<bool> _shouldCalculateEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final todayString = _getTodayDateString();

      final todayDoc = await _firestore
          .collection('Today_Earnings')
          .doc(user.uid)
          .collection('daily_earnings')
          .doc(todayString)
          .get();

      if (!todayDoc.exists) return true;

      final data = todayDoc.data() as Map<String, dynamic>?;
      if (data == null) return true;

      final lastCalculation = data['lastCalculationTime'] as Timestamp?;
      if (lastCalculation == null) return true;

      // Only calculate if it's been more than 1 hour since last calculation
      final now = DateTime.now();
      final lastCalcTime = lastCalculation.toDate();
      final difference = now.difference(lastCalcTime);

      return difference.inHours >= 1;
    } catch (e) {
      print('❌ Error checking calculation timing: $e');
      return true;
    }
  }

  // 🆕 ADD THIS: Helper method to get today's date string
  String _getTodayDateString() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }

  // ✅ NEW: Helper method to extract package amount from different data formats
  double _extractPackageAmount(Map<String, dynamic> packageData) {
    try {
      print('🔍 Extracting amount from: $packageData');

      // Try different possible amount fields with proper string handling

      // 1. Try totalAmount first (numeric)
      if (packageData['totalAmount'] != null) {
        final totalAmount = packageData['totalAmount'];
        if (totalAmount is double) return totalAmount;
        if (totalAmount is int) return totalAmount.toDouble();
        if (totalAmount is String) {
          final cleaned = totalAmount.replaceAll('\$', '').trim();
          return double.tryParse(cleaned) ?? 0.0;
        }
      }

      // 2. Try packagePrice (could be string like "$5")
      if (packageData['packagePrice'] != null) {
        final packagePrice = packageData['packagePrice'];
        if (packagePrice is double) return packagePrice;
        if (packagePrice is int) return packagePrice.toDouble();
        if (packagePrice is String) {
          final cleaned = packagePrice.replaceAll('\$', '').trim();
          return double.tryParse(cleaned) ?? 0.0;
        }
      }

      // 3. Try amount field
      if (packageData['amount'] != null) {
        final amount = packageData['amount'];
        if (amount is double) return amount;
        if (amount is int) return amount.toDouble();
        if (amount is String) {
          final cleaned = amount.replaceAll('\$', '').trim();
          return double.tryParse(cleaned) ?? 0.0;
        }
      }

      // 4. Try price_amount
      if (packageData['price_amount'] != null) {
        final priceAmount = packageData['price_amount'];
        if (priceAmount is double) return priceAmount;
        if (priceAmount is int) return priceAmount.toDouble();
        if (priceAmount is String) {
          final cleaned = priceAmount.replaceAll('\$', '').trim();
          return double.tryParse(cleaned) ?? 0.0;
        }
      }

      // 5. Try pay_amount
      if (packageData['pay_amount'] != null) {
        final payAmount = packageData['pay_amount'];
        if (payAmount is double) return payAmount;
        if (payAmount is int) return payAmount.toDouble();
        if (payAmount is String) {
          final cleaned = payAmount.replaceAll('\$', '').trim();
          return double.tryParse(cleaned) ?? 0.0;
        }
      }

      print('⚠️ No valid amount found in package data');
      return 0.0;
    } catch (e) {
      print('❌ Error extracting package amount: $e');
      return 0.0;
    }
  }
}
