import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(text: '********');
  final TextEditingController _majorController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Error: No user is currently logged in');
      setState(() => _isLoading = false);
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>? ?? {};
        print('Retrieved user data: $data');
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _emailController.text = user.email ?? '';
          _majorController.text = data['major'] ?? '';
          _isLoading = false;
        });
      } else {
        print('User document does not exist');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'major': _majorController.text,
          });
          setState(() {
            _isEditing = false;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Profile updated')));
        } catch (e) {
          print('Error updating profile: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!_isEditing)
                Column(
                  children: [
                    Text(
                      '${_firstNameController.text} ${_lastNameController.text}',
                      style: TextStyle(fontSize: 24),
                    ),
                    SizedBox(height: 10),
                    Text(_emailController.text, style: TextStyle(fontSize: 18)),
                    SizedBox(height: 10),
                    Text(_majorController.text, style: TextStyle(fontSize: 18)),
                  ],
                ),
              if (_isEditing)
                Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(labelText: 'First Name'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your first name' : null,
                    ),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(labelText: 'Last Name'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your last name' : null,
                    ),
                    TextFormField(
                      controller: _majorController,
                      decoration: InputDecoration(labelText: 'Major'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter your major' : null,
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      readOnly: true,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      readOnly: true,
                      obscureText: true,
                    ),
                  ],
                ),
              SizedBox(height: 20),
              _isEditing
                  ? ElevatedButton(
                      onPressed: _saveChanges,
                      child: Text('Save Changes'),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                      child: Text('Edit Profile'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
