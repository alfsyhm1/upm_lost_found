import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final myId = Supabase.instance.client.auth.currentUser?.id;

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
    // Stream to count unread messages (Approximate for now)
    final alertStream = Supabase.instance.client.from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((list) => list.where((m) => m['receiver_id'] == myId).length);

    return Scaffold(
      body: _getPage(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
          else setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Report'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Locator'),
          NavigationDestination(
            icon: StreamBuilder<int>(
              stream: alertStream,
              builder: (context, snapshot) {
                int count = snapshot.data ?? 0;
                return badges.Badge(
                  showBadge: count > 0,
                  badgeContent: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  child: const Icon(Icons.notifications_outlined),
                );
              },
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}