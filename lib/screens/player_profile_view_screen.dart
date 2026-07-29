import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:country_picker/country_picker.dart';
import '../utils/city_utils.dart';

const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String translateLevel(String level, AppLocalizations loc) {
  switch (level) {
    case 'Beginner': return loc.levelBeginner;
    case 'Intermediate': return loc.levelIntermediate;
    case 'Advanced': return loc.levelAdvanced;
    default: return level;
  }
}

String translateDay(String day, AppLocalizations loc) {
  switch (day) {
    case 'Mon': return loc.mon;
    case 'Tue': return loc.tue;
    case 'Wed': return loc.wed;
    case 'Thu': return loc.thu;
    case 'Fri': return loc.fri;
    case 'Sat': return loc.sat;
    case 'Sun': return loc.sun;
    default: return day;
  }
}

class PlayerProfileViewScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool showActions;
  final DocumentReference? requestRef;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onReject;
  final Future<void> Function()? onRequestMatch;
  final Future<void> Function()? onCancel;

  const PlayerProfileViewScreen({
    super.key,
    required this.userData,
    this.showActions = false,
    this.requestRef,
    this.onAccept,
    this.onReject,
    this.onRequestMatch,
    this.onCancel,
  });

  @override
  State<PlayerProfileViewScreen> createState() =>
      _PlayerProfileViewScreenState();
}

class _PlayerProfileViewScreenState extends State<PlayerProfileViewScreen> {
  bool isLoading = false;

  String getCountryFlag(String countryName) {
    try {
      final match = CountryService().getAll().firstWhere(
            (c) => c.name.toLowerCase() == countryName.toLowerCase(),
            orElse: () => CountryService().getAll().first,
          );
      if (match.name.toLowerCase() == countryName.toLowerCase()) {
        return match.flagEmoji;
      }
    } catch (_) {}
    return '';
  }

  /// Returns the localized country name, falling back to English if the
  /// device locale isn't supported or countryCode is missing.
  String getLocalizedCountryName(
    BuildContext context,
    String? countryCode,
    String fallbackName,
  ) {
    if (fallbackName.isEmpty) return '';

    String? resolvedCode = countryCode;
    if (resolvedCode == null || resolvedCode.isEmpty) {
      try {
        final match = CountryService().getAll().firstWhere(
              (c) => c.name.toLowerCase() == fallbackName.toLowerCase(),
              orElse: () => CountryService().getAll().first,
            );
        if (match.name.toLowerCase() == fallbackName.toLowerCase()) {
          resolvedCode = match.countryCode;
        }
      } catch (_) {}
    }

    if (resolvedCode == null || resolvedCode.isEmpty) return fallbackName;

    try {
      final raw = CountryLocalizations.of(context)
          ?.countryName(countryCode: resolvedCode);
      if (raw != null && raw.isNotEmpty) {
        return raw[0].toUpperCase() + raw.substring(1);
      }
    } catch (_) {}

    return fallbackName;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final userData = widget.userData;
    final String name = userData['name'] ?? loc.unknown;
    final rawLevel = userData['tennisLevel'] ?? '';
    final String level =
        rawLevel.isEmpty ? loc.notSet : translateLevel(rawLevel, loc);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final viewedUid = (userData['uid'] as String?) ?? '';
    final List availabilityRaw = userData['availability'] ?? [];

    final List<String> sortedAvailability = List<String>.from(availabilityRaw)
      ..sort((a, b) => weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)));

    final String availabilityText = sortedAvailability.isEmpty
        ? loc.noAvailability
        : sortedAvailability.map((day) => translateDay(day, loc)).join(', ');

    final String rawCity = (userData['city'] as String? ?? '');
    final String city =
        rawCity.isNotEmpty ? formatCityDisplay(rawCity) : loc.notSet;
    final String country = userData['country'] ?? loc.notSet;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.playerProfile),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  CircleAvatar(
                    radius: 50,
                    backgroundImage: (userData['photoUrl'] != null &&
                            userData['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(userData['photoUrl'])
                        : null,
                    child: userData['photoUrl'] == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Match count badge — builds trust/confidence ──
                  // Uses the matchesPlayed counter already stored on the
                  // user document (incremented when matches are logged),
                  // avoiding any extra Firestore reads or permission issues.
                  Builder(
                    builder: (context) {
                      final count =
                          (userData['matchesPlayed'] as int?) ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sports_tennis,
                                size: 16, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Text(
                              loc.matchesPlayedCount(count),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  Text(
                    "📍 ${loc.city}: $city",
                    style: const TextStyle(fontSize: 15),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "🌍 ${loc.country}: ${getLocalizedCountryName(context, userData['countryCode'] as String?, country)}",
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        getCountryFlag(country),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Note: birth date intentionally NOT shown here for
                  // privacy/security — only the user sees their own
                  // birth date in My Profile / Edit Profile.

                  Text(
                    "🎾 ${loc.level}: $level",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "📅 ${loc.availability}: $availabilityText",
                    style: const TextStyle(fontSize: 15),
                  ),

                  const SizedBox(height: 24),

                  // 🔹 Request Match (Available Players)
                  if (widget.onRequestMatch != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('match_requests')
                          .where('fromUid', isEqualTo: currentUid)
                          .where('toUid', isEqualTo: viewedUid)
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final hasRequest =
                            snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                        return ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final navigator = Navigator.of(context);
                                  setState(() => isLoading = true);
                                  if (widget.onRequestMatch != null) {
                                    await widget.onRequestMatch!();
                                  }
                                  if (!mounted) return;
                                  navigator.pop();
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  hasRequest ? loc.requested : loc.requestMatch),
                        );
                      },
                    ),

                  if (widget.onCancel != null) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              setState(() => isLoading = true);
                              if (widget.onCancel != null) {
                                await widget.onCancel!();
                              }
                              if (!mounted) return;
                              navigator.pop();
                            },
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel),
                      label: Text(isLoading ? loc.processing : loc.cancelRequest),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],

                  if (widget.showActions) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setState(() => isLoading = true);
                                  if (widget.onAccept != null) {
                                    await widget.onAccept!();
                                  }
                                  if (!mounted) return;
                                  Navigator.pop(context, 'accepted');
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: Text(isLoading ? loc.processing : loc.accept),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setState(() => isLoading = true);
                                  if (widget.onReject != null) {
                                    await widget.onReject!();
                                  }
                                  if (!mounted) return;
                                  Navigator.pop(context, 'rejected');
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.close),
                          label: Text(isLoading ? loc.processing : loc.reject),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}