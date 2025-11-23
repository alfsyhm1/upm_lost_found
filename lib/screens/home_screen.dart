import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_screen.dart';
import '../widgets/item_card.dart';
import '../models/item_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Wrap in DefaultTabController
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UPM Lost & Found'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "LOST ITEMS"),
              Tab(text: "FOUND ITEMS"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList('lost'),  // Tab 1 Content
            _buildList('found'), // Tab 2 Content
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFFB30000),
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
          },
        ),
      ),
    );
  }

  // 2. Reusable List Builder
  Widget _buildList(String type) {
    final stream = Supabase.instance.client
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('type', type) // Filter by type
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final items = snapshot.data!.map((e) => Item.fromMap(e)).toList();
        
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type == 'lost' ? Icons.search_off : Icons.check_circle_outline, 
                     size: 60, color: Colors.grey),
                Text("No $type items reported yet."),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) => ItemCard(item: items[index]),
        );
      },
    );
  }
}