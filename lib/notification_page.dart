import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  List<Map<String, dynamic>> _pendingConnections = [];
  List<Map<String, dynamic>> _existingConnections = [];
  bool _loadingPending = true;
  bool _loadingExisting = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserId();
  }

  Future<void> _fetchCurrentUserId() async {
    User? currentUser = _auth.currentUser;
    _currentUserId = currentUser?.uid;
    await _fetchPendingConnections();
    await _fetchExistingConnections();
  }

  Future<void> _fetchPendingConnections() async {
    setState(() => _loadingPending = true);
    if (_currentUserId != null) {
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('pendingConnections')
            .where('to', isEqualTo: _currentUserId)
            .limit(20) // Load the first 20 connections
            .get();

        setState(() {
          _pendingConnections = snapshot.docs.map((doc) {
            return {
              'from': doc['from'],
              'id': doc.id,
            };
          }).toList();
          _loadingPending = false;
        });
      } catch (e) {
        print('Error fetching pending connections: $e');
        setState(() => _loadingPending = false);
      }
    }
  }

  Future<void> _fetchExistingConnections() async {
    setState(() => _loadingExisting = true);
    if (_currentUserId != null) {
      try {
        // Fetch the user's document
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        if (userDoc.exists) {
          // Get the list of user IDs from the 'connections' field
          List<dynamic> connections = userDoc['connections'] ?? [];

          // Fetch details for each connected user
          List<Map<String, dynamic>> connectionsData = [];
          for (var userId in connections) {
            DocumentSnapshot userSnapshot =
                await _firestore.collection('users').doc(userId).get();
            if (userSnapshot.exists) {
              connectionsData.add({
                'from': userId,
                'userData': userSnapshot.data(),
              });
            }
          }

          setState(() {
            _existingConnections = connectionsData;
            _loadingExisting = false;
          });
        } else {
          setState(() => _loadingExisting = false);
        }
      } catch (e) {
        print('Error fetching existing connections: $e');
        setState(() => _loadingExisting = false);
      }
    }
  }

  Future<void> _acceptConnection(String fromUserId, String docId) async {
    // Remove from pending
    await _firestore.collection('pendingConnections').doc(docId).delete();

    FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
      'connections': FieldValue.arrayUnion([fromUserId]),
    });

    FirebaseFirestore.instance.collection('users').doc(fromUserId).update({
      'connections': FieldValue.arrayUnion([_currentUserId]),
    });

    _fetchPendingConnections(); // Refresh the list
    _fetchExistingConnections(); // Refresh the existing connections
  }

  Future<void> _declineConnection(String docId) async {
    // Remove from pending
    await _firestore.collection('pendingConnections').doc(docId).delete();
    _fetchPendingConnections(); // Refresh the list
  }

  Future<void> _removeConnection(String userIdToRemove) async {
    if (_currentUserId != null) {
      try {
        // Remove the user from the current user's 'connections'
        await _firestore.collection('users').doc(_currentUserId).update({
          'connections': FieldValue.arrayRemove([userIdToRemove]),
        });

        // Remove the current user from the other user's 'connections'
        await _firestore.collection('users').doc(userIdToRemove).update({
          'connections': FieldValue.arrayRemove([_currentUserId]),
        });

        // Refresh the connections list after removal
        _fetchExistingConnections();
      } catch (e) {
        print('Error removing connection: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching user details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Connections"),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Pending Connections",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 10),
              _loadingPending
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingConnections.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingConnections.length,
                          itemBuilder: (context, index) {
                            final request = _pendingConnections[index];
                            return FutureBuilder<Map<String, dynamic>?>(
                              future: _fetchUserDetails(request['from']),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data == null) {
                                  return const Text(
                                      'Error loading user details');
                                }

                                final userData = snapshot.data!;
                                return Card(
                                  color: Colors.grey[800],
                                  child: ListTile(
                                    title: Text(
                                      userData['firstName'] ?? 'Unknown',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      userData['email'] ?? 'No email',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check_circle,
                                              size: 30, color: Colors.green),
                                          onPressed: () => _acceptConnection(
                                              request['from'], request['id']),
                                          tooltip: 'Accept',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle,
                                              size: 30, color: Colors.red),
                                          onPressed: () =>
                                              _declineConnection(request['id']),
                                          tooltip: 'Decline',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            "No pending connections",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
              const SizedBox(height: 20),
              const Text(
                "Existing Connections",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 10),
              _loadingExisting
                  ? const Center(child: CircularProgressIndicator())
                  : _existingConnections.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _existingConnections.length,
                          itemBuilder: (context, index) {
                            final connection = _existingConnections[index];
                            final userData = connection['userData'];
                            return Card(
                              color: Colors.grey[800],
                              child: ListTile(
                                title: Text(
                                  userData?['firstName'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  userData?['email'] ?? 'No email',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                      Icons.person_remove_alt_1_rounded,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _removeConnection(connection['from']),
                                  tooltip: 'Remove connection',
                                ),
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            "No existing connections",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
