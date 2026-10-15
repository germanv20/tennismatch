import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

import '../utils/name_utils.dart';

/// A registered player chosen in [showPlayerPicker].
class PickedPlayer {
  final String uid;
  final String name;
  const PickedPlayer(this.uid, this.name);
}

/// Name field for a doubles slot that can optionally be linked to a
/// registered player. Typing a name keeps it a plain (guest) name; the
/// search button opens [showPlayerPicker], and picking someone fills the
/// name, marks the field as linked (check icon, read-only) and reports the
/// uid via [onLinked]. The X unlinks and makes it editable again.
class LinkablePlayerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  /// uid this slot is linked to, or null for a plain typed name.
  final String? linkedUid;

  /// uids that can't be picked here (yourself and players already linked in
  /// other slots).
  final Set<String> excludeUids;

  /// Called with the picked player, or null when the slot is unlinked.
  final void Function(PickedPlayer? player) onLinked;

  /// Called whenever the typed text changes (unlinked slots only).
  final VoidCallback onTextChanged;

  const LinkablePlayerField({
    super.key,
    required this.controller,
    required this.label,
    required this.linkedUid,
    required this.excludeUids,
    required this.onLinked,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final linked = linkedUid != null;

    return TextField(
      controller: controller,
      readOnly: linked,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => onTextChanged(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(
          linked ? Icons.verified_user : Icons.person_outline,
          color: linked ? Colors.green : null,
        ),
        suffixIcon: linked
            ? IconButton(
                tooltip: loc.linkPlayerRemove,
                icon: const Icon(Icons.close),
                onPressed: () => onLinked(null),
              )
            : IconButton(
                tooltip: loc.linkPlayerSearch,
                icon: const Icon(Icons.person_search),
                onPressed: () async {
                  final picked = await showPlayerPicker(
                    context,
                    excludeUids: excludeUids,
                  );
                  if (picked != null) onLinked(picked);
                },
              ),
      ),
    );
  }
}

/// Bottom sheet listing registered players (searchable by name). Returns the
/// chosen player or null if dismissed. Loads the `users` collection once
/// (the same full list Available Players already streams) and filters
/// client-side.
Future<PickedPlayer?> showPlayerPicker(
  BuildContext context, {
  required Set<String> excludeUids,
}) {
  return showModalBottomSheet<PickedPlayer>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlayerPickerSheet(excludeUids: excludeUids),
  );
}

class _PlayerPickerSheet extends StatefulWidget {
  final Set<String> excludeUids;
  const _PlayerPickerSheet({required this.excludeUids});

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _future =
      _load();
  String _query = '';

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _load() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final docs = snap.docs
        .where((d) =>
            !widget.excludeUids.contains(d.id) &&
            ((d.data()['name'] as String?) ?? '').trim().isNotEmpty)
        .toList()
      ..sort((a, b) => formatNameDisplay(a.data()['name'] as String)
          .compareTo(formatNameDisplay(b.data()['name'] as String)));
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final height = MediaQuery.of(context).size.height * 0.75;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: loc.linkPlayerHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data ?? const [];
                  final list = _query.isEmpty
                      ? all
                      : all
                          .where((d) => (d.data()['name'] as String)
                              .toLowerCase()
                              .contains(_query))
                          .toList();
                  if (list.isEmpty) {
                    return Center(child: Text(loc.linkPlayerNoResults));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final data = list[i].data();
                      final name = formatNameDisplay(data['name'] as String);
                      final photo = data['photoUrl'] as String?;
                      final city = data['city'] as String?;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (photo != null && photo.isNotEmpty)
                                  ? NetworkImage(photo)
                                  : null,
                          child: (photo == null || photo.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(name),
                        subtitle: (city != null && city.isNotEmpty)
                            ? Text(city)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, PickedPlayer(list[i].id, name)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
