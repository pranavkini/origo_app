import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:origo/jobs_page.dart'; // Import your JobsPage
import 'package:origo/messaging.dart';
import 'package:origo/notification_page.dart';
import 'package:origo/profilepage.dart';
import 'package:origo/psearch_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Origo',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 2; // Default to ProfilePage (index 2)
  String? _firstName; // Store the first name of the user
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? ''; // Get the user ID dynamically

  // Define the pages for each tab in the bottom navigation bar
  List<Widget> _pages = []; // Initialize as empty

  @override
  void initState() {
    super.initState();
    _getUserName();
  }

  Future<void> _getUserName() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      setState(() {
        _firstName = userDoc['firstName']; // Get the first name
        _initializePages(); // Initialize pages after getting the user name
      });
    } else {
      setState(() {
        _firstName = 'Guest'; // Default name if user not found
        _initializePages(); // Initialize pages even if user not found
      });
    }
  }

  void _initializePages() {
    // Ensure pages are initialized only once after retrieving the user's first name
    _pages = [
      JobsPage(), // Replace HomeContent with JobsPage
      SearchPage(),
      const ProfilePage(), // Pass firstName to ProfilePage
      NotificationsPage(),
      Messaging(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(top: 10),
          child: Image.asset(
            'lib/images/logo.png',
            height: 100,
            width: 100,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 50,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _pages.isNotEmpty ? _pages[_selectedIndex] : Center(child: CircularProgressIndicator()), // Show loading indicator while pages are being initialized
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          elevation: 10,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color.fromRGBO(0, 153, 114, 1),
          unselectedItemColor: Colors.grey[400],
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'), // Change label to 'Jobs' and update the icon
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Chat'),
          ],
        ),
      ),
    );
  }
}
