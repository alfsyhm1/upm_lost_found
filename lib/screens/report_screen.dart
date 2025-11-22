import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:latlong2/latlong.dart';
import '../services/dijkstra_service.dart';
import '../models/faculty_model.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _locationController = TextEditingController();
  
  String _type = 'lost';
  String _category = 'Electronics';
  File? _image;
  bool _loading = false;
  Position? _position;
  String? _suggestedDropOffNode; // For Dijkstra

  final List<String> _categories = ['Electronics', 'Clothing', 'Documents', 'Keys', 'Wallet', 'Other'];

  // AI Function: Detect items in photo
  Future<void> _processImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
    try {
      final labels = await imageLabeler.processImage(inputImage);
      if (labels.isNotEmpty) {
        final detected = labels.take(3).map((l) => l.label).join(', ');
        setState(() {
          _title.text = labels.first.label;
          _desc.text = "Detected: $detected. \nDetails: ";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Detected: $detected")));
      }
    } catch (e) {
      debugPrint("AI Error: $e");
    } finally {
      imageLabeler.close();
    }
  }

  Future<void> _getImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      final file = File(picked.path);
      setState(() => _image = file);
      _processImage(file); // Run AI
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _position = pos;
      _locationController.text = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
    });

    // If item found, run Dijkstra to find nearest faculty
    if (_type == 'found') {
      final nearestId = findNearestFacultyId(LatLng(pos.latitude, pos.longitude));
      setState(() {
        _suggestedDropOffNode = nearestId;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      String imageUrl = '';
      
      if (_image != null) {
        final filePath = 'images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('images').upload(filePath, _image!);
        imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(filePath);
      }

      await Supabase.instance.client.from('items').insert({
        'title': _title.text,
        'description': _desc.text,
        'type': _type,
        'category': _category,
        'image_url': imageUrl,
        'reported_by': user?.id,
        'location_lat': _position?.latitude,
        'location_lng': _position?.longitude,
        'location_name': _locationController.text,
        'drop_off_node': _suggestedDropOffNode,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Submitted Successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle Type
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text("Lost"),
                      value: "lost", 
                      groupValue: _type, 
                      onChanged: (v) => setState(() => _type = v.toString()),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text("Found"),
                      value: "found", 
                      groupValue: _type, 
                      onChanged: (v) => setState(() => _type = v.toString()),
                    ),
                  ),
                ],
              ),

              // Image Picker
              GestureDetector(
                onTap: _getImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _image != null 
                    ? Image.file(_image!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [Icon(Icons.camera_alt, size: 40), Text("Take Photo (AI Scan)")],
                      ),
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v.toString()),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),

              // Location
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                  )
                ],
              ),

              // Dijkstra Suggestion Box
              if (_type == 'found' && _suggestedDropOffNode != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  color: Colors.green.shade50,
                  child: Column(
                    children: [
                      const Text("Suggested Drop-off Point (Nearest Faculty)", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(getFacultyName(_suggestedDropOffNode!)),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                child: _loading ? const CircularProgressIndicator() : const Text("SUBMIT REPORT"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}