import 'dart:async';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'locator_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart'; 

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final myId = Supabase.instance.client.auth.currentUser?.id;
  StreamSubscription? _msgSubscription;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen for app background/foreground state
    _initNotifications();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Handle click on system notification
        if (response.payload != null) {
           // We can navigate to the chat here if we pass senderId in payload
           setState(() => _currentIndex = 3); // Go to Alerts tab
        }
      }
    );

    // REQUEST PERMISSION FOR ANDROID 13+
    final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  Future<void> _showSystemNotification(String title, String body, String payload) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'upm_lost_found_channel', 
      'Messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher', // Ensure you have an icon
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    
    await _notificationsPlugin.show(
      DateTime.now().millisecond, 
      title, 
      body, 
      details,
      payload: payload, // Pass data to click handler
    );
  }

  void _setupNotificationListener() {
    // Listen for NEW messages
    _msgSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', myId!)
        .order('created_at', ascending: false)
        .limit(1) 
        .listen((List<Map<String, dynamic>> data) {
          if (data.isEmpty) return;
          
          final lastMsg = data.first;
          final senderId = lastMsg['sender_id'];
          final content = lastMsg['content'];
          final createdAt = DateTime.parse(lastMsg['created_at']);

          // 1. FILTER: Ignore messages older than 30 seconds (Increased from 10s)
          // This allows "just missed" messages to still notify you.
          if (DateTime.now().difference(createdAt).inSeconds > 30) return;

          // 2. FILTER: Ignore if I am the sender
          if (senderId == myId) return;

          // 3. FILTER: Ignore if I am CURRENTLY looking at this chat
          if (ChatScreen.activeChatUserId == senderId) return;

          // 4. TRIGGER NOTIFICATION
          // Shows on Lock Screen / Status Bar
          _showSystemNotification("New Message", content, senderId);

          // 5. ALSO SHOW IN-APP SNACKBAR (Only if app is open)
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFFB30000),
                content: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text("New: $content", maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                action: SnackBarAction(
                  label: "VIEW",
                  textColor: Colors.amber,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                      otherUserId: senderId, 
                      otherUserName: "User", 
                      itemId: lastMsg['item_id'],
                    )));
                  },
                ),
              )
            );
          }
    });
  }

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
    final alertStream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', myId!)
        .order('created_at');

    return Scaffold(
      body: _getPage(_currentIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: const Color(0xFFB30000).withOpacity(0.2), // Red Tint
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Report'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Locator'),
          NavigationDestination(
            icon: StreamBuilder<List<Map<String, dynamic>>>(
              stream: alertStream,
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.length : 0;
                return badges.Badge(
                  showBadge: count > 0,
                  badgeContent: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  badgeStyle: const badges.BadgeStyle(badgeColor: Color(0xFFB30000)), // UPM Red Badge
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