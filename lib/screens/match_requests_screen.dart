import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'incoming_requests_screen.dart';
import 'outgoing_requests_screen.dart';

/// Combined Home-screen entry point for match requests — replaces the
/// previous two separate grid tiles (Incoming Requests / Outgoing
/// Requests) with one tile that opens this single tabbed screen, as part
/// of decluttering the Home screen grid (see CLAUDE.md). Embeds
/// [IncomingRequestsList]/[OutgoingRequestsList] directly (not the
/// Scaffold-wrapped IncomingRequestsScreen/OutgoingRequestsScreen) so
/// there's only one AppBar here, not one per tab.
///
/// [IncomingRequestsScreen] and [OutgoingRequestsScreen] themselves are
/// unchanged and still pushed directly from a few other places (a
/// notification tap, the bell dropdown, the "sent you a request" card on
/// Available Players) where landing straight on Incoming — not this tabbed
/// chooser — is the right behavior.
class MatchRequestsScreen extends StatelessWidget {
  final User currentUser;

  const MatchRequestsScreen({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.matchRequestsTile),
          bottom: TabBar(
            tabs: [
              Tab(text: loc.matchRequestsIncomingTab),
              Tab(text: loc.matchRequestsOutgoingTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const IncomingRequestsList(),
            OutgoingRequestsList(currentUser: currentUser),
          ],
        ),
      ),
    );
  }
}
