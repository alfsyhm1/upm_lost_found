import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'lost';
  File? _image;
  bool _loading = false;
  Position? _position;

  Future<void> _getImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _getLocation() async {
    _position = await Geolocator.getCurrentPosition();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await _getLocation();
    final user = Supabase.instance.client.auth.currentUser;
    final filePath = 'images/${DateTime.now().millisecondsSinceEpoch}.jpg';

    String imageUrl = '';
    if (_image != null) {
      await Supabase.instance.client.storage.from('images').upload(filePath, _image!);
      imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(filePath);
    }

    await Supabase.instance.client.from('items').insert({
      'title': _title.text,
      'description': _desc.text,
      'type': _type,
      'image_url': imageUrl,
      'reported_by': user?.id,
      'location_lat': _position?.latitude,
      'location_lng': _position?.longitude,
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item reported')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Lost/Found')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
            DropdownButton<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'lost', child: Text('Lost')),
                DropdownMenuItem(value: 'found', child: Text('Found')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            _image != null
                ? Image.file(_image!, height: 120)
                : ElevatedButton(onPressed: _getImage, child: const Text('Add Photo')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
