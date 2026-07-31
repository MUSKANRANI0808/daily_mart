enum UserRole { admin, seller, customer }

class UserModel {
  final String id;
  String name;
  final String? mobile;
  final String? username;
  final UserRole role;

  UserModel({
    required this.id,
    required this.name,
    this.mobile,
    this.username,
    required this.role,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? mobile,
    String? username,
    UserRole? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      username: username ?? this.username,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'username': username,
        'role': role.name,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        mobile: json['mobile'],
        username: json['username'],
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.customer,
        ),
      );
}
