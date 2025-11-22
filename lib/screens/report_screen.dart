import 'package:latlong2/latlong.dart'; // Crucial for LatLng
import '../services/dijkstra_service.dart'; // Crucial for findNearestFacultyId
// Crucial for faculty data
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart'; // AI Package
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
// Import the updated service

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationTagController = TextEditingController();
  
  String _type = 'found'; // 'lost' or 'found'
  String _category = 'Electronics';
  File? _image;
  bool _loading = false;
  Position? _currentPosition;
  String? _suggestedDropOffNode;

  final List<String> _categories = ['Electronics', 'Clothing', 'Documents', 'Keys', 'Wallet', 'Other'];

  // AI: Process Image
  Future<void> _processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
    
    try {
      final labels = await imageLabeler.processImage(inputImage);
      if (labels.isNotEmpty) {
        // Auto-fill title and description with top labels
        String detected = labels.take(3).map((l) => l.label).join(', ');
        setState(() {
          _titleController.text = labels.first.label; // Main object
          _descController.text = "Detected items: $detected. \nColor/Details: ";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Detected: $detected')),
        );
      }
    } catch (e) {
      debugPrint('AI Error: $e');
    } finally {
      imageLabeler.close();
    }
  }

  Future<void> _getImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _image = File(picked.path));
      await _processImage(_image!);
    }
  }

  Future<void> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = pos;
        _locationTagController.text = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
      });
      
      // Calculate nearest faculty for drop-off suggestion
      if (_type == 'found') {
        _calculateNearestDropOff(pos);
      }
    }
  }

  void _calculateNearestDropOff(Position pos) {
    // Simple logic to find nearest faculty node
    // In a real app, you'd iterate through all facultyNodes
    // This uses the Dijkstra Service helper
    String nearestId = findNearestFacultyId(LatLng(pos.latitude, pos.longitude));
    setState(() {
      _suggestedDropOffNode = nearestId;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null && _type == 'found') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please take a photo for found items.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      String imageUrl = '';
      
      if (_image != null) {
        final filePath = 'images/${user?.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage.from('images').upload(filePath, _image!);
        imageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(filePath);
      }

      await Supabase.instance.client.from('items').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _type,
        'category': _category,
        'image_url': imageUrl,
        'reported_by': user?.id,
        'location_lat': _currentPosition?.latitude,
        'location_lng': _currentPosition?.longitude,
        'location_name': _locationTagController.text,
        'drop_off_node': _suggestedDropOffNode, // Optional: where it was left
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully!')));
        // Reset form
        _titleController.clear();
        _descController.clear();
        setState(() => _image = null);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
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
              // Type Selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'lost', label: Text('I Lost Something')),
                  ButtonSegment(value: 'found', label: Text('I Found Something')),
                ],
                selected: {_type},
                onSelectionChanged: (newSet) {
                  setState(() {
                    _type = newSet.first;
                    if (_type == 'lost') _suggestedDropOffNode = null;
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected) ? Colors.red.shade100 : null;
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // Image Upload with AI Badge
              GestureDetector(
                onTap: _getImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                            Text("Tap to take photo (AI Enabled)"),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (AI Auto-filled)',
                  hintText: 'Identifying details, color, brand...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),

              // Location Section
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _locationTagController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin_drop),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _getLocation,
                  ),
                ],
              ),

              // Dijkstra Suggestion for Found Items
              if (_type == 'found' && _suggestedDropOffNode != null)
                Card(
                  color: Colors.green.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        const Text("Suggested Action", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Nearest Faculty Centre: ${getFacultyName(_suggestedDropOffNode!)}"),
                        const SizedBox(height: 5),
                        Text("You can drop it off here so the owner can collect it.", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                child: _loading ? const CircularProgressIndicator() : const Text('SUBMIT REPORT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}