import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      if (res.session != null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // No session returned — show details so user can diagnose (e.g. email not confirmed)
        final msg = res.user == null ? 'Login failed: no session returned' : 'Login completed but no session';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      // If session is returned, user is signed in immediately. Otherwise, they may need to confirm email.
      if (res.session != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created — logged in')));
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created — check your email to confirm')));
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('UPM Lost & Found', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 30),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: const Text('Login'),
              ),
              TextButton(onPressed: _register, child: const Text('Register')),
            ],
          ),
        ),
      ),
    );
  }
}
