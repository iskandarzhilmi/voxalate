import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
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

  final Stream<QuerySnapshot> _usersStream =
      FirebaseFirestore.instance.collection('users').snapshots();

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
              StreamBuilder<QuerySnapshot>(
                stream: _usersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading');
                  }

                  // if document id equals user id, get the usage left
                  final usageLeft = snapshot.data!.docs
                      .where(
                        (element) =>
                            element.id ==
                            FirebaseAuth.instance.currentUser!.uid,
                      )
                      .first
                      .get('speechSummarisationUsesLeft');
                  return Text(
                    'Usage left: ${usageLeft.toString()}',
                  );
                },
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(
                      height: 50,
                    ),
                    IconButton(
                      iconSize: 50,
                      onPressed: () {
                        if (isRecording) {
                          stopRecording();
                        } else {
                          startRecording();
                        }
                      },
                      icon: isRecording
                          ? const Icon(
                              Icons.stop,
                            )
                          : const Icon(
                              Icons.mic,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 50,
              ),
              BlocBuilder<TranscribeBloc, TranscribeState>(
                builder: (context, state) {
                  if (state is TranscribeInitial) {
                    return const Text('Press the button to start recording');
                  } else if (state is TranscribeLoading) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            height: 20,
                            width: 100,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            height: 50,
                            width: double.infinity,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            height: 20,
                            width: 100,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            height: 50,
                            width: double.infinity,
                          ),
                        ),
                      ],
                    );
                  } else if (state is TranscribeLoaded) {
                    return SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transcription',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SelectableText(state.transcribeOutput.transcription),
                          const SizedBox(
                            height: 20,
                          ),
                          if (state.transcribeOutput.translation != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Translation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SelectableText(
                                    state.transcribeOutput.translation!),
                              ],
                            ),
                          const SizedBox(
                            height: 20,
                          ),
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SelectableText(state.transcribeOutput.summary ?? ''),
                        ],
                      ),
                    );
                  } else if (state is TranscribeError) {
                    return Text(state.message);
                  } else {
                    return const Text('Something went wrong');
                  }
                },
              ),
              SizedBox(
                height: 50,
              ),
              SizedBox(
                height: 50,
              ),
              ElevatedButton(
                onPressed: () {
                  // context.read<AuthenticationBloc>().add(LoggedOut());
                  FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
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
    final user = FirebaseAuth.instance.currentUser!;
    final Map<String, dynamic> data = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((value) => value.data()!);

    if (data['speechSummarisationUsesLeft'] as int <= 0) {
      BotToast.showText(text: 'You have no uses left');
      return;
    }

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

    // decrement speechSummarisationUsesLeft on firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .update({
      'speechSummarisationUsesLeft': FieldValue.increment(-1),
    });
  }
}
