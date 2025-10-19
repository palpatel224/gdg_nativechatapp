class AppUser {
  final String uid;
  final String email;
  final String? name;
  final String? photoUrl;
  final String? status;

  AppUser({
    required this.uid,
    required this.email,
    this.name,
    this.photoUrl,
    this.status,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
    'status': status,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    uid: m['uid'] ?? '',
    email: m['email'] ?? '',
    name: m['name'],
    photoUrl: m['photoUrl'],
    status: m['status'],
  );
}
