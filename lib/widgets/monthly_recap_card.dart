import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

import '../screens/monthly_recap_screen.dart';
import '../services/monthly_recap_service.dart';
import '../utils/monthly_recap_utils.dart';

/// Home card for the previous month's recap. Only shown during the first
/// [MonthlyRecapService.homeCardDays] days of a month and until dismissed.
/// If the user played that month it invites them to open the recap;
/// if they didn't (but have played before) it becomes a "get back on court"
/// nudge. Hidden otherwise, and while loading.
class MonthlyRecapCard extends StatefulWidget {
  const MonthlyRecapCard({super.key});

  @override
  State<MonthlyRecapCard> createState() => _MonthlyRecapCardState();
}

class _MonthlyRecapCardState extends State<MonthlyRecapCard> {
  late final DateTime _prev;
  MonthlyRecap? _recap;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _prev = DateTime(now.year, now.month - 1);
    if (now.day <= MonthlyRecapService.homeCardDays) _init();
  }

  Future<void> _init() async {
    try {
      if (await MonthlyRecapService.isDismissed(_prev.year, _prev.month)) {
        return;
      }
      final recap = await MonthlyRecapService.load(_prev.year, _prev.month);
      final show = recap.matches > 0 || recap.hasEverPlayed;
      if (!mounted || !show) return;
      setState(() {
        _recap = recap;
        _visible = true;
      });
    } catch (_) {
      // Non-critical; card stays hidden.
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    await MonthlyRecapService.dismiss(_prev.year, _prev.month);
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MonthlyRecapScreen(year: _prev.year, month: _prev.month),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recap = _recap;
    if (!_visible || recap == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final month = monthName(loc, _prev.year, _prev.month);
    final played = recap.matches > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFF1B5E20),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                Icon(played ? Icons.auto_awesome : Icons.sports_tennis,
                    color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        played
                            ? loc.recapHomeCardTitle(month)
                            : loc.recapNudgeTitle(month),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        played
                            ? loc.recapHomeCardSubtitle
                            : loc.recapNudgeButton,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
