import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _firstName;
  String? _lastName;
  String? _email;
  String? _education;
  String? _workExperience;
  String? _skills;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch user details initially
  }

  Future<void> _fetchUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          // Update with correct field names
          _firstName = userDoc['firstName'];
          _lastName = userDoc['lastName'];
          _email = userDoc['email'];
          _education = userDoc['education'];
          _workExperience = userDoc['workExperience'];
          _skills = userDoc['skills'];
        });
      }
    }
  }

  Future<void> _updateField(String fieldName, String currentValue) async {
    TextEditingController fieldController = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $fieldName'),
          content: TextField(
            controller: fieldController,
            decoration: InputDecoration(labelText: fieldName),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                User? user = _auth.currentUser;

                if (user != null) {
                  // Update using the exact field name in Firestore
                  await _firestore.collection('users').doc(user.uid).update({
                    fieldName: fieldController.text.trim(),
                  });
                  Navigator.of(context).pop();
                  _fetchUserDetails(); // Refresh data after update
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'User Profile',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildEditableField('firstName', 'First Name', _firstName),
              _buildEditableField('lastName', 'Last Name', _lastName),
              _buildEditableField('email', 'Email', _email),
              _buildEditableField('education', 'Education', _education),
              _buildEditableField('workExperience', 'Work Experience', _workExperience),
              _buildEditableField('skills', 'Skills', _skills),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(String firestoreField, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value ?? 'Not provided',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () {
              _updateField(firestoreField, value ?? '');
            },
          ),
        ],
      ),
    );
  }
}
