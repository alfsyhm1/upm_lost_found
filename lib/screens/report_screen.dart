import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:latlong2/latlong.dart' as latLng;
import '../services/dijkstra_service.dart';
import '../models/item_model.dart';
import '../models/faculty_model.dart'; // Import Faculty Nodes
import 'item_detail_screen.dart'; 

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _currentStep = 0;
  String _type = 'found';
  List<File> _images = [];
  bool _loading = false;
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  
  // Security
  final _questionController = TextEditingController(); 
  final _answerController = TextEditingController();
  bool _isMultipleChoice = true;
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController(), TextEditingController()];
  int _correctOptionIndex = 0;

  String _category = 'Other';
  double? _lat;
  double? _lng;
  
  // --- NEW: SMART DROP-OFF LOGIC ---
  String? _selectedFacultyId; // The ID of the faculty (e.g., "FSKTM")
  // ---------------------------------

  final List<String> _categories = ['Electronics', 'Clothing', 'Wallet', 'Keys', 'Documents', 'Accessories', 'Other'];

  Widget _buildHeader() {
    return Positioned(
      top: 50, left: 20,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white, 
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)],
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
        ),
      ),
    );
  }

  Widget _buildSelectionStep() {
    return Scaffold(
      appBar: AppBar(title: const Text("New Report")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("What are you reporting?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _selectionButton("I FOUND\nAN ITEM", Icons.volunteer_activism, Colors.blue, 'found'),
                _selectionButton("I LOST\nAN ITEM", Icons.search, Colors.red, 'lost'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionButton(String text, IconData icon, Color color, String type) {
    return GestureDetector(
      onTap: () => _handleSelection(type),
      child: Container(
        width: 150, height: 150,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSelection(String type) async {
    setState(() => _type = type);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add photos of the $type item?", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text("Take Photo"),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purple),
                title: const Text("Choose from Gallery"),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
              ),
              if (type == 'lost')
                ListTile(
                  leading: const Icon(Icons.edit_note, color: Colors.grey),
                  title: const Text("Skip photo (Describe only)"),
                  onTap: () { 
                    Navigator.pop(ctx); 
                    setState(() => _currentStep = 1); 
                    _getSmartLocation(); 
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final picked = await picker.pickMultiImage();
        if (picked.isNotEmpty) {
          setState(() => _images = picked.map((e) => File(e.path)).toList());
          if (mounted) {
             await Future.delayed(const Duration(milliseconds: 500));
             _analyzeImages();
          }
        }
      } else {
        final picked = await picker.pickImage(source: source);
        if (picked != null) {
          setState(() => _images.add(File(picked.path)));
          if (mounted) {
             await Future.delayed(const Duration(milliseconds: 500));
             _analyzeImages();
          }
        }
      }
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    }
  }

  Future<void> _analyzeImages() async {
    if (_images.isEmpty) return;
    setState(() => _loading = true);

    try {
      final inputImage = InputImage.fromFile(_images.first);
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.3));
      final labels = await labeler.processImage(inputImage);
      labeler.close();

      final palette = await PaletteGenerator.fromImageProvider(FileImage(_images.first));
      String colorInfo = "Unknown Color";
      if (palette.dominantColor != null) {
        colorInfo = palette.dominantColor!.color.computeLuminance() > 0.5 ? "Light/White" : "Dark/Black";
      }

      setState(() => _loading = false);

      final priorityKeywords = ['Key', 'Wallet', 'Phone', 'Laptop', 'Bag', 'Card', 'Passport', 'Watch', 'Headphones'];
      String detectedName = "Unknown Item";
      
      for (var label in labels) {
        if (priorityKeywords.any((k) => label.label.toLowerCase().contains(k.toLowerCase()))) {
          detectedName = label.label;
          break;
        }
      }
      if (detectedName == "Unknown Item" && labels.isNotEmpty) {
        detectedName = labels.first.label;
      }

      _titleController.text = detectedName;
      String tags = labels.take(5).map((l) => l.label).join(', ');
      _descController.text = "Item: $detectedName\nColor: $colorInfo\nAI Tags: $tags";
      _autoCategorize(detectedName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✨ AI auto-filled details! Tap fields to edit."),
            backgroundColor: Colors.purple.shade700,
            duration: const Duration(seconds: 2),
          )
        );
      }

      setState(() => _currentStep = 1);
      _getSmartLocation();
      _checkForSimilarItems(detectedName);

    } catch (e) {
      debugPrint("AI Error: $e");
      setState(() { _loading = false; _currentStep = 1; });
    }
  }

  Future<void> _checkForSimilarItems(String query) async {
    try {
      final response = await Supabase.instance.client
          .from('items')
          .select()
          .eq('type', _type == 'lost' ? 'found' : 'lost') 
          .ilike('title', '%$query%')
          .limit(3);

      final matches = (response as List).map((e) => Item.fromMap(e)).toList();

      if (matches.isNotEmpty && mounted) {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(20),
            height: 350,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                    SizedBox(width: 10),
                    Text("Potential Matches Found!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (ctx, i) => Card(
                      child: ListTile(
                        title: Text(matches[i].title),
                        subtitle: Text(matches[i].locationName),
                        trailing: ElevatedButton(
                          child: const Text("Check"),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailScreen(item: matches[i]))),
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("No, these aren't mine. Continue reporting."),
                )
              ],
            ),
          ),
        );
      }
    } catch (e) { debugPrint("Search Error: $e"); }
  }

  void _autoCategorize(String label) {
    label = label.toLowerCase();
    if (label.contains('phone') || label.contains('laptop')) _category = 'Electronics';
    else if (label.contains('wallet') || label.contains('card')) _category = 'Wallet';
    else if (label.contains('key')) _category = 'Keys';
    else if (label.contains('clothing')) _category = 'Clothing';
  }

  Future<void> _getSmartLocation() async {
    if (_locationController.text.isNotEmpty) return;
    setState(() => _loading = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loading = false);
          return;
        }
      }

      Position pos = await Geolocator.getCurrentPosition();
      _lat = pos.latitude;
      _lng = pos.longitude;
      
      List<Placemark> places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (places.isNotEmpty) {
        _locationController.text = "${places.first.name}, ${places.first.street}";
      }
      
      // --- DIJKSTRA LOGIC: Find Nearest Faculty ---
      if (_type == 'found') {
        String nearestId = findNearestFacultyId(latLng.LatLng(pos.latitude, pos.longitude));
        setState(() {
          _selectedFacultyId = nearestId; // Set the dropdown value
        });
      }
      // ---------------------------------------------

    } catch (e) {
      debugPrint("Location Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }
  
  Future<void> _submit() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      List<String> uploadedUrls = [];
      for (var img in _images) {
        final path = 'images/${user?.id}_${DateTime.now().millisecondsSinceEpoch}_${uploadedUrls.length}.jpg';
        await Supabase.instance.client.storage.from('images').upload(path, img);
        uploadedUrls.add(Supabase.instance.client.storage.from('images').getPublicUrl(path));
      }

      List<String> options = [];
      String? answer;
      
      if (_type == 'found' && _questionController.text.isNotEmpty) {
        if (_isMultipleChoice) {
          options = _optionControllers.map((c) => c.text).where((t) => t.isNotEmpty).toList();
          if (options.isNotEmpty) answer = options[_correctOptionIndex]; 
        } else {
          answer = _answerController.text.trim();
        }
      }

      String username = "Anonymous";
      try {
        final profile = await Supabase.instance.client.from('profiles').select('username').eq('id', user!.id).maybeSingle();
        if (profile != null) username = profile['username'] ?? "Anonymous";
      } catch (_) {}

      // Get Faculty Name if selected
      String? dropOffName;
      if (_selectedFacultyId != null) {
        dropOffName = getFacultyName(_selectedFacultyId!);
      }

      await Supabase.instance.client.from('items').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _type,
        'category': _category,
        'image_urls': uploadedUrls,
        'location_lat': _lat,
        'location_lng': _lng,
        'location_name': _locationController.text,
        'reported_by': user!.id,
        'reported_username': username,
        'drop_off_node': dropOffName, // Stores "Faculty of Computer Science"
        'verification_question': _questionController.text.isEmpty ? null : _questionController.text,
        'verification_options': options,
        'verification_answer': answer,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Published!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) return _buildSelectionStep();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_images.isNotEmpty)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_images[i])),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                _buildTextField("Item Name", _titleController),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _category,
                  decoration: const InputDecoration(labelText: "Category", filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v.toString()),
                ),
                const SizedBox(height: 10),
                _buildTextField("Description", _descController, lines: 3),
                const SizedBox(height: 10),
                _buildTextField("Location", _locationController, icon: Icons.map),
                
                // --- NEW: SMART FACULTY DROPDOWN ---
                if (_type == 'found' && facultyNodes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [Icon(Icons.assistant_navigation, color: Colors.green), SizedBox(width: 10), Text("Drop-off Suggestion (Dijkstra)", style: TextStyle(fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 10),
                        const Text("Select the faculty you will return this item to:"),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: _selectedFacultyId,
                          isExpanded: true,
                          decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                          items: facultyNodes.map((node) => DropdownMenuItem(
                            value: node.id,
                            child: Text(node.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedFacultyId = v),
                        ),
                      ],
                    ),
                  ),
                ],
                // -----------------------------------

                if (_type == 'found') ...[
                  const SizedBox(height: 30),
                  const Text("🔒 Security Question", style: TextStyle(fontWeight: FontWeight.bold)),
                  
                  Row(
                    children: [
                      const Text("Type: "),
                      ChoiceChip(
                        label: const Text("Multiple Choice"),
                        selected: _isMultipleChoice,
                        onSelected: (v) => setState(() => _isMultipleChoice = true),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Text Input"),
                        selected: !_isMultipleChoice,
                        onSelected: (v) => setState(() => _isMultipleChoice = false),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  _buildTextField("Question (e.g. What name is on the back?)", _questionController),
                  const SizedBox(height: 10),
                  
                  if (_isMultipleChoice) ...[
                    const Text("Options (Select Correct One):", style: TextStyle(fontSize: 12)),
                    ...List.generate(3, (index) => RadioListTile(
                      title: TextField(controller: _optionControllers[index], decoration: InputDecoration(hintText: "Option ${index + 1}")),
                      value: index,
                      groupValue: _correctOptionIndex,
                      onChanged: (v) => setState(() => _correctOptionIndex = v as int),
                    )),
                  ] else ...[
                    _buildTextField("Correct Answer (Exact text)", _answerController),
                  ]
                ],

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _submit, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    child: const Text("Post Report", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          _buildHeader(), 
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController c, {int lines = 1, IconData? icon}) {
    return TextField(
      controller: c, maxLines: lines,
      decoration: InputDecoration(
        labelText: label, prefixIcon: icon != null ? Icon(icon) : null,
        filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
      ),
    );
  }
}