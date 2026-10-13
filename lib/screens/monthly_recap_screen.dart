import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

import '../services/monthly_recap_service.dart';
import '../utils/monthly_recap_utils.dart';
import 'available_players_screen.dart';

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.tennismatch.app';

String monthName(AppLocalizations loc, int year, int month) {
  final s = DateFormat.MMMM(loc.localeName).format(DateTime(year, month));
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// "Your <month> in tennis" — swipeable recap cards, the last of which is a
/// shareable summary image. If the month had no matches, shows a nudge to
/// find a player instead. Computed on-device (see [MonthlyRecapService]).
class MonthlyRecapScreen extends StatefulWidget {
  final int year;
  final int month;
  const MonthlyRecapScreen({super.key, required this.year, required this.month});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  late final Future<({MonthlyRecap recap, int badges})> _future = _load();
  final PageController _pages = PageController();
  final GlobalKey _shareKey = GlobalKey();
  int _page = 0;
  bool _sharing = false;

  Future<({MonthlyRecap recap, int badges})> _load() async {
    final results = await Future.wait([
      MonthlyRecapService.load(widget.year, widget.month),
      MonthlyRecapService.unlockedBadgeCount(),
    ]);
    return (recap: results[0] as MonthlyRecap, badges: results[1] as int);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _share(AppLocalizations loc) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _shareKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tennis_recap_'
          '${widget.year}_${widget.month}.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: loc.recapShareText(_playStoreUrl),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(loc.recapShareFailed)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final month = monthName(loc, widget.year, widget.month);
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(loc.recapTitle(month)),
      ),
      body: FutureBuilder<({MonthlyRecap recap, int badges})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
                child: Text(loc.failedToLoadStats,
                    style: const TextStyle(color: Colors.white)));
          }
          final recap = snap.data!.recap;
          final badges = snap.data!.badges;
          if (recap.matches == 0) return _nudge(loc, month);
          final pages = _buildPages(loc, recap, badges, month);
          return Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              if (_page == pages.length - 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sharing ? null : () => _share(loc),
                      icon: _sharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.share),
                      label: Text(loc.recapShare),
                    ),
                  ),
                )
              else
                const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _nudge(AppLocalizations loc, String month) {
    final next = monthName(
        loc, widget.month == 12 ? widget.year + 1 : widget.year,
        widget.month == 12 ? 1 : widget.month + 1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_tennis, size: 72, color: Colors.white70),
            const SizedBox(height: 20),
            Text(loc.recapNudgeTitle(month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(loc.recapNudgeBody(next),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const AvailablePlayersScreen()),
              ),
              child: Text(loc.recapNudgeButton),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(
      AppLocalizations loc, MonthlyRecap r, int badges, String month) {
    final diff = r.matches - r.previousMatches;
    final vs = diff == 0
        ? loc.recapSameAsPrevious
        : loc.recapVsPrevious(diff > 0 ? '+$diff' : '$diff');
    final hours = r.totalMinutes ~/ 60;
    final mins = r.totalMinutes % 60;

    String highlightText;
    IconData highlightIcon;
    switch (r.highlight) {
      case RecapHighlight.bagel:
        highlightText = loc.recapHighlightBagel;
        highlightIcon = Icons.donut_large;
        break;
      case RecapHighlight.winStreak:
        highlightText = loc.badgeWinStreakTitle(r.highlightStreak ?? 3);
        highlightIcon = Icons.trending_up;
        break;
      case RecapHighlight.tiebreak:
        highlightText = loc.recapHighlightTiebreak;
        highlightIcon = Icons.bolt;
        break;
      case RecapHighlight.bigWin:
        highlightText = loc.recapHighlightBigWin(r.highlightScore ?? '');
        highlightIcon = Icons.military_tech;
        break;
      case RecapHighlight.none:
        highlightText = loc.recapHighlightNone;
        highlightIcon = Icons.sports_tennis;
        break;
    }

    return [
      _RecapPage(
        icon: Icons.sports_tennis,
        title: loc.matchesPlayed,
        big: '${r.matches}',
        lines: [vs, loc.recapRecord(r.wins, r.losses, r.ties)],
      ),
      _RecapPage(
        icon: Icons.timer_outlined,
        title: loc.recapTimeOnCourt,
        big: loc.recapHoursMinutes(hours, mins),
        lines: const [],
      ),
      if (r.distinctOpponents > 0)
        _RecapPage(
          icon: Icons.groups,
          title: loc.badgeOpponentsTitle(r.distinctOpponents),
          big: '${r.distinctOpponents}',
          lines: [
            loc.recapNewOpponents(r.newOpponents),
            if (r.topOpponentName != null && r.topOpponentCount > 1)
              loc.recapTopOpponent(r.topOpponentName!, r.topOpponentCount),
          ],
        ),
      _RecapPage(
        icon: highlightIcon,
        title: loc.recapHighlightTitle,
        big: '',
        lines: [highlightText],
        bigIsIcon: true,
      ),
      if (r.topCourt != null)
        _RecapPage(
          icon: Icons.location_on,
          title: loc.recapCourtTitle,
          big: r.topCourt!,
          bigSmall: true,
          lines: [loc.recapCourtCount(r.topCourtCount)],
        ),
      _RecapPage(
        icon: Icons.local_fire_department,
        title: loc.recapStreakTitle,
        big: '${r.weeklyStreakAtEnd}',
        lines: [loc.weekStreakChip(r.weeklyStreakAtEnd),
          loc.recapBadgesCount(badges)],
      ),
      _SummaryPage(
        shareKey: _shareKey,
        recap: r,
        month: month,
        hoursText: loc.recapHoursMinutes(hours, mins),
      ),
    ];
  }
}

class _RecapPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String big;
  final bool bigSmall;
  final bool bigIsIcon;
  final List<String> lines;

  const _RecapPage({
    required this.icon,
    required this.title,
    required this.big,
    required this.lines,
    this.bigSmall = false,
    this.bigIsIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: bigIsIcon ? 96 : 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 18)),
            if (!bigIsIcon) ...[
              const SizedBox(height: 8),
              Text(big,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: bigSmall ? 34 : 72,
                      fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 12),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: bigIsIcon ? 22 : 17,
                        fontWeight:
                            bigIsIcon ? FontWeight.bold : FontWeight.normal)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Final page; the [RepaintBoundary] around the card is what gets captured
/// as the shared image (fixed colors so it looks the same in any theme).
class _SummaryPage extends StatelessWidget {
  final GlobalKey shareKey;
  final MonthlyRecap recap;
  final String month;
  final String hoursText;

  const _SummaryPage({
    required this.shareKey,
    required this.recap,
    required this.month,
    required this.hoursText,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RepaintBoundary(
          key: shareKey,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E7D32), Color(0xFF0B3D13)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/icon/icon_512.png',
                          width: 32, height: 32),
                    ),
                    const SizedBox(width: 10),
                    Text(loc.appTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(loc.recapTitle(month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text('${recap.matches}',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 64,
                        fontWeight: FontWeight.bold)),
                Text(loc.matchesPlayed,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                Text(loc.recapRecord(recap.wins, recap.losses, recap.ties),
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(Icons.timer_outlined, hoursText),
                    if (recap.distinctOpponents > 0)
                      _stat(Icons.groups, '${recap.distinctOpponents}'),
                    _stat(Icons.local_fire_department,
                        '${recap.weeklyStreakAtEnd}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String text) => Column(
        children: [
          Icon(icon, color: Colors.amber),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      );
}
