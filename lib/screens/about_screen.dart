import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gen_l10n/app_localizations.dart';

/// "About the app" screen, reached from the home screen's ⋮ overflow menu.
/// Shows the app icon/name/tagline, the version/build number (read
/// dynamically via package_info_plus so it never has to be hand-updated
/// here when pubspec.yaml's version bumps), the existing Privacy Policy
/// link (same URL/pattern as my_profile_screen.dart — deliberately left
/// untouched there, just mirrored here), and a "Rate us on Google Play"
/// link reusing the same Play Store URL already used in three other
/// screens (guest_match_details_screen.dart, log_doubles_match_screen.dart,
/// log_guest_match_screen.dart).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _privacyPolicyUrl =
      'https://sites.google.com/view/tennismatch-privacy';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tennismatch.app';

  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.aboutApp)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/icon/icon_512.png',
                  width: 96,
                  height: 96,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                loc.appTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                loc.loginSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _packageInfo == null
                    ? ''
                    : loc.aboutVersionLabel(
                        _packageInfo!.version, _packageInfo!.buildNumber),
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: Text(loc.rateUsOnGooglePlay),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(_playStoreUrl),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(loc.privacyPolicyLink),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(_privacyPolicyUrl),
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
