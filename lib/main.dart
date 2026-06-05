import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'screens/match_chat_screen.dart';
import 'screens/incoming_requests_screen.dart';
import 'services/theme_service.dart';
import 'screens/match_detail_screen.dart';
import 'screens/home_screen.dart';
import 'screens/complete_profile_screen.dart';


final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔔 Request notification permission (Android 13+)
  NotificationSettings settings =
      await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint("🔔 Permission status: ${settings.authorizationStatus}");

  // Load saved theme before first frame
  final themeNotifier = ThemeNotifier();
  await themeNotifier.loadSavedTheme();

  runApp(
    ChangeNotifierProvider.value(
      value: themeNotifier,
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final tennisTheme = themeNotifier.current;

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [
        Locale('en'),
        Locale('es'),
      ],

      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;

        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },

      navigatorKey: navigatorKey,

      // Apply the selected tennis theme
      theme: tennisTheme.toThemeData().copyWith(
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),

      home: const AuthTest(),
    );
  }
}

Future<void> navigateToChat(String matchId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final matchDoc = await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .get();

  if (!matchDoc.exists) return;

  final matchData = matchDoc.data() as Map<String, dynamic>;

  final opponentUid =
      matchData['player1Uid'] == currentUser.uid
          ? matchData['player2Uid']
          : matchData['player1Uid'];

  final opponentSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(opponentUid)
      .get();

  if (!opponentSnap.exists) return;

  final opponentData = opponentSnap.data() as Map<String, dynamic>;

  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => MatchChatScreen(
        matchId: matchId,
        otherPlayerUid: opponentUid,
        otherPlayerName: opponentData['name'] ?? 'Player',
        otherPlayerPhotoUrl: opponentData['photoUrl'] ?? '',
      ),
    ),
    (route) => route.isFirst,
  );
}

/// Navigates to MatchDetailScreen — used for match_reminder notifications
Future<void> navigateToMatchDetail(String matchId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final matchDoc = await FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .get();

  if (!matchDoc.exists) return;

  final matchData = matchDoc.data() as Map<String, dynamic>;

  final opponentUid =
      matchData['player1Uid'] == currentUser.uid
          ? matchData['player2Uid']
          : matchData['player1Uid'];

  final opponentSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(opponentUid)
      .get();

  if (!opponentSnap.exists) return;

  final opponentData = opponentSnap.data() as Map<String, dynamic>;

  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => MatchDetailScreen(
        matchDoc: matchDoc,
        opponentData: opponentData,
      ),
    ),
    (route) => route.isFirst,
  );
}

/// Routes to the correct screen based on notification type
Future<void> handleNotificationTap(Map<String, dynamic> data) async {
  final type = data['type'] as String? ?? '';
  final matchId = data['matchId'] as String?;

  // Wait until the navigator is ready
  if (navigatorKey.currentState == null) {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  if (navigatorKey.currentState == null) return;

  if (type == 'match_reminder' && matchId != null) {
    await navigateToMatchDetail(matchId);
  } else if (type == 'match_request') {
    // Navigate to Incoming Requests screen so user can accept/reject
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IncomingRequestsScreen()),
      (route) => route.isFirst,
    );
  } else if (matchId != null) {
    // chat_message, match_accepted → open chat
    await navigateToChat(matchId);
  }
}

class AuthTest extends StatefulWidget {
  const AuthTest({super.key});

  @override
  State<AuthTest> createState() => _AuthTestState();
}

