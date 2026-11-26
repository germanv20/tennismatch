import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/skill_level.dart';

/// Bottom sheet listing every level of [system] with its description.
/// Returns the chosen value, or null if dismissed. [suggested] gets a
/// "Suggested" tag (used for existing users, from their old level).
Future<num?> showSkillLevelSheet(
  BuildContext context, {
  required String system,
  num? selected,
  num? suggested,
}) {
  final loc = AppLocalizations.of(context)!;
  final values = SkillLevel.valuesFor(system);
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<num>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.level,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.levelPickerHint,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: values.length,
                itemBuilder: (_, i) {
                  final v = values[i];
                  final isSelected = selected != null && selected == v;
                  final isSuggested = suggested != null && suggested == v;
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? scheme.primary : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            SkillLevel.label(loc, system, v),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isSuggested) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              loc.levelSuggestedTag,
                              style: TextStyle(
                                  fontSize: 11, color: scheme.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(SkillLevel.description(loc, system, v)),
                    onTap: () => Navigator.pop(ctx, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Form-style field that shows the chosen level and opens the sheet above.
class SkillLevelField extends StatelessWidget {
  final String system;
  final num? value;
  final num? suggested;
  final bool showError;
  final ValueChanged<num> onChanged;

  const SkillLevelField({
    super.key,
    required this.system,
    required this.value,
    required this.onChanged,
    this.suggested,
    this.showError = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final hasValue = value != null;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showSkillLevelSheet(
          context,
          system: system,
          selected: value,
          suggested: suggested,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: loc.level,
          border: const OutlineInputBorder(),
          errorText: showError && !hasValue ? loc.requiredField : null,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: hasValue
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(SkillLevel.label(loc, system, value!)),
                  Text(
                    SkillLevel.description(loc, system, value!),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              )
            : Text(
                loc.selectLevel,
                style: TextStyle(color: Colors.grey[600]),
              ),
      ),
    );
  }
}
