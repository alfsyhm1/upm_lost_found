class Item {
  final String id;
  final String title;
  final String description;
  final String type;
  final String imageUrl;
  final String locationName;

  Item({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.locationName,
  });

  factory Item.fromMap(Map<String, dynamic> data) => Item(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        type: data['type'],
        imageUrl: data['image_url'] ?? '',
        locationName: data['location_name'] ?? '',
      );
}
