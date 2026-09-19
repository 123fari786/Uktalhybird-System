import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TotalTeamScreen extends StatefulWidget {
  const TotalTeamScreen({super.key});

  @override
  State<TotalTeamScreen> createState() => _TotalTeamScreenState();
}

class _TotalTeamScreenState extends State<TotalTeamScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = true;
  int _directCount = 0;
  int _indirectCount = 0;

  // Color Scheme
  final Color primaryColor = const Color(0xFF6C63FF);
  final Color secondaryColor = const Color(0xFF4A44B5);
  final Color accentColor = const Color(0xFF00D4AA);
  final Color backgroundColor = const Color(0xFFF8F9FF);
  final Color cardColor = Colors.white;
  final Color textPrimary = const Color(0xFF2D3748);
  final Color textSecondary = const Color(0xFF718096);
  final Color directBadgeColor = const Color(0xFF4ADE80);
  final Color indirectBadgeColor = const Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userReferralCode = userData['referralCode'];

      // Get all team members recursively
      final allMembers = await _getAllTeamMembers(userReferralCode);

      setState(() {
        _teamMembers = allMembers;
        _directCount = allMembers
            .where((member) => member['isDirect'] == true)
            .length;
        _indirectCount = allMembers
            .where((member) => member['isDirect'] == false)
            .length;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading team members: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getAllTeamMembers(
    String referralCode,
  ) async {
    List<Map<String, dynamic>> allMembers = [];

    try {
      // Get direct members
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      for (final doc in directMembersQuery.docs) {
        final memberData = doc.data();
        allMembers.add({
          'id': doc.id,
          'name': memberData['name'] ?? 'Unknown',
          'email': memberData['email'] ?? '',
          'joinDate': memberData['timestamp'] ?? DateTime.now(),
          'isDirect': true,
          'referralCode': memberData['referralCode'],
        });

        // Get indirect members recursively
        final indirectMembers = await _getIndirectTeamMembers(
          memberData['referralCode'],
        );
        allMembers.addAll(indirectMembers);
      }
    } catch (e) {
      print('Error getting team members: $e');
    }

    return allMembers;
  }

  Future<List<Map<String, dynamic>>> _getIndirectTeamMembers(
    String referralCode,
  ) async {
    List<Map<String, dynamic>> indirectMembers = [];

    try {
      final membersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      for (final doc in membersQuery.docs) {
        final memberData = doc.data();
        indirectMembers.add({
          'id': doc.id,
          'name': memberData['name'] ?? 'Unknown',
          'email': memberData['email'] ?? '',
          'joinDate': memberData['timestamp'] ?? DateTime.now(),
          'isDirect': false,
          'referralCode': memberData['referralCode'],
        });

        // Continue recursion for deeper levels
        final deeperMembers = await _getIndirectTeamMembers(
          memberData['referralCode'],
        );
        indirectMembers.addAll(deeperMembers);
      }
    } catch (e) {
      print('Error getting indirect members: $e');
    }

    return indirectMembers;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final names = name.split(' ');
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF4A44B5),
      const Color(0xFF00D4AA),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA726),
      const Color(0xFF66BB6A),
      const Color(0xFFAB47BC),
    ];
    final index = name.length % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Total Team Overview",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 24 : 20,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadTeamMembers,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _teamMembers.isEmpty
          ? _buildEmptyState()
          : _buildTeamList(size),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading Team Members...",
            style: TextStyle(
              fontSize: 16,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
            color: textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            "No Team Members Yet",
            style: TextStyle(
              fontSize: 18,
              color: textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Start building your team by sharing your referral code",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList(Size size) {
    return Column(
      children: [
        // Summary Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  "Total Team",
                  _teamMembers.length.toString(),
                  Icons.people_alt,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  "Direct",
                  _directCount.toString(),
                  Icons.person_add,
                  directBadgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  "Indirect",
                  _indirectCount.toString(),
                  Icons.group,
                  indirectBadgeColor,
                ),
              ),
            ],
          ),
        ),

        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search team members...",
                      hintStyle: TextStyle(
                        color: textSecondary.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      // Implement search functionality
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.filter_list, color: primaryColor),
                  onPressed: () {
                    // Implement filter functionality
                  },
                ),
              ],
            ),
          ),
        ),

        // Team Members List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _teamMembers.length,
            itemBuilder: (context, index) {
              final member = _teamMembers[index];
              return _buildMemberCard(member, size);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, Size size) {
    final isDirect = member['isDirect'] as bool;
    final joinDate = member['joinDate'] is Timestamp
        ? (member['joinDate'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getAvatarColor(member['name']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _getInitials(member['name']),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAvatarColor(member['name']),
              ),
            ),
          ),
        ),
        title: Text(
          member['name'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              member['email'],
              style: TextStyle(fontSize: 12, color: textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Joined: ${_formatDate(joinDate)}',
              style: TextStyle(
                fontSize: 11,
                color: textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDirect
                ? directBadgeColor.withOpacity(0.1)
                : indirectBadgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDirect ? directBadgeColor : indirectBadgeColor,
              width: 1,
            ),
          ),
          child: Text(
            isDirect ? 'Direct' : 'Indirect',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDirect ? directBadgeColor : indirectBadgeColor,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
