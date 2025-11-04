/// Modelos de dados do módulo de favoritos
library;

/// Tipos de itens que podem ser favoritados
enum FavoriteItemType {
  project('project'),
  task('task'),
  subtask('subtask');

  final String value;
  const FavoriteItemType(this.value);

  static FavoriteItemType fromString(String value) {
    return FavoriteItemType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid favorite item type: $value'),
    );
  }
}

/// Modelo de um favorito
class Favorite {
  final String id;
  final String userId;
  final FavoriteItemType itemType;
  final String itemId;
  final DateTime createdAt;

  const Favorite({
    required this.id,
    required this.userId,
    required this.itemType,
    required this.itemId,
    required this.createdAt,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      itemType: FavoriteItemType.fromString(json['item_type'] as String),
      itemId: json['item_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_type': itemType.value,
      'item_id': itemId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

