import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import '../gen_l10n/app_localizations.dart';
import '../utils/skill_level.dart';
import '../widgets/skill_level_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  DateTime? birthdate;
  String? name;
  String? city;
  String? country;
  String? countryCode;
  // Skill level value within the country's system (see utils/skill_level.dart).
  num? levelValue;
  // Suggestion from the old Beginner/Intermediate/Advanced choice, shown
  // while the user hasn't picked a new-style level yet.
  num? _suggestedLevel;
  List<String> availability = [];

  // Track whether the user attempted to save, so date/country
  // validation messages only show after a failed submit attempt
  bool _attemptedSave = false;

  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  @override
  void initState() {
    super.initState();

    final data = widget.userData;

    if (data['birthDate'] != null) {
      birthdate = (data['birthDate'] as Timestamp).toDate();
    }

    name = data['name'];
    city = data['city'];
    country = data['country'];
    countryCode = data['countryCode'];
    final stored = SkillLevel.fromUserData(data);
    final system = SkillLevel.systemForCountryCode(countryCode);
    if (stored != null && stored.system == system) {
      levelValue = stored.value;
    } else {
      _suggestedLevel =
          SkillLevel.suggestionFromLegacy(system, data['tennisLevel'] as String?);
    }
    availability = List<String>.from(data['availability'] ?? []);
    _nameController.text = name ?? '';
    _cityController.text = city ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  bool isSaving = false;


  /// Formats a city name for storage: trims whitespace and capitalizes
  /// only the first letter, preserving accents and the rest of the text
  /// exactly as the user typed it (e.g. "popayán" -> "Popayán").
  /// Matching/grouping by city (e.g. in AvailablePlayersScreen) normalizes
  /// accents/case separately at comparison time, so this stays display-safe.
  static String _formatCity(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  Future<void> saveProfile() async {
    final loc = AppLocalizations.of(context)!;

    setState(() => _attemptedSave = true);

    // Run all field validations together so the user sees every
    // problem at once instead of one snackbar at a time
    final isFormValid = _formKey.currentState!.validate();
    final isDateValid = birthdate != null;
    final isCountryValid = country != null && country!.isNotEmpty;
    // Existing users who haven't chosen a new-style level yet can still save
    // other changes (the Home prompt asks them softly) — only require it
    // when there is no legacy level either.
    final hasLegacyLevel =
        (widget.userData['tennisLevel'] as String?)?.isNotEmpty == true;
    final isLevelValid = levelValue != null || hasLegacyLevel;
    final isNameValid = name != null && name!.trim().isNotEmpty;

    if (!isFormValid ||
        !isDateValid ||
        !isCountryValid ||
        !isLevelValid ||
        !isNameValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.completeRequiredFields)),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final updateData = {
        'name': name!.trim(),
        'city': _formatCity(city ?? ''),
        'country': country,
        'countryCode': countryCode,
        if (levelValue != null)
          ...SkillLevel.toFirestore(
              SkillLevel.systemForCountryCode(countryCode), levelValue!),
        'availability': availability,
        'birthDate': Timestamp.fromDate(birthdate!),
        'age': getAge(birthdate!),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.profileUpdatedSuccessfully)),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          birthdate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
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

    final showDateError = _attemptedSave && birthdate == null;
    final showCountryError =
        _attemptedSave && (country == null || country!.isEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(loc.editProfile)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // ── Birth date — required ──
              ListTile(
                title: Text(
                  birthdate == null
                      ? loc.selectBirthdate
                      : "${birthdate!.day}/${birthdate!.month}/${birthdate!.year}",
                  style: TextStyle(
                    color: showDateError ? Colors.red : null,
                  ),
                ),
                trailing: Icon(
                  Icons.calendar_today,
                  color: showDateError ? Colors.red : null,
                ),
                shape: showDateError
                    ? RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.red),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                onTap: pickBirthdate,
              ),
              if (showDateError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    loc.requiredField,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Country — required ──
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
                        color: showCountryError
                            ? Colors.red
                            : (country == null ? Colors.grey : Colors.black),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.arrow_drop_down,
                  color: showCountryError ? Colors.red : null,
                ),
                shape: showCountryError
                    ? RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.red),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: false,
                    onSelect: (Country selectedCountry) {
                      setState(() {
                        final oldSystem =
                            SkillLevel.systemForCountryCode(countryCode);
                        country = selectedCountry.name;
                        countryCode = selectedCountry.countryCode;
                        // Different level system (Colombia vs NTRP): the
                        // current level no longer applies, ask again.
                        final newSystem =
                            SkillLevel.systemForCountryCode(countryCode);
                        if (newSystem != oldSystem) {
                          levelValue = null;
                          _suggestedLevel = SkillLevel.suggestionFromLegacy(
                              newSystem,
                              widget.userData['tennisLevel'] as String?);
                        }
                      });
                    },
                  );
                },
              ),
              if (showCountryError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    loc.requiredField,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 12),

              // ── Name — required ──
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.nameLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => name = value,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.requiredField;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ── City — required ──
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: loc.city,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => city = value,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return loc.requiredField;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              SkillLevelField(
                system: SkillLevel.systemForCountryCode(countryCode),
                value: levelValue,
                suggested: _suggestedLevel,
                showError: _attemptedSave &&
                    (widget.userData['tennisLevel'] as String?)?.isNotEmpty !=
                        true,
                onChanged: (v) => setState(() => levelValue = v),
              ),

              const SizedBox(height: 16),

              Text(loc.selectAvailability),

              Wrap(
                spacing: 8,
                children: days.map((day) {
                  final isSelected = availability.contains(day);
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

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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