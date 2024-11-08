import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const primaryGreen = Color(0xFF2E7D32);
  static const darkBackground = Color(0xFF000000);
  static const textLight = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFBDBDBD);
  static const errorRed = Color(0xFFEF5350);
  static final borderGray = Color(0xFF2E7D32).withOpacity(0.2);
  static final hintGray = Color(0xFFFFFFFF).withOpacity(0.38);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  String? _firstName;
  String? _lastName;
  String? _email;
  String? _education;
  String? _workExperience;
  String? _skills;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _fetchUserDetails();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
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
          backgroundColor: AppColors.darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: AppColors.borderGray, width: 1),
          ),
          title: Text(
            'Edit $fieldName',
            style: const TextStyle(color: AppColors.textLight),
          ),
          content: TextField(
            controller: fieldController,
            style: const TextStyle(color: AppColors.textLight),
            decoration: InputDecoration(
              labelText: fieldName,
              labelStyle: TextStyle(color: AppColors.hintGray),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.borderGray),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryGreen),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.hintGray),
              ),
            ),
            TextButton(
              onPressed: () async {
                User? user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('users').doc(user.uid).update({
                    fieldName: fieldController.text.trim(),
                  });
                  Navigator.of(context).pop();
                  _fetchUserDetails();
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.account_circle,
                              size: 80,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              (_firstName ?? 'First Name') + ' ' + (_lastName ?? 'Last Name'),
                              style: const TextStyle(
                                fontSize: 32,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      ..._buildProfileSections(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildProfileSections() {
    return [
      _buildEditableField('firstName', 'First Name', _firstName),
      _buildEditableField('lastName', 'Last Name', _lastName),
      _buildEditableField('email', 'Email', _email),
      _buildEditableField('education', 'Education', _education),
      _buildEditableField('workExperience', 'Work Experience', _workExperience),
      _buildEditableField('skills', 'Skills', _skills),
    ];
  }

  Widget _buildEditableField(String firestoreField, String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        color: AppColors.darkBackground,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.hintGray,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value ?? 'Not provided',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.primaryGreen,
            ),
            onPressed: () => _updateField(firestoreField, value ?? ''),
          ),
        ],
      ),
    );
  }
}