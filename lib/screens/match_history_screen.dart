import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../widgets/match_card.dart';
import '../widgets/empty_state.dart';
import 'match_details_screen.dart';
import 'guest_match_details_screen.dart';
import 'doubles_match_details_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  String currentUserName = '';

  // ── Filter state — separate for each tab ──
  // Singles tab filters
  String _singlesFilterName = '';
  String? _singlesFilterResult;
  String? _singlesFilterType;    // 'regular' | 'guest' | null
  String? _singlesFilterPeriod;

  // Doubles tab filters
  String _doublesFilterName = '';
  String? _doublesFilterResult;
  String? _doublesFilterPeriod;

  bool get _hasSinglesFilter =>
      _singlesFilterName.isNotEmpty ||
      _singlesFilterResult != null ||
      _singlesFilterType != null ||
      _singlesFilterPeriod != null;

  bool get _hasDoublesFilter =>
      _doublesFilterName.isNotEmpty ||
      _doublesFilterResult != null ||
      _doublesFilterPeriod != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUserName();
    });
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        currentUserName = doc['name'] ?? '';
      });
    } catch (e) {
      debugPrint('❌ Failed to load user name: $e');
    }
  }

  /// Normalises set perspective so p1 is always the current user
  List _normaliseSets(
    List rawSets,
    bool currentUserIsP1,
  ) {
    if (currentUserIsP1) return rawSets;
    // Flip both score and tiebreak fields so p1 always = current user
    return rawSets.map((s) {
      final flipped = <String, dynamic>{'p1': s['p2'], 'p2': s['p1']};
      // Also flip tiebreak scores if present
      if (s['tb1'] != null && s['tb2'] != null) {
        flipped['tb1'] = s['tb2'];
        flipped['tb2'] = s['tb1'];
      }
      return flipped;
    }).toList();
  }

  /// Builds a card for a REGULAR (non-guest) completed match
  Widget _buildRegularMatchCard(
    BuildContext context,
    DocumentSnapshot matchDoc,
    AppLocalizations loc,
    String currentUid,
  ) {
    final match = matchDoc.data() as Map<String, dynamic>;
    final List players = match['players'] ?? [];
    final playerNames = match['playerNames'] ?? {};
    final opponentUid =
        players.firstWhere((uid) => uid != currentUid, orElse: () => '');
    final opponentName = playerNames[opponentUid] ?? loc.unknown;

    final summary = match['summary'] as Map<String, dynamic>? ?? {};
    final player1Uid = match['player1Uid'];
    final bool currentUserIsP1 = currentUid == player1Uid;

    Timestamp? matchDateTs =
        summary['matchDate'] ?? match['result']?['matchDate'];
    final DateTime matchDate =
        matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

    final rawSets = match['result']?['sets'] ?? [];
    final List sets = _normaliseSets(rawSets, currentUserIsP1);

    final location = match['result']?['location'] ?? '';
    final duration = match['result']?['durationMinutes'] ?? 0;
    final notes = match['result']?['notes']?.toString();
    final deletionRequest = match['deletionRequest'];

    final bool hasDeleteNotification = deletionRequest != null &&
        ((deletionRequest['status'] == 'pending' &&
                deletionRequest['requestedBy'] != currentUid &&
                !(deletionRequest['seenBy'] ?? []).contains(currentUid)) ||
            (deletionRequest['requestedBy'] == currentUid &&
                (deletionRequest['status'] == 'accepted' ||
                    deletionRequest['status'] == 'rejected') &&
                !(deletionRequest['seenBy'] ?? []).contains(currentUid)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailsScreen(
                matchId: matchDoc.id,
                players: players,
                playerName: currentUserName,
                opponentName: opponentName,
                opponentUid: opponentUid,
                sets: sets,
                location: location,
                duration: duration,
                matchDate: matchDate,
                notes: notes,
              ),
            ),
          );

          if (result == true && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.matchDeleted),
                  duration: const Duration(seconds: 2),
                ),
              );
            });
          }
        },
        child: MatchCard(
          hasDeleteRequest: hasDeleteNotification,
          deletionRequest: deletionRequest,
          matchId: matchDoc.id,
          players: players,
          playerName: currentUserName,
          opponentName: opponentName,
          opponentUid: opponentUid,
          sets: sets,
          location: location,
          duration: duration,
          matchDate: matchDate,
          winnerUid: match['winnerUid'] ?? '',
          currentUserUid: currentUid,
          isTie: match['isTie'] == true,
          notes: notes,
        ),
      ),
    );
  }

  /// Builds a card for a GUEST match
  Widget _buildGuestMatchCard(
    BuildContext context,
    DocumentSnapshot matchDoc,
    AppLocalizations loc,
    String currentUid,
  ) {
    final match = matchDoc.data() as Map<String, dynamic>;
    final guest = match['guestOpponent'] as Map<String, dynamic>? ?? {};
    // p1 in Firestore is always the match creator (createdBy).
    // If the current user claimed the match (is not the creator),
    // flip scores and names so the current user always sees their
    // own perspective on the left.
    final createdBy = match['createdBy'] as String? ?? '';
    final bool userIsCreator = createdBy == currentUid;

    // Creator sees guestOpponent as opponent.
    // Claimant sees the creator as opponent — name from playerNames.
    final String opponentName;
    final String opponentPhone;
    if (userIsCreator) {
      opponentName = guest['name'] ?? loc.guestOpponent;
      opponentPhone = guest['phone'] ?? '';
    } else {
      final playerNames = match['playerNames'] as Map<String, dynamic>? ?? {};
      opponentName = playerNames[createdBy] as String? ?? loc.guestOpponent;
      opponentPhone = '';
    }

    final rawSets = match['result']?['sets'] ?? [];
    final List sets = userIsCreator
        ? List.from(rawSets)
        : rawSets.map((s) {
            final flipped = <String, dynamic>{
              'p1': s['p2'],
              'p2': s['p1'],
            };
            if (s['tb1'] != null && s['tb2'] != null) {
              flipped['tb1'] = s['tb2'];
              flipped['tb2'] = s['tb1'];
            }
            return flipped;
          }).toList();

    final location = match['result']?['location'] ?? '';
    final duration = match['result']?['durationMinutes'] ?? 0;
    final guestNotes = match['result']?['notes']?.toString();

    Timestamp? matchDateTs = match['result']?['matchDate'];
    final DateTime matchDate =
        matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

    final winnerUid = match['winnerUid'] ?? '';
    final bool isTie = match['isTie'] == true;
    // winnerUid stores the creator's UID when they won.
    // For a claimed match viewed by the claimant, flip the win/loss perspective.
    final bool currentUserWon = !isTie && (userIsCreator
        ? winnerUid == currentUid
        : winnerUid != currentUid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuestMatchDetailsScreen(
                matchId: matchDoc.id,
                playerName: currentUserName,
                opponentName: opponentName,
                opponentPhone: opponentPhone,
                sets: sets,
                location: location,
                duration: duration,
                matchDate: matchDate,
                winnerUid: currentUserWon ? currentUid : 'opponent',
                currentUserUid: currentUid,
                notes: guestNotes,
              ),
            ),
          );

          if (result == true && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.matchDeleted),
                  duration: const Duration(seconds: 2),
                ),
              );
            });
          }
        },
        child: _GuestMatchCard(
          playerName: currentUserName,
          opponentName: opponentName,
          sets: sets,
          location: location,
          duration: duration,
          matchDate: matchDate,
          currentUserWon: currentUserWon,
          isTie: isTie, // doubles can now be tied
          loc: loc,
        ),
      ),
    );
  }

  Widget _buildDoublesMatchCard(
    BuildContext context,
    DocumentSnapshot matchDoc,
    AppLocalizations loc,
    String currentUid,
  ) {
    final match = matchDoc.data() as Map<String, dynamic>;
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final isTie = match['isTie'] == true;
    final winnerTeam = match['winnerTeam'] as int? ?? 1;
    final bool team1Won = !isTie && winnerTeam == 1;

    final rawSets = match['result']?['sets'] ?? [];
    final location = match['result']?['location'] ?? '';
    final duration = match['result']?['durationMinutes'] ?? 0;
    final doublesNotes = match['result']?['notes']?.toString();
    Timestamp? matchDateTs = match['result']?['matchDate'];
    final DateTime matchDate =
        matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

    final team1Label = '${team1['player1'] ?? ''} / ${team1['player2'] ?? ''}';
    final team2Label = '${team2['player1'] ?? ''} / ${team2['player2'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoublesMatchDetailsScreen(
                matchId: matchDoc.id,
                team1Player1: team1['player1'] ?? '',
                team1Player2: team1['player2'] ?? '',
                team2Player1: team2['player1'] ?? '',
                team2Player2: team2['player2'] ?? '',
                winnerTeam: winnerTeam,
                sets: List.from(rawSets),
                location: location,
                duration: duration,
                matchDate: matchDate,
                notes: doublesNotes,
              ),
            ),
          );
          if (result == true && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.matchDeleted),
                  duration: const Duration(seconds: 2)),
              );
            });
          }
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 35, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team 1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(team1Label,
                                style: TextStyle(
                                  fontWeight: team1Won
                                      ? FontWeight.bold : FontWeight.normal),
                                overflow: TextOverflow.ellipsis)),
                              if (team1Won) ...[
                                const SizedBox(width: 4),
                                const Text('🏆'),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: rawSets.map<Widget>((set) {
                            final p1 = set['p1'] ?? 0;
                            final p2 = set['p2'] ?? 0;
                            final won = p1 > p2;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(p1.toString(),
                                style: TextStyle(fontSize: 16,
                                  fontWeight: won ? FontWeight.bold : FontWeight.normal,
                                  color: won ? Colors.green.shade700 : Colors.grey)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Team 2
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(team2Label,
                                style: TextStyle(
                                  fontWeight: !team1Won
                                      ? FontWeight.bold : FontWeight.normal),
                                overflow: TextOverflow.ellipsis)),
                              if (!team1Won) ...[
                                const SizedBox(width: 4),
                                const Text('🏆'),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: rawSets.map<Widget>((set) {
                            final p1 = set['p1'] ?? 0;
                            final p2 = set['p2'] ?? 0;
                            final won = p2 > p1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(p2.toString(),
                                style: TextStyle(fontSize: 16,
                                  fontWeight: won ? FontWeight.bold : FontWeight.normal,
                                  color: won ? Colors.green.shade700 : Colors.grey)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • $duration min',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Win/Loss/Tie badge
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTie
                        ? Colors.grey[600]
                        : team1Won ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isTie ? loc.tieMatchLabel
                        : team1Won ? loc.win : loc.loss,
                    style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              // Doubles badge
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    loc.doubles.toUpperCase(),
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700),
                  ),
                ),
              ),
              // Tap hint chevron
              Positioned(
                bottom: 8, right: 8,
                child: Icon(Icons.chevron_right,
                    size: 20, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }

    void _showFilterSheet(
      BuildContext context, AppLocalizations loc, bool isSinglesTab) {
    // Work on a copy of the relevant tab's filter state
    String tempName =
        isSinglesTab ? _singlesFilterName : _doublesFilterName;
    String? tempResult =
        isSinglesTab ? _singlesFilterResult : _doublesFilterResult;
    String? tempType = isSinglesTab ? _singlesFilterType : null;
    String? tempPeriod =
        isSinglesTab ? _singlesFilterPeriod : _doublesFilterPeriod;

    final nameController = TextEditingController(text: tempName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.filterTitle,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempName = '';
                            tempResult = null;
                            tempType = null;
                            tempPeriod = null;
                          });
                          nameController.clear();
                        },
                        child: Text(loc.filterClear),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Opponent name search
                  Text(loc.filterByName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    onChanged: (v) => tempName = v,
                    decoration: InputDecoration(
                      hintText: loc.filterNameHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Result filter
                  Text(loc.filterByResult,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(ctx, setSheetState, loc.win,
                          'win', tempResult,
                          (v) => tempResult = v,
                          Colors.green),
                      _filterChip(ctx, setSheetState, loc.loss,
                          'loss', tempResult,
                          (v) => tempResult = v,
                          Colors.red),
                      _filterChip(ctx, setSheetState, loc.tieMatchLabel,
                          'tie', tempResult,
                          (v) => tempResult = v,
                          Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Type filter — singles tab only, doubles tab skips this
                  if (isSinglesTab) ...[
                    Text(loc.filterByType,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _filterChip(ctx, setSheetState, loc.filterRegistered,
                            'regular', tempType,
                            (v) => tempType = v,
                            Colors.blue),
                        _filterChip(ctx, setSheetState, loc.filterGuest,
                            'guest', tempType,
                            (v) => tempType = v,
                            Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Date range filter
                  Text(loc.filterByDate,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(ctx, setSheetState, loc.filterThisMonth,
                          'month', tempPeriod,
                          (v) => tempPeriod = v,
                          Colors.teal),
                      _filterChip(ctx, setSheetState, loc.filterLast3Months,
                          '3months', tempPeriod,
                          (v) => tempPeriod = v,
                          Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isSinglesTab) {
                            _singlesFilterName = tempName.trim();
                            _singlesFilterResult = tempResult;
                            _singlesFilterType = tempType;
                            _singlesFilterPeriod = tempPeriod;
                          } else {
                            _doublesFilterName = tempName.trim();
                            _doublesFilterResult = tempResult;
                            _doublesFilterPeriod = tempPeriod;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text(loc.filterApply),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    StateSetter setSheetState,
    String label,
    String value,
    String? currentValue,
    void Function(String?) onChanged,
    Color color,
  ) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) {
        setSheetState(() {
          onChanged(isSelected ? null : value);
        });
      },
      selectedColor: color,
      backgroundColor: Colors.grey[200],
      checkmarkColor: Colors.white,
      showCheckmark: false,
    );
  }

  /// Apply all active filters to a list of match documents
  List<QueryDocumentSnapshot> _applyFilters(
    List<QueryDocumentSnapshot> docs,
    String currentUid, {
    required String filterName,
    required String? filterResult,
    required String? filterType,
    required String? filterPeriod,
  }) {
    final hasFilter = filterName.isNotEmpty ||
        filterResult != null ||
        filterType != null ||
        filterPeriod != null;

    if (!hasFilter) return docs;

    return docs.where((doc) {
      final match = doc.data() as Map<String, dynamic>;
      final type = match['type'] as String? ?? 'regular';

      // ── Type filter ──
      if (filterType != null && type != filterType) return false;

      // ── Date filter ──
      if (filterPeriod != null) {
        final completedAt = match['completedAt'] as Timestamp?;
        if (completedAt == null) return false;
        final date = completedAt.toDate();
        final now = DateTime.now();
        if (filterPeriod == 'month') {
          if (date.year != now.year || date.month != now.month) return false;
        } else if (filterPeriod == '3months') {
          if (date.isBefore(
              now.subtract(const Duration(days: 90)))) return false;
        }
      }

      // ── Result filter ──
      if (filterResult != null) {
        final isTie = match['isTie'] == true;

        if (type == 'doubles_guest') {
          // Doubles: winnerTeam is top-level (1 or 2)
          // team1.player1 is the creator's name — creator is always in team1
          final winnerTeam = match['winnerTeam'] as int? ?? 0;
          // Creator is always team1 since they logged the match
          final currentUserIsTeam1 =
              match['createdBy'] == currentUid;
          final currentUserWon =
              (currentUserIsTeam1 && winnerTeam == 1) ||
              (!currentUserIsTeam1 && winnerTeam == 2);

          if (filterResult == 'tie' && !isTie) return false;
          if (filterResult == 'win' &&
              (isTie || !currentUserWon)) return false;
          if (filterResult == 'loss' &&
              (isTie || currentUserWon)) return false;
        } else {
          // Singles / guest: use winnerUid
          final winnerUid = match['winnerUid'] as String? ?? '';
          if (filterResult == 'tie' && !isTie) return false;
          if (filterResult == 'win' &&
              (isTie || winnerUid != currentUid)) return false;
          if (filterResult == 'loss' &&
              (isTie || winnerUid == currentUid)) return false;
        }
      }

      // ── Name filter ──
      if (filterName.isNotEmpty) {
        final query = filterName.toLowerCase();
        bool nameMatches = false;

        if (type == 'doubles_guest') {
          // team1/team2 are top-level with player1/player2 name strings
          final team1 =
              Map<String, dynamic>.from(match['team1'] ?? {});
          final team2 =
              Map<String, dynamic>.from(match['team2'] ?? {});
          final allNames = [
            team1['player1']?.toString() ?? '',
            team1['player2']?.toString() ?? '',
            team2['player1']?.toString() ?? '',
            team2['player2']?.toString() ?? '',
          ];
          nameMatches =
              allNames.any((n) => n.toLowerCase().contains(query));
        } else {
          // Regular / guest: check playerNames map and guestOpponent
          final playerNames = Map<String, dynamic>.from(
              match['playerNames'] ?? {});
          final opponentName = playerNames.entries
              .firstWhere((e) => e.key != currentUid,
                  orElse: () => const MapEntry('', ''))
              .value
              .toString()
              .toLowerCase();
          final guestName =
              (match['guestOpponent']?['name'] ?? '')
                  .toString()
                  .toLowerCase();
          nameMatches = opponentName.contains(query) ||
              guestName.contains(query);
        }

        if (!nameMatches) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildMatchList(
    BuildContext context,
    AppLocalizations loc,
    String currentUid,
    List<String> types,
    String emptyTitle,
    String emptySubtitle, {
    required String filterName,
    required String? filterResult,
    required String? filterType,
    required String? filterPeriod,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: currentUid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(loc.loading),
              ],
            ),
          );
        }

        // Filter by tab type first, then apply user filters
        final tabDocs = snapshot.data!.docs.where((doc) {
          final match = doc.data() as Map<String, dynamic>;
          final type = match['type'] as String? ?? 'regular';
          return types.contains(type);
        }).toList();

        final docs = _applyFilters(
          tabDocs,
          currentUid,
          filterName: filterName,
          filterResult: filterResult,
          filterType: filterType,
          filterPeriod: filterPeriod,
        );

        if (docs.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final matchDoc = docs[index];
            final match = matchDoc.data() as Map<String, dynamic>;
            final type = match['type'] as String? ?? 'regular';

            if (type == 'doubles_guest') {
              return _buildDoublesMatchCard(
                context, matchDoc, loc, currentUid,
              );
            } else if (type == 'guest') {
              return _buildGuestMatchCard(
                context, matchDoc, loc, currentUid,
              );
            } else {
              return _buildRegularMatchCard(
                context, matchDoc, loc, currentUid,
              );
            }
          },
        );
      },
    );
  }

  /// Builds a tab label like "Singles (12)" with a live count of completed
  /// matches for that tab's type(s), so the user doesn't need to scroll
  /// to know how many matches they have logged.
  Widget _tabLabelWithCount(
    BuildContext context,
    String label,
    String currentUid,
    List<String> types,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: currentUid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.where((doc) {
            final match = doc.data() as Map<String, dynamic>;
            final type = match['type'] as String? ?? 'regular';
            return types.contains(type);
          }).length;
        }
        return Text('$label ($count)');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.matchHistory),
          actions: [
            // Wrap in Builder to get TabController context
            Builder(builder: (ctx) {
              final tabIndex =
                  DefaultTabController.of(ctx).index;
              final isSingles = tabIndex == 0;
              final hasFilter =
                  isSingles ? _hasSinglesFilter : _hasDoublesFilter;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: loc.filterTitle,
                    onPressed: () =>
                        _showFilterSheet(context, loc, isSingles),
                  ),
                  if (hasFilter)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            onTap: (_) => setState(() {}), // refresh badge on tab change
            tabs: [
              Tab(child: _tabLabelWithCount(
                  context, loc.singles, currentUid, ['regular', 'guest'])),
              Tab(child: _tabLabelWithCount(
                  context, loc.doubles, currentUid, ['doubles_guest'])),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // Singles tab
              _buildMatchList(
                context, loc, currentUid,
                ['regular', 'guest'],
                loc.noMatchHistory,
                loc.playMatchesToSeeHistory,
                filterName: _singlesFilterName,
                filterResult: _singlesFilterResult,
                filterType: _singlesFilterType,
                filterPeriod: _singlesFilterPeriod,
              ),
              // Doubles tab
              _buildMatchList(
                context, loc, currentUid,
                ['doubles_guest'],
                loc.noDoublesHistory,
                loc.playDoublesToSeeHistory,
                filterName: _doublesFilterName,
                filterResult: _doublesFilterResult,
                filterType: null,
                filterPeriod: _doublesFilterPeriod,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline card widget for guest matches — visually distinct with orange accent
class _GuestMatchCard extends StatelessWidget {
  final String playerName;
  final String opponentName;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;
  final bool currentUserWon;
  final bool isTie;
  final AppLocalizations loc;

  const _GuestMatchCard({
    required this.playerName,
    required this.opponentName,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
    required this.currentUserWon,
    required this.isTie,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 35, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          playerName,
                          style: TextStyle(
                            fontWeight: currentUserWon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (currentUserWon) ...[
                          const SizedBox(width: 4),
                          const Text('🏆'),
                        ],
                      ],
                    ),
                    Row(
                      children: sets.map<Widget>((set) {
                        final p1 = set['p1'] ?? 0;
                        final p2 = set['p2'] ?? 0;
                        final won = p1 > p2;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            p1.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: won
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: won
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          opponentName,
                          style: TextStyle(
                            fontWeight: !currentUserWon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (!currentUserWon) ...[
                          const SizedBox(width: 4),
                          const Text('🏆'),
                        ],
                      ],
                    ),
                    Row(
                      children: sets.map<Widget>((set) {
                        final p1 = set['p1'] ?? 0;
                        final p2 = set['p2'] ?? 0;
                        final won = p2 > p1;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            p2.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: won
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: won
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  '$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • $duration min',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // Win/Loss/Tie badge top-right
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isTie
                    ? Colors.grey[600]
                    : currentUserWon ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isTie ? loc.tieMatchLabel
                    : currentUserWon ? loc.win : loc.loss,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Guest badge top-left (orange)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                loc.guestMatchBadge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ),

          // Tap hint chevron
          Positioned(
            bottom: 8,
            right: 8,
            child: Icon(Icons.chevron_right,
                size: 20, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}