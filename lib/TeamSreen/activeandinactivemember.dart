import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MembersScreen extends StatefulWidget {
  final bool showActive; // true = Active Members, false = Inactive Members

  const MembersScreen({super.key, required this.showActive});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color Scheme
  final Color primaryBlue = const Color(0xFF0000FF);
  final Color accentGreen = const Color(0xFF00C853);
  final Color accentRed = const Color(0xFFFF5252);
  final Color backgroundGrey = const Color(0xFFF5F7FA);
  final Color cardWhite = const Color(0xFFFFFFFF);
  final Color textDark = const Color(0xFF333333);
  final Color textLight = const Color(0xFF666666);
  final Color goldenAccent = const Color(0xFFFFD700);

  late bool isActiveTab;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    isActiveTab = widget.showActive;
  }

  // Stream to get all team members
  Stream<List<Map<String, dynamic>>> _getTeamMembersStream() {
    return Stream.fromFuture(_getCurrentUserReferralCode()).asyncExpand((
      referralCode,
    ) {
      if (referralCode.isEmpty) return Stream.value([]);
      return _getAllTeamMembersStream(referralCode);
    });
  }

  // Get current user's referral code
  Future<String> _getCurrentUserReferralCode() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '';

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['referralCode'] ?? '';
      }
      return '';
    } catch (e) {
      print('Error getting referral code: $e');
      return '';
    }
  }

  // Stream for all team members
  Stream<List<Map<String, dynamic>>> _getAllTeamMembersStream(
    String referralCode,
  ) {
    return _getAllTeamMemberIdsStream(referralCode).asyncMap((memberIds) async {
      List<Map<String, dynamic>> members = [];

      for (final memberId in memberIds) {
        final memberDoc = await _firestore
            .collection('Signup_Data')
            .doc(memberId)
            .get();

        if (memberDoc.exists) {
          final memberData = memberDoc.data() as Map<String, dynamic>;

          // Check if member has deposits (active/inactive status)
          final hasDeposit = await _checkMemberHasDeposit(memberId);

          members.add({
            'id': memberId,
            'name': memberData['name'] ?? 'Unknown',
            'email': memberData['email'] ?? 'No email',
            'username': memberData['username'] ?? 'No username',
            'joinDate': _formatJoinDate(memberData['joinedAt']),
            'isActive': hasDeposit,
            'referralCode': memberData['referralCode'] ?? '',
            'level': _calculateMemberLevel(memberData),
          });
        }
      }

      return members;
    });
  }

  // Stream to get all team member IDs recursively
  Stream<Set<String>> _getAllTeamMemberIdsStream(String referralCode) {
    return _firestore
        .collection('Signup_Data')
        .where('sponsorId', isEqualTo: referralCode)
        .snapshots()
        .asyncExpand((directMembersSnapshot) async* {
          Set<String> allMemberIds = {};

          for (final doc in directMembersSnapshot.docs) {
            allMemberIds.add(doc.id);
            final memberData = doc.data() as Map<String, dynamic>;
            final memberReferralCode = memberData['referralCode'];

            if (memberReferralCode != null && memberReferralCode.isNotEmpty) {
              // Recursively get downline members
              final downlineIds = await _getAllTeamMemberIdsStream(
                memberReferralCode,
              ).first;
              allMemberIds.addAll(downlineIds);
            }
          }

          yield allMemberIds;
        });
  }

  // ✅ UPDATED: Check if member has VALID deposits (EXCLUDING admin-activated packages)
  // ✅ UPDATED: Check if member has VALID user-purchased packages
  Future<bool> _checkMemberHasDeposit(String memberId) async {
    try {
      // Check both collections for purchased packages
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

      // Combine both collections
      final allPackages = [...userPackages.docs, ...signupPackages.docs];

      // Check if any package meets the criteria for active member
      for (final packageDoc in allPackages) {
        final packageData = packageDoc.data();

        final status = packageData['status']?.toString().toLowerCase();
        final isActive = packageData['isActive'] ?? false;
        final activatedBy = packageData['activatedBy']
            ?.toString()
            .toLowerCase();
        final packageTitle =
            packageData['packageTitle']?.toString().trim() ?? '';

        // ✅ Member is ACTIVE if:
        // 1. Package has valid title
        // 2. Status is 'finished'
        // 3. isActive is true
        // 4. activatedBy is NOT 'admin' (user purchased)
        if (packageTitle.isNotEmpty &&
            status == 'finished' &&
            isActive == true &&
            activatedBy != 'admin') {
          return true; // Member has at least one valid user-purchased package
        }
      }

      // If no valid user-purchased packages found, member is INACTIVE
      return false;
    } catch (e) {
      print('Error checking member deposits: $e');
      return false;
    }
  }

  String _formatJoinDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _calculateMemberLevel(Map<String, dynamic> memberData) {
    final levels = ['Member'];
    final index = (memberData['name']?.length ?? 0) % levels.length;
    return levels[index];
  }

  List<Map<String, dynamic>> _filterMembers(
    List<Map<String, dynamic>> members,
    bool active,
    String searchQuery,
  ) {
    var filtered = members
        .where((member) => member['isActive'] == active)
        .toList();

    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (member) =>
                member['name'].toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                member['email'].toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                member['username'].toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    return filtered;
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? accentGreen : accentRed;
  }

  String _getStatusText(bool isActive) {
    return isActive ? 'Active' : 'Inactive';
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'diamond':
        return const Color(0xFFB9F2FF);
      case 'platinum':
        return const Color(0xFFE5E4E2);
      case 'gold':
        return goldenAccent;
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
        return const Color(0xFFCD7F32);
      default:
        return primaryBlue.withOpacity(0.1);
    }
  }

  Color _getLevelTextColor(String level) {
    switch (level.toLowerCase()) {
      case 'diamond':
        return const Color(0xFF00B4D8);
      case 'platinum':
        return const Color(0xFF555555);
      case 'gold':
        return const Color(0xFFB8860B);
      case 'silver':
        return const Color(0xFF696969);
      case 'bronze':
        return const Color(0xFF8B4513);
      default:
        return primaryBlue;
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Color(0xFFE91E63), // Pink
      Color(0xFF9C27B0), // Purple
      Color(0xFF673AB7), // Deep Purple
      Color(0xFF3F51B5), // Indigo
      Color(0xFF2196F3), // Blue
      Color(0xFF00BCD4), // Cyan
      Color(0xFF009688), // Teal
      Color(0xFF4CAF50), // Green
      Color(0xFFFF9800), // Orange
      Color(0xFFFF5722), // Deep Orange
    ];

    final index = name.length % colors.length;
    return colors[index];
  }

  void _onTabChanged(bool active) {
    setState(() {
      isActiveTab = active;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      body: Column(
        children: [
          // App Bar with Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, Color(0xFF6666FF)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Back button and title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            "Team Members",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // For balance
                      ],
                    ),
                  ),

                  // Tabs
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        _buildTab("Active Members", true),
                        _buildTab("Inactive Members", false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search members...",
                  prefixIcon: Icon(Icons.search, color: primaryBlue),
                  filled: true,
                  fillColor: cardWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),

          // Members List with StreamBuilder
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getTeamMembersStream(),
              builder: (context, snapshot) {
                // Show data immediately as it loads
                if (snapshot.hasData) {
                  final allMembers = snapshot.data!;
                  final filteredMembers = _filterMembers(
                    allMembers,
                    isActiveTab,
                    _searchQuery,
                  );

                  return _buildContent(filteredMembers);
                }

                // If no data yet, show empty state with potential to show data as it arrives
                return _buildContent([]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool activeTab) {
    final selected = isActiveTab == activeTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(activeTab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? primaryBlue : Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> filteredMembers) {
    return Column(
      children: [
        // Stats and Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredMembers.length} ${filteredMembers.length == 1 ? 'member' : 'members'} found',
                style: TextStyle(
                  color: textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(isActiveTab).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(isActiveTab),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStatusText(isActiveTab),
                  style: TextStyle(
                    color: _getStatusColor(isActiveTab),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Members List
        Expanded(
          child: filteredMembers.isNotEmpty
              ? _buildMembersList(filteredMembers)
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isActiveTab ? "No Active Members" : "No Inactive Members",
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActiveTab
                ? "Active members will appear here once they make deposits"
                : "Members without deposits will appear here",
            style: TextStyle(color: textLight, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(List<Map<String, dynamic>> filteredMembers) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) {
        final member = filteredMembers[index];
        final initials = _getInitials(member['name']);
        final avatarColor = _getAvatarColor(member['name']);
        final isActive = member['isActive'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cardWhite, Colors.grey.withOpacity(0.05)],
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [avatarColor, avatarColor.withOpacity(0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member['email'],
                      style: TextStyle(color: textLight, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getLevelColor(member['level']),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            member['level'],
                            style: TextStyle(
                              color: _getLevelTextColor(member['level']),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.calendar_today, size: 10, color: textLight),
                        const SizedBox(width: 2),
                        Text(
                          member['joinDate'],
                          style: TextStyle(color: textLight, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(isActive).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(isActive),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _getStatusText(isActive),
                        style: TextStyle(
                          color: _getStatusColor(isActive),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  _showMemberDetails(context, member);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMemberDetails(
    BuildContext context,
    Map<String, dynamic> member,
  ) async {
    try {
      // Get member's packages from both collections
      final userPackages = await _firestore
          .collection('users')
          .doc(member['id'])
          .collection('purchasedPackages')
          .get();

      final signupPackages = await _firestore
          .collection('Signup_Data')
          .doc(member['id'])
          .collection('purchasedPackages')
          .get();

      // Combine and process packages
      final allPackages = [...userPackages.docs, ...signupPackages.docs];

      List<Map<String, dynamic>> memberPackages = [];

      for (final packageDoc in allPackages) {
        final packageData = packageDoc.data();
        final packageTitle =
            packageData['packageTitle']?.toString().trim() ?? '';

        if (packageTitle.isNotEmpty) {
          // ✅ FIX: Handle price field properly
          dynamic price =
              packageData['packagePrice'] ?? packageData['price'] ?? 'Unknown';

          // Convert double to string if needed
          if (price is double) {
            price = '\$$price';
          }

          memberPackages.add({
            'title': packageTitle,
            'status': packageData['status'] ?? 'unknown',
            'isActive': packageData['isActive'] ?? false,
            'activatedBy': packageData['activatedBy'] ?? 'user',
            'purchaseDate': packageData['purchaseDate'] ?? 'Unknown',
            'price': price, // ✅ FIXED: Use the properly handled price
          });
        }
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _buildMemberDetailsSheet(member, memberPackages),
      );
    } catch (e) {
      print('Error fetching member packages: $e');
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _buildMemberDetailsSheet(member, []),
      );
    }
  }

  Widget _buildMemberDetailsSheet(
    Map<String, dynamic> member,
    List<Map<String, dynamic>> packages,
  ) {
    final initials = _getInitials(member['name']);
    final avatarColor = _getAvatarColor(member['name']);
    final isActive = member['isActive'];

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.85, // ✅ Maximum height
        ),
        child: SingleChildScrollView(
          // ✅ Make it scrollable
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [avatarColor, avatarColor.withOpacity(0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Member name
                Text(
                  member['name'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(isActive).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(isActive),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.pending,
                        size: 16,
                        color: _getStatusColor(isActive),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(isActive),
                        style: TextStyle(
                          color: _getStatusColor(isActive),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Basic Details
                _buildDetailRow("Email", member['email'], Icons.email),
                _buildDetailRow("Username", member['username'], Icons.person),
                _buildDetailRow(
                  "Join Date",
                  member['joinDate'],
                  Icons.calendar_today,
                ),
                _buildDetailRow("Level", member['level'], Icons.emoji_events),
                _buildDetailRow(
                  "Referral Code",
                  member['referralCode'],
                  Icons.code,
                ),

                const SizedBox(height: 20),

                // Packages Section - With limited height and scroll
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundGrey,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: primaryBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag,
                            color: primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Purchased Packages (${packages.length})",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      packages.isNotEmpty
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 300, // ✅ Limit packages list height
                              ),
                              child: SingleChildScrollView(
                                // ✅ Make packages list scrollable
                                child: Column(
                                  children: packages.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final pkg = entry.value;
                                    final isUserPurchased =
                                        pkg['activatedBy']
                                            ?.toString()
                                            .toLowerCase() !=
                                        'admin';

                                    // ✅ FIX: Handle double price conversion
                                    String priceText = 'Unknown';
                                    if (pkg['price'] != null) {
                                      if (pkg['price'] is double) {
                                        priceText = '\$${pkg['price']}';
                                      } else if (pkg['price'] is String) {
                                        priceText = pkg['price'];
                                      } else {
                                        priceText = '\$${pkg['price']}';
                                      }
                                    }

                                    return Container(
                                      margin: EdgeInsets.only(
                                        bottom: index == packages.length - 1
                                            ? 0
                                            : 10,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cardWhite,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isUserPurchased
                                              ? accentGreen
                                              : accentRed,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Status Icon
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: pkg['isActive'] == true
                                                  ? accentGreen.withOpacity(0.2)
                                                  : Colors.orange.withOpacity(
                                                      0.2,
                                                    ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              pkg['isActive'] == true
                                                  ? Icons.check_circle
                                                  : Icons.pending,
                                              size: 16,
                                              color: pkg['isActive'] == true
                                                  ? accentGreen
                                                  : Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Package Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Package Title and Purchase Type
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        pkg['title'] ??
                                                            'Unknown Package',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: textDark,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isUserPurchased
                                                            ? accentGreen
                                                                  .withOpacity(
                                                                    0.1,
                                                                  )
                                                            : accentRed
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: isUserPurchased
                                                              ? accentGreen
                                                              : accentRed,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        isUserPurchased
                                                            ? 'User'
                                                            : 'Admin',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isUserPurchased
                                                              ? accentGreen
                                                              : accentRed,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),

                                                // Package Status
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.circle,
                                                      size: 8,
                                                      color:
                                                          pkg['isActive'] ==
                                                              true
                                                          ? accentGreen
                                                          : Colors.orange,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      pkg['isActive'] == true
                                                          ? 'Active'
                                                          : 'Inactive',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            pkg['isActive'] ==
                                                                true
                                                            ? accentGreen
                                                            : Colors.orange,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Icon(
                                                      Icons.assignment,
                                                      size: 12,
                                                      color: textLight,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      pkg['status']
                                                              ?.toString()
                                                              .toUpperCase() ??
                                                          'UNKNOWN',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: textLight,
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Package Price and Date
                                                if (priceText != 'Unknown' ||
                                                    pkg['purchaseDate'] !=
                                                        null) ...[
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      if (priceText !=
                                                          'Unknown') ...[
                                                        Icon(
                                                          Icons.attach_money,
                                                          size: 12,
                                                          color: textLight,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          priceText,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: textLight,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                      ],
                                                      if (pkg['purchaseDate'] !=
                                                          null) ...[
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 12,
                                                          color: textLight,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          pkg['purchaseDate']
                                                                  is String
                                                              ? pkg['purchaseDate']
                                                              : pkg['purchaseDate']
                                                                    .toString(),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: textLight,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 40,
                                    color: textLight.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "No Packages Purchased",
                                    style: TextStyle(
                                      color: textLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    "This member hasn't purchased any packages yet",
                                    style: TextStyle(
                                      color: textLight.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 3,
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
