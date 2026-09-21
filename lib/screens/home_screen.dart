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
import 'player_statistics_screen.dart';
import 'my_profile_screen.dart';
import 'log_guest_match_screen.dart'; // NEW
import 'log_doubles_match_screen.dart'; // NEW
import 'ranking_screen.dart';
import 'match_requests_screen.dart';
import '../widgets/home_card.dart';
import '../widgets/recent_activity_card.dart';
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
 
/// One entry in the notification bell's dropdown — either an incoming
/// pending request awaiting the viewer's response, or an outgoing request
/// the viewer sent that was just accepted or rejected (not yet seen).
class _BellNotificationItem {
  final DocumentReference requestRef;
  final String type; // 'incoming_pending' | 'accepted' | 'rejected'
  final String otherName;
  final Timestamp? timestamp;

  const _BellNotificationItem({
    required this.requestRef,
    required this.type,
    required this.otherName,
    required this.timestamp,
  });
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
  final GlobalKey _bellKey = GlobalKey();
 
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
 
  /// Bottom-sheet chooser opened by the combined "Log Match" Home tile
  /// (replaces the previous separate Singles/Doubles tiles — see CLAUDE.md).
  /// Both options push the same unchanged screens/snackbars the old tiles
  /// did; only the extra tap to pick one is new.
  void _showLogMatchChooser(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  loc.logMatchChooserTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(loc.logMatchCard),
                onTap: () async {
                  Navigator.pop(sheetContext);
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
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(loc.logDoubles),
                onTap: () async {
                  Navigator.pop(sheetContext);
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
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
 
  /// The bell icon itself, badge count live via three merged streams
  /// (incoming pending requests + unseen outgoing accept/reject outcomes).
  /// Nested StreamBuilders, same "merge multiple live sources client-side"
  /// pattern used elsewhere (e.g. available_players_screen.dart's incoming
  /// pending request flag) since Firestore can't union dissimilar queries.
  Widget _buildNotificationBell(AppLocalizations loc) {
    final uid = widget.currentUser.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('match_requests')
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, incomingSnap) {
        // Filtered client-side, not via a Firestore `where` clause: existing
        // pending requests created before this field existed have no
        // `seenByRecipient` at all, and a Firestore equality filter on
        // `== false` would silently exclude docs missing the field
        // entirely, hiding them from the badge forever.
        final incomingCount = incomingSnap.data?.docs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['seenByRecipient'] !=
                    true)
                .length ??
            0;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('match_requests')
              .where('fromUid', isEqualTo: uid)
              .where('status', isEqualTo: 'accepted')
              .where('seenBySender', isEqualTo: false)
              .snapshots(),
          builder: (context, acceptedSnap) {
            final acceptedCount = acceptedSnap.data?.docs.length ?? 0;
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('match_requests')
                  .where('fromUid', isEqualTo: uid)
                  .where('status', isEqualTo: 'rejected')
                  .where('seenBySender', isEqualTo: false)
                  .snapshots(),
              builder: (context, rejectedSnap) {
                final rejectedCount = rejectedSnap.data?.docs.length ?? 0;
                final total = incomingCount + acceptedCount + rejectedCount;
                return NotificationBadge(
                  count: total,
                  child: IconButton(
                    key: _bellKey,
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: loc.notificationsTooltip,
                    onPressed: () => _showNotificationsDropdown(loc),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Fetches the dropdown's contents fresh each time the bell is tapped
  /// (not a live stream while open — the badge above is what stays live).
  /// Resolves each request's other-party name with a per-doc `users` read,
  /// same approach incoming_requests_screen.dart already uses per row.
  Future<List<_BellNotificationItem>> _fetchBellNotifications(
      String uid) async {
    final firestore = FirebaseFirestore.instance;
    final results = <_BellNotificationItem>[];

    Future<void> addFrom(
      QuerySnapshot snap,
      String type,
      String Function(Map<String, dynamic>) otherUidOf,
      String Function(Map<String, dynamic>) timestampFieldOf,
    ) async {
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final otherUid = otherUidOf(data);
        if (otherUid.isEmpty) continue;
        final userSnap = await firestore.collection('users').doc(otherUid).get();
        final name = (userSnap.data()?['name'] as String?) ?? '';
        results.add(_BellNotificationItem(
          requestRef: doc.reference,
          type: type,
          otherName: name,
          timestamp: data[timestampFieldOf(data)] as Timestamp?,
        ));
      }
    }

    final incomingSnap = await firestore
        .collection('match_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    await addFrom(
      incomingSnap,
      'incoming_pending',
      (data) => data['fromUid'] as String? ?? '',
      (_) => 'createdAt',
    );

    // Mark whatever's currently shown as seen, so the badge clears now that
    // the user has viewed it in the dropdown — the item itself stays in the
    // list below (still pending, still worth seeing again), only the badge
    // count reacts to this flag (see _buildNotificationBell).
    final unseenIncoming = incomingSnap.docs.where(
        (d) => (d.data() as Map<String, dynamic>)['seenByRecipient'] != true);
    if (unseenIncoming.isNotEmpty) {
      final seenBatch = firestore.batch();
      for (final doc in unseenIncoming) {
        seenBatch.update(doc.reference, {'seenByRecipient': true});
      }
      await seenBatch.commit();
    }

    final acceptedSnap = await firestore
        .collection('match_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .where('seenBySender', isEqualTo: false)
        .get();
    await addFrom(
      acceptedSnap,
      'accepted',
      (data) => data['toUid'] as String? ?? '',
      (_) => 'respondedAt',
    );

    final rejectedSnap = await firestore
        .collection('match_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'rejected')
        .where('seenBySender', isEqualTo: false)
        .get();
    await addFrom(
      rejectedSnap,
      'rejected',
      (data) => data['toUid'] as String? ?? '',
      (_) => 'respondedAt',
    );

    results.sort((a, b) {
      final at = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final bt = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at); // newest first
    });

    return results;
  }

  /// HH:mm, same manual padLeft approach match_chat_screen.dart already
  /// uses for message timestamps — no new date-formatting dependency.
  String _formatNotificationTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildNotificationTile(_BellNotificationItem item, AppLocalizations loc) {
    IconData icon;
    Color color;
    String text;
    switch (item.type) {
      case 'accepted':
        icon = Icons.check_circle;
        color = Colors.green;
        text = loc.notificationRequestAccepted(item.otherName);
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        text = loc.notificationRequestRejected(item.otherName);
        break;
      default:
        icon = Icons.mail;
        color = Colors.blue;
        text = loc.notificationIncomingRequest(item.otherName);
    }
    final timeText = _formatNotificationTime(item.timestamp);
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 13)),
              if (timeText.isNotEmpty)
                Text(
                  timeText,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Incoming pending -> Incoming Requests screen. Accepted -> marks seen
  /// then opens My Scheduled Matches. Rejected -> marks seen and dismisses
  /// only, since there's no natural destination screen for it.
  Future<void> _handleNotificationTap(_BellNotificationItem item) async {
    if (item.type == 'incoming_pending') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IncomingRequestsScreen()),
      );
      return;
    }

    await item.requestRef.update({'seenBySender': true});

    if (item.type == 'accepted') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyMatchesScreen(currentUser: widget.currentUser),
        ),
      );
    }
    // rejected: dismiss only — handled by marking seen above.
  }

  Future<void> _showNotificationsDropdown(AppLocalizations loc) async {
    final uid = widget.currentUser.uid;
    final items = await _fetchBellNotifications(uid);

    if (!mounted) return;

    final RenderBox button =
        _bellKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    // Anchor on the icon's bottom-right corner only (a zero-size rect), not
    // its full bounds — using the icon's own top edge as the menu's top
    // made the dropdown open at the icon's vertical position (mid-app-bar),
    // overlapping the title next to it, instead of opening below the app
    // bar entirely.
    final buttonBottomRight =
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(buttonBottomRight, buttonBottomRight),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_BellNotificationItem?>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
      items: items.isEmpty
          ? [
              PopupMenuItem<_BellNotificationItem?>(
                enabled: false,
                child: Text(
                  loc.noNewNotifications,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ]
          : items
              .map((item) => PopupMenuItem<_BellNotificationItem?>(
                    value: item,
                    child: _buildNotificationTile(item, loc),
                  ))
              .toList(),
    );

    if (selected == null) return;
    await _handleNotificationTap(selected);
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
          // Notification bell — live count of pending incoming requests
          // plus unseen outgoing accept/reject outcomes, dropdown fetched
          // fresh each time it's opened (see _showNotificationsDropdown).
          _buildNotificationBell(loc),
          // Theme selector button
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: loc.themeSelector,
            onPressed: () => _showThemeSelector(context),
          ),
          // Overflow menu — My Profile / Send Feedback moved here out of
          // the grid (see CLAUDE.md): lower-frequency, more "settings"-like
          // than the daily-use actions the grid now focuses on. Same
          // destinations as before, just reached from the app bar instead.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyProfileScreen(),
                    ),
                  );
                  break;
                case 'feedback':
                  openFeedbackForm(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(loc.myProfile),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'feedback',
                child: ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: Text(loc.sendFeedback),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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

                const SizedBox(height: spaceM),

                // ── Recent Activity teaser — Idea 1, city activity feed ──
                const RecentActivityCard(),

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
 
                    // ── Log Match card — combines the former separate
                    // Singles/Doubles tiles into one, opening a lightweight
                    // bottom-sheet chooser first (see _showLogMatchChooser)
                    // rather than adding a new screen; part of decluttering
                    // the Home grid (see CLAUDE.md). Both destination
                    // screens/snackbars below are unchanged.
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.logMatchTile,
                        icon: Icons.sports_score,
                        onTap: () => _showLogMatchChooser(context, loc),
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

                    // ── Ranking card — Phase 3, city-scoped Elo leaderboard ──
                    AspectRatio(
                      aspectRatio: 1,
                      child: HomeCard(
                        title: loc.rankingTitle,
                        icon: Icons.emoji_events,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RankingScreen(),
                          ),
                        ),
                      ),
                    ),

                    // ── Match Requests card — combines the former
                    // separate Incoming/Outgoing tiles into one tile
                    // opening MatchRequestsScreen's tabbed view (see
                    // CLAUDE.md). The badge is the sum of both counts, so
                    // "something needs my attention" is still visible from
                    // the grid without opening either tab.
                    StreamBuilder<int>(
                      stream: getIncomingRequestsCount(
                          widget.currentUser.uid),
                      builder: (context, incomingSnapshot) {
                        final incomingCount = incomingSnapshot.data ?? 0;
                        return StreamBuilder<int>(
                          stream: getOutgoingRequestsCount(
                              widget.currentUser.uid),
                          builder: (context, outgoingSnapshot) {
                            final firestoreOutgoingCount =
                                outgoingSnapshot.data ?? 0;
                            if (outgoingOverrideCount != null &&
                                outgoingOverrideCount! > 0 &&
                                firestoreOutgoingCount >
                                    outgoingOverrideCount!) {
                              outgoingOverrideCount = null;
                            }
                            final displayOutgoingCount =
                                outgoingOverrideCount ??
                                    firestoreOutgoingCount;
                            return AspectRatio(
                              aspectRatio: 1,
                              child: NotificationBadge(
                                count: incomingCount + displayOutgoingCount,
                                child: HomeCard(
                                  title: loc.matchRequestsTile,
                                  icon: Icons.swap_horiz,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MatchRequestsScreen(
                                          currentUser: widget.currentUser,
                                        ),
                                      ),
                                    );
                                    // Same "hide the badge now, let it
                                    // self-correct once Firestore's real
                                    // count changes" trick the old
                                    // standalone Outgoing tile used —
                                    // there's no per-item "seen" flag for
                                    // outgoing requests, unlike incoming.
                                    setState(() {
                                      outgoingOverrideCount = 0;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
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