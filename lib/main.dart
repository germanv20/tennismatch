import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'screens/match_chat_screen.dart';
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

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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

      theme: ThemeData(
        primarySwatch: Colors.green,

        scaffoldBackgroundColor: const Color(0xFFF5F5F5),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32), // deep tennis green
          foregroundColor: Colors.white,
          elevation: 2,
        ),

        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      home: const AuthTest(), // keep yours
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

  final opponentData =
      opponentSnap.data() as Map<String, dynamic>;

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
    });

    // When app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final matchId = message.data['matchId'];
      if (matchId != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          navigateToChat(matchId);
        });
      }
    });

    // When app opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final matchId = message.data['matchId'];
        if (matchId != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            navigateToChat(matchId);
          });
        }
      }
    });

  }


  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // 🔥 Force account picker
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser =
          await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential =
        await _auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        await ensureUserDocument(user);
      }

    } catch (e) {
      debugPrint('❌ Google sign-in failed: $e');
      debugPrint('🔥 Firebase UID: ${_auth.currentUser?.uid}');
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

  Future<void> createUserProfile(User user) async {
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      await docRef.set({
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'tennisLevel': null,
        'availability': [],
      });
    }
  }

  

  Future<void> ensureUserDocument(User user) async {
    final ref =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'name': user.displayName ?? 'Unknown',
        'email': user.email,
        'photoUrl': user.photoURL,
        'tennisLevel': null,
        'availability': [],
        'birthdate': null,
        'city': null,
        'country': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setupFCM() async {
    debugPrint('🔥 setupFCM started');

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();

    if (token != null) {
      debugPrint('📱 FCM Token: $token');
      await saveFcmToken(token);
    }

    // Listen for token refresh (VERY important)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed: $newToken');
      await saveFcmToken(newToken);
    });
  }



  Future<void> saveFcmToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set({
      'fcmTokens': {
        token: true,
      }
    }, SetOptions(merge: true));

    debugPrint('✅ FCM token saved to Firestore');
  }

  Widget _featureItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
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
            body: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [

                      const SizedBox(height: 40),

                      // 🎾 LOGO + TITLE
                      Column(
                        children: const [
                          Icon(Icons.sports_tennis, size: 90, color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            "TennisMatch",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 🧠 TAGLINE
                      Text(
                        loc.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 🧊 FEATURE CARD (GLASS STYLE)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            _featureItem(
                              icon: Icons.sports_tennis,
                              text: loc.featureMatchByLevel,
                            ),
                            const SizedBox(height: 16),
                            _featureItem(
                              icon: Icons.calendar_today,
                              text: loc.featureAvailability,
                            ),
                            const SizedBox(height: 16),
                            _featureItem(
                              icon: Icons.chat_bubble,
                              text: loc.featureChat,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // 🔘 GOOGLE BUTTON (PREMIUM)
                      SizedBox(
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
                            elevation: 3,
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

                      const SizedBox(height: 12),

                      // 🔒 TRUST TEXT
                      Text(
                        loc.loginDisclaimer,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
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
                body: Center(child: Text(AppLocalizations.of(context)!.userProfileNotFound)),
              );
            }

            final rawData = userSnapshot.data!.data();

            if (rawData == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final Map<String, dynamic> data =
                rawData as Map<String, dynamic>;

            // ✅ THIS is the ONLY place HomeScreen should be called
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
  }
}
