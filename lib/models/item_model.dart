class Item {
  final String id; // unique id generated randomly
  final String title; // title for the item
  final String description; 
  final String type; // 'lost' or 'found'
  final List<String> imageUrls;
  final String category;  //the dropdown category
  final double? locationLat;
  final double? locationLng;
  final String locationName;
  final String? dropOffNode;  //fac name
  final String? contactNumber;
  final String? reportedBy;
  final String? reportedUsername;
  final String? verificationQuestion;
  final List<String> verificationOptions; // security choices ["A", "B", "C"] 
  final String? verificationAnswer; // secret correct answer
  final DateTime createdAt;

  Item({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrls,
    required this.category,
    this.locationLat,
    this.locationLng,
    required this.locationName,
    this.dropOffNode,
    this.contactNumber,
    this.reportedBy,
    this.reportedUsername,
    this.verificationQuestion,
    required this.verificationOptions, 
    this.verificationAnswer,
    required this.createdAt,
  });

  factory Item.fromMap(Map<String, dynamic> data) {
    return Item(
      // getting data from supabase map, with null checks
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'Unknown Item',
      description: data['description'] ?? '',
      type: data['type'] ?? 'lost',
      imageUrls: data['image_urls'] != null 
          ? List<String>.from(data['image_urls']) 
          : (data['image_url'] != null ? [data['image_url']] : []), 
      category: data['category'] ?? 'Other',
      locationLat: data['location_lat']?.toDouble(),// convert to double from supabase, which may store as int
      locationLng: data['location_lng']?.toDouble(),
      locationName: data['location_name'] ?? '',
      dropOffNode: data['drop_off_node'],
      contactNumber: data['contact_number'],
      reportedBy: data['reported_by'],
      reportedUsername: data['reported_username'],
      verificationQuestion: data['verification_question'],
      
      verificationOptions: data['verification_options'] != null 
          ? List<String>.from(data['verification_options']) 
          : [], 
          
      verificationAnswer: data['verification_answer'],
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
    );
  }
}