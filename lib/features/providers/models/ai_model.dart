class AIModel {
  const AIModel({
    required this.id,
    required this.name,
    required this.providerId,
    this.description,
    this.contextLength,
    this.promptPrice,
    this.completionPrice,
    this.currencyCode,
    this.supportsStreaming = true,
  });

  final String id;
  final String name;
  final String providerId;
  final String? description;
  final int? contextLength;
  final double? promptPrice;
  final double? completionPrice;
  final String? currencyCode;
  final bool supportsStreaming;

  AIModel copyWith({
    String? id,
    String? name,
    String? providerId,
    String? description,
    int? contextLength,
    double? promptPrice,
    double? completionPrice,
    String? currencyCode,
    bool? supportsStreaming,
  }) {
    return AIModel(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      description: description ?? this.description,
      contextLength: contextLength ?? this.contextLength,
      promptPrice: promptPrice ?? this.promptPrice,
      completionPrice: completionPrice ?? this.completionPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'providerId': providerId,
      'description': description,
      'contextLength': contextLength,
      'promptPrice': promptPrice,
      'completionPrice': completionPrice,
      'currencyCode': currencyCode,
      'supportsStreaming': supportsStreaming,
    };
  }

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'] as String,
      name: json['name'] as String,
      providerId: json['providerId'] as String,
      description: json['description'] as String?,
      contextLength: json['contextLength'] as int?,
      promptPrice: (json['promptPrice'] as num?)?.toDouble(),
      completionPrice: (json['completionPrice'] as num?)?.toDouble(),
      currencyCode: json['currencyCode'] as String?,
      supportsStreaming: json['supportsStreaming'] as bool? ?? true,
    );
  }
}
