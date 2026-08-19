import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmassist/core/constants/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchEmail(String email, {String subject = '', String body = ''}) async {
    final Map<String, String> queryParams = {
      if (subject.isNotEmpty) 'subject': subject,
      if (body.isNotEmpty) 'body': body,
    };
    final String queryString = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final String mailUrl = 'mailto:$email${queryString.isNotEmpty ? '?$queryString' : ''}';
    final Uri uri = Uri.parse(mailUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyToClipboard(email, 'Email address');
      }
    } catch (_) {
      _copyToClipboard(email, 'Email address');
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _copyToClipboard(urlString, 'URL');
      }
    } catch (_) {
      _copyToClipboard(urlString, 'URL');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 700;

    return Scaffold(
      body: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About PharmAssist',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Developer Profile, Contact Info, Architecture & Feature Recommendations',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: [
                  // App Hero Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                            theme.colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/pharmAssist_nobg.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppConstants.appName,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Version 1.2.0 • Offline-First Pharmacy ERP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_done_rounded, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      'CLOUD SYNC READY',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'PharmAssist is an enterprise-grade pharmacy management application engineered for high-speed POS billing, real-time inventory management, batch tracking, and seamless Google Cloud Firestore synchronization across desktop and mobile devices.',
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Developer Profile Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_pin_rounded, color: theme.colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Developer Profile',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.purple.withValues(alpha: 0.2),
                                child: const Icon(Icons.code_rounded, color: Colors.purple, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Praveen MT (Red)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const Text(
                                      'Lead Software Architect & Full-Stack Security Engineer',
                                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Specialized in building resilient, offline-first Flutter desktop and mobile solutions, reactive state architectures, secure SQLite storage, and automated Firestore synchronization pipelines.',
                                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),

                          Text(
                            'Core Technology Stack:',
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTechChip(context, 'Flutter 3.x', Icons.flutter_dash, Colors.blue),
                              _buildTechChip(context, 'Dart 3.x', Icons.code, Colors.cyan),
                              _buildTechChip(context, 'Drift SQLite', Icons.storage_rounded, Colors.orange),
                              _buildTechChip(context, 'Riverpod 2.x', Icons.waves_rounded, Colors.indigo),
                              _buildTechChip(context, 'Cloud Firestore', Icons.cloud_outlined, Colors.amber.shade800),
                              _buildTechChip(context, 'Cross-Platform (Linux/Win/Android)', Icons.devices_rounded, Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Details & Social Links
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.contact_support_rounded, color: theme.colorScheme.primary, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Contact & Support',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildContactTile(
                                context,
                                icon: Icons.email_rounded,
                                title: 'Developer Email',
                                subtitle: 'praveenmtdarker@gmail.com',
                                color: Colors.redAccent,
                                onTap: () => _launchEmail('praveenmtdarker@gmail.com', subject: 'PharmAssist Inquiry'),
                              ),
                              _buildContactTile(
                                context,
                                icon: Icons.code_rounded,
                                title: 'GitHub Repository',
                                subtitle: 'github.com/ReverseEngineeringDude/PharmAssist',
                                color: Colors.deepPurple,
                                onTap: () => _launchUrl('https://github.com/ReverseEngineeringDude/PharmAssist'),
                              ),
                              _buildContactTile(
                                context,
                                icon: Icons.send_rounded,
                                title: 'Telegram Community',
                                subtitle: '@pharmassistsoftware',
                                color: Colors.lightBlue,
                                onTap: () => _launchUrl('https://t.me/pharmassistsoftware'),
                              ),
                              _buildContactTile(
                                context,
                                icon: Icons.bug_report_rounded,
                                title: 'Report Issue / Request',
                                subtitle: 'github.com/.../issues',
                                color: Colors.orange,
                                onTap: () => _launchUrl('https://github.com/ReverseEngineeringDude/PharmAssist/issues'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Footer Copyright
                  Center(
                    child: Text(
                      'PharmAssist ERP © 2026 Praveen MT (RedByteSec). All Rights Reserved.',
                      style: TextStyle(fontSize: 11, color: theme.disabledColor),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechChip(BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
