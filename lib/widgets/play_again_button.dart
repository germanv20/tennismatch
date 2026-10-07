import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../services/rematch_service.dart';

/// One-tap "Play again" button: sends a normal match request to
/// [opponentUid] via [RematchService] and reports the outcome in a
/// snackbar. Used on History cards and the completed-match detail screen.
class PlayAgainButton extends StatefulWidget {
  final String opponentUid;

  /// Compact text-button style (History cards) vs. a full outlined button
  /// (detail screen).
  final bool compact;

  const PlayAgainButton({
    super.key,
    required this.opponentUid,
    this.compact = false,
  });

  @override
  State<PlayAgainButton> createState() => _PlayAgainButtonState();
}

class _PlayAgainButtonState extends State<PlayAgainButton> {
  bool _sending = false;

  Future<void> _onPressed() async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);

    String message;
    try {
      final result = await RematchService.requestRematch(widget.opponentUid);
      switch (result) {
        case RematchResult.sent:
          message = loc.requestSent;
          break;
        case RematchResult.alreadyPending:
          message = loc.requestAlreadySent;
          break;
        case RematchResult.incomingPending:
          message = loc.rematchIncomingPending;
          break;
        case RematchResult.alreadyScheduled:
          message = loc.rematchAlreadyScheduled;
          break;
      }
    } catch (e) {
      message = 'Error: $e';
    }

    if (mounted) setState(() => _sending = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final icon = _sending
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.replay, size: 16);
    final label = Text(loc.playAgain);

    if (widget.compact) {
      return TextButton.icon(
        onPressed: _sending ? null : _onPressed,
        icon: icon,
        label: label,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _sending ? null : _onPressed,
      icon: icon,
      label: label,
    );
  }
}
