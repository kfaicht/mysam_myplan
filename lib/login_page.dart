import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for email and password input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Global key for form validation
  final _formKey = GlobalKey<FormState>();

  /// User login
  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Attempt Firebase login
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Navigate to the home page after login
        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        // Display error snack bar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  /// Handle password reset via Firebase
  void _resetPassword() async {
    if (_emailController.text.isEmpty) {
      // Prompt user to enter their email if the field is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    try {
      // Send password reset email
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent! Check your inbox')),
      );
    } catch (e) {
      // Display error as a snack bar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MySam MyPlan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Attach the global key to the form for validation
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // App title
              const SizedBox(height: 20),
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 199, 122, 40), // Custom accent color
                ),
              ),

              // Email input field
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Color.fromARGB(255, 128, 128, 128)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),

              // Password input field
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Color.fromARGB(255, 130, 130, 130)),
                ),
                obscureText: true, // Hide password input
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),

              // Login button
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 199, 122, 40), // Button color
                  foregroundColor: Colors.white, // Text color
                ),
                child: const Text('Login'),
              ),

              // Navigation to Create Account page
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/create'); // Navigate to Create Account
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              ),

              // Forgot Password option
              const SizedBox(height: 10),
              TextButton(
                onPressed: _resetPassword, // Trigger password reset
                child: const Text('Forgot Password?'),
              ),

              // Decorative image
              SizedBox(
                width: 300,
                height: 300,
                child: Image.asset(
                  'assets/images/planny.png', // Path to the Planny logo
                  fit: BoxFit.contain, // Maintain aspect ratio
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
