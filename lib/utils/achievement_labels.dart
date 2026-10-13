import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

import 'achievements_utils.dart';

/// Localized title/description/icon for an [AchievementBadge], keyed off its
/// `kind` (tiered badges share a kind and differ by `target`).
String badgeTitle(AchievementBadge b, AppLocalizations loc) {
  switch (b.kind) {
    case 'first_match':
      return loc.badgeFirstMatchTitle;
    case 'matches':
      return loc.badgeMatchesTitle(b.target);
    case 'week_streak':
      return loc.badgeWeekStreakTitle(b.target);
    case 'opponents':
      return loc.badgeOpponentsTitle(b.target);
    case 'rivalry':
      return loc.badgeRivalryTitle;
    case 'first_rating':
      return loc.badgeFirstRatingTitle;
    case 'first_win':
      return loc.badgeFirstWinTitle;
    case 'win_streak':
      return loc.badgeWinStreakTitle(b.target);
    case 'bagel':
      return loc.badgeBagelTitle;
    case 'tiebreak':
      return loc.badgeTiebreakTitle;
    case 'giant':
      return loc.badgeGiantTitle;
    case 'reputation':
      return loc.badgeReputationTitle;
  }
  return b.id;
}

String badgeDescription(AchievementBadge b, AppLocalizations loc) {
  switch (b.kind) {
    case 'first_match':
      return loc.badgeFirstMatchDesc;
    case 'matches':
      return loc.badgeMatchesDesc(b.target);
    case 'week_streak':
      return loc.badgeWeekStreakDesc(b.target);
    case 'opponents':
      return loc.badgeOpponentsDesc(b.target);
    case 'rivalry':
      return loc.badgeRivalryDesc(b.target);
    case 'first_rating':
      return loc.badgeFirstRatingDesc;
    case 'first_win':
      return loc.badgeFirstWinDesc;
    case 'win_streak':
      return loc.badgeWinStreakDesc(b.target);
    case 'bagel':
      return loc.badgeBagelDesc;
    case 'tiebreak':
      return loc.badgeTiebreakDesc;
    case 'giant':
      return loc.badgeGiantDesc;
    case 'reputation':
      return loc.badgeReputationDesc;
  }
  return '';
}

IconData badgeIcon(AchievementBadge b) {
  switch (b.kind) {
    case 'first_match':
      return Icons.sports_tennis;
    case 'matches':
      return Icons.emoji_events;
    case 'week_streak':
      return Icons.local_fire_department;
    case 'opponents':
      return Icons.groups;
    case 'rivalry':
      return Icons.compare_arrows;
    case 'first_rating':
      return Icons.thumb_up_alt_outlined;
    case 'first_win':
      return Icons.military_tech;
    case 'win_streak':
      return Icons.trending_up;
    case 'bagel':
      return Icons.donut_large;
    case 'tiebreak':
      return Icons.bolt;
    case 'giant':
      return Icons.workspace_premium;
    case 'reputation':
      return Icons.star;
  }
  return Icons.emoji_events;
}

String badgeGroupTitle(BadgeGroup g, AppLocalizations loc) {
  switch (g) {
    case BadgeGroup.playing:
      return loc.badgeGroupPlaying;
    case BadgeGroup.social:
      return loc.badgeGroupSocial;
    case BadgeGroup.performance:
      return loc.badgeGroupPerformance;
    case BadgeGroup.reputation:
      return loc.badgeGroupReputation;
  }
}

/// Visual for a badge: the "N matches played" tiers show their own number
/// inside a ring (so 5/10/25/50 each look different); every other badge
/// uses its [badgeIcon]. [size] is the overall diameter/icon size.
Widget badgeVisual(AchievementBadge b, {required double size, required Color color}) {
  if (b.kind != 'matches') {
    return Icon(badgeIcon(b), size: size, color: color);
  }
  final text = '${b.target}';
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: size * 0.08),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: size * (text.length > 1 ? 0.46 : 0.55),
          ),
        ),
      ),
    ),
  );
}
