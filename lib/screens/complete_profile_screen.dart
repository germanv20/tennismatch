import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gen_l10n/app_localizations.dart';
import '../main.dart' show rootScaffoldMessengerKey;

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Pre-fill name from Google account so user can confirm or edit it
  final TextEditingController _nameController = TextEditingController();

  DateTime? birthdate;
  String? name; // collected here as safety net if Google doesn't provide it
  String? city;
  String? country;
  String? countryCode;
  String? tennisLevel;
  List<String> availability = [];
  String? phoneNumber;

  bool isSaving = false;
  bool termsAccepted = false;

  final List<String> levels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> days = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  String getFlagEmoji(String countryName) {
    try {
      final countryObj = Country.tryParse(countryName);
      return countryObj?.flagEmoji ?? '';
    } catch (_) {
      return '';
    }
  }

  int getAge(DateTime birthdate) {
    final today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month &&
            today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  /// Normalises phone to E.164 — strips spaces/dashes/parens
  /// Returns null if the number doesn't start with '+' after normalisation
  String? _normalisePhone(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith('+')) return null;
    if (cleaned.length < 8) return null;
    return cleaned;
  }

  static const _privacyPolicyUrl =
      'https://sites.google.com/view/tennismatch-privacy';

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(_privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }


  /// Normalizes a city name for consistent Firestore storage and comparison:
  /// strips accents (é→e, á→a, ñ→n, etc.) and lowercases so that
  /// "Popayán" and "Popayan" are treated as the same city.
  static String _normalizeCity(String input) {
    const accents = 'áàäâãåéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
    const normal  = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      final idx = accents.indexOf(ch);
      buffer.write(idx >= 0 ? normal[idx] : ch);
    }
    return buffer.toString().toLowerCase().trim();
  }

  Future<void> saveProfile() async {
    final loc = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate() ||
        birthdate == null ||
        tennisLevel == null) {
      return;
    }

    if (country == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.requiredField)),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // ── Claim mechanic: run BEFORE profile update ──
      // The profile update triggers navigation to HomeScreen via
      // main.dart's FutureBuilder — if claim runs after, it gets
      // interrupted mid-execution. Run it first while screen is stable.
      final normalisedPhone =
          phoneNumber != null ? _normalisePhone(phoneNumber!) : null;
      if (normalisedPhone != null) {
        await _claimGuestMatches(uid, normalisedPhone);
      }

      final Map<String, dynamic> updateData = {
        'birthDate': Timestamp.fromDate(birthdate!),
        'age': getAge(birthdate!),
        'city': _normalizeCity(city ?? ''),
        'country': country,
        'countryCode': countryCode,
        'tennisLevel': tennisLevel,
        'availability': availability,
        if (name != null && name!.isNotEmpty) 'name': name,
      };

      // Only store phone if valid E.164 format
      if (normalisedPhone != null) {
        updateData['phoneNumber'] = normalisedPhone;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  /// Finds all guest matches with this phone number and links them.
  /// 
  /// Uses a phoneIndex lookup collection to avoid Firestore security
  /// rule query restrictions on the matches collection.
  Future<void> _claimGuestMatches(String uid, String phone) async {

    // Step 1: Look up match IDs registered under this phone number
    final indexSnapshot = await FirebaseFirestore.instance
        .collection('phoneIndex')
        .doc(phone)
        .collection('matches')
        .get();

    if (indexSnapshot.docs.isEmpty) return;

    // Step 2: Fetch each match document directly by ID
    final List<DocumentSnapshot> matchDocs = [];
    for (final indexDoc in indexSnapshot.docs) {
      final matchId = indexDoc.id;
      try {
        final matchDoc = await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .get();
        if (matchDoc.exists) {
          final data = matchDoc.data();
          final guest = data?['guestOpponent'] as Map<String, dynamic>?;
          if (guest != null && guest['claimedBy'] == null) {
            matchDocs.add(matchDoc);
          }
        } else {
          debugPrint('⚠️ Match $matchId not found in phoneIndex');
        }
      } catch (e) {
        // Skip unreadable matches — don't abort the whole claim
        debugPrint('⚠️ Could not read match during claim: $e');
      }
    }

    if (matchDocs.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      int claimedWins = 0;
      int claimedLosses = 0;
      int claimedDuration = 0;

      for (final doc in matchDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};

        // The original logger was player1 (p1 = them, p2 = guest/us)
        // For the new owner: their perspective is p2, so we flip
        final result = data['result'] as Map<String, dynamic>? ?? {};
        final rawSets = result['sets'] as List? ?? [];
        final duration =
            (result['durationMinutes'] ?? 0) as num;

        // Determine if the guest (now claiming user) won
        // winnerUid is 'guest' if the guest won, or the logger's uid if they won
        final bool claimantWon = data['winnerUid'] == 'guest';

        if (claimantWon) {
          claimedWins++;
        } else {
          claimedLosses++;
        }
        claimedDuration += duration.toInt();

        // Flip sets so p1 = claimant, p2 = original logger
        // Also flip tb1/tb2 to maintain correct tiebreak perspective
        final List flippedSets = rawSets.map((s) {
          final flipped = <String, dynamic>{
            'p1': s['p2'],
            'p2': s['p1'],
          };
          if (s['tb1'] != null && s['tb2'] != null) {
            flipped['tb1'] = s['tb2'];
            flipped['tb2'] = s['tb1'];
          }
          return flipped;
        }).toList();

        // Mark match as claimed and add claimant to players array
        batch.update(doc.reference, {
          'guestOpponent.claimedBy': uid,
          'players': FieldValue.arrayUnion([uid]),
          // Store flipped perspective for claimant
          'claimantResult': {
            'uid': uid,
            'sets': flippedSets,
            'won': claimantWon,
          },
        });
      }

      // Update claimant's stats
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);

      batch.update(userRef, {
        'matchesPlayed': FieldValue.increment(matchDocs.length),
        'totalDuration': FieldValue.increment(claimedDuration),
        'wins': FieldValue.increment(claimedWins),
        'losses': FieldValue.increment(claimedLosses),
      });


      await batch.commit();

      // Use rootScaffoldMessengerKey — this screen may already be gone
      // by the time the claim completes because main.dart's StreamBuilder
      // navigates to HomeScreen as soon as the profile write is detected

      rootScaffoldMessengerKey.currentState?.clearSnackBars();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            // We can't use AppLocalizations here without a context,
            // so we read it from the navigator's current context
            _getClaimedMessage(),
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Surface the error so we can debug claim issues
      debugPrint('❌ Claim guest matches error: $e');

    }
  }

  String _getClaimedMessage() {
    final ctx = rootScaffoldMessengerKey.currentContext;
    if (ctx != null) {
      return AppLocalizations.of(ctx)?.claimedMatchesMerged ??
          'Your past match results have been linked to your account 🎾';
    }
    return 'Your past match results have been linked to your account 🎾';
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Google Sign-In if available
    final googleName = FirebaseAuth.instance.currentUser?.displayName;
    if (googleName != null && googleName.isNotEmpty) {
      _nameController.text = googleName;
      name = googleName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _translateDay(String day, AppLocalizations loc) {
    switch (day) {
      case 'Mon': return loc.monFull;
      case 'Tue': return loc.tueFull;
      case 'Wed': return loc.wedFull;
      case 'Thu': return loc.thuFull;
      case 'Fri': return loc.friFull;
      case 'Sat': return loc.satFull;
      case 'Sun': return loc.sunFull;
      default: return day;
    }
  }

  Future<void> pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => birthdate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.completeProfile)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // Name field — pre-filled from Google, editable
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: loc.nameLabel),
                onChanged: (value) => name = value,
                validator: (value) => value == null || value.isEmpty
                    ? loc.requiredField
                    : null,
              ),

              const SizedBox(height: 12),

              // Birthdate
              ListTile(
                title: Text(
                  birthdate == null
                      ? loc.selectBirthdate
                      : "${birthdate!.toLocal()}".split(' ')[0],
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickBirthdate,
              ),

              const SizedBox(height: 12),

              // City
              TextFormField(
                decoration: InputDecoration(labelText: loc.city),
                onChanged: (value) => city = value,
                validator: (value) => value == null || value.isEmpty
                    ? loc.requiredField
                    : null,
              ),

              const SizedBox(height: 12),

              Text(
                loc.country,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),

              // Country
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    if (country != null) ...[
                      Text(
                        getFlagEmoji(country!),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      country ?? loc.selectCountry,
                      style: TextStyle(
                        color: country == null
                            ? Colors.grey
                            : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: false,
                    countryListTheme: CountryListThemeData(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelect: (Country selectedCountry) {
                      setState(() {
                        country = selectedCountry.name;
                        countryCode = selectedCountry.countryCode;
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              // Tennis Level — use localized display names
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: loc.level),
                items: levels.map((level) {
                  final localizedLevel = level == 'Beginner'
                      ? loc.levelBeginner
                      : level == 'Intermediate'
                          ? loc.levelIntermediate
                          : loc.levelAdvanced;
                  return DropdownMenuItem(
                    value: level,
                    child: Text(localizedLevel),
                  );
                }).toList(),
                onChanged: (value) => tennisLevel = value,
                validator: (value) =>
                    value == null ? loc.requiredField : null,
              ),

              const SizedBox(height: 16),

              Text(loc.selectAvailability),

              Wrap(
                spacing: 8,
                children: days.map((day) {
                  final isSelected = availability.contains(day);
                  // Translate day abbreviation to localized full name
                  final localizedDay = _translateDay(day, loc);
                  return FilterChip(
                    label: Text(localizedDay),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        isSelected
                            ? availability.remove(day)
                            : availability.add(day);
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Phone number (for claim mechanic) ──
              const Divider(),
              const SizedBox(height: 8),

              Text(
                loc.yourPhoneNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loc.phoneOptionalHint,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: loc.phoneNumberLabel,
                  hintText: loc.phoneNumberHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                onChanged: (value) => phoneNumber = value,
                validator: (value) {
                  // Optional field — only validate format if filled
                  if (value == null || value.isEmpty) return null;
                  final normalised = _normalisePhone(value);
                  if (normalised == null) {
                    return loc.invalidPhoneNumber;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Terms & Privacy Policy ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: termsAccepted,
                    onChanged: (v) =>
                        setState(() => termsAccepted = v ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => termsAccepted = !termsAccepted),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            Text(
                              loc.termsAcceptText,
                              style: const TextStyle(fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: _openPrivacyPolicy,
                              child: Text(
                                loc.privacyPolicyLink,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).primaryColor,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: (isSaving || !termsAccepted)
                    ? null
                    : saveProfile,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(loc.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}