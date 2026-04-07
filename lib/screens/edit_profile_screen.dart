import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import '../utils/day_utils.dart';
import '../gen_l10n/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? birthdate;
  String? city;
  String? country;
  String? tennisLevel;
  List<String> availability = [];

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
  }

  bool isSaving = false;

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

      final updateData = {
        'city': city,
        'country': country,
        'tennisLevel': tennisLevel,
        'availability': availability,
      };

      if (birthdate != null) {
        updateData['birthDate'] = Timestamp.fromDate(birthdate!);
        updateData['age'] = getAge(birthdate!);
      }

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
      initialDate: birthdate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
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
      appBar: AppBar(title: Text(loc.editProfile)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ListTile(
                title: Text(
                  birthdate == null
                      ? loc.selectBirthdate
                      : "${birthdate!.day}/${birthdate!.month}/${birthdate!.year}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickBirthdate,
              ),

              const SizedBox(height: 12),

              TextFormField(
                initialValue: city,
                decoration: InputDecoration(labelText: loc.city),
                onChanged: (value) => city = value,
              ),

              const SizedBox(height: 12),

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
                        color: country == null ? Colors.grey : Colors.black,
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
                    onSelect: (Country selectedCountry) {
                      setState(() {
                        country = selectedCountry.name;
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: tennisLevel,
                decoration: InputDecoration(labelText: loc.level),
                items: levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) => tennisLevel = value,
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