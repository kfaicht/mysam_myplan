import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'calendar_page.dart';
import 'todo_page.dart';
import 'class_schedule_page.dart';
import 'profile_page.dart';
import 'chatbot_page.dart'; 
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    Calendar(),
    ToDoList(),
    ClassSchedulePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  void _confirmLogOut() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Log Out'),
          content: Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                _logOut();
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _openChatbotPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ChatbotPage()), // Navigate to ChatbotPage
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentDate = DateFormat('MMMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Planner'),
            Text(
              currentDate,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (BuildContext context) {
              return IconButton(
                icon: Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'To-Do List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Class Schedule',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 70, 93, 123),
        onTap: _onItemTapped,
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 70, 93, 123),
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => Profile()));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log Out'),
              onTap: () {
                Navigator.of(context).pop();
                _confirmLogOut();
              },
            ),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email Support'),
              subtitle: Text('Contact us at myplanassistance@gmail.com for assistance.'),
            ),
            ListTile(
              leading: Icon(Icons.web),
              title: Text('Support Website'),
              subtitle: Text(
                'Copy and paste https://sites.google.com/view/myplan-assistance/home into any browser to access our support page.',
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatbotPage, // Navigate to ChatbotPage
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage('assets/images/transparent_planny_1152_splash - Copy.png'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}
