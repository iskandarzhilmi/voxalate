import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voxalate/firebase_options.dart';
import 'package:voxalate/injection.dart' as dependency_injection;
import 'package:voxalate/presentation/bloc/transcribe_bloc.dart';
import 'package:voxalate/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  dependency_injection.initialiseLocator();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => dependency_injection.locator<TranscribeBloc>(),
        )
      ],
      child: MaterialApp(
        title: 'Voxalate',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color(0xFF25B2C2),
            // secondary: const Color(0xFFE0E0E0),
            secondary: const Color(0xFF2B3C96),
          ),
          // accentColor: const Color(0XFF2D2D2D),
        ),
        home: const HomePage(title: 'Voxalate - Transcribe and Translate'),
      ),
    );
  }
}
