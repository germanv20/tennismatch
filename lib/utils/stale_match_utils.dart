import 'package:cloud_firestore/cloud_firestore.dart';

/// Timing for accepted-but-never-played matches. The Cloud Function
/// `onStaleMatchCleanup` (functions/index.js) auto-cancels them for
/// inactivity; these numbers MUST match its STALE_* constants.
///
///  - with a scheduledDate: "Did you play it?" prompt 1 day after it,
///    auto-cancel 7 days after it
///  - without one: prompt 7 days after acceptance (match createdAt),
///    auto-cancel 10 days after acceptance
const int stalePromptAfterScheduleDays = 1;
const int staleCancelAfterScheduleDays = 7;
const int stalePromptAfterAcceptDays = 7;
const int staleCancelAfterAcceptDays = 10;

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

/// When the "Did you play this match?" prompt starts showing (null if the
/// match has no usable reference time yet).
DateTime? stalePromptAt(Map<String, dynamic> match) {
  final scheduled = _ts(match['scheduledDate']);
  if (scheduled != null) {
    return scheduled.add(const Duration(days: stalePromptAfterScheduleDays));
  }
  final created = _ts(match['createdAt']);
  if (created != null) {
    return created.add(const Duration(days: stalePromptAfterAcceptDays));
  }
  return null;
}

/// When the server will auto-cancel the match.
DateTime? staleCancelAt(Map<String, dynamic> match) {
  final scheduled = _ts(match['scheduledDate']);
  if (scheduled != null) {
    return scheduled.add(const Duration(days: staleCancelAfterScheduleDays));
  }
  final created = _ts(match['createdAt']);
  if (created != null) {
    return created.add(const Duration(days: staleCancelAfterAcceptDays));
  }
  return null;
}

bool isStalePromptDue(Map<String, dynamic> match, [DateTime? now]) {
  final at = stalePromptAt(match);
  return at != null && !(now ?? DateTime.now()).isBefore(at);
}
