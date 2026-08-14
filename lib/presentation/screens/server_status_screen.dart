import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/config/mailcow_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format_helper.dart';
import '../../providers/mailcow_provider.dart';

import '../widgets/app_background.dart';

class ServerStatusScreen extends StatelessWidget {
  const ServerStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mailcow = context.watch<MailcowProvider>();

    final domainInfo = mailcow.domainInfo;
    final health = mailcow.serverHealth;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        title: const Text('Status Server Mailcow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Uji Ulang Koneksi',
            onPressed: () => mailcow.refreshAll(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Identity Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.dns_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Mailcow Server Info',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (health?.isAllHealthy == true)
                              ? AppColors.success
                              : AppColors.warning,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (health?.isAllHealthy == true) ? 'ONLINE' : 'CHECKING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildServerDetailRow('Host Server', MailcowConfig.mailHost),
                  _buildServerDetailRow('Server IP', MailcowConfig.serverIp),
                  _buildServerDetailRow('Domain Sekolah', MailcowConfig.domain),
                  _buildServerDetailRow('Metode Auth', MailcowConfig.authMethod),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Services & Port Status Grid
            Text(
              'Status Layanan Port & Protokol',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildPortCard(
                    title: 'IMAP (Port 993)',
                    subtitle: 'Penerimaan SSL/TLS',
                    isOnline: health?.imapOnline ?? true,
                    latency: health?.latencyMs ?? 0,
                    icon: Icons.mark_email_unread_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPortCard(
                    title: 'SMTP (Port 465)',
                    subtitle: 'Pengiriman SSL/TLS',
                    isOnline: health?.smtpOnline ?? true,
                    latency: health?.latencyMs ?? 0,
                    icon: Icons.send_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildPortCard(
              title: 'Mailcow REST API (Port 80/HTTP)',
              subtitle: 'Manajemen Domain & Quota Mailbox',
              isOnline: health?.apiOnline ?? true,
              latency: health?.latencyMs ?? 0,
              icon: Icons.api_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Domain Statistics
            Text(
              'Statistik Domain (${MailcowConfig.domain})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (mailcow.isLoadingDomain)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: SpinKitThreeBounce(color: AppColors.primary, size: 24),
                ),
              )
            else if (domainInfo != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    _buildStatTile(
                      icon: Icons.account_circle_outlined,
                      title: 'Total Akun Mailbox',
                      value: '${domainInfo.mailboxesInDomain} dari ${domainInfo.maxMailboxes} akun',
                      isDark: isDark,
                    ),
                    const Divider(),
                    _buildStatTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'Alias Email Aktif',
                      value: '${domainInfo.aliasesInDomain} dari ${domainInfo.maxAliases} alias',
                      isDark: isDark,
                    ),
                    const Divider(),
                    _buildStatTile(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Batas Kuota per Mailbox',
                      value: FormatHelper.formatFileSize(domainInfo.defQuotaForMbox),
                      isDark: isDark,
                    ),
                    const Divider(),
                    _buildStatTile(
                      icon: Icons.cloud_done_outlined,
                      title: 'Total Kuota Domain',
                      value: FormatHelper.formatFileSize(domainInfo.maxQuotaForDomain),
                      isDark: isDark,
                    ),
                    const Divider(),
                    _buildStatTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Total Pesan di Server',
                      value: '${domainInfo.msgsTotal} email',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Diagnostics Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.network_check_rounded, size: 20),
                label: const Text('Jalankan Diagnosa Ulang'),
                onPressed: () => mailcow.refreshAll(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildServerDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortCard({
    required String title,
    required String subtitle,
    required bool isOnline,
    required int latency,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: isOnline ? AppColors.success : AppColors.error, size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOnline ? 'TERHUBUNG' : 'TERPUTUS',
                  style: TextStyle(
                    color: isOnline ? AppColors.success : AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          if (isOnline && latency > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Latency: ~${latency}ms',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
