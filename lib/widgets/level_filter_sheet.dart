import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/skill_level.dart';

/// The Search Players level filter: an exact category for Colombia
/// ([exact]) or an NTRP range ([from]..[to], either end open) elsewhere.
/// All-null means "no filter".
typedef LevelFilter = ({num? exact, num? from, num? to});

/// Opens the filter sheet for [system]. Returns the new filter (all-null =
/// cleared), or null if the sheet was dismissed without a choice.
Future<LevelFilter?> showLevelFilterSheet(
  BuildContext context, {
  required String system,
  required LevelFilter current,
}) {
  final loc = AppLocalizations.of(context)!;

  return showModalBottomSheet<LevelFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: system == SkillLevel.co
            ? _ExactSheet(loc: loc, current: current)
            : _RangeSheet(loc: loc, current: current),
      ),
    ),
  );
}

/// Colombia: one category at a time, or all.
class _ExactSheet extends StatelessWidget {
  final AppLocalizations loc;
  final LevelFilter current;
  const _ExactSheet({required this.loc, required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(String title, num? value, {String? subtitle}) {
      final selected = current.exact == value;
      return ListTile(
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? scheme.primary : null,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle),
        onTap: () =>
            Navigator.pop<LevelFilter>(context, (exact: value, from: null, to: null)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(loc.levelFilterTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              tile(loc.levelFilterAll, null),
              for (final v in SkillLevel.coValues)
                tile(SkillLevel.label(loc, SkillLevel.co, v), v,
                    subtitle: SkillLevel.description(loc, SkillLevel.co, v)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(loc.levelFilterHiddenNote,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
      ],
    );
  }
}

/// NTRP: "From" and "To" dropdowns, each optionally open-ended.
class _RangeSheet extends StatefulWidget {
  final AppLocalizations loc;
  final LevelFilter current;
  const _RangeSheet({required this.loc, required this.current});

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  num? _from;
  num? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.current.from;
    _to = widget.current.to;
  }

  DropdownButtonFormField<num?> _dropdown(
      String label, num? value, ValueChanged<num?> onChanged) {
    final loc = widget.loc;
    return DropdownButtonFormField<num?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<num?>(value: null, child: Text(loc.levelFilterAll)),
        for (final v in SkillLevel.ntrpValues)
          DropdownMenuItem<num?>(
            value: v,
            child: Text(SkillLevel.label(loc, SkillLevel.ntrp, v)),
          ),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.levelFilterTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _dropdown(loc.levelFilterFrom, _from, (v) => setState(() => _from = v)),
          const SizedBox(height: 12),
          _dropdown(loc.levelFilterTo, _to, (v) => setState(() => _to = v)),
          const SizedBox(height: 8),
          Text(loc.levelFilterHiddenNote,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop<LevelFilter>(
                    context, (exact: null, from: null, to: null)),
                child: Text(loc.levelFilterClear),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  var from = _from;
                  var to = _to;
                  // Keep the range sensible if the ends were picked reversed.
                  if (from != null && to != null && from > to) {
                    final t = from;
                    from = to;
                    to = t;
                  }
                  Navigator.pop<LevelFilter>(
                      context, (exact: null, from: from, to: to));
                },
                child: Text(loc.levelFilterApply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
