import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Withdrawalhistory extends StatefulWidget {
  const Withdrawalhistory({super.key});

  @override
  State<Withdrawalhistory> createState() => _WithdrawalhistoryState();
}

class _WithdrawalhistoryState extends State<Withdrawalhistory> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Pending', 'Completed', 'Failed'];
  String _selectedCategory = 'All';
  final List<String> _categoryOptions = [
    'All',
    'Packages',
    'Passive Income',
    'Matrix',
    'Lottery',
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Withdrawal History",
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
      body: Column(
        children: [
          // Filter Section
          _buildFilterSection(w),
          SizedBox(height: h * 0.02),

          // History List
          Expanded(child: _buildWithdrawalHistoryList(w, h)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(double w) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.02),
      padding: EdgeInsets.symmetric(horizontal: w * 0.03, vertical: w * 0.02),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Status Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Status:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.04,
                  color: Colors.black87,
                ),
              ),
              DropdownButton<String>(
                value: _selectedFilter,
                icon: Icon(Icons.arrow_drop_down, color: Color(0xFF0000FF)),
                underline: SizedBox(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedFilter = newValue!;
                  });
                },
                items: _filterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Category Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Category:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.04,
                  color: Colors.black87,
                ),
              ),
              DropdownButton<String>(
                value: _selectedCategory,
                icon: Icon(Icons.arrow_drop_down, color: Color(0xFF0000FF)),
                underline: SizedBox(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
                items: _categoryOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: w * 0.035,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalHistoryList(double w, double h) {
    final user = _auth.currentUser;
    if (user == null) {
      return Center(
        child: Text(
          "Please login to view history",
          style: TextStyle(fontSize: w * 0.04),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getWithdrawalFeesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print("Firestore Error: ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: w * 0.15, color: Colors.red),
                SizedBox(height: h * 0.02),
                Text(
                  "Error loading history",
                  style: TextStyle(fontSize: w * 0.04, color: Colors.red),
                ),
                SizedBox(height: h * 0.01),
                Text(
                  "Please check your connection",
                  style: TextStyle(fontSize: w * 0.035, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(w, h);
        }

        final withdrawals = snapshot.data!.docs;

        // Client-side filtering
        final filteredWithdrawals = _applyClientSideFilter(withdrawals);

        if (filteredWithdrawals.isEmpty) {
          return _buildEmptyState(w, h);
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: w * 0.04),
          itemCount: filteredWithdrawals.length,
          itemBuilder: (context, index) {
            final withdrawal =
                filteredWithdrawals[index].data() as Map<String, dynamic>;
            return _buildWithdrawalCard(withdrawal, w, h);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getWithdrawalFeesStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    // ✅ Get data from withdrawal_fees collection
    return _firestore
        .collection('withdrawal_fees')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _applyClientSideFilter(
    List<QueryDocumentSnapshot> withdrawals,
  ) {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Pehle current user ke withdrawals filter karein
    List<QueryDocumentSnapshot> userWithdrawals = withdrawals.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId']?.toString() ?? '';
      return userId == user.uid;
    }).toList();

    // Phir status ke according filter karein
    if (_selectedFilter != 'All') {
      userWithdrawals = userWithdrawals.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? 'completed';
        final filter = _selectedFilter.toLowerCase();
        return status == filter;
      }).toList();
    }

    // Phir category ke according filter karein
    if (_selectedCategory != 'All') {
      userWithdrawals = userWithdrawals.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category']?.toString() ?? '';
        final type = data['type']?.toString() ?? '';

        String displayCategory = _getDisplayCategory(category, type);
        return displayCategory == _selectedCategory;
      }).toList();
    }

    return userWithdrawals;
  }

  String _getDisplayCategory(String category, String type) {
    // Map Firestore categories to display categories
    switch (category.toLowerCase()) {
      case 'packages':
        return 'Packages';
      case 'passive_income':
      case 'passive income':
        return 'Passive Income';
      case 'matrix':
        return 'Matrix';
      case 'lottery':
        return 'Lottery';
      default:
        // Fallback to type if category is not clear
        switch (type.toLowerCase()) {
          case 'package_withdrawal':
            return 'Packages';
          case 'passive_withdrawal':
            return 'Passive Income';
          case 'matrix_withdrawal':
            return 'Matrix';
          case 'lottery_withdrawal':
            return 'Lottery';
          default:
            return 'Other';
        }
    }
  }

  Widget _buildEmptyState(double w, double h) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: w * 0.2, color: Colors.grey[400]),
          SizedBox(height: h * 0.02),
          Text(
            _getEmptyStateMessage(),
            style: TextStyle(
              fontSize: w * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: h * 0.01),
          Text(
            "Your withdrawal history will appear here",
            style: TextStyle(fontSize: w * 0.035, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEmptyStateMessage() {
    if (_selectedFilter != 'All' && _selectedCategory != 'All') {
      return "No ${_selectedFilter} ${_selectedCategory} Withdrawals";
    } else if (_selectedFilter != 'All') {
      return "No ${_selectedFilter} Withdrawals";
    } else if (_selectedCategory != 'All') {
      return "No ${_selectedCategory} Withdrawals";
    } else {
      return "No Withdrawal History";
    }
  }

  Widget _buildWithdrawalCard(
    Map<String, dynamic> withdrawal,
    double w,
    double h,
  ) {
    // ✅ Correct field names based on withdrawal_fees collection
    final feeAmount = withdrawal['feeAmount'] ?? 0.0;
    final originalAmount = withdrawal['originalAmount'] ?? 0.0;
    final netAmount = withdrawal['netAmount'] ?? 0.0;
    final currency = withdrawal['currency'] ?? 'USD';
    final category = withdrawal['category'] ?? '';
    final type = withdrawal['type'] ?? '';
    final timestamp = withdrawal['timestamp'];
    final feePercentage = withdrawal['feePercentage'] ?? 10;
    final status = withdrawal['status'] ?? 'completed';

    // Calculate display values
    final displayCategory = _getDisplayCategory(category, type);
    final displayAmount = netAmount > 0
        ? netAmount
        : (originalAmount - feeAmount);

    // Status colors and icons
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
    }

    return Container(
      margin: EdgeInsets.only(bottom: h * 0.015),
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "\$${displayAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0000FF),
                    ),
                  ),
                  SizedBox(height: h * 0.005),
                  Text(
                    currency.toUpperCase(),
                    style: TextStyle(
                      fontSize: w * 0.03,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.03,
                  vertical: w * 0.015,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: w * 0.04, color: statusColor),
                    SizedBox(width: w * 0.015),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: w * 0.03,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: h * 0.01),

          // Details
          _buildDetailRow("Category:", displayCategory, w),
          _buildDetailRow("Type:", _capitalize(type.replaceAll('_', ' ')), w),

          // Amount Breakdown
          _buildDetailRow(
            "Gross Amount:",
            "\$${originalAmount.toStringAsFixed(2)}",
            w,
          ),
          _buildDetailRow(
            "Withdrawal Fee ($feePercentage%):",
            "-\$${feeAmount.toStringAsFixed(2)}",
            w,
            isRed: true,
          ),
          _buildDetailRow(
            "Net Amount:",
            "\$${displayAmount.toStringAsFixed(2)}",
            w,
            isBold: true,
            isGreen: true,
          ),

          SizedBox(height: h * 0.008),

          // Date and Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(_parseTimestamp(timestamp)),
                style: TextStyle(fontSize: w * 0.03, color: Colors.grey[500]),
              ),
              Text(
                _formatTime(_parseTimestamp(timestamp)),
                style: TextStyle(fontSize: w * 0.03, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
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
      padding: EdgeInsets.symmetric(vertical: w * 0.005),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: w * 0.035,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: w * 0.035,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isRed
                    ? Colors.red
                    : (isGreen ? Colors.green : Colors.black87),
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else {
        return DateTime.now();
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
