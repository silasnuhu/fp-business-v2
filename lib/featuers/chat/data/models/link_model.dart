class Metadata {
  final String title;
  final String description;
  final String image;
  final String publisher;

  Metadata({
    required this.title,
    required this.description,
    required this.image,
    required this.publisher,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'image': image,
    'publisher': publisher,
  };

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      publisher: json['publisher'] ?? '',
    );
  }
}
