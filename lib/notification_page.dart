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
        QuerySnapshot snapshot = await _firestore
            .collection('connections')
            .where('to', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'accepted')
            .limit(20) // Load the first 20 connections
            .get();

        setState(() {
          _existingConnections = snapshot.docs.map((doc) {
            return {
              'from': doc['from'],
              'id': doc.id,
            };
          }).toList();
          _loadingExisting = false;
        });
      } catch (e) {
        print('Error fetching existing connections: $e');
        setState(() => _loadingExisting = false);
      }
    }
  }

  Future<void> _acceptConnection(String fromUserId, String docId) async {
    // Remove from pending
    await _firestore.collection('pendingConnections').doc(docId).delete();

    // Add to network
    await _firestore.collection('connections').add({
      'from': fromUserId,
      'to': _currentUserId,
      'status': 'accepted',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _fetchPendingConnections(); // Refresh the list
    _fetchExistingConnections(); // Refresh the existing connections
  }

  Future<void> _declineConnection(String docId) async {
    // Remove from pending
    await _firestore.collection('pendingConnections').doc(docId).delete();
    _fetchPendingConnections(); // Refresh the list
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Text('Error loading user details');
                      }

                      final userData = snapshot.data!;
                      return Card(
                        color: Colors.grey[800],
                        child: ListTile(
                          title: Text(
                            userData['firstName'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            userData['email'] ?? 'No email',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    _acceptConnection(request['from'], request['id']),
                                child: const Text('Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(0, 153, 114, 1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () => _declineConnection(request['id']),
                                child: const Text('Decline'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
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
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _fetchUserDetails(connection['from']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Text('Error loading user details');
                      }

                      final userData = snapshot.data!;
                      return Card(
                        color: Colors.grey[800],
                        child: ListTile(
                          title: Text(
                            userData['firstName'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            userData['email'] ?? 'No email',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    },
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
