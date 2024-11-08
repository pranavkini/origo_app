import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:origo/util/mybutton.dart';
import 'package:origo/util/mytextfield.dart';

class SignUpPage extends StatelessWidget {
  SignUpPage({super.key});

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController educationController = TextEditingController();
  final TextEditingController workExController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  Future<void> _signUp(BuildContext context) async {
    if (_formKey.currentState?.validate() ?? false) {
      if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")),
        );
        return;
      }

      try {
        // Step 1: Create the user account
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: usernameController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Step 2: Save user info in Firestore
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'firstName': firstNameController.text.trim(),
          'lastName': lastNameController.text.trim(),
          'email': usernameController.text.trim(),
          'education': educationController.text.trim(),
          'workExperience': workExController.text.trim(),
          'skills': skillsController.text.trim(),
          'createdAt': Timestamp.now(),
        });

        Navigator.pop(context); // Navigate back to the previous screen after sign-up
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An unknown error occurred')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),  // Add space at top for safe scrolling
                    const Icon(
                      Icons.account_circle,
                      color: Colors.white,
                      size: 100,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Create an Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "First Name",
                      obscureText: false,
                      controller: firstNameController,
                      icon: const Icon(Icons.person),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Last Name",
                      obscureText: false,
                      controller: lastNameController,
                      icon: const Icon(Icons.person),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Email",
                      obscureText: false,
                      controller: usernameController,
                      icon: const Icon(Icons.email),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Password",
                      obscureText: true,
                      controller: passwordController,
                      icon: const Icon(Icons.lock),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Confirm Password",
                      obscureText: true,
                      controller: confirmPasswordController,
                      icon: const Icon(Icons.lock),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Education",
                      obscureText: false,
                      controller: educationController,
                      icon: const Icon(Icons.school),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Work Experience",
                      obscureText: false,
                      controller: workExController,
                      icon: const Icon(Icons.work),
                    ),
                    const SizedBox(height: 20),
                    MyTextField(
                      hint: "Skills",
                      obscureText: false,
                      controller: skillsController,
                      icon: const Icon(Icons.star),
                    ),
                    const SizedBox(height: 30),
                    MyButton(
                      text: "Sign Up",
                      onTap: () => _signUp(context),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already a member?", style: TextStyle(color: Colors.white)),
                          SizedBox(width: 4),
                          Text('Login Now', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
