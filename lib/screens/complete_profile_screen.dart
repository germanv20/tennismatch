import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import '../utils/day_utils.dart';
import '../gen_l10n/app_localizations.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
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

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'birthDate': Timestamp.fromDate(birthdate!),
        'age': getAge(birthdate!),
        'city': city,
        'country': country,
        'tennisLevel': tennisLevel,
        'availability': availability,
      });

      if (!mounted) return;
      Navigator.pop(context);

    } catch (e) {
      debugPrint("❌ Error saving profile: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving profile")),
      );
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
                validator: (value) =>
                    value == null || value.isEmpty ? loc.requiredField : null,
              ),

              const SizedBox(height: 12),

              Text(
                loc.country,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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

              // Tennis Level
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: loc.level),
                items: levels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
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
                onPressed: saveProfile,
                child: Text(loc.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}