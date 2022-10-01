import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Tap the button to start recording',
            ),
            TextButton(
              onPressed: () async {
                if (Platform.isIOS) {
                  final file = File('recording.m4a');
                  await recorder.startRecorder(
                    toFile: file.path,
                    codec: Codec.aacMP4,
                  );
                } else if (Platform.isAndroid) {
                  final file = File('recording.mp3');
                  await recorder.startRecorder(
                    toFile: file.path,
                    codec: Codec.mp3,
                  );
                } else {
                  throw UnsupportedError('Unsupported platform');
                }
              },
              child: const Text('Start recording'),
            ),
            TextButton(
              onPressed: () async {
                await recorder.stopRecorder();

                String? fileType;

                if (Platform.isIOS) {
                  fileType = 'm4a';
                } else if (Platform.isAndroid) {
                  fileType = 'mp3';
                } else {
                  throw UnsupportedError('Unsupported platform');
                }

                // final file = await File('test.$fileType').create();
                // final uploadTask = storageReference
                //     .child('speech/test.$fileType')
                //     .putFile(file);
                // await uploadTask.whenComplete(() => log('File uploaded'));

                final file = File('test.$fileType');
                final bytes = await file.readAsBytes();
                final uploadTask = storageReference
                    .child('test.$fileType')
                    .putData(bytes,
                        SettableMetadata(contentType: 'audio/$fileType'));

                final snapshot = await uploadTask;
                final url = await snapshot.ref.getDownloadURL();

                log('Uploaded file to $url');
              },
              child: const Text('Stop recording'),
            ),
          ],
        ),
      ),
    );
  }
}
