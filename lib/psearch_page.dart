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
            'uid': doc.id,
            ...doc.data() as Map<String, dynamic>,
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
      try {
        // Fetch pending connections
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
        print('Error fetching pending connections as receiver: $e');
      }

      try {
        // Fetch pending connections where current user is the sender
        QuerySnapshot snapshot = await _firestore
            .collection('pendingConnections')
            .where('from', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        setState(() {
          _pendingConnections
              .addAll(snapshot.docs.map((doc) => doc['to'] as String).toList());
        });
      } catch (e) {
        print('Error fetching pending connections as sender: $e');
      }

      try {
        // Fetch declined connections
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

      try {
        // Fetch accepted connections
        DocumentSnapshot currentUserDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        if (currentUserDoc.exists) {
          var connections = currentUserDoc['connections'] as List<dynamic>?;
          setState(() {
            _acceptedConnections =
                connections != null ? List<String>.from(connections) : [];
          });
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: _filterUsers,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  prefixIconColor: Colors.grey,
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
                          color: Colors.grey[850],
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16),
                          child: ListTile(
                            title: Text(
                              '${user['firstName']} ${user['lastName']}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              user['email'],
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: isPending
                                      ? const Icon(Icons.access_time,
                                          color: Colors.yellow)
                                      : isDeclined
                                          ? const Icon(Icons.block,
                                              color: Colors.grey)
                                          : isConnected
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.green)
                                              : const Icon(
                                                  Icons.add_circle_outlined,
                                                  color: Colors.white),
                                  onPressed: isPending
                                      ? null
                                      : isDeclined
                                          ? null
                                          : isConnected
                                              ? null
                                              : () {
                                                  _connectUser(user['uid']);
                                                },
                                  tooltip: isPending
                                      ? 'Connection Pending'
                                      : isDeclined
                                          ? 'Connection Declined'
                                          : isConnected
                                              ? 'Already Connected'
                                              : 'Send Connection Request',
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileDetailsPage(user: user),
                                ),
                              );
                            },
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
      ),
    );
  }
}

class ProfileDetailsPage extends StatelessWidget {
  final Map<String, dynamic> user;

  ProfileDetailsPage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${user['firstName']} ${user['lastName']}'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user['firstName']} ${user['lastName']}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            _buildProfileField('Education', user['education']),
            _buildProfileField('Work Experience', user['workExperience']),
            _buildProfileField('Skills', user['skills']),
            _buildProfileField('Email', user['email']),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'Not provided',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
