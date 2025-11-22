import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/main_container_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase (Replace with your actual keys)
  await Supabase.initialize(
    url: 'https://qtocjhbqvfbydvzdawcr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0b2NqaGJxdmZieWR2emRhd2NyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDk3OTYsImV4cCI6MjA3NzgyNTc5Nn0.7iyhBYKsrvGWHIzV3mnP5blomcibLK9II_B2DjNzaV8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UPM Lost & Found',
      theme: ThemeData(
        // UPM Red & White Theme
        primaryColor: const Color(0xFFB30000), // UPM Red
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFFB30000),
          secondary: const Color(0xFFFFCDD2),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB30000),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB30000),
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainContainerScreen(),
      },
    );
  }
}