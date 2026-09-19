import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BonusLevelDetailsScreen extends StatefulWidget {
  final String level;
  final String bonus;
  final double progress;
  final bool achieved;
  final List<String> requirements;
  final Map<String, dynamic>? preloadedData;

  const BonusLevelDetailsScreen({
    super.key,
    required this.level,
    required this.bonus,
    required this.progress,
    required this.achieved,
    required this.requirements,
    this.preloadedData,
  });

  @override
  State<BonusLevelDetailsScreen> createState() =>
      _BonusLevelDetailsScreenState();
}

class _BonusLevelDetailsScreenState extends State<BonusLevelDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _levelEarning = 0.0;
  double _totalBusiness = 0.0;
  bool _isLoading = false;

  // User data variables
  String _userName = "";
  String _userEmail = "";
  String _userFullName = "";
  String _userPackage = "Starter Package";
  String _joiningDate = "";
  String _userLevel = "1";

  // Color constants defined at class level
  static const primaryPurple = Color(0xFF6C63FF);
  static const primaryBlue = Color(0xFF2196F3);
  static const accentGreen = Color(0xFF4CAF50);
  static const accentOrange = Color(0xFFFF9800);
  static const accentPink = Color(0xFFE91E63);
  static const deepBlue = Color(0xFF1976D2);
  static const lightBlue = Color(0xFFBBDEFB);
  static const white = Colors.white;
  static const backgroundColor = Color(0xFFF8F9FA);
  static const cardColor = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF2C3E50);
  static const textSecondary = Color(0xFF7F8C8D);
  static const shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();

    if (widget.preloadedData != null) {
      _setDataFromPreloaded(widget.preloadedData!);
    } else {
      _loadUserDataAndLevelDetails();
    }
  }

  void _setDataFromPreloaded(Map<String, dynamic> data) {
    setState(() {
      _userFullName = data['userFullName'] ?? "User";
      _userEmail = data['userEmail'] ?? "No Email";
      _userName = data['userName'] ?? "username";
      _userLevel = data['userLevel'] ?? "1";
      _joiningDate = data['joiningDate'] ?? "Not Available";
      _userPackage = data['userPackage'] ?? "Starter Package";
      _levelEarning = (data['levelEarning'] ?? 0.0).toDouble();
      _totalBusiness = (data['totalBusiness'] ?? 0.0).toDouble();
    });
  }

  Future<void> _loadUserDataAndLevelDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final levelNumber =
          int.tryParse(widget.level.replaceAll('Level ', '')) ?? 0;

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        _userFullName = userData['name'] ?? "User";
        _userEmail = userData['email'] ?? "No Email";
        _userName = userData['username'] ?? "username";
        _userLevel = (userData['level'] ?? 1).toString();

        final timestamp = userData['joinedAt'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          _joiningDate =
              "${date.day} ${_getMonthName(date.month)} ${date.year}";
        } else {
          _joiningDate = "Not Available";
        }

        final packagesQuery = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('purchasedPackages')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (packagesQuery.docs.isNotEmpty) {
          final packageData = packagesQuery.docs.first.data();
          _userPackage = packageData['packageTitle'] ?? "Starter Package";
        }
      }

      final sponsorWalletDoc = await _firestore
          .collection('Sponsar_wallets')
          .doc(user.uid)
          .get();

      if (sponsorWalletDoc.exists) {
        final walletData = sponsorWalletDoc.data() as Map<String, dynamic>;
        final levelEarningsData =
            walletData['levelEarnings'] as Map<String, dynamic>?;

        if (levelEarningsData != null) {
          final levelsMap =
              levelEarningsData['levels'] as Map<String, dynamic>?;
          if (levelsMap != null) {
            final levelKey = 'level_$levelNumber';
            _levelEarning = (levelsMap[levelKey] ?? 0.0).toDouble();
          }
        }

        _totalBusiness =
            (levelEarningsData?['total'] ??
                    walletData['totalLevelBonus'] ??
                    0.0)
                .toDouble();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading user and level details: $e');
    }
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

  String _getFirstLetter(String name) {
    if (name.isEmpty) return "U";
    return name[0].toUpperCase();
  }

  double _calculateProgress() {
    if (_levelEarning <= 0) return 0.0;
    final maxEarningForLevel = 1000.0;
    final progress = (_levelEarning / maxEarningForLevel).clamp(0.0, 1.0);
    return progress;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    final bonusPercentage =
        int.tryParse(widget.bonus.replaceAll('% Bonus', '')) ?? 0;
    final bonusAmount = _levelEarning;
    final dynamicProgress = _calculateProgress();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.level} Details",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isTablet ? 22 : 18,
            color: white,
          ),
        ),
        backgroundColor: primaryPurple,
        centerTitle: true,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryPurple, primaryBlue],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- User Profile Card ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryPurple.withOpacity(0.9), primaryBlue],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryPurple.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // User Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, lightBlue],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getFirstLetter(_userFullName),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: primaryPurple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    _userFullName,
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Username
                  Text(
                    "@${_userName.toLowerCase()}",
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Details Row - ONLY PACKAGE AND LEVEL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildUserDetailChip(
                        Icons.card_membership,
                        "Package",
                        _userPackage,
                        accentOrange,
                      ),
                      _buildUserDetailChip(
                        Icons.star,
                        "Level",
                        "Level $_userLevel",
                        accentGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Level & Bonus Card ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentOrange, accentPink],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: accentOrange.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Trophy Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Level Title
                  Text(
                    widget.level,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 36 : 28,
                      fontWeight: FontWeight.bold,
                      color: white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bonus Percentage
                  Text(
                    "+${widget.bonus}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 32 : 24,
                      fontWeight: FontWeight.w800,
                      color: white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: widget.achieved
                          ? accentGreen.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: widget.achieved ? accentGreen : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.achieved ? Icons.lock_open : Icons.lock,
                          color: widget.achieved ? accentGreen : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.achieved ? "Level Unlocked" : "Level Locked",
                          style: TextStyle(
                            color: widget.achieved ? accentGreen : Colors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Progress Section ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up_rounded, color: primaryPurple),
                          const SizedBox(width: 8),
                          Text(
                            "Level Progress",
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 16,
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${(dynamicProgress * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 14,
                          color: primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: dynamicProgress,
                      minHeight: isTablet ? 18 : 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        dynamicProgress >= 1.0 ? accentGreen : primaryPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Earnings Text
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "\$${_levelEarning.toStringAsFixed(3)} earned",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: isTablet ? 16 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Earnings Summary ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.attach_money_rounded,
                          color: primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Earnings Summary",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 20 : 17,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Level Earnings
                  _buildEarningItem(
                    "Level Earnings",
                    _levelEarning,
                    Icons.account_balance_wallet_rounded,
                    accentGreen,
                    context,
                  ),
                  const SizedBox(height: 16),

                  // Total Business
                  _buildEarningItem(
                    "Total Business",
                    _totalBusiness,
                    Icons.business_center_rounded,
                    primaryBlue,
                    context,
                  ),
                  const SizedBox(height: 16),

                  // Bonus Amount
                  _buildEarningItem(
                    "Bonus Amount",
                    bonusAmount,
                    Icons.celebration_rounded,
                    accentOrange,
                    context,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Detailed Breakdown ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryPurple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.analytics_rounded,
                          color: primaryPurple,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Detailed Breakdown",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 20 : 17,
                          color: primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bonus Percentage
                  _buildDetailItem(
                    "Bonus Percentage",
                    "${bonusPercentage}%",
                    Icons.percent_rounded,
                    accentPink,
                    context,
                  ),
                  const SizedBox(height: 16),

                  _buildDetailItem(
                    "Level Status",
                    widget.achieved ? "Active" : "Inactive",
                    widget.achieved
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    widget.achieved ? accentGreen : Colors.red,
                    context,
                  ),

                  const SizedBox(height: 16),

                  // // Earnings Calculation
                  // _buildDetailItem(
                  //   "Earnings Formula",

                  //   "${bonusPercentage}% of Total Business",
                  //   Icons.calculate_rounded,
                  //   accentOrange,
                  //   context,
                  // ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---- Requirements Section ----
            if (widget.requirements.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: deepBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.list_alt_rounded,
                            color: deepBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Level Requirements",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 20 : 17,
                            color: deepBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...widget.requirements.map(
                      (req) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: isTablet ? 28 : 24,
                              height: isTablet ? 28 : 24,
                              decoration: BoxDecoration(
                                color: widget.achieved
                                    ? accentGreen.withOpacity(0.15)
                                    : primaryPurple.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.achieved
                                    ? Icons.check_rounded
                                    : Icons.circle_rounded,
                                color: widget.achieved
                                    ? accentGreen
                                    : primaryPurple,
                                size: isTablet ? 18 : 16,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                req,
                                style: TextStyle(
                                  fontSize: isTablet ? 17 : 15,
                                  color: textPrimary,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // // Action Button (Conditional - Only show if level is achieved and has earnings)
            // if (widget.achieved && _levelEarning > 0)
            //   Container(
            //     width: double.infinity,
            //     margin: const EdgeInsets.symmetric(horizontal: 20),
            //     child: ElevatedButton(
            //       onPressed: () {
            //         _showClaimDialog(context);
            //       },
            //       style: ElevatedButton.styleFrom(
            //         backgroundColor: accentGreen,
            //         foregroundColor: white,
            //         padding: const EdgeInsets.symmetric(vertical: 18),
            //         shape: RoundedRectangleBorder(
            //           borderRadius: BorderRadius.circular(16),
            //         ),
            //         elevation: 6,
            //         shadowColor: accentGreen.withOpacity(0.4),
            //       ),
            //       child: Row(
            //         mainAxisAlignment: MainAxisAlignment.center,
            //         children: [
            //           Icon(Icons.account_balance_wallet_rounded, size: 24),
            //           const SizedBox(width: 12),
            //           Text(
            //             "Claim \$${_levelEarning.toStringAsFixed(3)}",
            //             style: const TextStyle(
            //               fontSize: 18,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailChip(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningItem(
    String title,
    double amount,
    IconData icon,
    Color color,
    BuildContext context,
  ) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 15,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "\$${amount.toStringAsFixed(3)}",
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: color.withOpacity(0.5),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String title,
    String value,
    IconData icon,
    Color color,
    BuildContext context,
  ) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withOpacity(0.05), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              maxLines: 1,
              title,
              style: TextStyle(
                fontSize: isTablet ? 17 : 15,
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 17 : 15,
              color: color,
              fontWeight: FontWeight.bold,
            ),

            overflow: TextOverflow.ellipsis, // ✅ keeps text in one line
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  void _showClaimDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, primaryPurple.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: accentGreen,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Claim Earnings",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to claim \$${_levelEarning.toStringAsFixed(3)} from ${widget.level}?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: textSecondary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Successfully claimed \$${_levelEarning.toStringAsFixed(3)} from ${widget.level}!",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: accentGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          "Claim Now",
                          style: TextStyle(fontWeight: FontWeight.bold),
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
}
