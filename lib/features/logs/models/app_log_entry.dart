import 'dart:convert';

class AppLogEntry {
  const AppLogEntry({
    required this.id,
    required this.createdAt,
    required this.level,
    required this.category,
    required this.message,
    this.metadata,
  });

  final String id;
  final DateTime createdAt;
  final String level;
  final String category;
  final String message;
  final Map<String, dynamic>? metadata;

  factory AppLogEntry.fromJson(Map<String, dynamic> json) {
    return AppLogEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      level: json['level'] as String,
      category: json['category'] as String,
      message: json['message'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  factory AppLogEntry.fromMap(Map<String, Object?> map) {
    final String? rawMetadata = map['metadata_json'] as String?;
    Map<String, dynamic>? parsedMetadata;

    if (rawMetadata != null && rawMetadata.trim().isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawMetadata);
        if (decoded is Map<String, dynamic>) {
          parsedMetadata = decoded;
        } else {
          parsedMetadata = <String, dynamic>{'value': decoded.toString()};
        }
      } catch (_) {
        parsedMetadata = <String, dynamic>{'raw': rawMetadata};
      }
    }

    return AppLogEntry(
      id: map['id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      level: map['level'] as String,
      category: map['category'] as String,
      message: map['message'] as String,
      metadata: parsedMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'level': level,
      'category': category,
      'message': message,
      'metadata': metadata,
    };
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'level': level,
      'category': category,
      'message': message,
      'metadata_json': metadata == null ? null : jsonEncode(metadata),
    };
  }
}
