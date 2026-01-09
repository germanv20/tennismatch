import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'player_profile_screen.dart';
import 'incoming_requests_screen.dart';
import 'my_matches_screen.dart';

const tennisLevels = [
  'Beginner',
  'Intermediate',
  'Advanced',
];

const List<String> availableDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthTest(),
    );
  }
}

class AuthTest extends StatefulWidget {
  const AuthTest({super.key});

  @override
  State<AuthTest> createState() => _AuthTestState();
}

class _AuthTestState extends State<AuthTest> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn(scopes: ['email']).signIn();

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

  Future<void> updateTennisLevel(String level) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'tennisLevel': level,
    });
  }

  Future<void> updateAvailability(List<String> days) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'availability': days,
    });
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
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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
          return Scaffold(
            appBar: AppBar(title: const Text('TennisMatch Login')),
            body: Center(
              child: ElevatedButton(
                onPressed: signInWithGoogle,
                child: const Text('Sign in with Google'),
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
              return const Scaffold(
                body: Center(child: Text('User profile not found')),
              );
            }


            final rawData = userSnapshot.data!.data();
            if (rawData == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final Map<String, dynamic> data = rawData as Map<String, dynamic>;


            final String? tennisLevel = data['tennisLevel'];
            final List<dynamic> availabilityRaw = data['availability'] ?? [];
            final List<String> availability =
                availabilityRaw.map((e) => e.toString()).toList();


            return Scaffold(
              appBar: AppBar(title: const Text('TennisMatch Profile')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Welcome ${user.displayName}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(user.email ?? ''),
                    const SizedBox(height: 20),

                    const Text('Your tennis level'),
                    const SizedBox(height: 8),

                    DropdownButton<String>(
                      value: tennisLevel,
                      hint: const Text('Choose level'),
                      items: tennisLevels.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await updateTennisLevel(value);
                      },
                    ),

                    const SizedBox(height: 20),

                    const Text('Your availability'),
                    const SizedBox(height: 8),

                    Column(
                      children: availableDays.map((day) {
                        final isSelected = availability.contains(day);

                        return CheckboxListTile(
                          title: Text(day),
                          value: isSelected,
                          onChanged: (checked) {
                            final updated = List<String>.from(availability);

                            if (checked == true) {
                              updated.add(day);
                            } else {
                              updated.remove(day);
                            }

                            updateAvailability(updated);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      'Available Players',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (tennisLevel == null)
                      const Text(
                        'Select your tennis level to see available players',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('tennisLevel', isEqualTo: tennisLevel)
                            .snapshots(),
                        builder: (context, snapshot) {

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (!snapshot.hasData) {
                          return const Text('No data available');
                        }

                        final docs = snapshot.data!.docs;

                        final matches = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          // Exclude current user
                          if (data['uid'] == user.uid) return false;

                          final List<dynamic> otherAvailability =
                              data['availability'] ?? [];

                          // At least one shared day
                          return otherAvailability.any(
                            (day) => availability.contains(day),
                          );
                        }).toList();

                        if (matches.isEmpty) {
                          return const Text('No players available right now.');
                        }

                        return Column(
                          children: matches.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerProfileScreen(
                                      userData: data,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(data['photoUrl'] ?? ''),
                                  ),
                                  title: Text(data['name'] ?? 'Unknown'),
                                  subtitle: Text(
                                    'Available: ${(data['availability'] as List).join(', ')}',
                                  ),
                                  trailing: const Icon(Icons.sports_tennis),
                                ),
                              ),
                            );

                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.mail),
                      label: const Text('Incoming Match Requests'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IncomingRequestsScreen(),
                          ),
                        );
                      },
                    ),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyMatchesScreen(currentUser: user),
                          ),
                        );
                      },
                      child: const Text('My Matches'),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: signOut,
                      child: const Text('Sign out'),
                    ),

                  ],
                ),
              ),
            );
          },
        );
      },
    );

  }
}
