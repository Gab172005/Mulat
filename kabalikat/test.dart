import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final text = "The capital of France is Paris. The Eiffel Tower is there. Water boils at 100 degrees Celsius.";
  final prompt = '''
You are a helpful study assistant. Create a study deck from the following document.
Return ONLY valid JSON with no markdown formatting. The JSON must have two keys: "flashcards" and "quizzes".
"flashcards" is an array of objects with "front" (question/concept) and "back" (answer/definition).
"quizzes" is an array of objects with "question", "options" (array of 4 strings), and "answerIndex" (0-3).

Document Text:
\$text
''';

  final res = await http.post(
    Uri.parse('http://localhost:11434/api/generate'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({
      'model': 'llama3.2:latest',
      'prompt': prompt,
      'stream': false,
      'format': 'json',
    }),
  );

  print(res.body);
}
