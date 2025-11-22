import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item_model.dart';
import '../widgets/item_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Item> matchedItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkMatches();
  }

  Future<void> _checkMatches() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. Get categories of items I LOST
    final myLostItems = await Supabase.instance.client
        .from('items')
        .select('category')
        .eq('reported_by', user.id)
        .eq('type', 'lost');

    if (myLostItems.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    List<String> myCategories = (myLostItems as List)
        .map((e) => e['category'] as String)
        .toSet() // remove duplicates
        .toList();

    // 2. Find items OTHERS FOUND in those categories
    final matches = await Supabase.instance.client
        .from('items')
        .select()
        .eq('type', 'found')
        .inFilter('category', myCategories)
        .neq('reported_by', user.id) // Don't show my own reports
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        matchedItems = (matches as List).map((e) => Item.fromMap(e)).toList();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alerts")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : matchedItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No matches found for your lost items yet."),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: matchedItems.length,
                  itemBuilder: (context, index) {
                    final item = matchedItems[index];
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.green.shade50,
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      "Possible match: Someone found a ${item.category}")),
                            ],
                          ),
                        ),
                        ItemCard(item: item),
                      ],
                    );
                  },
                ),
    );
  }
}