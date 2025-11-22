import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_screen.dart';
import '../widgets/item_card.dart';
import '../models/item_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Item> items = [];

  Future<void> _loadItems() async {
    final res = await Supabase.instance.client.from('items').select().order('created_at', ascending: false);
    setState(() {
      items = (res as List).map((e) => Item.fromMap(e)).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UPM Lost & Found')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => ItemCard(item: items[index]),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
        },
      ),
    );
  }
}
