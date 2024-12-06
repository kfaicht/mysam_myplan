import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatbotPage extends StatefulWidget {
  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'Hi Bearkat! My name is Planny, your personal planning assistant! How can I help you today?'
    }
  ]; // Initial message from the assistant

  String? _openAIKey;

  @override
  void initState() {
    super.initState();
    _loadOpenAIKey(); // Load the API key on initialization
  }

  Future<void> _loadOpenAIKey() async {
    // Retrieve the OpenAI API key from secure storage
    String? key = await _secureStorage.read(key: 'openai_api_key');

    if (key == null) {
      // Store the API key in secure storage if it doesn't exist
      await _secureStorage.write(
        key: 'openai_api_key',
        value: 'removed due to public github', // Replace with actual OpenAI API key
      );
      key = await _secureStorage.read(key: 'openai_api_key');
    }

    setState(() {
      _openAIKey = key;
    });
  }

  Future<String> chatWithBot(String message) async {
    if (_openAIKey == null) {
      throw Exception('OpenAI API key not available');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAIKey',
      },
      body: json.encode({
        'model': 'gpt-4',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a planner assistant for Sam Houston State University students. You should help them in everything regarding study, academics, and life in general. You should have conversations with them and always ask if they need any help. If they ask how to set a task, tell them to select the task tab at the bottom of the screen and click the floating "+" button. The same is for an event but they go to the calendar tab at the bottom of the screen. Same for adding a class but they go to class. They can edit their profile and also can visit a support page in the settings menu.'
          },
          {'role': 'user', 'content': message}
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to fetch response from OpenAI');
    }
  }

  Future<void> _sendMessage() async {
    String message = _controller.text;
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _controller.clear(); // Clear the input field
    });

    // Get response from OpenAI
    try {
      String response = await chatWithBot(message);
      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Sorry, something went wrong. Please try again later.'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planny the Planning Assistant'),
        backgroundColor: const Color.fromARGB(255, 70, 93, 123), // Custom color
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF5F5F5), // Light gray background
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundImage: AssetImage('assets/images/planny.png'), // Path to chatbot image
                            ),
                          ),
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: isUser ? Color.fromARGB(255, 199, 122, 40) : Colors.grey[300],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(15),
                                topRight: const Radius.circular(15),
                                bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
                                bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                              ),
                            ),
                            child: Text(
                              message['content']!,
                              style: TextStyle(color: isUser ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: const Color.fromARGB(255, 70, 93, 123),
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
