import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DirectMembersScreen extends StatefulWidget {
  const DirectMembersScreen({super.key});

  @override
  State<DirectMembersScreen> createState() => _DirectMembersScreenState();
}

class _DirectMembersScreenState extends State<DirectMembersScreen> {
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

  String? _referralCode;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  int _activeCount = 0;
  int _inactiveCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDirectMembers();
  }

  Future<void> _loadDirectMembers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user's referral code
      final userDoc = await _firestore
          .collection('Signup_Data')
          .doc(user.uid)
          .get();
      if (!userDoc.exists) return;

      final referralCode = userDoc.data()?['referralCode'];
      if (referralCode == null) return;

      setState(() {
        _referralCode = referralCode;
      });

      // Get direct members
      final directMembersQuery = await _firestore
          .collection('Signup_Data')
          .where('sponsorId', isEqualTo: referralCode)
          .get();

      List<Map<String, dynamic>> members = [];
      int activeCount = 0;
      int inactiveCount = 0;

      // Process each member
      for (final doc in directMembersQuery.docs) {
        final data = doc.data();
        final id = doc.id;

        // Check if member has deposits
        final hasDeposit = await _checkMemberHasDeposit(id);

        if (hasDeposit) {
          activeCount++;
        } else {
          inactiveCount++;
        }

        members.add({
          'id': id,
          'name': data['name'] ?? 'Unknown User',
          'email': data['email'] ?? 'No email',
          'username': data['username'] ?? 'No username',
          'joinDate': _formatJoinDate(data['joinedAt'] ?? data['createdAt']),
          'isActive': hasDeposit,
          'referralCode': data['referralCode'] ?? '',
          'phone': data['phone'] ?? 'No phone',
          'package': await _getUserPackage(id),
        });
      }

      setState(() {
        _members = members;
        _activeCount = activeCount;
        _inactiveCount = inactiveCount;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading direct members: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkMemberHasDeposit(String memberId) async {
    try {
      print('🔍 Checking deposits for member: $memberId');

      // Check user-purchased packages in users collection
      final userPackages = await _firestore
          .collection('users')
          .doc(memberId)
          .collection('purchasedPackages')
          .get();

      // Check if any user package is active and finished
      for (final doc in userPackages.docs) {
        final data = doc.data();
        final packageTitle = data['packageTitle']?.toString().trim() ?? '';
        final status = data['status']?.toString().trim() ?? '';
        final isActive = data['isActive'] ?? false;

        print(
          '   User Package: $packageTitle, Status: $status, isActive: $isActive',
        );

        // Check if package is finished and active
        if (packageTitle.isNotEmpty &&
            status == 'finished' &&
            isActive == true) {
          print('   ✅ Active user package found: $packageTitle');
          return true;
        }
      }

      // ✅ Check admin-activated packages in Signup_Data collection
      final adminPackages = await _firestore
          .collection('Signup_Data')
          .doc(memberId)
          .collection('purchasedPackages')
          .get();

      // Check if any admin package is active and finished
      for (final doc in adminPackages.docs) {
        final data = doc.data();
        final packageTitle = data['packageTitle']?.toString().trim() ?? '';
        final status = data['status']?.toString().trim() ?? '';
        final isActive = data['isActive'] ?? false;
        final activatedBy = data['activatedBy']?.toString().trim() ?? '';

        print(
          '   Admin Package: $packageTitle, Status: $status, isActive: $isActive, activatedBy: $activatedBy',
        );

        // Check if package is finished and active (admin packages might have different criteria)
        if (packageTitle.isNotEmpty) {
          // For admin packages, check if they are finished OR activated by admin
          if ((status == 'finished' && isActive == true) ||
              (activatedBy == 'admin' && packageTitle.isNotEmpty)) {
            print('   ✅ Active admin package found: $packageTitle');
            return true;
          }
        }
      }

      print('   ❌ No active packages found for member: $memberId');
      return false;
    } catch (e) {
      print('❌ Error checking member deposit: $e');
      return false;
    }
  }

  Future<String> _getUserPackage(String memberId) async {
    try {
      print('🔍 Checking packages for member: $memberId');
      List<String> allPackages = [];

      // Check user-purchased packages
      final userPackages = await _firestore
          .collection('users')
          .doc(memberId)
          .collection('purchasedPackages')
          .orderBy('createdAt', descending: true)
          .get();

      print('📦 User packages found: ${userPackages.docs.length}');
      for (final doc in userPackages.docs) {
        final data = doc.data();
        final packageTitle = data['packageTitle']?.toString().trim() ?? '';
        final status = data['status']?.toString().trim() ?? '';
        final isActive = data['isActive'] ?? false;

        print(
          '   User Package: $packageTitle, Status: $status, isActive: $isActive',
        );

        // Only include finished and active packages
        if (packageTitle.isNotEmpty &&
            status == 'finished' &&
            isActive == true) {
          allPackages.add(packageTitle);
          print('   ✅ Added user package: $packageTitle');
        }
      }

      // Check admin-activated packages
      final adminPackages = await _firestore
          .collection('Signup_Data')
          .doc(memberId)
          .collection('purchasedPackages')
          .orderBy('createdAt', descending: true)
          .get();

      print('📦 Admin packages found: ${adminPackages.docs.length}');
      for (final doc in adminPackages.docs) {
        final data = doc.data();
        final packageTitle = data['packageTitle']?.toString().trim() ?? '';
        final status = data['status']?.toString().trim() ?? '';
        final isActive = data['isActive'] ?? false;
        final activatedBy = data['activatedBy']?.toString().trim() ?? '';

        print(
          '   Admin Package: $packageTitle, Status: $status, isActive: $isActive, activatedBy: $activatedBy',
        );

        // For admin packages, use more lenient criteria
        if (packageTitle.isNotEmpty) {
          // Include if finished and active OR activated by admin
          if ((status == 'finished' && isActive == true) ||
              (activatedBy == 'admin' && packageTitle.isNotEmpty)) {
            if (activatedBy == 'admin') {
              allPackages.add('$packageTitle (Admin)');
              print('   ✅ Added admin package: $packageTitle (Admin)');
            } else {
              allPackages.add(packageTitle);
              print('   ✅ Added admin package: $packageTitle');
            }
          }
        }
      }

      print('🎯 Final packages for $memberId: $allPackages');

      // Return all packages separated by comma, or "No Package"
      if (allPackages.isNotEmpty) {
        return allPackages.join(', ');
      }

      return 'Admin Package';
    } catch (e) {
      print('❌ Error getting user package: $e');
      return 'Admin Package';
    }
  }

  String _formatJoinDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }

  Color _getStatusColor(bool isActive) => isActive ? accentGreen : accentRed;

  String _getStatusText(bool isActive) => isActive ? 'Active' : 'Inactive';

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
      Color(0xFF3F51B5),
      Color(0xFF2196F3),
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFFFF5722),
    ];
    return colors[name.length % colors.length];
  }

  void _showMemberDetails(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getAvatarColor(member['name']),
                    child: Text(
                      _getInitials(member['name']),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          member['email'],
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        member['isActive'],
                      ).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(member['isActive']),
                      ),
                    ),
                    child: Text(
                      _getStatusText(member['isActive']),
                      style: TextStyle(
                        color: _getStatusColor(member['isActive']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Member Details
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Username', member['username']),
                    _buildDetailRow('Referral Code', member['referralCode']),
                    _buildDetailRow('Join Date', member['joinDate']),
                    _buildDetailRow('Package', member['package']),
                    _buildDetailRow('Phone', member['phone']),
                    _buildDetailRow('Member ID', member['id']),

                    SizedBox(height: 20),

                    // Additional Information
                    Text(
                      'Performance Stats',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryBlue,
                      ),
                    ),
                    SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat('Direct Team', '0'),
                        _buildMiniStat('Total Team', '0'),
                        _buildMiniStat('Level Income', '\$0'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Close Button
            Container(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: textLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: primaryBlue,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: textLight),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text(
          "Direct Members",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _members.isEmpty
          ? _buildEmptyState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryBlue),
          SizedBox(height: 16),
          Text(
            "Loading Direct Members...",
            style: TextStyle(
              fontSize: 16,
              color: textLight,
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
            color: textLight.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No Direct Members Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Share your referral code to get direct members",
            style: TextStyle(color: textLight, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryBlue),
            ),
            child: Text(
              _referralCode ?? 'Loading...',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Top Summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBlue, Color(0xFF6666FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("Total", _members.length.toString(), Icons.people_alt),
              _buildStat("Active", _activeCount.toString(), Icons.check_circle),
              _buildStat("Inactive", _inactiveCount.toString(), Icons.pending),
            ],
          ),
        ),

        // Members List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDirectMembers,
            color: primaryBlue,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                final initials = _getInitials(member['name']);
                final avatarColor = _getAvatarColor(member['name']);
                final isActive = member['isActive'];

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: avatarColor,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      member['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    subtitle: Text(
                      member['email'], // ✅ ONLY email, no package details
                      style: TextStyle(color: textLight, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(isActive).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatusColor(isActive)),
                      ),
                      child: Text(
                        _getStatusText(isActive),
                        style: TextStyle(
                          color: _getStatusColor(isActive),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () => _showMemberDetails(member),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
