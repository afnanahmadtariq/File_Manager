import 'dart:convert';

/// Represents a cached index of files for a specific category filter
class FileIndex {
  final String category;
  final DateTime lastUpdated;
  final List<String> filePaths;

  FileIndex({
    required this.category,
    required this.lastUpdated,
    required this.filePaths,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'lastUpdated': lastUpdated.toIso8601String(),
    'filePaths': filePaths,
  };

  factory FileIndex.fromJson(Map<String, dynamic> json) => FileIndex(
    category: json['category'] as String,
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    filePaths: List<String>.from(json['filePaths'] as List),
  );

  String toJsonString() => jsonEncode(toJson());

  static FileIndex fromJsonString(String jsonString) =>
      FileIndex.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  /// Check if the index is still valid (less than 30 minutes old)
  bool get isValid => DateTime.now().difference(lastUpdated).inMinutes < 30;
}
