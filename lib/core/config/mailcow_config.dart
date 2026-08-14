class MailcowConfig {
  static const String appName = 'BaknusID';
  static const String schoolName = 'SMK Bakti Nusantara 666';
  
  // Mailcow API & Auth Settings
  static const String apiUrl = 'http://mail.smk.baktinusantara666.sch.id';
  static const String apiKey = '925B68-0FF6BB-36B760-F6C051-AAF343';
  static const String domain = 'smk.baktinusantara666.sch.id';
  static const String authMethod = 'SMTP';
  static const String mailHost = 'mail.smk.baktinusantara666.sch.id';
  static const int smtpPort = 465;
  static const int imapPort = 993;
  static const bool useSsl = true;

  // Server metadata
  static const String serverIp = '119.235.218.190';
  static const String supportEmail = 'admin@smk.baktinusantara666.sch.id';

  // Public Avatar Endpoint
  static const String avatarBaseUrl = 'https://baknusmail.smkbn666.sch.id/api/public/avatar';
  static String getAvatarUrl(String email) => '$avatarBaseUrl/${email.trim()}';
}
