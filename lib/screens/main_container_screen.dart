import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'locator_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;

  // This function builds ONLY the screen you selected.
  // It prevents the Map and other heavy screens from loading in the background.
  Widget _getPage(int index) {
    switch (index) {
      case 0: return const HomeScreen();
      case 1: return const ReportScreen();
      case 2: return const LocatorScreen();
      case 3: return const AlertsScreen();
      case 4: return const ProfileScreen();
      default: return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We use _getPage instead of IndexedStack to save memory
      body: _getPage(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // If user taps "Report" (index 1), push it as a new screen instead of switching tabs
          // This keeps the back button working correctly.
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
          } else {
            setState(() => _currentIndex = index);
          }
        },
        indicatorColor: Colors.red.shade100,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Report'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Locator'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}