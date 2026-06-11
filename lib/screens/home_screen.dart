import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'available_players_screen.dart';
import 'match_history_screen.dart';
import 'my_matches_screen.dart';
import 'incoming_requests_screen.dart';
import 'outgoing_requests_screen.dart';
import 'player_statistics_screen.dart';
import 'my_profile_screen.dart';
import 'log_guest_match_screen.dart'; // NEW
import 'log_doubles_match_screen.dart'; // NEW
import '../widgets/home_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
 
const double spaceXS = 4;
const double spaceS = 8;
const double spaceM = 16;
const double spaceL = 24;
const double spaceXL = 32;
 
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
 
  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
  });
 
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
 
const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
 
class HomeScreen extends StatefulWidget {
  final User currentUser;
  final Map<String, dynamic> userData;
 
  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.userData,
  });
 
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
 
class _HomeScreenState extends State<HomeScreen> {
  int? outgoingOverrideCount;
 
  String translateLevel(String level, AppLocalizations loc) {
    switch (level) {
      case 'Beginner': return loc.levelBeginner;
      case 'Intermediate': return loc.levelIntermediate;
      case 'Advanced': return loc.levelAdvanced;
      default: return level;
    }
  }
 
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
 
  Widget buildProfileCard(AppLocalizations loc) {
    final String name = widget.currentUser.displayName ?? 'Player';
    final String rawLevel = widget.userData['tennisLevel'] ?? '';
    final String level =
        rawLevel.isEmpty ? loc.notSet : translateLevel(rawLevel, loc);
 
    final List availabilityRaw =
        normalizeDays(widget.userData['availability'] ?? []);
 
    final List<String> sortedAvailability =
        List<String>.from(availabilityRaw)
          ..sort((a, b) =>
              weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)));
 
    // Use theme playerCardColor for the gradient
    final cardColor = context.read<ThemeNotifier>().current.playerCardColor;
    final cardColorLight = Color.lerp(cardColor, Colors.white, 0.3) ?? cardColor;
 
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColorLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Tappable profile photo with camera overlay
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(context, loc),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 29,
                    backgroundImage: (widget.userData['photoUrl'] != null &&
                            widget.userData['photoUrl'].toString().isNotEmpty)
                        ? NetworkImage(widget.userData['photoUrl'])
                        : null,
                    child: widget.userData['photoUrl'] == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                ),
                // Camera icon badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: spaceS),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🎾 $level',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: spaceS),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sortedAvailability.map((day) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        translateDay(day, loc),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 
  Future<void> updateTennisLevel(String level) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUser.uid)
        .update({'tennisLevel': level});
  }
 
  Future<void> updateAvailability(List<String> days) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUser.uid)
        .update({'availability': days});
  }
 
  Future<void> openFeedbackForm(BuildContext context) async {
    final url = Uri.parse(
        'https://docs.google.com/forms/d/e/1FAIpQLScGcT2eC2znik4ndofkiExqAN1k7LL_A3eOOQfjeCkl-5RO-A/viewform');
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context)!;
 
    final success =
        await launchUrl(url, mode: LaunchMode.externalApplication);
 
    if (!success) {
      messenger.showSnackBar(
        SnackBar(content: Text(loc.failedToOpenFeedbackForm)),
      );
    }
  }
 
  Future<void> _pickAndUploadPhoto(
      BuildContext context, AppLocalizations loc) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,       // compress to reduce upload size
      maxWidth: 512,
      maxHeight: 512,
    );
 
    if (image == null) return; // user cancelled
 
    final uid = widget.currentUser.uid;
 
    // Show uploading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(loc.uploadingPhoto),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }
 
    try {
      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');
 
      await ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
 
      final downloadUrl = await ref.getDownloadURL();
 
      // Update Firestore user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': downloadUrl});
 
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.photoUpdated),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Photo upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.photoUploadError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
 
  void _showThemeSelector(BuildContext context) {
    final themeNotifier = context.read<ThemeNotifier>();
    final loc = AppLocalizations.of(context)!;
 
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: themeNotifier,
          child: Consumer<ThemeNotifier>(
            builder: (context, notifier, _) {
              final loc2 = AppLocalizations.of(context)!;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.themeSelector,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...allThemes.map((theme) {
                      final isSelected = notifier.current.code == theme.code;
 
                      // Resolve localized name from ARB key
                      final localizedLabel = switch (theme.labelKey) {
                        'themeDefault'    => loc2.themeDefault,
                        'themeClay'       => loc2.themeClay,
                        'themeGrass'      => loc2.themeGrass,
                        'themeHardCourt1' => loc2.themeHardCourt1,
                        'themeHardCourt2' => loc2.themeHardCourt2,
                        _                 => theme.label,
                      };
 
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.playerCardColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.black26, width: 2)
                                : null,
                          ),
                        ),
                        title: Text(
                          localizedLabel,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: theme.playerCardColor)
                            : null,
                        onTap: () async {
                          await notifier.setTheme(theme);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
 
  Future<void> signOut(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.loggedOutSuccessfully)),
    );
  }
 
  Stream<int> getIncomingRequestsCount(String userId) {
    return FirebaseFirestore.instance
        .collection('match_requests')
        .where('toUid', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }
 
  Stream<int> getNewMatchesCount(String userId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: userId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final notified =
                List<String>.from(data['notifiedPlayers'] ?? []);
            if (!notified.contains(userId)) count++;
          }
          return count;
        });
  }
 
  Stream<int> getOutgoingRequestsCount(String userId) {
    return FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }
 
  Stream<int> getPendingDeletionRequestsCount(String userId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final deletionRequest = data['deletionRequest'];
            if (deletionRequest == null) continue;
            final status = deletionRequest['status'];
            final isRequester =
                deletionRequest['requestedBy'] == userId;
            final seenBy =
                List<String>.from(deletionRequest['seenBy'] ?? []);
            final notSeen = !seenBy.contains(userId);
            if (status == 'pending' && !isRequester && notSeen) count++;
            if ((status == 'accepted' || status == 'rejected') &&
                isRequester &&
                notSeen) count++;
          }
          return count;
        });
  }
 
  @override
  Widget build(BuildContext context) {
    final String? tennisLevel = widget.userData['tennisLevel'];
    final List<dynamic> availabilityRaw =
        widget.userData['availability'] ?? [];
    final List<String> availability = normalizeDays(availabilityRaw);
    final loc = AppLocalizations.of(context)!;
 
    final dayMap = {
      'Mon': loc.monFull, 'Tue': loc.tueFull, 'Wed': loc.wedFull,
      'Thu': loc.thuFull, 'Fri': loc.friFull, 'Sat': loc.satFull,
      'Sun': loc.sunFull,
    };
 
    final levelMap = {
      'Beginner': loc.levelBeginner,
      'Intermediate': loc.levelIntermediate,
      'Advanced': loc.levelAdvanced,
    };
 
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appTitle),
        actions: [
          // Theme selector button
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: loc.themeSelector,
            onPressed: () => _showThemeSelector(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: loc.signOut,
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.signOut),
                  content: Text(loc.signOutConfirmation),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(loc.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(loc.signOut),
                    ),
                  ],
                ),
              );
              if (confirm == true) await signOut(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
 
                buildProfileCard(loc),
 
                const SizedBox(height: spaceL),
 
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loc.yourTennisLevel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
 
                const SizedBox(height: spaceS),
 
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(spaceM),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: levelMap.entries.map((entry) {
                      final isSelected = tennisLevel == entry.key;
                      return GestureDetector(
                        onTap: () async =>
                            await updateTennisLevel(entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.read<ThemeNotifier>().current.selectionColor
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: context.read<ThemeNotifier>()
                                          .current.selectionColor
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Icon(Icons.check,
                                    color: Colors.white, size: 16),
                              if (isSelected) const SizedBox(width: 6),
                              Text(
                                entry.value,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
 
                const SizedBox(height: spaceXL),
 
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(spaceM),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: spaceS),
                          Text(
                            loc.availability,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: spaceXS),
                      Text(
                        loc.availabilityHint,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: spaceM),
                      Wrap(
                        spacing: spaceS,
                        runSpacing: spaceS,
                        children: dayMap.entries.map((entry) {
                          final key = entry.key;
                          final label = entry.value;
                          final isSelected = availability.contains(key);
 
                          return GestureDetector(
                            onTap: () async {
                              final updated =
                                  List<String>.from(availability);
                              isSelected
                                  ? updated.remove(key)
                                  : updated.add(key);
                              await updateAvailability(updated);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.read<ThemeNotifier>().current.selectionColor
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
 
                const SizedBox(height: spaceL),
 
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
 
                    // ── Log Singles Match card ──
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.logMatchCard,
                        icon: Icons.add_circle_outline,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LogGuestMatchScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(loc.guestMatchSaved)),
                            );
                          }
                        },
                      ),
                    ),
 
                    // ── Log Doubles Match card ──
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.logDoubles,
                        icon: Icons.group_outlined,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LogDoublesMatchScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(loc.doublesMatchSaved)),
                            );
                          }
                        },
                      ),
                    ),
 
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.findPlayers,
                        icon: Icons.sports_tennis,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AvailablePlayersScreen(),
                          ),
                        ),
                      ),
                    ),
 
                    StreamBuilder<int>(
                      stream: getNewMatchesCount(widget.currentUser.uid),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return AspectRatio(
                          aspectRatio: 1,
                          child: NotificationBadge(
                            count: count,
                            child: HomeCard(
                              title: loc.myMatches,
                              icon: Icons.calendar_today,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MyMatchesScreen(
                                      currentUser: widget.currentUser,
                                    ),
                                  ),
                                );
                                setState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),
 
                    StreamBuilder<int>(
                      stream: getPendingDeletionRequestsCount(
                          widget.currentUser.uid),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return AspectRatio(
                          aspectRatio: 1,
                          child: NotificationBadge(
                            count: count,
                            child: HomeCard(
                              title: loc.matchHistory,
                              icon: Icons.history,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MatchHistoryScreen(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
 
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.myStats,
                        icon: Icons.bar_chart,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerStatisticsScreen(
                              userId: widget.currentUser.uid,
                            ),
                          ),
                        ),
                      ),
                    ),
 
                    StreamBuilder<int>(
                      stream: getIncomingRequestsCount(
                          widget.currentUser.uid),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return AspectRatio(
                          aspectRatio: 1,
                          child: NotificationBadge(
                            count: count,
                            child: HomeCard(
                              title: loc.incomingRequests,
                              icon: Icons.move_to_inbox,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const IncomingRequestsScreen(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
 
                    StreamBuilder<int>(
                      stream: getOutgoingRequestsCount(
                          widget.currentUser.uid),
                      builder: (context, snapshot) {
                        final firestoreCount = snapshot.data ?? 0;
                        if (outgoingOverrideCount != null &&
                            outgoingOverrideCount! > 0 &&
                            firestoreCount > outgoingOverrideCount!) {
                          outgoingOverrideCount = null;
                        }
                        final displayCount =
                            outgoingOverrideCount ?? firestoreCount;
                        return AspectRatio(
                          aspectRatio: 1,
                          child: NotificationBadge(
                            count: displayCount,
                            child: HomeCard(
                              title: loc.outgoingRequests,
                              icon: Icons.outbox,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OutgoingRequestsScreen(
                                      currentUser: widget.currentUser,
                                    ),
                                  ),
                                );
                                setState(() {
                                  outgoingOverrideCount = 0;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
 
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.myProfile,
                        icon: Icons.person,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyProfileScreen(),
                          ),
                        ),
                      ),
                    ),
 
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.sendFeedback,
                        icon: Icons.feedback,
                        onTap: () => openFeedbackForm(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}