import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GeminiPromptApp());
}

class GeminiPromptApp extends StatelessWidget {
  const GeminiPromptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Prompt Optimizer',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF20232A), // 60% - dark neutral
        primaryColor: const Color(0xFF2D9CDB), // 30% - muted blue accent
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2D9CDB), // accent
          secondary: Color(0xFF27AE60), // 10% - vibrant green highlight
          background: Color(0xFF20232A),
          surface: Color(0xFF232946),
          onPrimary: Color(0xFFF4F4F4),
          onSecondary: Color(0xFF232946),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF232946),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2D9CDB)),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF27AE60), width: 2),
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          labelStyle: TextStyle(color: Color(0xFF2D9CDB)),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFF4F4F4), fontFamily: 'Roboto'),
          titleLarge: TextStyle(color: Color(0xFF2D9CDB), fontWeight: FontWeight.bold, fontFamily: 'ShareTechMono'),
        ),
        elevatedButtonTheme: const ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xFF27AE60)),
            foregroundColor: WidgetStatePropertyAll(Color(0xFFF4F4F4)),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
            elevation: WidgetStatePropertyAll(4),
            shadowColor: WidgetStatePropertyAll(Color(0xFF2D9CDB)),
          ),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF232946),
          shadowColor: Color(0xFF2D9CDB),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D9CDB)),
        useMaterial3: true,
      ),
      home: const PromptOptimizer(),
    );
  }
}

class PromptOptimizer extends StatefulWidget {
  const PromptOptimizer({super.key});

  @override
  State<PromptOptimizer> createState() => _PromptOptimizerState();
}

class _PromptOptimizerState extends State<PromptOptimizer> {
  final TextEditingController _basePromptController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _toneController = TextEditingController();
  final TextEditingController _formatController = TextEditingController();
  final TextEditingController _optimizedPromptController = TextEditingController();

  final FirebaseService _firebaseService = FirebaseService();

  bool _isLoading = false;
  bool _showOptimized = false;
  String _errorMessage = '';
  String? _editingDocId;

  // API key - in production, use secure storage methods
  final String apiKey = 'AIzaSyAEogbvBo0VwGqw3Vr21nzJwS_RMon-gD4'; // Replace with your actual API key

  @override
  void dispose() {
    _basePromptController.dispose();
    _purposeController.dispose();
    _contextController.dispose();
    _toneController.dispose();
    _formatController.dispose();
    _optimizedPromptController.dispose();
    super.dispose();
  }

