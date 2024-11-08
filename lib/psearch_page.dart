import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _searchQuery = '';
  String? _currentUserId;
  List<String> _pendingConnections = [];
  List<String> _declinedConnections = [];
  List<String> _acceptedConnections = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    User? currentUser = _auth.currentUser;
    _currentUserId = currentUser?.uid;
    await _fetchUsers();
    await _fetchConnections();
  }

  Future<void> _fetchUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      List<Map<String, dynamic>> users = [];

      for (var doc in snapshot.docs) {
        if (doc.id != _currentUserId) {
          users.add({
            'firstName': doc['firstName'],
            'lastName': doc['lastName'],
            'email': doc['email'],
            'uid': doc.id,
          });
        }
      }

      setState(() {
        _users = users;
        _filteredUsers = users;
      });
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  Future<void> _fetchConnections() async {
    if (_currentUserId != null) {
      // Fetch pending connections sent to the current user
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('pendingConnections')
            .where('to', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        setState(() {
          _pendingConnections =
              snapshot.docs.map((doc) => doc['from'] as String).toList();
        });
      } catch (e) {
        print('Error fetching pending connections: $e');
      }

      // Fetch declined connections sent to the current user
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('pendingConnections')
            .where('to', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'declined')
            .get();

        setState(() {
          _declinedConnections =
              snapshot.docs.map((doc) => doc['from'] as String).toList();
        });
      } catch (e) {
        print('Error fetching declined connections: $e');
      }

      // Fetch accepted connections where the current user is either the sender or receiver
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('connections')
            .where('to', isEqualTo: _currentUserId)
            .get();

        setState(() {
          _acceptedConnections =
              snapshot.docs.map((doc) => doc['from'] as String).toList();
        });
      } catch (e) {
        print('Error fetching accepted connections: $e');
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          String fullName = '${user['firstName']} ${user['lastName']}';
          return fullName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _connectUser(String userId) async {
    if (_pendingConnections.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection request already sent!')),
      );
      return;
    }

    if (_declinedConnections.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot send a connection request again!')),
      );
      return;
    }

    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      try {
        // Add the connection request to the pendingConnections collection for both users
        await _firestore.collection('pendingConnections').add({
          'from': currentUser.uid,
          'to': userId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {
          _pendingConnections.add(userId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection request sent!')),
        );
      } catch (e) {
        print('Error sending connection request: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You need to be logged in to connect.')),
      );
    }
  }

  Future<void> _updateConnectionStatus(String userId, String status) async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      try {
        // Update the connection status in the pendingConnections collection
        QuerySnapshot snapshot = await _firestore
            .collection('pendingConnections')
            .where('from', isEqualTo: userId)
            .where('to', isEqualTo: currentUser.uid)
            .get();

        for (var doc in snapshot.docs) {
          await doc.reference.update({
            'status': status,
          });
        }

        // Also update the reverse connection status
        QuerySnapshot reverseSnapshot = await _firestore
            .collection('pendingConnections')
            .where('from', isEqualTo: currentUser.uid)
            .where('to', isEqualTo: userId)
            .get();

        for (var doc in reverseSnapshot.docs) {
          await doc.reference.update({
            'status': status,
          });
        }

        // Refresh the connection lists
        _fetchConnections();
      } catch (e) {
        print('Error updating connection status: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredUsers.isNotEmpty
                ? ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      bool isPending =
                          _pendingConnections.contains(user['uid']);
                      bool isDeclined =
                          _declinedConnections.contains(user['uid']);
                      bool isConnected =
                          _acceptedConnections.contains(user['uid']);

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
                          trailing: ElevatedButton(
                            onPressed: isPending
                                ? null
                                : isDeclined
                                    ? null
                                    : isConnected
                                        ? () {
                                            // Show Snackbar when already connected
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'You are already connected!')),
                                            );
                                          }
                                        : () {
                                            _connectUser(user['uid']);
                                          },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPending
                                  ? Colors.yellow
                                  : (isDeclined
                                      ? Colors.grey
                                      : (isConnected
                                          ? Colors.green
                                          : const Color.fromRGBO(
                                              0, 153, 114, 1))),
                            ),
                            child: Text(
                              isPending
                                  ? 'Awaiting'
                                  : isDeclined
                                      ? 'Cooldown'
                                      : isConnected
                                          ? 'Connected'
                                          : 'Connect',
                              style: TextStyle(
                                color: isPending
                                    ? Colors.black
                                    : (isDeclined ? Colors.grey : Colors.white),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
