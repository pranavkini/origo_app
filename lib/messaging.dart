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
      _currentUserId = currentUser.uid;
      _fetchConnections();
    }
  }

  Future<void> _fetchConnections() async {
    if (_currentUserId != null) {
      try {
        QuerySnapshot fromConnections = await _firestore
            .collection('connections')
            .where('from', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();

        QuerySnapshot toConnections = await _firestore
            .collection('connections')
            .where('to', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();

        List<Map<String, dynamic>> connections = [
          ...fromConnections.docs.map((doc) => {
            'uid': doc['to'],
          }),
          ...toConnections.docs.map((doc) => {
            'uid': doc['from'],
          }),
        ];

        for (var connection in connections) {
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(connection['uid'])
              .get();

          connection.addAll({
            'firstName': userDoc['firstName'],
            'lastName': userDoc['lastName'],
            'email': userDoc['email'],
          });
        }

        setState(() {
          _connectedUsers = connections;
        });
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
                  _openChat(user['uid'],
                      '${user['firstName']} ${user['lastName']}');
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

  ChatScreen({required this.peerUserId, required this.peerUserName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String message = _messageController.text.trim();
    _messageController.clear();

    await _firestore.collection('chats').add({
      'senderId': _currentUserId,
      'receiverId': widget.peerUserId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> _getChatStream() {
    return _firestore
        .collection('chats')
        .where('senderId', whereIn: [_currentUserId, widget.peerUserId])
        .where('receiverId', whereIn: [_currentUserId, widget.peerUserId])
        .orderBy('timestamp', descending: false)
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index];
                    bool isMe = msg['senderId'] == _currentUserId;

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 5.0, horizontal: 10.0),
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Text(
                          msg['message'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
