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
        // Fetch accepted connections where the current user is involved
        QuerySnapshot snapshot = await _firestore
            .collection('connections')
            .where('from', isEqualTo: _currentUserId)
            .get();

        List<Map<String, dynamic>> connections = snapshot.docs.map((doc) {
          return {
            'uid': doc['to'],
            'firstName': doc['toFirstName'],
            'lastName': doc['toLastName'],
            'email': doc['toEmail']
          };
        }).toList();

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
                  _openChat(user['uid'], '${user['firstName']} ${user['lastName']}');
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

class ChatScreen extends StatelessWidget {
  final String peerUserId;
  final String peerUserName;

  ChatScreen({required this.peerUserId, required this.peerUserName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(peerUserName),
      ),
      body: Center(
        child: Text("Chat with $peerUserName"),
      ),
    );
  }
}
