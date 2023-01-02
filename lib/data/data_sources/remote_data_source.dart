import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:voxalate/data/models/open_ai_completion_model.dart';
import 'package:voxalate/data/models/prediction_model.dart';

abstract class RemoteDataSource {
  Future<void> uploadFile(String path);
  Stream<PredictionModel> getPredictionStream(String predictionId);
  Future<PredictionModel> startPrediction();
  Future<OpenAiCompletionModel> getSummary(String englishText);
}

class RemoteDataSourceImplementation implements RemoteDataSource {
  final http.Client client;
  final storageReference = FirebaseStorage.instance.ref();

  RemoteDataSourceImplementation({required this.client});

  @override
  Future<void> uploadFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final snapshot = await storageReference.child('test.wav').putData(bytes);
    log('Uploaded file to ${snapshot.ref.fullPath}');
    log('Download URL: ${await snapshot.ref.getDownloadURL()}');
  }

  @override
  Future<PredictionModel> startPrediction() async {
    final String modelVersion = await getModelVersion();
    final String downloadUrl = await getDownloadUrl();
    final String body = jsonEncode({
      'version': modelVersion,
      'input': {
        'audio': downloadUrl,
        'translate': true,
        'model': 'large',
      },
    });
    final response = await http.post(
      Uri.parse('https://api.replicate.com/v1/predictions'),
      headers: {
        'Authorization': 'Token 066709f72f2494c995b2585a0776d2b7c49287ae',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    log('Response: ${response.body}');
    return PredictionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Stream<PredictionModel> getPredictionStream(String predictionId) async* {
    while (true) {
      final response = await http.get(
        Uri.parse(
          'https://api.replicate.com/v1/predictions/$predictionId',
        ),
        headers: {
          'Authorization': 'Token 066709f72f2494c995b2585a0776d2b7c49287ae',
        },
      );
      final predictionOutput = PredictionModel.fromJson(
        // utf decode to fix issue with special characters
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );

      if (predictionOutput.status == 'succeeded') {
        yield predictionOutput;
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Future<OpenAiCompletionModel> getSummary(String englishText) async {
    final String body = jsonEncode({
      'model': 'text-davinci-003',
      // 'model': 'text-curie-001',
      'max_tokens': 1500,
      'n': 1,
      'prompt': '$englishText\nSummarise this:\n\n',
    });
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/completions'),
      headers: {
        'Authorization':
            'Bearer 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',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    log('Response: ${response.body}');
    return OpenAiCompletionModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> getDownloadUrl() async {
    return storageReference.child('test.wav').getDownloadURL();
  }

  Future<String> getModelVersion() async {
    final response = await http.get(
      Uri.parse('https://api.replicate.com/v1/models/openai/whisper/versions'),
      headers: {
        'Authorization': 'Token 066709f72f2494c995b2585a0776d2b7c49287ae',
        'Content-Type': 'application/json',
      },
    );
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>;
    final latestVersion = results.first as Map<String, dynamic>;
    return latestVersion['id'] as String;
  }
}