  Future<void> _savePrompt({bool isUpdate = false}) async {
    final promptData = {
      'basePrompt': _basePromptController.text,
      'purpose': _purposeController.text,
      'context': _contextController.text,
      'tone': _toneController.text,
      'format': _formatController.text,
      'optimizedPrompt': _optimizedPromptController.text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (isUpdate && _editingDocId != null) {
      await _firebaseService.updatePrompt(_editingDocId!, promptData);
    } else {
      await _firebaseService.addPrompt(promptData);
    }
    setState(() {
      _editingDocId = null;
      _clearFields();
      _showOptimized = false;
    });
  }

  void _clearFields() {
    _basePromptController.clear();
    _purposeController.clear();
    _contextController.clear();
    _toneController.clear();
    _formatController.clear();
    _optimizedPromptController.clear();
  }

  void _editPrompt(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    _basePromptController.text = data['basePrompt'] ?? '';
    _purposeController.text = data['purpose'] ?? '';
    _contextController.text = data['context'] ?? '';
    _toneController.text = data['tone'] ?? '';
    _formatController.text = data['format'] ?? '';
    _optimizedPromptController.text = data['optimizedPrompt'] ?? '';
    setState(() {
      _editingDocId = doc.id;
      _showOptimized = true;
    });
  }

  Future<void> _deletePrompt(String docId) async {
    await _firebaseService.deletePrompt(docId);
    setState(() {});
  }

  Widget _buildSavedPromptsList() {
    return StreamBuilder(
      stream: _firebaseService.getPrompts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data as QuerySnapshot).docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No saved prompts'),
          );
        }
        final docs = (snapshot.data as QuerySnapshot).docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['optimizedPrompt'] ?? ''),
              subtitle: Text(data['basePrompt'] ?? ''),
              onTap: () => _editPrompt(doc),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close drawer
                      _editPrompt(doc);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deletePrompt(doc.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _generateOptimizedPrompt() async {
    final String basePrompt = _basePromptController.text.trim();
    if (basePrompt.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a base prompt';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Create a meta-prompt to ask Gemini to optimize the user's prompt
      final String metaPrompt = '''
You are a prompt optimization expert. Create an optimized prompt for Gemini AI based on these inputs:

Base request: ${_basePromptController.text}
Purpose: ${_purposeController.text}
Context: ${_contextController.text}
Tone: ${_toneController.text}
Output format: ${_formatController.text}

Respond with ONLY the optimized prompt, structured effectively with clear instructions.
''';

      // Call Gemini API - Using the specified v1beta API endpoint for gemini-2.0-flash
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': metaPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // The structure of the response should be the same as before
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty &&
            data['candidates'][0]['content']['parts'][0]['text'] != null) {
          final optimizedPrompt = data['candidates'][0]['content']['parts'][0]['text'];
          setState(() {
            _optimizedPromptController.text = optimizedPrompt;
            _showOptimized = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to parse API response.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'API Error: ${response.statusCode} - ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _optimizedPromptController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prompt copied to clipboard')),
    );
  }

  @override
  int _selectedDrawerIndex = 0; // 0: Prompt Generation, 1: Saved Prompts

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF232946),
        elevation: 6,
        title: const Text(
          'Prompt Generator',
          style: TextStyle(
            color: Color(0xFF2D9CDB),
            fontFamily: 'ShareTechMono',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 2,
            shadows: [Shadow(color: Color(0xFF27AE60), blurRadius: 8, offset: Offset(0, 0))],
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2D9CDB)),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF232946),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF2D9CDB)),
                title: const Text('Prompt Generation', style: TextStyle(color: Color(0xFF2D9CDB), fontWeight: FontWeight.bold, fontFamily: 'ShareTechMono')),
                selected: _selectedDrawerIndex == 0,
                selectedTileColor: const Color(0xFF20232A),
                onTap: () {
                  setState(() {
                    _selectedDrawerIndex = 0;
                  });
                  Navigator.of(context).pop();
                },
              ),
              const Divider(color: Color(0xFF2D9CDB)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Saved Prompts', style: TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'ShareTechMono', letterSpacing: 1)),
              ),
              Expanded(
                child: _buildDrawerSavedPromptsSection(),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF20232A), Color(0xFF232946), Color(0xFF20232A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(child: _showOptimized ? _buildResultView() : _buildInputForm()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerSavedPromptsSection() {
    return StreamBuilder(
      stream: _firebaseService.getPrompts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data as QuerySnapshot).docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No saved prompts'),
          );
        }
        final docs = (snapshot.data as QuerySnapshot).docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['basePrompt'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                _editPrompt(doc);
                Navigator.of(context).pop();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _editPrompt(doc);
                      Navigator.of(context).pop();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deletePrompt(doc.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedPromptsPage() {
    return StreamBuilder(
      stream: _firebaseService.getPrompts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || (snapshot.data as QuerySnapshot).docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No saved prompts'),
          );
        }
        final docs = (snapshot.data as QuerySnapshot).docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              child: ListTile(
                title: Text(data['basePrompt'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: const Text('What do you want Gemini to do?'),
                onTap: () {
                  _editPrompt(doc);
                  setState(() {
                    _selectedDrawerIndex = 0;
                  });
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _editPrompt(doc);
                        setState(() {
                          _selectedDrawerIndex = 0;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deletePrompt(doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildInputForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            'What do you want Gemini to do?',
            _basePromptController,
            maxLines: 3,
          ),
          _buildTextField(
            'What is the purpose of this request?',
            _purposeController,
          ),
          _buildTextField(
            'Any specific context or background information?',
            _contextController,
          ),
          _buildTextField(
            'Preferred tone (formal, casual, technical, etc.)',
            _toneController,
          ),
          _buildTextField(
            'Desired output format (paragraph, list, code, etc.)',
            _formatController,
          ),
          const SizedBox(height: 20),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _generateOptimizedPrompt,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate Optimized Prompt'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Optimized Prompt:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(_optimizedPromptController.text),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showOptimized = false;
                  });
                },
                child: const Text('Edit Input'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _copyToClipboard,
                child: const Text('Copy to Clipboard'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Save Prompt'),
          onPressed: _optimizedPromptController.text.isNotEmpty ? () async {
            await _savePrompt();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Prompt saved!')),
            );
          } : null,
        ),
      ],
    );
  }
}