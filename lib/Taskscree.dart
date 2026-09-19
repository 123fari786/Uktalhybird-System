import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Define packages list for TaskScreen
  final List<Map<String, dynamic>> _packages = [
    {"title": "Starter Package", "baseTasks": 15},
    {"title": "Basic Package", "baseTasks": 5},
    {"title": "Standard Package", "baseTasks": 5},
    {"title": "Pro Package", "baseTasks": 5},
    {"title": "Elite Package", "baseTasks": 5},
    {"title": "Premium Package", "baseTasks": 5},
    {"title": "Ultimate Package", "baseTasks": 5},
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('All 15 Days Tasks'),
        backgroundColor: const Color(0xFF0000FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('purchasedPackages')
            .snapshots(),
        builder: (context, packageSnapshot) {
          if (packageSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(w, h);
          }

          if (packageSnapshot.hasError) {
            return _buildErrorState(w, h, packageSnapshot.error.toString());
          }

          // Calculate total daily tasks from active packages
          int totalDailyTasks = _calculateTotalDailyTasks(packageSnapshot.data);

          // Calculate total tasks for 15 days
          int totalTasksFor15Days = totalDailyTasks * 15;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(_currentUser!.uid)
                .collection('dailyTasks')
                .snapshots(),
            builder: (context, allTasksSnapshot) {
              if (allTasksSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState(w, h);
              }

              if (allTasksSnapshot.hasError) {
                return _buildErrorState(
                  w,
                  h,
                  allTasksSnapshot.error.toString(),
                );
              }

              // Get or generate ALL 15 days tasks at once
              List<Map<String, dynamic>> allTasks = _getOrGenerateAllTasks(
                totalTasksFor15Days,
                allTasksSnapshot.data,
              );

              // Calculate completed tasks count
              int completedTasksCount = allTasks
                  .where((task) => task['isCompleted'] == true)
                  .length;

              return _buildMainContent(
                w,
                h,
                totalDailyTasks,
                totalTasksFor15Days,
                completedTasksCount,
                allTasks,
              );
            },
          );
        },
      ),
    );
  }

  int _calculateTotalDailyTasks(QuerySnapshot? packageSnapshot) {
    int totalDailyTasks = 15; // Start with minimum 15 tasks

    if (packageSnapshot != null) {
      // Get all active packages
      List<String> purchasedPackageTitles = [];
      for (var doc in packageSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? '';
        final isActive = data['isActive'] ?? false;
        final packageTitle = data['packageTitle']?.toString().trim() ?? '';
        final activatedBy = data['activatedBy'] ?? '';

        bool isActiveByAdmin = activatedBy == 'admin' && status == 'finished';
        bool isActiveByPurchase = status == 'finished' && isActive == true;

        if ((isActiveByAdmin || isActiveByPurchase) &&
            packageTitle.isNotEmpty) {
          purchasedPackageTitles.add(packageTitle);
        }
      }

      // Calculate cumulative tasks
      if (purchasedPackageTitles.isNotEmpty) {
        totalDailyTasks = 0;

        // Sort by package order and calculate cumulative
        for (int i = 0; i < _packages.length; i++) {
          final packageTitle = _packages[i]["title"]?.toString().trim() ?? '';

          if (purchasedPackageTitles.contains(packageTitle)) {
            if (i == 0) {
              totalDailyTasks += 15; // First package
            } else {
              totalDailyTasks += 5; // Subsequent packages
            }
          }
        }
      }
    }

    print('📦 Total Daily Tasks (Cumulative): $totalDailyTasks');
    return totalDailyTasks;
  }

  List<Map<String, dynamic>> _getOrGenerateAllTasks(
    int totalTasksFor15Days,
    QuerySnapshot? allTasksSnapshot,
  ) {
    List<Map<String, dynamic>> allTasks = [];

    // If tasks already exist, use them
    if (allTasksSnapshot != null && allTasksSnapshot.docs.isNotEmpty) {
      for (var doc in allTasksSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        allTasks.add({
          'id': doc.id,
          'title': data['title'] ?? 'Watch Ad Video',
          'subtitle': data['subtitle'] ?? 'Complete this ad to earn rewards',
          'isCompleted': data['isCompleted'] ?? false,
          'taskIndex': data['taskIndex'] ?? 0,
          'day': data['day'] ?? 1,
        });
      }

      // Sort tasks by day and index
      allTasks.sort((a, b) {
        int dayCompare = (a['day'] ?? 1).compareTo(b['day'] ?? 1);
        if (dayCompare != 0) return dayCompare;
        return (a['taskIndex'] ?? 0).compareTo(b['taskIndex'] ?? 0);
      });

      // If we have fewer tasks than totalTasksFor15Days, generate more
      if (allTasks.length < totalTasksFor15Days) {
        _generateAdditionalTasks(totalTasksFor15Days, allTasks.length);
      }
    } else {
      // Generate ALL tasks for 15 days at once
      _generateAllTasks(totalTasksFor15Days);
      return [];
    }

    return allTasks;
  }

  Future<void> _generateAdditionalTasks(
    int totalTasksFor15Days,
    int existingCount,
  ) async {
    if (_currentUser == null || existingCount >= totalTasksFor15Days) return;

    final batch = _firestore.batch();

    // Generate additional tasks
    for (int i = existingCount + 1; i <= totalTasksFor15Days; i++) {
      final day = ((i - 1) ~/ (totalTasksFor15Days ~/ 15)) + 1;
      final taskId = 'task_all_$i';
      final taskRef = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('dailyTasks')
          .doc(taskId);

      batch.set(taskRef, {
        'taskId': taskId,
        'title': 'Watch Ad Video $i (Day $day)',
        'subtitle': 'Complete this ad to earn rewards',
        'isCompleted': false,
        'taskIndex': i,
        'day': day,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      print(
        '✅ Generated ${totalTasksFor15Days - existingCount} additional tasks',
      );
    } catch (e) {
      print('❌ Error generating additional tasks: $e');
    }
  }

  Future<void> _generateAllTasks(int totalTasksFor15Days) async {
    if (_currentUser == null || totalTasksFor15Days == 0) return;

    final batch = _firestore.batch();

    // Clear all existing tasks
    final existingTasks = await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('dailyTasks')
        .get();

    for (var doc in existingTasks.docs) {
      batch.delete(doc.reference);
    }

    // Generate ALL tasks for 15 days
    for (int i = 1; i <= totalTasksFor15Days; i++) {
      final day = ((i - 1) ~/ (totalTasksFor15Days ~/ 15)) + 1;
      final taskId = 'task_all_$i';
      final taskRef = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('dailyTasks')
          .doc(taskId);

      batch.set(taskRef, {
        'taskId': taskId,
        'title': 'Watch Ad Video $i (Day $day)',
        'subtitle': 'Complete this ad to earn rewards',
        'isCompleted': false,
        'taskIndex': i,
        'day': day,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      print('✅ Generated $totalTasksFor15Days tasks for 15 days');
    } catch (e) {
      print('❌ Error generating tasks: $e');
    }
  }

  Future<void> _toggleTaskCompletion(
    String taskId,
    String taskTitle,
    bool currentStatus,
  ) async {
    if (_currentUser == null) return;

    final newStatus = !currentStatus;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('dailyTasks')
          .doc(taskId)
          .update({
            'isCompleted': newStatus,
            'completedAt': newStatus ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('Task $taskId updated to: $newStatus');
    } catch (e) {
      print('Error updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLoadingState(double w, double h) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Loading tasks...', style: TextStyle(fontSize: w * 0.04)),
        ],
      ),
    );
  }

  Widget _buildErrorState(double w, double h, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 60, color: Colors.red),
          SizedBox(height: 20),
          Text(
            'Error loading tasks',
            style: TextStyle(fontSize: w * 0.04, color: Colors.red),
          ),
          SizedBox(height: 10),
          Text(
            error,
            style: TextStyle(fontSize: w * 0.03, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    double w,
    double h,
    int totalDailyTasks,
    int totalTasksFor15Days,
    int completedTasksCount,
    List<Map<String, dynamic>> tasks,
  ) {
    // Calculate progress percentage
    double progressPercentage = totalTasksFor15Days > 0
        ? (completedTasksCount / totalTasksFor15Days).clamp(0.0, 1.0)
        : 0.0;

    // Group tasks by day
    Map<int, List<Map<String, dynamic>>> tasksByDay = {};
    for (var task in tasks) {
      int day = task['day'] ?? 1;
      if (!tasksByDay.containsKey(day)) {
        tasksByDay[day] = [];
      }
      tasksByDay[day]!.add(task);
    }

    return Padding(
      padding: EdgeInsets.all(w * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Bar for all 15 days
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(w * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '15 Days Progress',
                      style: TextStyle(
                        fontSize: w * 0.04,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0000FF),
                      ),
                    ),
                    Text(
                      '${(progressPercentage * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: w * 0.04,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0000FF),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: h * 0.01),
                LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey[300],
                  color: const Color(0xFF0000FF),
                  minHeight: h * 0.015,
                  borderRadius: BorderRadius.circular(10),
                ),
                SizedBox(height: h * 0.01),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completed: $completedTasksCount',
                      style: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: $totalTasksFor15Days',
                      style: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: h * 0.005),
                Text(
                  'Daily Tasks: $totalDailyTasks/day',
                  style: TextStyle(fontSize: w * 0.03, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          SizedBox(height: h * 0.03),

          // Tasks List
          Expanded(
            child: totalTasksFor15Days == 0
                ? _buildNoPackagesState(w, h)
                : tasks.isEmpty
                ? _buildLoadingState(w, h)
                : ListView.builder(
                    itemCount: tasksByDay.length,
                    itemBuilder: (context, dayIndex) {
                      int day = tasksByDay.keys.toList()[dayIndex];
                      List<Map<String, dynamic>> dayTasks = tasksByDay[day]!;
                      int dayCompletedTasks = dayTasks
                          .where((task) => task['isCompleted'] == true)
                          .length;

                      return _buildDaySection(
                        w,
                        h,
                        day,
                        dayTasks,
                        dayCompletedTasks,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(
    double w,
    double h,
    int day,
    List<Map<String, dynamic>> tasks,
    int completedTasksCount,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: h * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.04,
              vertical: h * 0.015,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0000FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $day',
                  style: TextStyle(
                    fontSize: w * 0.04,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$completedTasksCount/${tasks.length} tasks',
                  style: TextStyle(fontSize: w * 0.035, color: Colors.white),
                ),
              ],
            ),
          ),
          // Tasks for this day
          ...tasks.map(
            (task) => _buildTaskItem(
              task: task,
              isCompleted: task['isCompleted'] ?? false,
              onTap: () => _toggleTaskCompletion(
                task['id'],
                task['title'],
                task['isCompleted'] ?? false,
              ),
              w: w,
              h: h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPackagesState(double w, double h) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart, size: 60, color: Colors.grey[400]),
          SizedBox(height: 10),
          Text(
            'No Packages Purchased',
            style: TextStyle(fontSize: w * 0.04, color: Colors.grey[600]),
          ),
          SizedBox(height: 10),
          Text(
            'Purchase a package to get daily tasks',
            style: TextStyle(fontSize: w * 0.03, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem({
    required Map<String, dynamic> task,
    required bool isCompleted,
    required Function onTap,
    required double w,
    required double h,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.3)
              : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: () => onTap(),
        leading: Container(
          width: w * 0.12,
          height: w * 0.12,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : const Color(0xFF0000FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.play_circle_filled,
            color: Colors.white,
            size: w * 0.06,
          ),
        ),
        title: Text(
          task['title'],
          style: TextStyle(
            fontSize: w * 0.038,
            fontWeight: FontWeight.bold,
            color: isCompleted ? Colors.green : Colors.black,
          ),
        ),
        subtitle: Text(
          task['subtitle'],
          style: TextStyle(fontSize: w * 0.03, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: EdgeInsets.all(w * 0.02),
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.remove_red_eye,
            color: isCompleted ? Colors.white : const Color(0xFF0000FF),
            size: w * 0.045,
          ),
        ),
      ),
    );
  }
}
