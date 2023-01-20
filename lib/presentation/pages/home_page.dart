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
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:voxalate/presentation/bloc/transcribe_bloc.dart';
import 'package:voxalate/presentation/widgets/recorder_button.dart';

import '../../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
        title: Text(
          'Voxalate',
        ),
      ),
      persistentFooterAlignment: AlignmentDirectional.center,
      persistentFooterButtons: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: Icon(
                    Icons.logout,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.center,
                child: RecorderButton(
                  isRecording: isRecording,
                  startRecording: startRecording,
                  stopRecording: stopRecording,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.settings,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        )
      ],
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
                  // if stream is null
                  if (!snapshot.hasData) {
                    return CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading');
                  }

                  final usageLeft = snapshot.data!.docs
                      .where(
                        (element) =>
                            element.id ==
                            FirebaseAuth.instance.currentUser!.uid,
                      )
                      .first
                      .get('minutesLeft');
                  return Text(
                    'Usage left: ${usageLeft.toString()}',
                  );
                },
              ),
              const SizedBox(
                height: 50,
              ),
              BlocBuilder<TranscribeBloc, TranscribeState>(
                builder: (context, state) {
                  if (state is TranscribeInitial) {
                    return SizedBox(
                      width: double.infinity,
                      child: const Text(
                        'Press the button to start recording',
                        textAlign: TextAlign.center,
                      ),
                    );
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
                          // detected language
                          const Text(
                            'Detected Language',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SelectableText(
                            state.transcribeOutput.detectedLanguage
                                .split(' ')
                                .map((word) =>
                                    word[0].toUpperCase() + word.substring(1))
                                .join(' '),
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
              const SizedBox(
                height: 100,
              ),
              Text(
                '© 2023 Voxalate. All rights reserved. Powered by OpenAI',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
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

    if (data['minutesLeft'] as int <= 0) {
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
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Text(
                FirebaseAuth.instance.currentUser!.email!,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Delete Account',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              TextButton(
                onPressed: () async {
                  // ask the user to re-enter their password
                  final user = FirebaseAuth.instance.currentUser!;
                  final credential = await showDialog<AuthCredential>(
                    context: context,
                    builder: (context) => const ReauthenticateDialog(),
                  );

                  if (credential != null) {
                    try {
                      await user.reauthenticateWithCredential(credential);

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => ConfirmDeleteDialog(),
                      );

                      if (confirm != null && confirm) {
                        await user.delete();
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      }
                    } on FirebaseAuthException catch (e) {
                      BotToast.showText(text: e.message!);
                    }
                  }
                },
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Security',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => LoginPage(),
                    ),
                  );
                },
                child: const Text(
                  'Sign out',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReauthenticateDialog extends StatefulWidget {
  const ReauthenticateDialog({super.key});

  @override
  State<ReauthenticateDialog> createState() => _ReauthenticateDialogState();
}

class _ReauthenticateDialogState extends State<ReauthenticateDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reauthenticate'),
      content: TextField(
        controller: _passwordController,
        decoration: const InputDecoration(
          labelText: 'Password',
        ),
        obscureText: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              BotToast.showLoading();
              final user = FirebaseAuth.instance.currentUser!;
              final credential = EmailAuthProvider.credential(
                email: user.email!,
                password: _passwordController.text,
              );
              Navigator.of(context).pop(credential);
            } on FirebaseAuthException catch (e) {
              BotToast.showText(text: e.message!);
            } finally {
              BotToast.closeAllLoading();
            }
          },
          child: const Text('Reauthenticate'),
        ),
      ],
    );
  }
}

class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete your account?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
