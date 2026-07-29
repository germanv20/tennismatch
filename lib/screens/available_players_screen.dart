import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'player_profile_view_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../utils/city_utils.dart';

const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String translateDay(String day, AppLocalizations loc) {
  switch (day) {
    case 'Mon': return loc.mon;
    case 'Tue': return loc.tue;
    case 'Wed': return loc.wed;
    case 'Thu': return loc.thu;
    case 'Fri': return loc.fri;
    case 'Sat': return loc.sat;
    case 'Sun': return loc.sun;
    default: return day;
  }
}

List<String> normalizeDays(List rawDays) {
  final map = {
    'Mon': 'Mon', 'Tue': 'Tue', 'Wed': 'Wed',
    'Thu': 'Thu', 'Fri': 'Fri', 'Sat': 'Sat', 'Sun': 'Sun',
    'Lun': 'Mon', 'Mar': 'Tue', 'Mié': 'Wed',
    'Jue': 'Thu', 'Vie': 'Fri', 'Sáb': 'Sat', 'Dom': 'Sun',
  };
  return rawDays
      .map<String>((day) => map[day.toString()] ?? day.toString())
      .toSet()
      .toList();
}

class AvailablePlayersScreen extends StatefulWidget {
  const AvailablePlayersScreen({super.key});

  @override
  State<AvailablePlayersScreen> createState() =>
      _AvailablePlayersScreenState();
}

class _AvailablePlayersScreenState extends State<AvailablePlayersScreen> {
  // true = show only my city, false = show all cities
  bool _filterByCity = true;

  /// Normalizes a city name by stripping accents and lowercasing so that
  /// "Popayán" and "Popayan" are treated as the same city.
  static String _normalizeCity(String input) {
    const accents = 'áàäâãåéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
    const normal  = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
    final buffer = StringBuffer();
    for (final ch in input.split('')) {
      final idx = accents.indexOf(ch);
      buffer.write(idx >= 0 ? normal[idx] : ch);
    }
    return buffer.toString().toLowerCase().trim();
  }

