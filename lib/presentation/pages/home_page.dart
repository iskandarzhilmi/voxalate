import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:voxalate/data/models/open_ai_completion_model.dart';
import 'package:voxalate/data/models/prediction_model.dart';
import 'package:voxalate/presentation/bloc/transcribe_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
                  ],
                ),
              ),
              const SizedBox(
                height: 100,
              ),
              BlocBuilder<TranscribeBloc, TranscribeState>(
                builder: (context, state) {
                  if (state is TranscribeInitial) {
                    return const Text('Press the button to start recording');
                  } else if (state is TranscribeLoading) {
                    return const CircularProgressIndicator();
                  } else if (state is TranscribeLoaded) {
                    return Column(
                      children: [
                        Text(state.transcribeOutput.transcription),
                        Text(state.transcribeOutput.translation ?? ''),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isShowSummary = !isShowSummary;
                            });
                          },
                          child: isShowSummary
                              ? const Text('Hide Summary')
                              : const Text('Show Summary'),
                        ),
                        if (isShowSummary)
                          Text(state.transcribeOutput.summary ?? ''),
                      ],
                    );
                  } else if (state is TranscribeError) {
                    return Text(state.message);
                  } else {
                    return const Text('Something went wrong');
                  }
                },
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
        return;
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
    if (!mounted) return;
    context.read<TranscribeBloc>().add(TranscribeStarted(path!));
    // log('Recording stopped at $path');
    // final file = File(path!);
    // final bytes = await file.readAsBytes();
    // final snapshot = await storageReference.child('test.wav').putData(bytes);
    // log('Uploaded file to ${snapshot.ref.fullPath}');
    // log('Download URL: ${await snapshot.ref.getDownloadURL()}');

    final PredictionModel prediction = await startPrediction();

    setState(() {
      predictionId = prediction.id;
    });
  }

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
      yield predictionOutput;
      if (predictionOutput.status == 'succeeded') {
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<OpenAiCompletionModel> getSummary(String englishText) async {
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


// if (predictionId != null)
//                       StreamBuilder<PredictionModel>(
//                         stream: getPredictionStream(predictionId!),
//                         builder: (context, snapshot) {
//                           if (snapshot.hasData) {
//                             if (snapshot.data?.output?.translation != null) {
//                               return Column(
//                                 children: [
//                                   SelectableText(
//                                     snapshot.data!.output!.transcription!,
//                                   ),
//                                   const SizedBox(
//                                     height: 10,
//                                   ),
//                                   SelectableText(
//                                     snapshot.data!.output!.translation!,
//                                   ),
//                                   TextButton(
//                                     child: isShowSummary
//                                         ? const Text('Hide')
//                                         : const Text('Show'),
//                                     onPressed: () {
//                                       setState(() {
//                                         isShowSummary = !isShowSummary;
//                                       });
//                                     },
//                                   ),
//                                   if (isShowSummary)
//                                     FutureBuilder<OpenAiCompletionModel>(
//                                       future: getSummary(
//                                         snapshot.data!.output!.translation!,
//                                       ),
//                                       builder: (context, snapshot) {
//                                         if (snapshot.hasData) {
//                                           return SelectableText(
//                                             snapshot.data!.choices?[0].text ??
//                                                 'null',
//                                           );
//                                         }
//                                         return const SizedBox();
//                                       },
//                                     ),
//                                 ],
//                               );
//                             }
//                             if (snapshot.data?.output?.transcription != null) {
//                               return Column(
//                                 children: [
//                                   SelectableText(
//                                     snapshot.data!.output!.transcription!,
//                                   ),
//                                   FutureBuilder(
//                                     future: getSummary(
//                                       snapshot.data!.output!.transcription!,
//                                     ),
//                                     builder: (context, snapshot) {
//                                       if (snapshot.hasData) {
//                                         return SelectableText(
//                                           (snapshot.data as String?) ?? 'null',
//                                         );
//                                       }
//                                       return const Text('Loading...');
//                                     },
//                                   ),
//                                 ],
//                               );
//                             }
//                             return const Text('Loading...');
//                           } else {
//                             return const Text('No data');
//                           }
//                         },
//                       )
//                     else
//                       Container(),