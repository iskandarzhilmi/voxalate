import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:voxalate/firebase_options.dart';

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
  bool isShowSummary = false;

  @override
  void initState() {
    super.initState();
    initialiseSession();
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
                                  SelectableText(
                                    snapshot.data!.output!.transcription!,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  SelectableText(
                                    snapshot.data!.output!.translation!,
                                  ),
                                  TextButton(
                                    child: isShowSummary
                                        ? const Text('Hide')
                                        : const Text('Show'),
                                    onPressed: () {
                                      setState(() {
                                        isShowSummary = !isShowSummary;
                                      });
                                    },
                                  ),
                                  if (isShowSummary)
                                    FutureBuilder<OpenAiCompletion>(
                                      future: getSummary(
                                        snapshot.data!.output!.translation!,
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return SelectableText(
                                            snapshot.data!.choices?[0].text ??
                                                'null',
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                ],
                              );
                            }
                            if (snapshot.data?.output?.transcription != null) {
                              return Column(
                                children: [
                                  SelectableText(
                                    snapshot.data!.output!.transcription!,
                                  ),
                                  FutureBuilder(
                                    future: getSummary(
                                      snapshot.data!.output!.transcription!,
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return SelectableText(
                                          (snapshot.data as String?) ?? 'null',
                                        );
                                      }
                                      return const Text('Loading...');
                                    },
                                  ),
                                ],
                              );
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
              const SizedBox(
                height: 100,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> initialiseSession() async {
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  Future<void> startRecording() async {
    await Permission.microphone.request();
    await Permission.storage.request();

    final microphoneStatus = await Permission.microphone.status;
    final storageStatus = await Permission.storage.status;

    if (microphoneStatus.isGranted && storageStatus.isGranted) {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );

      setState(() {
        isRecording = true;
        predictionId = null;
      });

      if (Platform.isAndroid) {
        await recorder.startRecorder(
          toFile: 'test.wav',
          codec: Codec.pcm16WAV,
        );
      }

      if (Platform.isIOS) {
        await recorder.startRecorder(
          toFile: 'test.wav',
          codec: Codec.pcm16WAV,
        );
        return;
      }
      throw Exception('Platform not supported');
    } else {
      log('Permissions not granted');
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
        // utf decode to fix issue with special characters
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      yield predictionOutput;
      if (predictionOutput.status == 'succeeded') {
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

// curl https://api.openai.com/v1/completions \
//   -H 'Content-Type: application/json' \
//   -H 'Authorization: Bearer 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' \
//   -d '{
//   "model": "text-davinci-002",
//   "max_tokens": 3500,
//   "n":5,
//   "prompt": "$englishText\nSummarise this:"
// {
//   "id": "cmpl-uqkvlQyYK7bGYrRHQ0eXlWi7",
//   "object": "text_completion",
//   "created": 1589478378,
//   "model": "text-davinci-002",
//   "choices": [
//     {
//       "text": "\n\nThis is a test",
//       "index": 0,
//       "logprobs": null,
//       "finish_reason": "length"
//     }
//   ],
//   "usage": {
//     "prompt_tokens": 5,
//     "completion_tokens": 6,
//     "total_tokens": 11
//   }
//   }

  Future<OpenAiCompletion> getSummary(String englishText) async {
    final String body = jsonEncode({
      // 'model': 'text-davinci-002',
      'model': 'text-curie-001',
      'max_tokens': 1500,
      'n': 1,
      'prompt': '$englishText\nSummarise this:\n',
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
    return OpenAiCompletion.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>;
    final latestVersion = results.first as Map<String, dynamic>;
    return latestVersion['id'] as String;
  }
}

// Models

class Prediction {
  final String? id;
  final String? version;
  final String? createdAt;
  final String? completedAt;
  final String? status;
  final PredictionInput? input;
  final PredictionOutput? output;
  final String? error;
  final String? logs;
  final PredictionMetrics? metrics;

  Prediction({
    this.id,
    this.version,
    this.createdAt,
    this.completedAt,
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
      createdAt: json['created_at'] as String?,
      completedAt: json['completed_at'] as String?,
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

class OpenAiCompletion {
  final String? id;
  final String? object;
  final int? created;
  final String? model;
  final List<OpenAiCompletionChoice>? choices;
  final OpenAiCompletionUsage? usage;

  OpenAiCompletion({
    this.id,
    this.object,
    this.created,
    this.model,
    this.choices,
    this.usage,
  });

  factory OpenAiCompletion.fromJson(Map<String, dynamic> json) {
    return OpenAiCompletion(
      id: json['id'] as String?,
      object: json['object'] as String?,
      created: json['created'] as int?,
      model: json['model'] as String?,
      choices: json['choices'] != null
          ? (json['choices'] as List<dynamic>)
              .map(
                (e) =>
                    OpenAiCompletionChoice.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : null,
      usage: json['usage'] != null
          ? OpenAiCompletionUsage.fromJson(
              json['usage'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class OpenAiCompletionChoice {
  final String? text;
  final int? index;
  final dynamic logprobs;
  final String? finishReason;

  OpenAiCompletionChoice({
    this.text,
    this.index,
    this.logprobs,
    this.finishReason,
  });

  factory OpenAiCompletionChoice.fromJson(Map<String, dynamic> json) {
    return OpenAiCompletionChoice(
      text: json['text'] as String?,
      index: json['index'] as int?,
      logprobs: json['logprobs'],
      finishReason: json['finish_reason'] as String?,
    );
  }
}

class OpenAiCompletionUsage {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  OpenAiCompletionUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  factory OpenAiCompletionUsage.fromJson(Map<String, dynamic> json) {
    return OpenAiCompletionUsage(
      promptTokens: json['prompt_tokens'] as int?,
      completionTokens: json['completion_tokens'] as int?,
      totalTokens: json['total_tokens'] as int?,
    );
  }
}
