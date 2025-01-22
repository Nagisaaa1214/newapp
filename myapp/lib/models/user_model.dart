class UserModel {
  final String uid;
  final String email;
  final String? name;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'],
    );
  }
}