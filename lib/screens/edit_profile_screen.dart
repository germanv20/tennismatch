import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import '../gen_l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cityController = TextEditingController();

  DateTime? birthdate;
  String? city;
  String? country;
  String? tennisLevel;
  List<String> availability = [];

  // Track whether the user attempted to save, so date/country
  // validation messages only show after a failed submit attempt
  bool _attemptedSave = false;

  final List<String> levels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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

    city = data['city'];
    country = data['country'];
    tennisLevel = data['tennisLevel'];
    availability = List<String>.from(data['availability'] ?? []);
    _cityController.text = city ?? '';
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  bool isSaving = false;

  Future<void> saveProfile() async {
    final loc = AppLocalizations.of(context)!;

    setState(() => _attemptedSave = true);

    // Run all field validations together so the user sees every
    // problem at once instead of one snackbar at a time
    final isFormValid = _formKey.currentState!.validate();
    final isDateValid = birthdate != null;
    final isCountryValid = country != null && country!.isNotEmpty;
    final isLevelValid = tennisLevel != null;

    if (!isFormValid ||
        !isDateValid ||
        !isCountryValid ||
        !isLevelValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.completeRequiredFields)),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final updateData = {
        'city': city,
        'country': country,
        'tennisLevel': tennisLevel,
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
                        country = selectedCountry.name;
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

              DropdownButtonFormField<String>(
                initialValue: tennisLevel,
                decoration: InputDecoration(
                  labelText: loc.level,
                  border: const OutlineInputBorder(),
                ),
                items: levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) => setState(() => tennisLevel = value),
                validator: (value) =>
                    value == null ? loc.requiredField : null,
              ),

              const SizedBox(height: 16),

              Text(loc.selectAvailability),

              Wrap(
                spacing: 8,
                children: days.map((day) {
                  final isSelected = availability.contains(day);
                  return FilterChip(
                    label: Text(day),
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