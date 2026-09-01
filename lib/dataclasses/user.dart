class User {
  final String id;
  final String username;
  final String firstname;
  final String lastname;

  User({
    required this.id,
    required this.username,
    required this.firstname,
    required this.lastname,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstname: json['first_name'] as String? ?? '',
      lastname: json['last_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstname,
      'last_name': lastname,
    };
  }
}
