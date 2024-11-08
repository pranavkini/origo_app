import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Messaging extends StatefulWidget {
  @override
  _MessagingState createState() => _MessagingState();
}

class _MessagingState extends State<Messaging> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  List<Map<String, dynamic>> _connectedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser.uid;
      });
      _fetchConnections();
    }
  }

  Future<void> _fetchConnections() async {
    if (_currentUserId != null) {
      try {
        // Get current user's document
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUserId)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          // Get the connections array
          List<String> connections = List<String>.from(
              (userDoc.data() as Map<String, dynamic>)['connections'] ?? []);

          List<Map<String, dynamic>> users = [];

          // Fetch details for each connected user
          for (String userId in connections) {
            DocumentSnapshot connectedUserDoc =
            await _firestore.collection('users').doc(userId).get();

            if (connectedUserDoc.exists && connectedUserDoc.data() != null) {
              Map<String, dynamic> userData =
              connectedUserDoc.data() as Map<String, dynamic>;
              users.add({
                'uid': userId,
                'firstName': userData['firstName'] ?? '',
                'lastName': userData['lastName'] ?? '',
                'email': userData['email'] ?? '',
              });
            }
          }

          setState(() {
            _connectedUsers = users;
          });
        }
      } catch (e) {
        print('Error fetching connections: $e');
      }
    }
  }

  void _openChat(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          peerUserId: userId,
          peerUserName: userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Messaging'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _connectedUsers.isNotEmpty
            ? ListView.builder(
          itemCount: _connectedUsers.length,
          itemBuilder: (context, index) {
            final user = _connectedUsers[index];
            return Card(
              color: Colors.grey[800],
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                title: Text(
                  '${user['firstName']} ${user['lastName']}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  user['email'],
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  _openChat(
                      user['uid'], '${user['firstName']} ${user['lastName']}');
                },
              ),
            );
          },
        )
            : const Center(
          child: Text(
            "No connections found",
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String peerUserId;
  final String peerUserName;

  const ChatScreen({
    Key? key,
    required this.peerUserId,
    required this.peerUserName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;
  late String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _chatRoomId = _getChatRoomId(_currentUserId, widget.peerUserId);
  }

  String _getChatRoomId(String user1, String user2) {
    return user1.compareTo(user2) > 0 ? '$user1-$user2' : '$user2-$user1';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String message = _messageController.text.trim();
    _messageController.clear();

    try {
      await _firestore.collection('chatRooms').doc(_chatRoomId).set({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [_currentUserId, widget.peerUserId],
      }, SetOptions(merge: true));

      await _firestore
          .collection('chatRooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': _currentUserId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Stream<QuerySnapshot> _getChatStream() {
    return _firestore
        .collection('chatRooms')
        .doc(_chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerUserName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getChatStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index].data() as Map<String, dynamic>;
                    bool isMe = messageData['senderId'] == _currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 8.0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 14.0,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[700] : Colors.grey[800],
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              messageData['message'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                              ),
                            ),
                            if (messageData['timestamp'] != null)
                              Text(
                                _formatTimestamp(messageData['timestamp'] as Timestamp),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12.0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(30.0),
            ),
            margin: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}