import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:origo/authpage.dart';
import 'package:origo/sign_up.dart';
import 'package:origo/util/mybutton.dart';
import 'package:origo/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Job Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),  // Forest Green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: AuthPage(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _errorMessage = '';

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = e.message ?? 'An unknown error occurred';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Larger Logo without animation

                    // Increased size
                    Image.asset(
                      'lib/images/logo.png',
                      height: 300,
                      width: 300,
                    ),

                    SizedBox(height: 10),  // Increased spacing
                    // Email TextField
                    _buildTextField(
                      controller: _emailController,
                      icon: Icons.email_outlined,  // More subtle icon
                      hint: 'Email',
                      isPassword: false,
                    ),
                    SizedBox(height: 20),
                    // Password TextField
                    _buildTextField(
                      controller: _passwordController,
                      icon: Icons.lock_outline,  // More subtle icon
                      hint: 'Password',
                      isPassword: true,
                    ),
                    SizedBox(height: 10),
                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red[200],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    SizedBox(height: 30),
                    // Login Button
                    _buildLoginButton(),
                    SizedBox(height: 30),
                    // Register Link
                    _buildRegisterLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isPassword,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),  // Very subtle background
        borderRadius: BorderRadius.circular(12),  // Slightly less rounded
        border: Border.all(
          color: Color(0xFF2E7D32).withOpacity(0.2),  // Subtle forest green border
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: Color(0xFF2E7D32).withOpacity(0.7),  // Subtle forest green icon
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white38,  // More subtle hint text
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your ${hint.toLowerCase()}';
          }
          if (hint == 'Email' && !value.contains('@')) {
            return 'Please enter a valid email address';
          }
          if (hint == 'Password' && value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2E7D32),  // Forest green
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),  // Slightly less rounded
          ),
          elevation: 0,  // No shadow for a cleaner look
        ),
        child: Text(
          'Sign In',  // More professional text
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,  // Slightly less bold
            letterSpacing: 0.5,  // Subtle letter spacing
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?",  // More professional text
          style: TextStyle(
            color: Colors.white54,
            fontSize: 15,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SignUpPage()),
            );
          },
          child: Text(
            'Create Account',  // More professional text
            style: TextStyle(
              color: Color(0xFF2E7D32),  // Forest green
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}