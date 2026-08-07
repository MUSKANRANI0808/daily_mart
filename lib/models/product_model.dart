class ProductModel {
  final int id;
  final String sellerUsername;
  final String name;
  final String description;
  final String unit;
  final double rate;

  ProductModel({
    required this.id,
    required this.sellerUsername,
    required this.name,
    this.description = '',
    this.unit = 'Pcs',
    required this.rate,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      sellerUsername: json['seller_username'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      unit: json['unit'] ?? 'Pcs',
      rate: (json['rate'] != null) ? (double.tryParse(json['rate'].toString()) ?? 0.0) : 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_username': sellerUsername,
      'name': name,
      'description': description,
      'unit': unit,
      'rate': rate,
    };
  }
}
