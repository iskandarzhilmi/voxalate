import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:voxalate/firebase_options.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voxalate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Voxalate - Transcribe and Translate'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer player = FlutterSoundPlayer();
  final storageReference = FirebaseStorage.instance.ref();
  String? predictionId;

  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    recorder.openRecorder();
  }

  @override
  void dispose() {
    recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const SizedBox(
                height: 100,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'Tap the button to start recording',
                    ),
                    TextButton(
                      onPressed: () {
                        if (isRecording) {
                          stopRecording();
                        } else {
                          startRecording();
                        }
                      },
                      child: isRecording
                          ? const Text('Stop Recording')
                          : const Text('Start Recording'),
                    ),
                    if (predictionId != null)
                      StreamBuilder<Prediction>(
                        stream: getPredictionStream(predictionId!),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            if (snapshot.data?.output?.translation != null) {
                              return Column(
                                children: [
                                  Text(
                                    snapshot.data!.output!.transcription!,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Text(snapshot.data!.output!.translation!),
                                ],
                              );
                            }
                            if (snapshot.data?.output?.transcription != null) {
                              return Text(
                                  snapshot.data!.output!.transcription!);
                            }
                            return const Text('Loading...');
                          } else {
                            return const Text('No data');
                          }
                        },
                      )
                    else
                      Container(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> startRecording() async {
    setState(() {
      isRecording = true;
      predictionId = null;
    });
    if (Platform.isIOS) {
      final path = await recorder.startRecorder(
        toFile: 'test.wav',
        codec: Codec.pcm16WAV,
      );
    }
  }

  Future<void> stopRecording() async {
    setState(() {
      isRecording = false;
    });
    final path = await recorder.stopRecorder();
    log('Recording stopped at $path');
    final file = File(path!);
    final bytes = await file.readAsBytes();
    final uploadTask = storageReference.child('test.wav').putData(bytes);
    final snapshot = await uploadTask;
    log('Uploaded file to ${snapshot.ref.fullPath}');
    log('Download URL: ${await snapshot.ref.getDownloadURL()}');

    final Prediction prediction = await startPrediction();

    setState(() {
      predictionId = prediction.id;
    });
  }

  Future<Prediction> startPrediction() async {
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
    return Prediction.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Stream<Prediction> getPredictionStream(String predictionId) async* {
    while (true) {
      final response = await http.get(
        Uri.parse(
          'https://api.replicate.com/v1/predictions/$predictionId',
        ),
        headers: {
          'Authorization': 'Token 066709f72f2494c995b2585a0776d2b7c49287ae',
        },
      );
      final predictionOutput = Prediction.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      yield predictionOutput;
      if (predictionOutput.status == 'succeeded') {
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<String> getDownloadUrl() async {
    return storageReference.child('test.wav').getDownloadURL();
  }

  //TODO: Cache this
  // TODO: Create a class for this
  Future<String> getModelVersion() async {
    final response = await http.get(
      Uri.parse('https://api.replicate.com/v1/models/openai/whisper/versions'),
      headers: {
        'Authorization': 'Token 066709f72f2494c995b2585a0776d2b7c49287ae',
        'Content-Type': 'application/json',
      },
    );
    final json = jsonDecode(response.body);
    final results = json['results'] as List;
    final latestVersion = results.first as Map<String, dynamic>;
    return latestVersion['id'] as String;
  }
}

// Models

class Prediction {
  final String? id;
  final String? version;
  final String? created_at;
  final String? completed_at;
  final String? status;
  final PredictionInput? input;
  final PredictionOutput? output;
  final String? error;
  final String? logs;
  final PredictionMetrics? metrics;

  Prediction({
    this.id,
    this.version,
    this.created_at,
    this.completed_at,
    this.status,
    this.input,
    this.output,
    this.error,
    this.logs,
    this.metrics,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      id: json['id'] as String?,
      version: json['version'] as String?,
      created_at: json['created_at'] as String?,
      completed_at: json['completed_at'] as String?,
      status: json['status'] as String?,
      input: json['input'] != null
          ? PredictionInput.fromJson(json['input'] as Map<String, dynamic>)
          : null,
      output: json['output'] != null
          ? PredictionOutput.fromJson(json['output'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      logs: json['logs'] as String?,
      metrics: json['metrics'] != null
          ? PredictionMetrics.fromJson(
              json['metrics'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class PredictionInput {
  final String? audio;
  final String? model;
  final bool? translate;

  PredictionInput({
    this.audio,
    this.model,
    this.translate,
  });

  factory PredictionInput.fromJson(Map<String, dynamic> json) {
    return PredictionInput(
      audio: json['audio'] as String?,
      model: json['model'] as String?,
      translate: json['translate'] as bool?,
    );
  }
}

class PredictionOutput {
  final String? translation;
  final String? transcription;
  final String? detectedLanguage;

  PredictionOutput({
    this.translation,
    this.transcription,
    this.detectedLanguage,
  });

  factory PredictionOutput.fromJson(Map<String, dynamic> json) {
    return PredictionOutput(
      translation: json['translation'] as String?,
      transcription: json['transcription'] as String?,
      detectedLanguage: json['detected_language'] as String?,
    );
  }
}

class PredictionMetrics {
  final double? predictTime;

  PredictionMetrics({
    this.predictTime,
  });

  factory PredictionMetrics.fromJson(Map<String, dynamic> json) {
    return PredictionMetrics(
      predictTime: json['predict_time'] as double?,
    );
  }
}
