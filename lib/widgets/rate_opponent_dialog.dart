import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

/// Shared post-match opponent rating dialog + trigger (Phase 1, regular
/// matches only). Used from three places: the "Rate opponent" section on
/// both completed-match detail screens (match_detail_screen.dart and
/// match_details_screen.dart — see CLAUDE.md for why there are two), and
/// automatically right after submitting a match result
/// (add_match_result_screen.dart) or tapping the rate-opponent push
/// notification (main.dart). Extracted here instead of duplicated a
/// third time.

/// Shows the 1-5 star + no-show dialog and writes the rating on submit.
/// Still skippable via Cancel even when triggered automatically.
Future<void> showRateOpponentDialog(
  BuildContext context,
  AppLocalizations loc, {
  required String matchId,
  required String ratedUid,
  required String raterUid,
}) async {
  int selectedStars = 0;
  bool noShow = false;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(loc.rateOpponentDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= selectedStars
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: noShow
                          ? null
                          : () => setDialogState(
                              () => selectedStars = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: noShow,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    loc.opponentNoShowLabel,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onChanged: (value) => setDialogState(() {
                    noShow = value ?? false;
                    if (noShow) selectedStars = 0;
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(loc.cancel),
              ),
              TextButton(
                onPressed: (!noShow && selectedStars == 0)
                    ? null
                    : () async {
                        await FirebaseFirestore.instance
                            .collection('matches')
                            .doc(matchId)
                            .collection('ratings')
                            .doc(raterUid)
                            .set({
                          'ratedUid': ratedUid,
                          'stars': noShow ? 0 : selectedStars,
                          'noShow': noShow,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: Text(loc.confirm),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Renders either the "Rate opponent" button or, once the current user has
/// already rated this match, a confirmation card — driven live by a
/// StreamBuilder on their own rating doc. Hidden entirely if ratedUid is
/// unknown or is somehow the rater themselves.
class RateOpponentSection extends StatelessWidget {
  final String matchId;
  final String ratedUid;
  final String raterUid;

  const RateOpponentSection({
    super.key,
    required this.matchId,
    required this.ratedUid,
    required this.raterUid,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (ratedUid.isEmpty || ratedUid == raterUid) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('ratings')
          .doc(raterUid)
          .snapshots(),
      builder: (context, ratingSnapshot) {
        if (!ratingSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (ratingSnapshot.data!.exists) {
          final existing =
              ratingSnapshot.data!.data() as Map<String, dynamic>;
          final bool noShow = existing['noShow'] == true;
          final int stars = existing['stars'] as int? ?? 0;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    noShow
                        ? loc.ratingSubmittedNoShow
                        : loc.ratingSubmittedStars(stars),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        return OutlinedButton.icon(
          icon: const Icon(Icons.star_outline),
          label: Text(loc.rateOpponentButton),
          onPressed: () => showRateOpponentDialog(
            context,
            loc,
            matchId: matchId,
            ratedUid: ratedUid,
            raterUid: raterUid,
          ),
        );
      },
    );
  }
}
