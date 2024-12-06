import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});
  
  @override
  _CreateAccountState createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); //controller for confirm password
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _majorController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to create an account and store user details
  void _create() async {
    try {
      // Check if passwords match
      if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match!')),
        );
        return;
      }

      // Create user account using Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Get the current user ID
      String userId = userCredential.user!.uid;

      // Store additional user information in Firestore
      await _firestore.collection('users').doc(userId).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'major': _majorController.text.trim(),
        'email': _emailController.text.trim(),
      });

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      // Show a dialog box informing the user that the verification email has been sent
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Verification Email Sent'),
            content: const Text(
                'A verification email has been sent to your email address. '
                'Once you verify your email, click "Finish Creating Account" to complete registration.'),
            actions: <Widget>[
              ElevatedButton(
                onPressed: () async {
                  // Wait for the email verification status to be updated
                  User? user = _auth.currentUser;

                  if (user != null) {
                    // Reload the user data to get the updated emailVerified status
                    await user.reload();
                    user = _auth.currentUser; // Get the updated user after reload

                    if (user != null && user.emailVerified) {
                      // If email is verified log them in and navigate to home
                      Navigator.pushReplacementNamed(context, '/home');
                    } else {
                      // If email is not verified show message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please verify your email before finishing account creation.')),
                      );
                    }
                  }
                },
                child: const Text('Finish Creating Account'),
              ),
            ],
          );
        },
      );

    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              const SizedBox(height: 16), 
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              const SizedBox(height: 16), 
              TextField(
                controller: _majorController,
                decoration: const InputDecoration(labelText: 'Major'),
              ),
              const SizedBox(height: 16), 
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16), // Space between text boxes
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16), 
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _create,
                child: const Text('Create Account'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login'); // Navigate to login page
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
