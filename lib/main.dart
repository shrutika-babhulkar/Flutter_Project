import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(DictionaryApp());
}

class DictionaryApp extends StatefulWidget {
  @override
  State<DictionaryApp> createState() => _DictionaryAppState();
}

class _DictionaryAppState extends State<DictionaryApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Dictionary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.indigo,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo,
        ),
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DictionaryScreen(
        isDarkMode: isDarkMode,
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class DictionaryScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  DictionaryScreen({required this.isDarkMode, required this.toggleTheme});

  @override
  _DictionaryScreenState createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _wordData;
  String? _translation;
  bool _isLoading = false;
  String? _error;
  String _selectedLanguage = 'mr'; // Default Marathi

  final Map<String, String> _languages = {
    'English': 'en',
    'Marathi': 'mr',
    'Hindi': 'hi',
    'Spanish': 'es',
    'French': 'fr',
  };

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _fetchData(String word) async {
    setState(() {
      _isLoading = true;
      _wordData = null;
      _translation = null;
      _error = null;
    });

    try {
      final englishUrl =
      Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word');
      final englishResponse = await http.get(englishUrl);

      if (englishResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(englishResponse.body);
        _wordData = data[0];
      } else {
        _error = "No definition found for '$word'.";
      }

      final translateUrl = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$_selectedLanguage&dt=t&q=${Uri.encodeComponent(word)}');
      final translateResponse = await http.get(translateUrl);

      if (translateResponse.statusCode == 200) {
        final List<dynamic> translation = json.decode(translateResponse.body);
        _translation = translation[0][0][0];
      } else {
        _translation = "Unavailable";
      }
    } catch (e) {
      _error = "Error fetching data. Please check your connection.";
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
          if (!_speech.isListening && result.finalResult) {
            _fetchData(result.recognizedWords);
          }
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Widget _buildResult() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    if (_wordData == null) {
      return Center(
        child: Text(
          "Search a word to get started!",
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
      );
    }

    final phonetic = _wordData!['phonetic'] ?? '';
    final meanings = _wordData!['meanings'] ?? [];

    return Expanded(
      child: ListView(
        children: [
          Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Center(
                    child: Text(
                      _wordData!['word'] ?? '',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  // if (phonetic.isNotEmpty)
                  //   Center(
                  //     child: Text(
                  //       phonetic,
                  //       style: TextStyle(
                  //           fontSize: 16, fontStyle: FontStyle.italic),
                  //     ),
                  //   ),
                  SizedBox(height: 10),
                  if (_translation != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Translation: $_translation",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  SizedBox(height: 20),
                  ...meanings.map((meaning) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Part of Speech: ${meaning['partOfSpeech']}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ...List.generate(
                              (meaning['definitions'] as List).length, (index) {
                            final def = meaning['definitions'][index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("- ${def['definition'] ?? ''}",
                                      style: TextStyle(fontSize: 16)),
                                  if (def['example'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "Example: ${def['example']}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          Divider(),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dictionary App"),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
            tooltip: "Toggle Theme",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ExpansionTile(
              title: Text(
                "About This App",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "This is a multilingual dictionary app built with Flutter. "
                        "It allows users to search English words and view their meanings, "
                        "phonetics, and examples. It also supports translations into "
                        "languages such as Marathi, Hindi, French, and more. Voice search is included.",
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
            SizedBox(height: 10),
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search for a word...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _wordData = null;
                            _translation = null;
                            _error = null;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                        onPressed:
                        _isListening ? _stopListening : _startListening,
                        tooltip: 'Voice Search',
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _fetchData(value.trim());
                  }
                },
              ),
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: _selectedLanguage,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLanguage = newValue!;
                    });
                  },
                  items: _languages.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.value,
                      child: Text(entry.key),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 15),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
