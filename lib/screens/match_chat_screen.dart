import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'dart:async';

class MatchChatScreen extends StatefulWidget {
  final String matchId;
  final String otherPlayerUid;
  final String otherPlayerName;
  final String otherPlayerPhotoUrl;

  const MatchChatScreen({
    super.key,
    required this.matchId,
    required this.otherPlayerUid,
    required this.otherPlayerName,
    required this.otherPlayerPhotoUrl,
  });

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late final ScrollController _scrollController = ScrollController();

  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setActiveChat(true);
    _clearNotificationsForThisChat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markMessagesAsRead();
    });
  }

  /// Clear any pending notifications for this chat using FCM delivery channel.
  /// FCM notifications with tag "chat_{matchId}" are replaced/dismissed
  /// by sending a silent message with the same tag — this is handled
  /// natively by Android when the same tag is reused.
  /// The simplest approach without flutter_local_notifications is to
  /// use the Android notification manager via platform channel, but
  /// since we control the tag on the server, opening the chat is enough
  /// signal — the next notification will replace the old ones.
  ///
  /// For now: mark all as read in Firestore so the badge clears,
  /// and set activeChatUsers so the server skips future notifications.
  Future<void> _clearNotificationsForThisChat() async {
    // activeChatUsers is already set by setActiveChat(true) above.
    // This combined with markMessagesAsRead() gives the full clearing effect:
    // - New messages won't generate notifications (activeChatUsers guard)
    // - Unread badge clears (markMessagesAsRead)
    // - Existing notifications on the shade: Android replaces them on next
    //   send due to the tag, or user dismisses manually.
    await markMessagesAsRead();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-mark as active when user returns to app with chat open
    if (state == AppLifecycleState.resumed) {
      setActiveChat(true);
      markMessagesAsRead();
    } else if (state == AppLifecycleState.paused) {
      setActiveChat(false);
    }
  }

  void handleTyping(String value) {
    if (value.isNotEmpty) {
      setTyping(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        setTyping(false);
      });
    } else {
      _typingTimer?.cancel();
      setTyping(false);
    }
  }

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final matchRef = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId);

    try {
      await matchRef.collection('messages').add({
        'text': text,
        'senderUid': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': {currentUid: true},
      });

      await matchRef.update({
        'lastMessage': text.length > 50 ? text.substring(0, 50) : text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderUid': currentUid,
      });

      _typingTimer?.cancel();
      await setTyping(false);
    } catch (e) {
      debugPrint('❌ sendMessage error: $e');
    }
  }

  String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String formatDateLabel(DateTime date, AppLocalizations loc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return loc.today;
    if (messageDate == yesterday) return loc.yesterday;
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> markMessagesAsRead() async {
    final query = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .collection('messages')
        .where('senderUid', isNotEqualTo: currentUid)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    bool hasUpdates = false;

    for (final doc in query.docs) {
      final readBy = Map<String, dynamic>.from(doc.data()['readBy'] ?? {});
      if (readBy[currentUid] != true) {
        batch.update(doc.reference, {'readBy.$currentUid': true});
        hasUpdates = true;
      }
    }

    if (hasUpdates) await batch.commit();
  }

  Future<void> setTyping(bool isTyping) async {
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .update({'typing.$currentUid': isTyping});
  }

  Future<void> setActiveChat(bool isActive) async {
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .update({'activeChatUsers.$currentUid': isActive});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    setActiveChat(false);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherPlayerPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.otherPlayerPhotoUrl)
                  : null,
              child: widget.otherPlayerPhotoUrl.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(widget.otherPlayerName,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Typing indicator
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.matchId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final data =
                  snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final typing =
                  Map<String, dynamic>.from(data['typing'] ?? {});
              final isOtherTyping =
                  typing[widget.otherPlayerUid] == true;
              if (!isOtherTyping) return const SizedBox();
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    Text(
                      loc.isTyping(widget.otherPlayerName),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .doc(widget.matchId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    markMessagesAsRead();
                  });
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 50, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(loc.noMessagesYet),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderUid'] == currentUid;
                    final readBy = Map<String, dynamic>.from(
                        data['readBy'] ?? {});
                    final isReadByOther =
                        readBy[widget.otherPlayerUid] == true;
                    final Timestamp? timestamp =
                        data['createdAt'] as Timestamp?;
                    final DateTime? dateTime = timestamp?.toDate();

                    bool showDateSeparator = false;
                    if (dateTime != null) {
                      if (index == messages.length - 1) {
                        showDateSeparator = true;
                      } else {
                        final prevData = messages[index + 1].data()
                            as Map<String, dynamic>;
                        final prevTimestamp =
                            prevData['createdAt'] as Timestamp?;
                        final prevDateTime = prevTimestamp?.toDate();
                        if (prevDateTime != null &&
                            !isSameDay(dateTime, prevDateTime)) {
                          showDateSeparator = true;
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (showDateSeparator && dateTime != null)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              formatDateLabel(dateTime, loc),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      widget.otherPlayerPhotoUrl.isNotEmpty
                                          ? NetworkImage(
                                              widget.otherPlayerPhotoUrl)
                                          : null,
                                  child:
                                      widget.otherPlayerPhotoUrl.isEmpty
                                          ? const Icon(Icons.person,
                                              size: 16)
                                          : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 2),
                                      child: Text(
                                        widget.otherPlayerName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 14),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.blueAccent
                                          : Colors.grey.shade300,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (dateTime != null)
                                        Text(
                                          formatTime(dateTime),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          isReadByOther
                                              ? Icons.done_all
                                              : Icons.done,
                                          size: 16,
                                          color: isReadByOther
                                              ? Colors.blue
                                              : Colors.grey,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input field
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onChanged: handleTyping,
                    onSubmitted: (_) async {
                      await setTyping(false);
                      sendMessage();
                    },
                    decoration: InputDecoration(hintText: loc.typeMessage),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}