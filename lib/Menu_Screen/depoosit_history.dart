import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DepositHistory extends StatefulWidget {
  const DepositHistory({super.key});

  @override
  State<DepositHistory> createState() => _DepositHistoryState();
}

class _DepositHistoryState extends State<DepositHistory> {
  final primaryBlue = const Color(0xFF0000FF);
  final lightBlue = const Color(0xFFE6E6FF);
  final accentGreen = Colors.green;
  final accentOrange = Colors.orange;
  final accentRed = Colors.red;

  String _selectedFilter = 'all';
  List<String> filterOptions = ['all', 'completed', 'pending', 'failed'];
  bool _hasIndexError = false;
  bool _isLoading = true;
  int _selectedTab = 0; // 0 for Packages, 1 for Matrix, 2 for Lottery

  @override
  void initState() {
    super.initState();
    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Deposit History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0000FF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: _hasIndexError
          ? _buildIndexErrorState(w, h)
          : Column(
              children: [
                // 🔹 Header with Stats
                _buildHeaderStats(w, h),

                // 🔹 Tab Bar for Package vs Matrix vs Lottery History
                _buildTabBar(w),

                // 🔹 Filter Chips
                _buildFilterChips(w),

                // 🔹 History List based on selected tab
                Expanded(child: _buildHistoryList(w, h)),
              ],
            ),
    );
  }

  Widget _buildTabBar(double w) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.03),
      padding: EdgeInsets.all(w * 0.01),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 0;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: w * 0.03),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Packages',
                    style: TextStyle(
                      color: _selectedTab == 0
                          ? Colors.white
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: w * 0.03,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 1;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: w * 0.03),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Matrix',
                    style: TextStyle(
                      color: _selectedTab == 1
                          ? Colors.white
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: w * 0.03,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = 2;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: w * 0.03),
                decoration: BoxDecoration(
                  color: _selectedTab == 2 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Lottery',
                    style: TextStyle(
                      color: _selectedTab == 2
                          ? Colors.white
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: w * 0.03,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexErrorState(double w, double h) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(w * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: w * 0.2, color: Colors.orange),
            SizedBox(height: h * 0.03),
            Text(
              'Firestore Index Required',
              style: TextStyle(
                fontSize: w * 0.06,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: h * 0.02),
            Text(
              _getIndexErrorMessage(),
              style: TextStyle(
                fontSize: w * 0.04,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: h * 0.03),
            Column(
              children: [
                // Retry Button
                Container(
                  width: double.infinity,
                  height: h * 0.06,
                  margin: EdgeInsets.only(bottom: h * 0.015),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasIndexError = false;
                        _isLoading = true;
                      });
                      // Retry after a delay
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.04,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Switch to Other Tab Buttons
                if (_selectedTab != 0)
                  Container(
                    width: double.infinity,
                    height: h * 0.06,
                    margin: EdgeInsets.only(bottom: h * 0.01),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTab = 0;
                          _hasIndexError = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View Package Deposits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_selectedTab != 1)
                  Container(
                    width: double.infinity,
                    height: h * 0.06,
                    margin: EdgeInsets.only(bottom: h * 0.01),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTab = 1;
                          _hasIndexError = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View Matrix Deposits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (_selectedTab != 2)
                  Container(
                    width: double.infinity,
                    height: h * 0.06,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedTab = 2;
                          _hasIndexError = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View Lottery Deposits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: h * 0.02),

            // Firestore Index Help Text
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Firestore Index Help:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      fontSize: w * 0.04,
                    ),
                  ),
                  SizedBox(height: h * 0.01),
                  Text(
                    'Go to Firebase Console → Firestore → Indexes → Create composite index',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: w * 0.032,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIndexErrorMessage() {
    switch (_selectedTab) {
      case 0:
        return 'To view package deposit history, you need to create a Firestore index for "createdAt" field.';
      case 1:
        return 'To view matrix deposit history, you need to create a Firestore index for "timestamp" field.';
      case 2:
        return 'To view lottery deposit history, you need to create a Firestore index for "timestamp" field.';
      default:
        return 'Please create the Firestore index to view deposit history.';
    }
  }

  Widget _buildHeaderStats(double w, double h) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(w * 0.04),
      padding: EdgeInsets.all(w * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, const Color(0xFF0000CC)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _getStreamForSelectedTab(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isLoading) {
            return _buildStatRow(w, "Total Deposits", "\$0.00", "Loading...");
          }

          if (snapshot.hasError) {
            print('Header Error: ${snapshot.error}');

            // Check if it's an index error
            if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
              return _buildStatRow(
                w,
                _getHeaderTitle(),
                "Index Required",
                "Create Firestore index",
              );
            }

            return _buildStatRow(w, _getHeaderTitle(), "Error", "Tap to retry");
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildStatRow(
              w,
              _getHeaderTitle(),
              "\$0.00",
              "0 Transactions",
            );
          }

          final documents = snapshot.data!.docs;
          double totalAmount = 0;
          int completedCount = 0;
          int pendingCount = 0;
          int failedCount = 0;

          for (var doc in documents) {
            final data = doc.data() as Map<String, dynamic>;

            if (_selectedTab == 0) {
              // Package deposits calculation
              final status = data['status']?.toString() ?? 'pending';
              final amount = (data['totalAmount'] ?? 0).toDouble();

              totalAmount += amount;
              if (status == 'finished') {
                completedCount++;
              } else if (status == 'pending' || status == 'waiting') {
                pendingCount++;
              } else if (status == 'failed' || status == 'expired') {
                failedCount++;
              }
            } else if (_selectedTab == 1) {
              // Matrix deposits calculation
              final status = data['status']?.toString() ?? 'pending';
              final amount = (data['amount'] ?? 0).toDouble();

              totalAmount += amount;
              if (status == 'completed') {
                completedCount++;
              } else if (status == 'pending') {
                pendingCount++;
              } else if (status == 'failed') {
                failedCount++;
              }
            } else {
              // Lottery deposits calculation
              final status = data['status']?.toString() ?? 'pending';
              final amount = (data['amount'] ?? 0).toDouble();

              totalAmount += amount;
              if (status == 'completed') {
                completedCount++;
              } else if (status == 'pending') {
                pendingCount++;
              } else if (status == 'failed') {
                failedCount++;
              }
            }
          }

          return _buildStatRow(
            w,
            _getHeaderTitle(),
            "\$${totalAmount.toStringAsFixed(2)}",
            "$completedCount Completed • $pendingCount Pending • $failedCount Failed",
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getStreamForSelectedTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    switch (_selectedTab) {
      case 0:
        return FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchasedPackages')
            .orderBy('createdAt', descending: true)
            .snapshots();
      case 1:
        return FirebaseFirestore.instance
            .collection('Matric_payment_deposit')
            .doc(user.uid)
            .collection('matrix_payments')
            .orderBy('timestamp', descending: true)
            .snapshots();
      case 2:
        return FirebaseFirestore.instance
            .collection('Lottery_Payment_Deposit')
            .doc(user.uid)
            .collection('lottery_payments')
            .orderBy('timestamp', descending: true)
            .snapshots();
      default:
        return const Stream.empty();
    }
  }

  String _getHeaderTitle() {
    switch (_selectedTab) {
      case 0:
        return "Package Deposits";
      case 1:
        return "Matrix Deposits";
      case 2:
        return "Lottery Deposits";
      default:
        return "Total Deposits";
    }
  }

  Widget _buildStatRow(double w, String title, String amount, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white70,
            fontSize: w * 0.04,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: w * 0.01),
        Text(
          amount,
          style: TextStyle(
            color: Colors.white,
            fontSize: w * 0.07,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: w * 0.01),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white70, fontSize: w * 0.035),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterChips(double w) {
    return Container(
      height: w * 0.12,
      padding: EdgeInsets.symmetric(horizontal: w * 0.04),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filterOptions.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: w * 0.03),
            child: FilterChip(
              label: Text(
                _getFilterLabel(filter),
                style: TextStyle(
                  color: isSelected ? Colors.white : primaryBlue,
                  fontSize: w * 0.035,
                  fontWeight: FontWeight.w500,
                ),
              ),
              selected: isSelected,
              backgroundColor: Colors.white,
              selectedColor: primaryBlue,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: primaryBlue, width: 1.5),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return 'All';
    }
  }

  Widget _buildHistoryList(double w, double h) {
    if (_isLoading) {
      return _buildLoadingState(w, h);
    }

    switch (_selectedTab) {
      case 0:
        return _buildPackageHistoryList(w, h);
      case 1:
        return _buildMatrixHistoryList(w, h);
      case 2:
        return _buildLotteryHistoryList(w, h);
      default:
        return _buildPackageHistoryList(w, h);
    }
  }

  Widget _buildPackageHistoryList(double w, double h) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('purchasedPackages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(w, h);
        }

        if (snapshot.hasError) {
          print('Package Firestore Error: ${snapshot.error}');
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _hasIndexError = true;
              });
            });
            return _buildIndexErrorState(w, h);
          }
          return _buildErrorState(w, h, snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(w, h, 'Package');
        }

        var packages = snapshot.data!.docs;

        // Apply filter
        if (_selectedFilter != 'all') {
          packages = packages.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? 'pending';
            return _matchesFilter(status, _selectedFilter);
          }).toList();
        }

        if (packages.isEmpty) {
          return _buildEmptyFilterState(w, h);
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.01,
          ),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final package = packages[index];
            final data = package.data() as Map<String, dynamic>;
            return _buildPackageCard(w, h, data, package.id);
          },
        );
      },
    );
  }

  Widget _buildMatrixHistoryList(double w, double h) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Matric_payment_deposit')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('matrix_payments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(w, h);
        }

        if (snapshot.hasError) {
          print('Matrix Firestore Error: ${snapshot.error}');
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _hasIndexError = true;
              });
            });
            return _buildIndexErrorState(w, h);
          }
          return _buildErrorState(w, h, snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(w, h, 'Matrix');
        }

        var matrixPayments = snapshot.data!.docs;

        // Apply filter
        if (_selectedFilter != 'all') {
          matrixPayments = matrixPayments.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? 'pending';
            return _matchesFilter(status, _selectedFilter);
          }).toList();
        }

        if (matrixPayments.isEmpty) {
          return _buildEmptyFilterState(w, h);
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.01,
          ),
          itemCount: matrixPayments.length,
          itemBuilder: (context, index) {
            final payment = matrixPayments[index];
            final data = payment.data() as Map<String, dynamic>;
            return _buildMatrixCard(w, h, data, payment.id);
          },
        );
      },
    );
  }

  Widget _buildLotteryHistoryList(double w, double h) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Lottery_Payment_Deposit')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('lottery_payments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(w, h);
        }

        if (snapshot.hasError) {
          print('Lottery Firestore Error: ${snapshot.error}');
          if (snapshot.error.toString().contains('FAILED_PRECONDITION')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _hasIndexError = true;
              });
            });
            return _buildIndexErrorState(w, h);
          }
          return _buildErrorState(w, h, snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(w, h, 'Lottery');
        }

        var lotteryPayments = snapshot.data!.docs;

        // Apply filter
        if (_selectedFilter != 'all') {
          lotteryPayments = lotteryPayments.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? 'pending';
            return _matchesFilter(status, _selectedFilter);
          }).toList();
        }

        if (lotteryPayments.isEmpty) {
          return _buildEmptyFilterState(w, h);
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.01,
          ),
          itemCount: lotteryPayments.length,
          itemBuilder: (context, index) {
            final payment = lotteryPayments[index];
            final data = payment.data() as Map<String, dynamic>;
            return _buildLotteryCard(w, h, data, payment.id);
          },
        );
      },
    );
  }

  Widget _buildLotteryCard(
    double w,
    double h,
    Map<String, dynamic> data,
    String paymentId,
  ) {
    final status = data['status']?.toString() ?? 'pending';
    final amount = (data['amount'] ?? 0).toDouble();
    final currency = data['currency']?.toString() ?? 'USD';
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final type = data['type']?.toString() ?? 'lottery_ticket_purchase';
    final lotteryNumber = data['lottery_number']?.toString() ?? 'N/A';

    final statusConfig = _getStatusConfig(status);

    return Container(
      margin: EdgeInsets.only(bottom: h * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showLotteryDetails(data, paymentId, statusConfig);
          },
          child: Padding(
            padding: EdgeInsets.all(w * 0.04),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: w * 0.12,
                  height: w * 0.12,
                  decoration: BoxDecoration(
                    color: statusConfig.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusConfig.icon,
                    color: statusConfig.color,
                    size: w * 0.06,
                  ),
                ),
                SizedBox(width: w * 0.04),

                // Lottery Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lottery Ticket Purchase',
                        style: TextStyle(
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: h * 0.005),
                      Text(
                        '\$${amount.toStringAsFixed(2)} $currency',
                        style: TextStyle(
                          fontSize: w * 0.04,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      SizedBox(height: h * 0.003),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat(
                                'MMM dd, yyyy • HH:mm',
                              ).format(timestamp),
                              style: TextStyle(
                                fontSize: w * 0.032,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: w * 0.02),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.02,
                              vertical: h * 0.002,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Lottery',
                              style: TextStyle(
                                fontSize: w * 0.025,
                                color: Colors.purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lotteryNumber != 'N/A') ...[
                        SizedBox(height: h * 0.003),
                        Text(
                          'Ticket #$lotteryNumber',
                          style: TextStyle(
                            fontSize: w * 0.03,
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: h * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: statusConfig.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusConfig.color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    statusConfig.label,
                    style: TextStyle(
                      fontSize: w * 0.03,
                      fontWeight: FontWeight.w600,
                      color: statusConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLotteryDetails(
    Map<String, dynamic> data,
    String paymentId,
    StatusConfig statusConfig,
  ) {
    final amount = (data['amount'] ?? 0).toDouble();
    final currency = data['currency']?.toString() ?? 'USD';
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final type = data['type']?.toString() ?? 'lottery_ticket_purchase';
    final lotteryNumber = data['lottery_number']?.toString() ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lottery Ticket Details',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Status Badge
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusConfig.color.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusConfig.icon,
                          color: statusConfig.color,
                          size: MediaQuery.of(context).size.width * 0.04,
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.02,
                        ),
                        Text(
                          statusConfig.label,
                          style: TextStyle(
                            color: statusConfig.color,
                            fontWeight: FontWeight.w600,
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Details
                _buildDetailItem('Payment ID', paymentId),
                _buildDetailItem('Transaction Type', 'Lottery Ticket Purchase'),
                _buildDetailItem(
                  'Amount',
                  '\$${amount.toStringAsFixed(2)} $currency',
                ),
                _buildDetailItem('Currency', currency.toUpperCase()),
                _buildDetailItem('Ticket Type', type),
                if (lotteryNumber != 'N/A')
                  _buildDetailItem('Lottery Number', lotteryNumber),
                _buildDetailItem(
                  'Purchase Date',
                  DateFormat('MMMM dd, yyyy • HH:mm:ss').format(timestamp),
                ),
                _buildDetailItem('Status', statusConfig.label),

                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.w600,
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

  // ... (All other existing methods remain the same - _buildMatrixCard, _buildPackageCard, _buildErrorState, etc.)

  Widget _buildEmptyFilterState(double w, double h) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: w * 0.15, color: Colors.grey[400]),
          SizedBox(height: h * 0.02),
          Text(
            'No matching transactions',
            style: TextStyle(
              fontSize: w * 0.045,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: h * 0.01),
          Text(
            'Try changing your filter settings',
            style: TextStyle(fontSize: w * 0.04, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(double w, double h, String error) {
    bool isIndexError = error.toString().contains('FAILED_PRECONDITION');

    if (isIndexError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasIndexError = true;
          });
        }
      });
      return _buildIndexErrorState(w, h);
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(w * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: w * 0.2, color: Colors.red),
            SizedBox(height: h * 0.03),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: w * 0.05,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: h * 0.02),
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                'Error: ${error.toString()}',
                style: TextStyle(fontSize: w * 0.035, color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: h * 0.02),
            Text(
              'Please check your internet connection and try again.',
              style: TextStyle(fontSize: w * 0.04, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: h * 0.03),
            Container(
              width: double.infinity,
              height: h * 0.06,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                  });
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: w * 0.04,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(String status, String filter) {
    switch (filter) {
      case 'completed':
        return status == 'finished' || status == 'completed';
      case 'pending':
        return status == 'pending' || status == 'waiting';
      case 'failed':
        return status == 'failed' || status == 'expired';
      default:
        return true;
    }
  }

  Widget _buildMatrixCard(
    double w,
    double h,
    Map<String, dynamic> data,
    String paymentId,
  ) {
    final status = data['status']?.toString() ?? 'pending';
    final amount = (data['amount'] ?? 0).toDouble();
    final currency = data['currency']?.toString() ?? 'USD';
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final type = data['type']?.toString() ?? 'matrix_income_deposit';

    final statusConfig = _getStatusConfig(status);

    return Container(
      margin: EdgeInsets.only(bottom: h * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showMatrixDetails(data, paymentId, statusConfig);
          },
          child: Padding(
            padding: EdgeInsets.all(w * 0.04),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: w * 0.12,
                  height: w * 0.12,
                  decoration: BoxDecoration(
                    color: statusConfig.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusConfig.icon,
                    color: statusConfig.color,
                    size: w * 0.06,
                  ),
                ),
                SizedBox(width: w * 0.04),

                // Matrix Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matrix Income Deposit',
                        style: TextStyle(
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: h * 0.005),
                      Text(
                        '\$${amount.toStringAsFixed(2)} $currency',
                        style: TextStyle(
                          fontSize: w * 0.04,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      SizedBox(height: h * 0.003),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat(
                                'MMM dd, yyyy • HH:mm',
                              ).format(timestamp),
                              style: TextStyle(
                                fontSize: w * 0.032,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: w * 0.02),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: w * 0.02,
                              vertical: h * 0.002,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Matrix',
                              style: TextStyle(
                                fontSize: w * 0.025,
                                color: Colors.purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: h * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: statusConfig.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusConfig.color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    statusConfig.label,
                    style: TextStyle(
                      fontSize: w * 0.03,
                      fontWeight: FontWeight.w600,
                      color: statusConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMatrixDetails(
    Map<String, dynamic> data,
    String paymentId,
    StatusConfig statusConfig,
  ) {
    final amount = (data['amount'] ?? 0).toDouble();
    final currency = data['currency']?.toString() ?? 'USD';
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final type = data['type']?.toString() ?? 'matrix_income_deposit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Matrix Deposit Details',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Status Badge
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusConfig.color.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusConfig.icon,
                          color: statusConfig.color,
                          size: MediaQuery.of(context).size.width * 0.04,
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.02,
                        ),
                        Text(
                          statusConfig.label,
                          style: TextStyle(
                            color: statusConfig.color,
                            fontWeight: FontWeight.w600,
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Details
                _buildDetailItem('Payment ID', paymentId),
                _buildDetailItem('Transaction Type', 'Matrix Income Deposit'),
                _buildDetailItem(
                  'Amount',
                  '\$${amount.toStringAsFixed(2)} $currency',
                ),
                _buildDetailItem('Currency', currency.toUpperCase()),
                _buildDetailItem('Deposit Type', type),
                _buildDetailItem(
                  'Transaction Date',
                  DateFormat('MMMM dd, yyyy • HH:mm:ss').format(timestamp),
                ),
                _buildDetailItem('Status', statusConfig.label),

                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.w600,
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

  Widget _buildPackageCard(
    double w,
    double h,
    Map<String, dynamic> data,
    String packageId,
  ) {
    final status = data['status']?.toString() ?? 'pending';
    final amount = (data['totalAmount'] ?? 0).toDouble();
    final currency = data['currency']?.toString() ?? 'USD';
    final timestamp = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final packageTitle = data['packageTitle']?.toString() ?? 'Package Purchase';
    final packagePrice = data['packagePrice']?.toString() ?? 'N/A';
    final activationFee = data['activationFee']?.toString() ?? 'N/A';
    final isActive = data['isActive'] ?? false;

    final statusConfig = _getStatusConfig(status);

    return Container(
      margin: EdgeInsets.only(bottom: h * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showPackageDetails(data, packageId, statusConfig);
          },
          child: Padding(
            padding: EdgeInsets.all(w * 0.04),
            child: Row(
              children: [
                // Status Icon
                Container(
                  width: w * 0.12,
                  height: w * 0.12,
                  decoration: BoxDecoration(
                    color: statusConfig.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusConfig.icon,
                    color: statusConfig.color,
                    size: w * 0.06,
                  ),
                ),
                SizedBox(width: w * 0.04),

                // Package Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        packageTitle,
                        style: TextStyle(
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: h * 0.005),
                      Text(
                        '\$${amount.toStringAsFixed(2)} $currency',
                        style: TextStyle(
                          fontSize: w * 0.04,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      SizedBox(height: h * 0.003),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat(
                                'MMM dd, yyyy • HH:mm',
                              ).format(timestamp),
                              style: TextStyle(
                                fontSize: w * 0.032,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) ...[
                            SizedBox(width: w * 0.02),
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: w * 0.04,
                            ),
                            SizedBox(width: w * 0.01),
                            Text(
                              'Active',
                              style: TextStyle(
                                fontSize: w * 0.03,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: h * 0.005,
                  ),
                  decoration: BoxDecoration(
                    color: statusConfig.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusConfig.color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    statusConfig.label,
                    style: TextStyle(
                      fontSize: w * 0.03,
                      fontWeight: FontWeight.w600,
                      color: statusConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(double w, double h) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: h * 0.01),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: h * 0.015),
          padding: EdgeInsets.all(w * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: w * 0.12,
                height: w * 0.12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: w * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: w * 0.4,
                      height: h * 0.02,
                      color: Colors.grey[300],
                      margin: EdgeInsets.only(bottom: h * 0.005),
                    ),
                    Container(
                      width: w * 0.3,
                      height: h * 0.018,
                      color: Colors.grey[300],
                      margin: EdgeInsets.only(bottom: h * 0.003),
                    ),
                    Container(
                      width: w * 0.5,
                      height: h * 0.016,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
              ),
              Container(
                width: w * 0.15,
                height: h * 0.025,
                color: Colors.grey[300],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(double w, double h, String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: w * 0.2,
            color: Colors.grey[400],
          ),
          SizedBox(height: h * 0.02),
          Text(
            'No $type Deposits',
            style: TextStyle(
              fontSize: w * 0.05,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: h * 0.01),
          Text(
            'Your $type deposit transactions will appear here',
            style: TextStyle(fontSize: w * 0.04, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: h * 0.03),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.06,
                vertical: h * 0.015,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Icons.add, color: Colors.white, size: w * 0.05),
            label: Text(
              'Make Deposit',
              style: TextStyle(
                color: Colors.white,
                fontSize: w * 0.04,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPackageDetails(
    Map<String, dynamic> data,
    String packageId,
    StatusConfig statusConfig,
  ) {
    final amount = (data['totalAmount'] ?? 0).toDouble();
    final currency = data['currency']?.toString() ?? 'USD';
    final timestamp = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final packageTitle = data['packageTitle']?.toString() ?? 'Package Purchase';
    final packagePrice = data['packagePrice']?.toString() ?? 'N/A';
    final activationFee = data['activationFee']?.toString() ?? 'N/A';
    final paymentId = data['paymentId']?.toString() ?? 'N/A';
    final isActive = data['isActive'] ?? false;
    final breakdown = data['breakdown'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Package Details',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                // Status Badge
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.04,
                      vertical: MediaQuery.of(context).size.height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: statusConfig.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusConfig.color.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusConfig.icon,
                          color: statusConfig.color,
                          size: MediaQuery.of(context).size.width * 0.04,
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.02,
                        ),
                        Text(
                          statusConfig.label,
                          style: TextStyle(
                            color: statusConfig.color,
                            fontWeight: FontWeight.w600,
                            fontSize: MediaQuery.of(context).size.width * 0.04,
                          ),
                        ),
                        if (isActive) ...[
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.02,
                          ),
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.01,
                          ),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.035,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Details
                _buildDetailItem('Package ID', packageId),
                _buildDetailItem('Package Name', packageTitle),
                _buildDetailItem(
                  'Total Amount',
                  '\$${amount.toStringAsFixed(2)} $currency',
                ),
                _buildDetailItem('Payment ID', paymentId),

                // Breakdown Details
                if (breakdown != null) ...[
                  _buildDetailItem(
                    'Package Price',
                    breakdown['packagePrice']?.toString() ?? 'N/A',
                  ),
                  _buildDetailItem(
                    'Activation Fee',
                    breakdown['activationFee']?.toString() ?? 'N/A',
                  ),
                  _buildDetailItem(
                    'Total Paid',
                    breakdown['totalPaid']?.toString() ?? 'N/A',
                  ),
                ] else ...[
                  _buildDetailItem('Package Price', packagePrice),
                  _buildDetailItem('Activation Fee', activationFee),
                ],

                _buildDetailItem(
                  'Purchase Date',
                  DateFormat('MMMM dd, yyyy • HH:mm:ss').format(timestamp),
                ),
                _buildDetailItem(
                  'Package Status',
                  isActive ? 'Active' : 'Inactive',
                ),

                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.w600,
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * 0.01,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: MediaQuery.of(context).size.width * 0.038,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: MediaQuery.of(context).size.width * 0.038,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusConfig {
  final String label;
  final Color color;
  final IconData icon;

  StatusConfig({required this.label, required this.color, required this.icon});
}

StatusConfig _getStatusConfig(String status) {
  switch (status) {
    case 'finished':
    case 'completed':
      return StatusConfig(
        label: 'Completed',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    case 'pending':
    case 'waiting':
      return StatusConfig(
        label: 'Pending',
        color: Colors.orange,
        icon: Icons.access_time,
      );
    case 'failed':
    case 'expired':
      return StatusConfig(
        label: 'Failed',
        color: Colors.red,
        icon: Icons.error_outline,
      );
    default:
      return StatusConfig(
        label: 'Processing',
        color: Colors.blue,
        icon: Icons.autorenew,
      );
  }
}
