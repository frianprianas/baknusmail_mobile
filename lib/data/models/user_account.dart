class UserAccount {
  final String email;
  final String displayName;
  final String? password;
  final bool isDemo;
  final int quotaUsed;
  final int quotaTotal;
  final int messageCount;

  UserAccount({
    required this.email,
    required this.displayName,
    this.password,
    this.isDemo = false,
    this.quotaUsed = 0,
    this.quotaTotal = 3221225472, // 3 GB default Mailcow
    this.messageCount = 0,
  });

  String get domain => email.contains('@') ? email.split('@').last : '';

  double get quotaPercentage {
    if (quotaTotal <= 0) return 0;
    return (quotaUsed / quotaTotal).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'displayName': displayName,
        'password': password,
        'isDemo': isDemo,
        'quotaUsed': quotaUsed,
        'quotaTotal': quotaTotal,
        'messageCount': messageCount,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        email: json['email'] ?? '',
        displayName: json['displayName'] ?? '',
        password: json['password'],
        isDemo: json['isDemo'] ?? false,
        quotaUsed: json['quotaUsed'] ?? 0,
        quotaTotal: json['quotaTotal'] ?? 3221225472,
        messageCount: json['messageCount'] ?? 0,
      );
}