  Future<void> requestMatch(BuildContext context, String toUid) async {
    final loc = AppLocalizations.of(context)!;
    final fromUid = FirebaseAuth.instance.currentUser!.uid;

    if (fromUid == toUid) return;

    final query = await FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (!context.mounted) return;

    if (query.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.requestAlreadySent)),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('match_requests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.requestSent)),
    );
  }

  Stream<QuerySnapshot> getMyPendingRequests(String uid) {
    return FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Returns the flag emoji + localized country name.
  /// Works for both new profiles (have countryCode) and old ones
  /// (only have the English country name) by looking up the ISO code
  /// from the stored English name when countryCode is missing.
  static String _localizedCountryWithFlag(
    BuildContext context,
    String? countryCode,
    String fallbackName,
  ) {
    if (fallbackName.isEmpty) return '';

    // Resolve ISO code — either from the stored field (new profiles)
    // or by looking up the English name in the package's country list
    String? resolvedCode = countryCode;
    if (resolvedCode == null || resolvedCode.isEmpty) {
      // Try to find the country by its stored English name
      try {
        final allCountries = CountryService().getAll();
        final match = allCountries.firstWhere(
          (c) => c.name.toLowerCase() == fallbackName.toLowerCase(),
          orElse: () => allCountries.first,
        );
        if (match.name.toLowerCase() == fallbackName.toLowerCase()) {
          resolvedCode = match.countryCode;
        }
      } catch (_) {}
    }

    if (resolvedCode == null || resolvedCode.isEmpty) {
      return fallbackName;
    }

    // Get flag emoji from the resolved code
    String flagEmoji = '';
    try {
      final country = CountryService()
          .getAll()
          .firstWhere((c) => c.countryCode == resolvedCode);
      flagEmoji = country.flagEmoji;
    } catch (_) {}

    // Get localized name
    String localizedName = fallbackName;
    try {
      final raw = CountryLocalizations.of(context)
          ?.countryName(countryCode: resolvedCode);
      if (raw != null && raw.isNotEmpty) {
        localizedName = raw[0].toUpperCase() + raw.substring(1);
      }
    } catch (_) {}

    return flagEmoji.isNotEmpty
        ? '$localizedName $flagEmoji'
        : localizedName;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.availablePlayers)),
        body: EmptyState(
          icon: Icons.person_off,
          title: loc.notLoggedIn,
          subtitle: loc.loginToFindPlayers,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.availablePlayers)),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return ErrorState(message: loc.failedToLoadProfile);
            }
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawData = userSnapshot.data!.data();
            if (rawData == null) {
              return ErrorState(message: loc.invalidUserData);
            }

            final userData = rawData as Map<String, dynamic>;
            final List<String> availability =
                normalizeDays(userData['availability'] ?? []);
            final String userCity = formatCityDisplay(
                (userData['city'] as String? ?? '').trim());

            if (availability.isEmpty) {
              return EmptyState(
                icon: Icons.event_busy,
                title: loc.noAvailability,
                subtitle: loc.setAvailabilityToFindPlayers,
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(message: loc.failedToLoadPlayers);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // Filter by availability overlap
                final availableByDay = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (doc.id == user.uid) return false;
                  final List<String> otherAvailability =
                      normalizeDays(data['availability'] ?? []);
                  return otherAvailability
                      .any((day) => availability.contains(day));
                }).toList();

                // Apply city filter if enabled and user has a city set.
                // Both sides normalized (accents stripped + lowercased) so
                // "Popayán" and "Popayan" are treated as the same city
                // regardless of how each user typed it in their profile.
                final matches = (_filterByCity && userCity.isNotEmpty)
                    ? availableByDay.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final otherCity =
                            (data['city'] as String? ?? '').trim();
                        return _normalizeCity(otherCity) ==
                            _normalizeCity(userCity);
                      }).toList()
                    : availableByDay;

                return Column(
                  children: [
                    // ── City filter toggle ──
                    _buildCityToggle(loc, userCity, matches.length,
                        availableByDay.length),

                    // ── Player list ──
                    Expanded(
                      child: matches.isEmpty
                          ? _buildEmptyState(
                              loc, userCity, availableByDay.length)
                          : StreamBuilder<QuerySnapshot>(
                              stream: getMyPendingRequests(user.uid),
                              builder: (context, requestSnapshot) {
                                if (!requestSnapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                // UIDs with a pending outgoing request
                                final pendingUids = requestSnapshot
                                    .data!.docs
                                    .map((doc) => doc['toUid'] as String)
                                    .toSet();

                                // Also block players with whom there's
                                // already a confirmed (unplayed) match —
                                // they need to complete or cancel it first
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('matches')
                                      .where('players',
                                          arrayContains: user.uid)
                                      .where('status', isEqualTo: 'confirmed')
                                      .snapshots(),
                                  builder: (context, matchSnapshot) {
                                    if (!matchSnapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }

                                    // Extract the opponent's UID from each
                                    // confirmed match's players array
                                    final confirmedOpponentUids =
                                        matchSnapshot.data!.docs
                                            .expand((doc) {
                                              final match = doc.data()
                                                  as Map<String, dynamic>;
                                              final players = List<String>.from(
                                                  match['players'] ?? []);
                                              return players.where(
                                                  (uid) => uid != user.uid);
                                            })
                                            .toSet();

                                    // Merge: blocked if pending request
                                    // OR confirmed unplayed match exists
                                    final blockedUserIds = {
                                      ...pendingUids,
                                      ...confirmedOpponentUids,
                                    };

                                // Sort: by city then name when showing all
                                // cities (groups nearby players together);
                                // just by name within "My city" since
                                // everyone's already in the same place.
                                final sortedMatches =
                                    List<QueryDocumentSnapshot>.from(matches);
                                sortedMatches.sort((a, b) {
                                  final aData =
                                      a.data() as Map<String, dynamic>;
                                  final bData =
                                      b.data() as Map<String, dynamic>;
                                  if (!_filterByCity) {
                                    final aCity = _normalizeCity(
                                        aData['city'] as String? ?? '');
                                    final bCity = _normalizeCity(
                                        bData['city'] as String? ?? '');
                                    final cityCompare =
                                        aCity.compareTo(bCity);
                                    if (cityCompare != 0) return cityCompare;
                                  }
                                  final aName =
                                      (aData['name'] as String? ?? '')
                                          .toLowerCase();
                                  final bName =
                                      (bData['name'] as String? ?? '')
                                          .toLowerCase();
                                  return aName.compareTo(bName);
                                });

                                // Build a flat list of widgets, inserting a
                                // city header each time the city changes
                                // (only when "All cities" is active)
                                final listItems = <Widget>[];
                                String? lastCityHeader;

                                for (final doc in sortedMatches) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final playerCityRaw =
                                      (data['city'] as String? ?? '').trim();

                                  if (!_filterByCity &&
                                      playerCityRaw.isNotEmpty) {
                                    final normalizedCity =
                                        _normalizeCity(playerCityRaw);
                                    if (normalizedCity != lastCityHeader) {
                                      lastCityHeader = normalizedCity;
                                      final countryDisplay =
                                          _countrySuffix(context, data);
                                      final displayCity =
                                          formatCityDisplay(playerCityRaw);
                                      final headerText =
                                          countryDisplay.isNotEmpty
                                              ? '$displayCity${countryDisplay}'
                                              : displayCity;
                                      listItems.add(
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 16, 16, 6),
                                          child: Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 14,
                                                  color:
                                                      Theme.of(context)
                                                          .primaryColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                headerText,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  listItems.add(
                                    _buildPlayerCard(
                                      context, loc, doc, data,
                                      blockedUserIds,
                                    ),
                                  );
                                }

                                return ListView(children: listItems);
                              },
                            ); // inner StreamBuilder (confirmed matches)
                              },
                            ), // outer StreamBuilder (pending requests)
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Returns ", 🇨🇭 Switzerland" (localized) or empty string if no country.
  String _countrySuffix(BuildContext context, Map<String, dynamic> data) {
    final fallbackName = (data['country'] as String? ?? '').trim();
    if (fallbackName.isEmpty) return '';
    final countryCode = data['countryCode'] as String?;
    final display = _localizedCountryWithFlag(
        context, countryCode, fallbackName);
    return ', $display';
  }

  /// Builds a single player card for the Available Players list.
  Widget _buildPlayerCard(
    BuildContext context,
    AppLocalizations loc,
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    Set<String> blockedUserIds,
  ) {
    final List availabilityRaw = data['availability'] ?? [];
    final List<String> sortedAvailability =
        List<String>.from(availabilityRaw)
          ..sort((a, b) =>
              weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)));
    final String availabilityText = sortedAvailability.isEmpty
        ? loc.noAvailability
        : sortedAvailability.map((day) => translateDay(day, loc)).join(', ');

    final playerUid = (data['uid'] as String?)?.isNotEmpty == true
        ? data['uid'] as String
        : doc.id;
    final isAlreadyRequested = blockedUserIds.contains(playerUid);
    final playerCity =
        formatCityDisplay((data['city'] as String? ?? '').trim());

    // Online if their presence heartbeat (lib/main.dart) wrote lastActive
    // within the last 2 minutes — no boolean flag needed, self-expires.
    final lastActive = data['lastActive'] as Timestamp?;
    final isOnline = lastActive != null &&
        DateTime.now().difference(lastActive.toDate()) <
            const Duration(minutes: 2);

    return GestureDetector(
      onTap: isAlreadyRequested
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayerProfileViewScreen(
                    userData: data,
                    onRequestMatch: () async {
                      await requestMatch(context, doc.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Card(
          color: isAlreadyRequested ? Colors.grey[300] : null,
          child: ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundImage: (data['photoUrl'] != null &&
                          data['photoUrl'].toString().isNotEmpty)
                      ? NetworkImage(data['photoUrl'])
                      : null,
                  child: data['photoUrl'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              data['name'] ?? loc.unknown,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loc.availableLabel}: $availabilityText',
                  style: const TextStyle(color: Colors.grey),
                ),
                // Always show city + localized country name with flag
                if (playerCity.isNotEmpty)
                  Text(
                    '📍 $playerCity${_countrySuffix(context, data)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: isAlreadyRequested
                ? Text(
                    loc.requested,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Icon(Icons.sports_tennis),
          ),
        ),
      ),
    );
  }

  Widget _buildCityToggle(AppLocalizations loc, String userCity,
      int cityCount, int totalCount) {
    // Don't show toggle if user has no city set
    if (userCity.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.noCitySet,
                style: TextStyle(
                    color: Colors.orange[800], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          // Toggle chips
          GestureDetector(
            onTap: () => setState(() => _filterByCity = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _filterByCity
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 14,
                      color: _filterByCity
                          ? Colors.white
                          : Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    loc.filterMyCity,
                    style: TextStyle(
                      color: _filterByCity
                          ? Colors.white
                          : Colors.grey[700],
                      fontWeight: _filterByCity
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _filterByCity = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: !_filterByCity
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20)),
              ),
              child: Text(
                loc.filterAllCities,
                style: TextStyle(
                  color: !_filterByCity
                      ? Colors.white
                      : Colors.grey[700],
                  fontWeight: !_filterByCity
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Player count indicator
          Text(
            _filterByCity
                ? '$cityCount ${cityCount == 1 ? "jugador" : "jugadores"}'
                : '$totalCount ${totalCount == 1 ? "jugador" : "jugadores"}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      AppLocalizations loc, String userCity, int totalCount) {
    if (_filterByCity && totalCount > 0) {
      // Has players but none in their city
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                loc.noPlayersAvailable,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '📍 $userCity',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              // Suggest switching to all cities
              TextButton.icon(
                icon: const Icon(Icons.public),
                label: Text(loc.filterAllCities),
                onPressed: () => setState(() => _filterByCity = false),
              ),
            ],
          ),
        ),
      );
    }
    // No players at all
    return EmptyState(
      icon: Icons.people,
      title: loc.noPlayersAvailable,
      subtitle: loc.tryChangingAvailability,
    );
  }
}