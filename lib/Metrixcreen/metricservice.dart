// matrix_service.dart - COMPLETELY FIXED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatrixService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize user matrix when deposit is completed
  Future<void> initializeUserMatrix(String userId) async {
    try {
      // Get user data
      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(userId)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final referralCode = userData['referralCode'];

      // Create user matrix document
      await _firestore.collection('user_matrices').doc(userId).set({
        'userId': userId,
        'name': userData['name'],
        'referralCode': referralCode,
        'wallet_balance': 0.0,
        'current_matrix': 1,
        'matrix1_status': 'active',
        'matrix1_filled': 0,
        'matrix2_status': 'locked',
        'matrix2_filled': 0,
        'matrix3_status': 'locked',
        'matrix3_filled': 0,
        'matrix4_status': 'locked',
        'matrix4_filled': 0,
        'matrix5_status': 'locked',
        'matrix5_filled': 0,
        'matrix6_status': 'locked',
        'matrix6_filled': 0,
        'matrix7_status': 'locked',
        'matrix7_filled': 0,
        'matrix8_status': 'locked',
        'matrix8_filled': 0,
        'total_earnings': 0.0,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('✅ Matrix initialized for user: $userId');

      // ✅ FIXED: Add to global queue and process immediately
      await _addUserToGlobalQueue(userId);
    } catch (e) {
      print('❌ Error initializing user matrix: $e');
      rethrow;
    }
  }

  // Add user to global matrix placement queue
  Future<void> _addUserToGlobalQueue(String userId) async {
    try {
      await _firestore.collection('global_matrix_queue').add({
        'userId': userId,
        'status': 'waiting',
        'created_at': FieldValue.serverTimestamp(),
      });

      print('✅ User $userId added to global queue');

      // Process the queue to place user in matrix
      await _processMatrixPlacement();
    } catch (e) {
      print('❌ Error adding user to queue: $e');
    }
  }

  // ✅ FIXED: Process matrix placement - SIMPLIFIED GLOBAL FIFO
  Future<void> _processMatrixPlacement() async {
    try {
      // Get waiting users from queue (FIFO order)
      final queueSnapshot = await _firestore
          .collection('global_matrix_queue')
          .where('status', isEqualTo: 'waiting')
          .orderBy('created_at')
          .limit(10)
          .get();

      if (queueSnapshot.docs.isEmpty) {
        print('⏳ No waiting users in queue');
        return;
      }

      print('🔄 Processing ${queueSnapshot.docs.length} users from queue');

      // ✅ FIXED: Get all available sponsors first
      final availableSponsors = await _getAllAvailableSponsors();

      if (availableSponsors.isEmpty) {
        print('❌ No available sponsors found');
        return;
      }

      print('🎯 Found ${availableSponsors.length} available sponsors');

      for (var queueDoc in queueSnapshot.docs) {
        final userId = queueDoc['userId'];

        // Check if user is already placed
        final userMatrixDoc = await _firestore
            .collection('user_matrices')
            .doc(userId)
            .get();

        if (userMatrixDoc.exists) {
          final userData = userMatrixDoc.data();
          if (userData?['sponsor_id'] != null) {
            print('⏩ User $userId already placed, skipping');
            await queueDoc.reference.update({'status': 'placed'});
            continue;
          }
        }

        // ✅ FIXED: Find the first available sponsor with Matrix 1 open slots
        String? sponsorId;
        int targetLevel = 1;
        int currentFilled = 0;

        for (var sponsor in availableSponsors) {
          final sponsorUserId = sponsor['userId'];
          final matrix1Filled = sponsor['matrix1_filled'] ?? 0;

          if (matrix1Filled < 4) {
            sponsorId = sponsorUserId;
            currentFilled = matrix1Filled;
            break;
          }
        }

        if (sponsorId != null) {
          print(
            '🎯 Placing user $userId under sponsor $sponsorId (Matrix 1: $currentFilled/4)',
          );

          await _placeUserInMatrix(
            userId,
            sponsorId,
            targetLevel,
            currentFilled,
          );

          // Update queue status
          await queueDoc.reference.update({
            'status': 'placed',
            'sponsor_id': sponsorId,
            'placed_at': FieldValue.serverTimestamp(),
          });

          print('✅ User $userId successfully placed under sponsor $sponsorId');
        } else {
          print('⏳ No Matrix 1 slots available for user $userId (will retry)');
        }
      }
    } catch (e) {
      print('❌ Error processing matrix placement: $e');
    }
  }

  // ✅ NEW: Get all available sponsors with their matrix data
  Future<List<Map<String, dynamic>>> _getAllAvailableSponsors() async {
    try {
      // Get all users with active matrices, ordered by creation date (FIFO)
      final usersSnapshot = await _firestore
          .collection('user_matrices')
          .orderBy('created_at')
          .get();

      List<Map<String, dynamic>> availableSponsors = [];

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final matrixData = userDoc.data();

        // Check if user has any active matrix with open slots
        for (int level = 1; level <= 8; level++) {
          final matrixStatus = matrixData['matrix${level}_status'] ?? 'locked';
          final matrixFilled = matrixData['matrix${level}_filled'] ?? 0;

          if (matrixStatus == 'active' && matrixFilled < 4) {
            availableSponsors.add({
              'userId': userId,
              'matrix${level}_filled': matrixFilled,
              'matrix${level}_status': matrixStatus,
            });
            break; // Move to next user after finding first available matrix
          }
        }
      }

      print('📊 Available sponsors breakdown:');
      for (var sponsor in availableSponsors) {
        print(
          ' - User: ${sponsor['userId']} | Matrix 1: ${sponsor['matrix1_filled'] ?? 0}/4',
        );
      }

      return availableSponsors;
    } catch (e) {
      print('❌ Error getting available sponsors: $e');
      return [];
    }
  }

  // ✅ FIXED: Place user in sponsor's matrix
  Future<void> _placeUserInMatrix(
    String userId,
    String sponsorId,
    int targetLevel,
    int currentFilled,
  ) async {
    try {
      final sponsorDoc = await _firestore
          .collection('user_matrices')
          .doc(sponsorId)
          .get();

      if (!sponsorDoc.exists) {
        print('❌ Sponsor $sponsorId not found');
        return;
      }

      final newFilled = currentFilled + 1;

      // ✅ FIXED: Update sponsor's matrix slots
      await sponsorDoc.reference.update({
        'matrix${targetLevel}_filled': newFilled,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('📈 Sponsor $sponsorId Matrix $targetLevel updated: $newFilled/4');

      // Create matrix record for the placed user
      await _firestore.collection('matrices').add({
        'matrix_id': '${sponsorId}_M${targetLevel}_$newFilled',
        'user_id': userId,
        'sponsor_id': sponsorId,
        'level': targetLevel,
        'slot_position': newFilled,
        'status': 'filled',
        'placement_type': 'global_fifo',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update user's sponsor information
      await _firestore.collection('user_matrices').doc(userId).update({
        'sponsor_id': sponsorId,
        'sponsor_level': targetLevel,
        'placement_type': 'global_fifo',
        'updated_at': FieldValue.serverTimestamp(),
      });

      print(
        '✅ User $userId placed in Matrix $targetLevel slot $newFilled of sponsor $sponsorId',
      );

      // ✅ FIXED: Check if sponsor's matrix is complete
      if (newFilled == 4) {
        print(
          '🎉 Sponsor $sponsorId Matrix $targetLevel completed! Processing earnings...',
        );
        await _processMatrixCompletion(sponsorId, targetLevel);
      }
    } catch (e) {
      print('❌ Error placing user in matrix: $e');
    }
  }

  // Process matrix completion and earnings
  Future<void> _processMatrixCompletion(String userId, int matrixLevel) async {
    try {
      final matrixDoc = await _firestore
          .collection('user_matrices')
          .doc(userId)
          .get();

      if (!matrixDoc.exists) return;

      final matrixData = matrixDoc.data() as Map<String, dynamic>;
      final earnings = _calculateMatrixEarnings(matrixLevel);

      // Update user earnings and mark matrix as completed
      await matrixDoc.reference.update({
        'total_earnings': FieldValue.increment(earnings['total']!),
        'wallet_balance': FieldValue.increment(earnings['wallet']!),
        'matrix${matrixLevel}_status': 'completed',
        'matrix${matrixLevel}_filled': 0,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // If not the last matrix, unlock the next one
      if (matrixLevel < 8) {
        await matrixDoc.reference.update({
          'matrix${matrixLevel + 1}_status': 'active',
          'current_matrix': matrixLevel + 1,
        });
        print('🔓 Unlocked Matrix ${matrixLevel + 1} for user $userId');
      }

      // Create earning transaction
      await _addEarningTransaction(
        userId,
        earnings['total']!,
        matrixLevel,
        earnings['wallet']!,
        earnings['unlock']!,
      );

      // Create matrix completion record
      await _firestore.collection('matrices').add({
        'matrix_id': '${userId}_M${matrixLevel}_completed',
        'user_id': userId,
        'level': matrixLevel,
        'slots_filled': 4,
        'completed': true,
        'income_generated': earnings['total'],
        'wallet_credit': earnings['wallet'],
        'used_to_unlock': earnings['unlock'],
        'created_at': FieldValue.serverTimestamp(),
      });

      // Chain logic: Fill sponsor's next matrix level
      final sponsorId = matrixData['sponsor_id'];
      if (sponsorId != null && sponsorId.isNotEmpty) {
        final sponsorLevel = matrixData['sponsor_level'] ?? 1;
        final nextLevel = sponsorLevel + 1;

        if (nextLevel <= 8) {
          print(
            '⛓️ Chain progression: Filling sponsor $sponsorId Matrix $nextLevel',
          );
          await _fillSponsorMatrix(sponsorId, nextLevel);
        }
      }

      print(
        '💰 Matrix $matrixLevel completed for user $userId - Earnings: \$${earnings['total']}',
      );
    } catch (e) {
      print('❌ Error processing matrix completion: $e');
    }
  }

  // Fill sponsor's next matrix level (Chain progression)
  Future<void> _fillSponsorMatrix(String sponsorId, int matrixLevel) async {
    try {
      if (matrixLevel > 8) return;

      final sponsorDoc = await _firestore
          .collection('user_matrices')
          .doc(sponsorId)
          .get();

      if (!sponsorDoc.exists) return;

      final sponsorData = sponsorDoc.data() as Map<String, dynamic>;

      // Ensure the matrix level is active
      final matrixStatus =
          sponsorData['matrix${matrixLevel}_status'] ?? 'locked';
      if (matrixStatus == 'locked') {
        await sponsorDoc.reference.update({
          'matrix${matrixLevel}_status': 'active',
        });
      }

      final currentFilled = sponsorData['matrix${matrixLevel}_filled'] ?? 0;
      final newFilled = currentFilled + 1;

      await sponsorDoc.reference.update({
        'matrix${matrixLevel}_filled': newFilled,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Create matrix fill record
      await _firestore.collection('matrices').add({
        'matrix_id': '${sponsorId}_M${matrixLevel}_$newFilled',
        'sponsor_id': sponsorId,
        'level': matrixLevel,
        'slot_position': newFilled,
        'filled_by_completion': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      print(
        '⛓️ Sponsor $sponsorId Matrix $matrixLevel slot $newFilled filled by chain',
      );

      // Check if sponsor's matrix is complete
      if (newFilled == 4) {
        await _processMatrixCompletion(sponsorId, matrixLevel);
      }
    } catch (e) {
      print('❌ Error filling sponsor matrix: $e');
    }
  }

  // Calculate earnings for matrix level (50% wallet, 50% unlock next)
  Map<String, double> _calculateMatrixEarnings(int matrixLevel) {
    Map<int, Map<String, double>> earningsMap = {
      1: {'total': 40.0, 'wallet': 20.0, 'unlock': 20.0},
      2: {'total': 80.0, 'wallet': 40.0, 'unlock': 40.0},
      3: {'total': 160.0, 'wallet': 80.0, 'unlock': 80.0},
      4: {'total': 320.0, 'wallet': 160.0, 'unlock': 160.0},
      5: {'total': 640.0, 'wallet': 320.0, 'unlock': 320.0},
      6: {'total': 1280.0, 'wallet': 640.0, 'unlock': 640.0},
      7: {'total': 2560.0, 'wallet': 1280.0, 'unlock': 1280.0},
      8: {'total': 5120.0, 'wallet': 2560.0, 'unlock': 2560.0},
    };

    return earningsMap[matrixLevel] ??
        {'total': 0.0, 'wallet': 0.0, 'unlock': 0.0};
  }

  // Add earning transaction
  Future<void> _addEarningTransaction(
    String userId,
    double totalAmount,
    int matrixLevel,
    double walletAmount,
    double unlockAmount,
  ) async {
    try {
      // Wallet credit transaction
      await _firestore
          .collection('users_matric_wallet')
          .doc(userId)
          .collection('matrix_transactions')
          .add({
            'amount': walletAmount,
            'type': 'wallet_credit',
            'matrix_level': matrixLevel,
            'description': 'Matrix $matrixLevel Completion - Wallet Credit',
            'status': 'completed',
            'created_at': FieldValue.serverTimestamp(),
          });

      // Unlock next matrix transaction (only if not last level)
      if (matrixLevel < 8) {
        await _firestore
            .collection('users_matric_wallet')
            .doc(userId)
            .collection('matrix_transactions')
            .add({
              'amount': unlockAmount,
              'type': 'unlock_next',
              'matrix_level': matrixLevel,
              'description':
                  'Matrix $matrixLevel Completion - Unlock Matrix ${matrixLevel + 1}',
              'status': 'completed',
              'created_at': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('❌ Error adding earning transaction: $e');
    }
  }

  // Get user matrix data
  Future<Map<String, dynamic>?> getUserMatrixData(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_matrices')
          .doc(userId)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('❌ Error getting user matrix data: $e');
      return null;
    }
  }

  // Get matrix statistics
  Future<Map<String, dynamic>> getMatrixStats(String userId) async {
    try {
      final matrixData = await getUserMatrixData(userId);
      if (matrixData == null) {
        return {
          'total_earnings': 0.0,
          'wallet_balance': 0.0,
          'active_matrices': 0,
          'completed_matrices': 0,
          'current_matrix': 1,
        };
      }

      int activeMatrices = 0;
      int completedMatrices = 0;

      for (int i = 1; i <= 8; i++) {
        final status = matrixData['matrix${i}_status'] ?? 'locked';
        if (status == 'active') activeMatrices++;
        if (status == 'completed') completedMatrices++;
      }

      return {
        'total_earnings': (matrixData['total_earnings'] ?? 0).toDouble(),
        'wallet_balance': (matrixData['wallet_balance'] ?? 0).toDouble(),
        'active_matrices': activeMatrices,
        'completed_matrices': completedMatrices,
        'current_matrix': matrixData['current_matrix'] ?? 1,
      };
    } catch (e) {
      print('❌ Error getting matrix stats: $e');
      return {
        'total_earnings': 0.0,
        'wallet_balance': 0.0,
        'active_matrices': 0,
        'completed_matrices': 0,
        'current_matrix': 1,
      };
    }
  }

  // Get user's matrix progression history
  Future<List<Map<String, dynamic>>> getMatrixHistory(String userId) async {
    try {
      final historySnapshot = await _firestore
          .collection('matrices')
          .where('user_id', isEqualTo: userId)
          .get();

      // Sort manually in code instead of using orderBy
      final sortedDocs = historySnapshot.docs.toList()
        ..sort((a, b) {
          final aTime = a['created_at'] ?? Timestamp.now();
          final bTime = b['created_at'] ?? Timestamp.now();
          return bTime.compareTo(aTime); // Descending
        });

      return sortedDocs.take(20).map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'created_at': data['created_at']?.toDate(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting matrix history: $e');
      return [];
    }
  }

  // Get user's downline members
  Future<List<Map<String, dynamic>>> getDownlineMembers(String userId) async {
    try {
      final downlineSnapshot = await _firestore
          .collection('user_matrices')
          .where('sponsor_id', isEqualTo: userId)
          .get();

      return downlineSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'current_matrix': data['current_matrix'] ?? 1,
          'joined_at': data['created_at']?.toDate(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting downline members: $e');
      return [];
    }
  }

  // MANUAL: Force process queue (for testing)
  Future<void> forceProcessQueue() async {
    print('🔄 Manually processing matrix queue...');
    await _processMatrixPlacement();
  }

  // MANUAL: Check queue status
  Future<void> checkQueueStatus() async {
    final queueSnapshot = await _firestore
        .collection('global_matrix_queue')
        .where('status', isEqualTo: 'waiting')
        .orderBy('created_at')
        .get();

    print('📊 Queue status: ${queueSnapshot.docs.length} waiting users');

    for (var doc in queueSnapshot.docs) {
      print(' - User: ${doc['userId']} | Created: ${doc['created_at']}');
    }
  }

  // MANUAL: Debug current system state
  Future<void> debugSystemState() async {
    print('🐛 DEBUGGING SYSTEM STATE...');

    // Check all users
    final usersSnapshot = await _firestore
        .collection('user_matrices')
        .orderBy('created_at')
        .get();

    print('📊 TOTAL USERS: ${usersSnapshot.docs.length}');

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      print('👤 User: ${doc.id}');
      print('   - Name: ${data['name']}');
      print('   - Matrix 1: ${data['matrix1_filled'] ?? 0}/4 filled');
      print('   - Matrix 1 Status: ${data['matrix1_status']}');
      print('   - Sponsor: ${data['sponsor_id'] ?? "None"}');
      print('   - Created: ${data['created_at']}');
    }

    // Check queue
    await checkQueueStatus();
  }
}
