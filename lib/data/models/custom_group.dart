import 'package:cloud_firestore/cloud_firestore.dart';

class CustomGroup {
  final String id;
  final String name;
  final String description;
  final String creatorEmail;
  final String creatorName;
  final List<String> members;
  final Map<String, String> memberNames;
  final Map<String, String> memberTags;
  final DateTime createdAt;
  final String lastMessage;
  final DateTime? lastTimestamp;
  final String? groupIconUrl;

  CustomGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorEmail,
    required this.creatorName,
    required this.members,
    required this.memberNames,
    required this.memberTags,
    required this.createdAt,
    this.lastMessage = '',
    this.lastTimestamp,
    this.groupIconUrl,
  });

  factory CustomGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> mems = [];
    if (data['members'] is List) {
      mems = (data['members'] as List).map((e) => e.toString().toLowerCase().trim()).toList();
    }

    Map<String, String> names = {};
    if (data['memberNames'] is Map) {
      (data['memberNames'] as Map).forEach((k, v) {
        names[k.toString().toLowerCase().trim()] = v.toString();
      });
    }

    Map<String, String> tags = {};
    if (data['memberTags'] is Map) {
      (data['memberTags'] as Map).forEach((k, v) {
        tags[k.toString().toLowerCase().trim()] = v.toString();
      });
    }

    return CustomGroup(
      id: doc.id,
      name: data['name']?.toString() ?? 'Grup Obrolan',
      description: data['description']?.toString() ?? '',
      creatorEmail: data['creatorEmail']?.toString() ?? '',
      creatorName: data['creatorName']?.toString() ?? 'Pengguna',
      members: mems,
      memberNames: names,
      memberTags: tags,
      createdAt: parseDate(data['createdAt']),
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastTimestamp: data['lastTimestamp'] != null ? parseDate(data['lastTimestamp']) : null,
      groupIconUrl: data['groupIconUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'creatorEmail': creatorEmail.toLowerCase().trim(),
      'creatorName': creatorName,
      'members': members.map((e) => e.toLowerCase().trim()).toList(),
      'memberNames': memberNames,
      'memberTags': memberTags,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'groupIconUrl': groupIconUrl,
    };
  }

  bool isCreator(String userEmail) =>
      creatorEmail.toLowerCase().trim() == userEmail.toLowerCase().trim();
}
