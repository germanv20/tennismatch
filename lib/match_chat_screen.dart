import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

final ScrollController _scrollController = ScrollController();

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


class _MatchChatScreenState extends State<MatchChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  Timer? _typingTimer;

  void handleTyping(String value) {
    if (value.isNotEmpty) {
      setTyping(true);

      // Reset timer every keystroke
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        setTyping(false);
      });
    } else {
      // If text cleared, stop typing immediately
      _typingTimer?.cancel();
      setTyping(false);
    }
  }

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .collection('messages')
        .add({
      'text': text,
      'senderUid': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': {
        currentUid: true, // sender has obviously read it
      },
    });

    _messageController.clear();
    _typingTimer?.cancel();
    await setTyping(false);

  }

  String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> markMessagesAsRead() async {
    final query = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .collection('messages')
        .where('senderUid', isNotEqualTo: currentUid)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      final readBy = Map<String, dynamic>.from(data['readBy'] ?? {});

      if (readBy[currentUid] != true) {
        await doc.reference.update({
          'readBy.$currentUid': true,
        });
      }
    }
  }

  Future<void> setTyping(bool isTyping) async {
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .update({
      'typing.$currentUid': isTyping,
    });
  }

  @override
    void dispose() {
      _typingTimer?.cancel();
      // setTyping(false); // ensure typing stops if user leaves
      _messageController.dispose();
      super.dispose();
    }


  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markMessagesAsRead();
    });
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
            Text(
              widget.otherPlayerName,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.matchId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final typing = Map<String, dynamic>.from(data['typing'] ?? {});
              final isOtherTyping = typing[widget.otherPlayerUid] == true;

              if (!isOtherTyping) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 40), // align with avatar
                    Text(
                      '${widget.otherPlayerName} is typing…',
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

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet 👋'),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
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
                    final readBy = Map<String, dynamic>.from(data['readBy'] ?? {});
                    final isReadByOther = readBy.length > 1;
                    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
                    final DateTime? dateTime = timestamp?.toDate();

                    bool showDateSeparator = false;

                    if (dateTime != null) {
                      if (index == messages.length - 1) {
                        // Oldest message → always show date
                        showDateSeparator = true;
                      } else {
                        final prevData =
                            messages[index + 1].data() as Map<String, dynamic>;
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              formatDateLabel(dateTime),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Row(
                            mainAxisAlignment:
                                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar (only for other player)
                              if (!isMe)
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: widget.otherPlayerPhotoUrl.isNotEmpty
                                      ? NetworkImage(widget.otherPlayerPhotoUrl)
                                      : null,
                                  child: widget.otherPlayerPhotoUrl.isEmpty
                                      ? const Icon(Icons.person, size: 16)
                                      : null,
                                ),

                              if (!isMe) const SizedBox(width: 8),

                              Column(
                                crossAxisAlignment:
                                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  // Sender name (only for other player)
                                  if (!isMe)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        widget.otherPlayerName,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),

                                  // Message bubble
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 14,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.blueAccent
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      data['text'] ?? '',
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Timestamp
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

                                      if (isMe) const SizedBox(width: 6),

                                      if (isMe)
                                        Icon(
                                          isReadByOther ? Icons.done_all : Icons.done,
                                          size: 16,
                                          color: isReadByOther ? Colors.blue : Colors.grey,
                                        ),
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
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
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
