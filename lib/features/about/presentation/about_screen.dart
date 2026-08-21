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
    final borderColor = Colors.grey.withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About PharmAssist',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Developer Profile, Contact Info & Architecture Details',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Expanded(
              child: ListView(
                children: [
                  // App Hero Section (Free Layout)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.08),
                          theme.colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/pharmAssist_nobg.png',
                                width: 56,
                                height: 56,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppConstants.appName,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Version 1.2.0 • Offline-First Pharmacy ERP',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_done_rounded, size: 16, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text(
                                    'CLOUD SYNC READY',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'PharmAssist is an enterprise-grade pharmacy management application engineered for high-speed POS billing, real-time inventory management, batch tracking, and seamless Google Cloud Firestore synchronization across desktop and mobile devices.',
                          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Developer Profile & Tech Stack Section
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_pin_rounded, color: Colors.purple, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Developer Profile',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.purple.withValues(alpha: 0.1),
                              child: const Icon(Icons.code_rounded, color: Colors.purple, size: 36),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Praveen MT (Red)',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Lead Software Architect & Full-Stack Security Engineer',
                                    style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Specialized in building resilient, offline-first Flutter desktop and mobile solutions, reactive state architectures, secure SQLite storage, and automated Firestore synchronization pipelines.',
                                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        Divider(color: borderColor),
                        const SizedBox(height: 20),

                        Text(
                          'Core Technology Stack:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildTechChip(context, 'Flutter 3.x', Icons.flutter_dash, Colors.blue),
                            _buildTechChip(context, 'Dart 3.x', Icons.code, Colors.cyan.shade700),
                            _buildTechChip(context, 'Drift SQLite', Icons.storage_rounded, Colors.orange.shade700),
                            _buildTechChip(context, 'Riverpod 2.x', Icons.waves_rounded, Colors.indigo.shade400),
                            _buildTechChip(context, 'Cloud Firestore', Icons.cloud_outlined, Colors.amber.shade800),
                            _buildTechChip(context, 'Cross-Platform', Icons.devices_rounded, Colors.green.shade600),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Contact Details & Social Links Section
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.contact_support_rounded, color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Contact & Support',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildContactTile(
                              context,
                              icon: Icons.email_rounded,
                              title: 'Developer Email',
                              subtitle: 'praveenmtdarker@gmail.com',
                              color: Colors.redAccent,
                              borderColor: borderColor,
                              onTap: () => _launchEmail('praveenmtdarker@gmail.com', subject: 'PharmAssist Inquiry'),
                            ),
                            _buildContactTile(
                              context,
                              icon: Icons.code_rounded,
                              title: 'GitHub Repository',
                              subtitle: 'github.com/ReverseEngineeringDude/PharmAssist',
                              color: Colors.deepPurple,
                              borderColor: borderColor,
                              onTap: () => _launchUrl('https://github.com/ReverseEngineeringDude/PharmAssist'),
                            ),
                            _buildContactTile(
                              context,
                              icon: Icons.send_rounded,
                              title: 'Telegram Community',
                              subtitle: '@pharmassistsoftware',
                              color: Colors.lightBlue,
                              borderColor: borderColor,
                              onTap: () => _launchUrl('https://t.me/pharmassistsoftware'),
                            ),
                            _buildContactTile(
                              context,
                              icon: Icons.bug_report_rounded,
                              title: 'Report Issue / Request',
                              subtitle: 'github.com/.../issues',
                              color: Colors.orange,
                              borderColor: borderColor,
                              onTap: () => _launchUrl('https://github.com/ReverseEngineeringDude/PharmAssist/issues'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer Copyright
                  Center(
                    child: Text(
                      'PharmAssist ERP © 2026 Praveen MT (RedByteSec). All Rights Reserved.',
                      style: TextStyle(fontSize: 12, color: theme.disabledColor, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
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
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withValues(alpha: 0.05),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_outward_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}