class _AuthTestState extends State<AuthTest> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _fcmInitialized = false;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !_fcmInitialized) {
        _fcmInitialized = true;
        setupFCM();
      }
      // Reset flag on sign-out so fresh token is fetched on next login
      if (user == null) {
        _fcmInitialized = false;
      }
    });

    // When app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      Future.delayed(const Duration(milliseconds: 500), () {
        handleNotificationTap(message.data);
      });
    });

    // When app opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        // Longer delay needed — navigator not ready immediately on cold start
        Future.delayed(const Duration(milliseconds: 1500), () {
          handleNotificationTap(message.data);
        });
      }
    });
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Force account picker every time
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await ensureUserDocument(user);
      }
    } catch (e) {
      debugPrint('❌ Google sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('❌ Sign out failed: $e');
    }
  }

  /// Creates or repairs the user document without overwriting
  /// any fields that CompleteProfileScreen has already set.
  ///
  /// Strategy:
  /// - Read the document first
  /// - Only write fields that are genuinely missing (null or absent)
  /// - Never write null over a non-null value
  Future<void> ensureUserDocument(User user) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    final snap = await ref.get();
    final existing = snap.data() ?? {};

    // Build a map of ONLY the fields that are missing or empty
    final Map<String, dynamic> toWrite = {};

    // Auth-derived fields — always safe to write from Google account
    // Only update if missing to avoid overwriting custom display names
    if (_isMissing(existing, 'uid')) toWrite['uid'] = user.uid;
    if (_isMissing(existing, 'name')) {
      toWrite['name'] = user.displayName ?? 'Unknown';
    }
    if (_isMissing(existing, 'email')) toWrite['email'] = user.email;
    if (_isMissing(existing, 'photoUrl')) toWrite['photoUrl'] = user.photoURL;
    if (_isMissing(existing, 'createdAt')) {
      toWrite['createdAt'] = FieldValue.serverTimestamp();
    }

    // Profile fields — only set to null if completely absent
    // Never overwrite values set by CompleteProfileScreen
    if (!existing.containsKey('tennisLevel')) toWrite['tennisLevel'] = null;
    if (!existing.containsKey('availability')) toWrite['availability'] = [];
    if (!existing.containsKey('birthDate')) toWrite['birthDate'] = null;
    if (!existing.containsKey('city')) toWrite['city'] = null;
    if (!existing.containsKey('country')) toWrite['country'] = null;

    // Always update locale so Cloud Functions send notifications
    // in the user's device language
    final locale = PlatformDispatcher.instance.locale.languageCode;
    toWrite['locale'] = locale;

    if (toWrite.isNotEmpty) {
      // merge: true so we never wipe fields not in toWrite
      await ref.set(toWrite, SetOptions(merge: true));
      } else {
      }
  }

  /// Returns true if the field is absent OR its value is null/empty string
  bool _isMissing(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key)) return true;
    final value = data[key];
    if (value == null) return true;
    if (value is String && value.isEmpty) return true;
    return false;
  }

  Future<void> setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Delete the cached token first to force a completely fresh one.
    // Without this, getToken() returns the same cached token even after
    // it has been invalidated or deleted from Firestore.
    try {
      await messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM deleteToken error (non-fatal): $e');
    }

    // Now request a fresh token from FCM servers
    final token = await messaging.getToken();

    if (token != null) {
      await saveFcmToken(token);
      debugPrint('✅ Fresh FCM token saved');
    }

    // Listen for future token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await saveFcmToken(newToken);
    });
  }

  Future<void> saveFcmToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set({
      'fcmTokens': {token: true}
    }, SetOptions(merge: true));

    debugPrint('✅ FCM token saved');
  }

  Widget _featureItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // Cache the ensureUserDocument future so FutureBuilder doesn't
  // re-call it on every rebuild — only re-runs when user UID changes
  Future<void>? _ensureFuture;
  String? _ensureUid;

  Future<void> _getEnsureFuture(User user) {
    if (_ensureUid != user.uid) {
      _ensureUid = user.uid;
      _ensureFuture = ensureUserDocument(user);
    }
    return _ensureFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, authSnapshot) {

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          final loc = AppLocalizations.of(context)!;

          return Scaffold(
            body: Stack(
              children: [
                // ── Background gradient ──
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D3B1E), Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                // ── Tennis court lines at bottom ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _CourtLinesPainter(),
                  ),
                ),

                // ── Main content ──
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [

                        const SizedBox(height: 48),

                        // ── Logo + Title ──
                        Column(
                          children: [
                            // Custom tennis ball logo
                            CustomPaint(
                              size: const Size(100, 100),
                              painter: _TennisBallPainter(),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "TennisMatch",
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── Tagline ──
                        Text(
                          loc.loginSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Feature card ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 22),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              _featureItem(
                                icon: Icons.add_circle_outline,
                                text: loc.featureRecord,
                              ),
                              const SizedBox(height: 16),
                              _featureItem(
                                icon: Icons.people_outline,
                                text: loc.featureMatchByLevel,
                              ),
                              const SizedBox(height: 16),
                              _featureItem(
                                icon: Icons.calendar_today_outlined,
                                text: loc.featureAvailability,
                              ),
                              const SizedBox(height: 16),
                              _featureItem(
                                icon: Icons.chat_bubble_outline,
                                text: loc.featureChat,
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // ── Google Sign-In button ──
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: signInWithGoogle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    "https://developers.google.com/identity/images/g-logo.png",
                                    height: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    loc.signInWithGoogle,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          loc.loginDisclaimer,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Use FutureBuilder to wait for ensureUserDocument to finish
        // writing before streaming — prevents the CompleteProfileScreen flash
        return FutureBuilder<void>(
          future: _getEnsureFuture(user),
          builder: (context, ensureSnapshot) {
            if (ensureSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {

                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return Scaffold(
                    body: Center(
                      child: Text(AppLocalizations.of(context)!.userProfileNotFound),
                    ),
                  );
                }

                final rawData = userSnapshot.data!.data();
                if (rawData == null) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final Map<String, dynamic> data = rawData as Map<String, dynamic>;

                bool isEmpty(value) => value == null || value.toString().isEmpty;

                final isProfileIncomplete =
                    isEmpty(data['tennisLevel']) ||
                    data['birthDate'] == null ||
                    isEmpty(data['city']) ||
                    isEmpty(data['country']);

                if (isProfileIncomplete) {
                  return const CompleteProfileScreen();
                }

                return HomeScreen(
                  currentUser: user,
                  userData: data,
                );
              },
            );
          },
        );
      },
    );
  }
}


// ══════════════════════════════════════════════════════════════
// Tennis Ball Logo Painter
// Draws a realistic tennis ball with curved seam lines
// ══════════════════════════════════════════════════════════════
class _TennisBallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Outer glow / shadow ──
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center + const Offset(0, 4), radius, shadowPaint);

    // ── Ball body — tennis yellow-green ──
    final ballPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.9,
        colors: const [Color(0xFFCCE040), Color(0xFFADC417)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, ballPaint);

    // ── Subtle highlight (top-left shine) ──
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, highlightPaint);

    // ── Seam lines — white curved paths ──
    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = size.width * 0.045
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Left seam — S-curve on left side
    final leftSeam = Path();
    leftSeam.moveTo(center.dx - radius * 0.1, center.dy - radius * 0.85);
    leftSeam.cubicTo(
      center.dx - radius * 0.75, center.dy - radius * 0.55,
      center.dx - radius * 0.75, center.dy + radius * 0.55,
      center.dx - radius * 0.1, center.dy + radius * 0.85,
    );

    // Right seam — mirror S-curve on right side
    final rightSeam = Path();
    rightSeam.moveTo(center.dx + radius * 0.1, center.dy - radius * 0.85);
    rightSeam.cubicTo(
      center.dx + radius * 0.75, center.dy - radius * 0.55,
      center.dx + radius * 0.75, center.dy + radius * 0.55,
      center.dx + radius * 0.1, center.dy + radius * 0.85,
    );

    // Clip seams to ball circle
    canvas.save();
    canvas.clipPath(Path()..addOval(
      Rect.fromCircle(center: center, radius: radius - 1),
    ));
    canvas.drawPath(leftSeam, seamPaint);
    canvas.drawPath(rightSeam, seamPaint);
    canvas.restore();

    // ── Thin dark border ──
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 0.5, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// Tennis Court Lines Painter
// Draws subtle court line pattern at the bottom of the screen
// ══════════════════════════════════════════════════════════════
class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Baseline
    canvas.drawLine(
      Offset(0, size.height * 0.85),
      Offset(size.width, size.height * 0.85),
      paint,
    );

    // Service line
    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.55),
      paint,
    );

    // Net line
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.25),
      Offset(size.width, size.height * 0.25),
      netPaint,
    );

    // Center service line (vertical)
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.25),
      Offset(size.width / 2, size.height * 0.85),
      paint,
    );

    // Left singles sideline
    canvas.drawLine(
      Offset(size.width * 0.12, 0),
      Offset(size.width * 0.12, size.height),
      paint,
    );

    // Right singles sideline
    canvas.drawLine(
      Offset(size.width * 0.88, 0),
      Offset(size.width * 0.88, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}