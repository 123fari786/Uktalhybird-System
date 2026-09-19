import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:uktalhybird/Bottomnavigation/Pacakages.dart';
import 'package:uktalhybird/Bottomnavigation/Teamscreen.dart';
import 'package:uktalhybird/Bottomnavigation/lotterryscreen.dart';
import 'package:uktalhybird/Bottomnavigation/matrixscreen.dart';
import 'package:uktalhybird/dashborad.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2; // Default (Home screen)
  bool _showLoginIndicator = false;

  // Screens list
  final List<Widget> _screens = [
    PackageScreen(),
    TeamDashboardScreen(),
    const DashboardScreen(), // Home dashboard
    MatrixIncomeScreen(),
    const LotteryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showLoginIndicatorFunction() {
    if (!_showLoginIndicator) {
      setState(() {
        _showLoginIndicator = true;
      });

      // Hide after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showLoginIndicator = false;
          });
        }
      });
    }
  }

  // Enhanced method to wrap screens with scroll detection
  Widget _buildScrollableScreen(Widget screen) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (UserScrollNotification notification) {
        if (notification.direction == ScrollDirection.forward) {
          // Scrolling downward
          _showLoginIndicatorFunction();
        }
        return false;
      },
      child: screen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _selectedIndex,
            children: _screens
                .map((screen) => _buildScrollableScreen(screen))
                .toList(),
          ),

          // Simple Loading Indicator with animation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _showLoginIndicator
                ? MediaQuery.of(context).padding.top + 10
                : -100,
            left: 0,
            right: 0,
            child: _buildSimpleLoadingIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color.fromRGBO(41, 98, 255, 1),
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: "Package",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Team"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "Matrix",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports),
            label: "Lottery",
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleLoadingIndicator() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            elevation: 4,
            shape: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
