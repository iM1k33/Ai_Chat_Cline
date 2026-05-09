class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.selectedModelId,
    this.providerId,
    this.systemPrompt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? selectedModelId;
  final String? providerId;
  final String? systemPrompt;
  final bool isPinned;

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? selectedModelId,
    String? providerId,
    String? systemPrompt,
    bool? isPinned,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      providerId: providerId ?? this.providerId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'selectedModelId': selectedModelId,
      'providerId': providerId,
      'systemPrompt': systemPrompt,
      'isPinned': isPinned,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      selectedModelId: json['selectedModelId'] as String?,
      providerId: json['providerId'] as String?,
      systemPrompt: json['systemPrompt'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}
