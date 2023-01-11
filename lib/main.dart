import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  FirebaseAuth.instance.authStateChanges().listen((user) {
    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => dependency_injection.locator<TranscribeBloc>(),
          )
        ],
        child: MaterialApp(
          builder: BotToastInit(),
          title: 'Voxalate',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFF25B2C2),
              secondary: const Color(0xFF2B3C96),
            ),
          ),
          home: MyApp(),
        ),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data!.emailVerified) {
            return HomePage();
          } else {
            return PendingEmailVerificationPage();
          }
        } else {
          return LoginPage();
        }
      },
    );
  }
}

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voxalate Login'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LoginForm(),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your email';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Email',
            ),
          ),
          TextFormField(
            controller: _passwordController,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter your password';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Password',
            ),
            obscureText: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    // Replace 'email' and 'password' with the user's email and password.
                    BotToast.showLoading();
                    UserCredential userCredential = await loginWithFirebase(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );

                    // Show a toast notification to confirm the login was successful.
                    BotToast.showText(
                      text:
                          'Login successful: ${userCredential.user?.email ?? 'unknown'}',
                      duration: Duration(seconds: 3),
                    );
                  } catch (e) {
                    // Show a toast notification with the error message.
                    BotToast.showText(
                      text: 'Error logging in: $e',
                      duration: Duration(seconds: 3),
                    );
                  } finally {
                    // Close the loading indicator.
                    BotToast.closeAllLoading();
                  }
                }
              },
              child: Text('Login'),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SignUpForm()),
              );
            },
            child: Text('Sign Up'),
          )
        ],
      ),
    );
  }

  Future<UserCredential> loginWithFirebase({
    required String email,
    required String password,
  }) async {
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}

class SignUpForm extends StatefulWidget {
  @override
  _SignUpFormState createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voxalate Sign Up'),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter your first name',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter a password',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          // Replace 'email' and 'password' with the user's email and password.
                          BotToast.showLoading();
                          final UserCredential userCredential =
                              await signUpWithFirebase(
                            name: _nameController.text,
                            email: _emailController.text,
                            password: _passwordController.text,
                          );

                          // Show a toast notification to confirm the login was successful.
                          BotToast.showText(
                            text:
                                'Sign up successful: ${userCredential.user?.email ?? 'unknown'}',
                            duration: Duration(seconds: 3),
                          );
                        } catch (e) {
                          // Show a toast notification with the error message.
                          BotToast.showText(
                            text: 'Error signing up: $e',
                            duration: Duration(seconds: 3),
                          );
                        } finally {
                          // Close the loading indicator.
                          BotToast.closeAllLoading();
                        }
                      }
                    },
                    child: Text('Sign Up'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<UserCredential> signUpWithFirebase({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await userCredential.user?.sendEmailVerification();

    await userCredential.user?.updateDisplayName(name);

    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(userCredential.user?.uid)
    //     .update({
    //   'name': name,
    // });

    // check the document every 1 second until the document is created then update the name

    return userCredential;
  }
}

class PendingEmailVerificationPage extends StatefulWidget {
  const PendingEmailVerificationPage({super.key});

  @override
  State<PendingEmailVerificationPage> createState() =>
      _PendingEmailVerificationPageState();
}

class _PendingEmailVerificationPageState
    extends State<PendingEmailVerificationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voxalate'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Please verify your email address',
              style: Theme.of(context).textTheme.headline6,
            ),
            SizedBox(
              height: 20,
            ),
            Text(
              'We have sent you an email with a link to verify your email address. Please click on the link to verify your email address.',
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  BotToast.showLoading();
                  await FirebaseAuth.instance.currentUser?.reload();
                  if (FirebaseAuth.instance.currentUser?.emailVerified ??
                      false) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(),
                      ),
                    );
                  } else {
                    BotToast.showText(
                      text: 'Please verify your email address',
                      duration: Duration(seconds: 3),
                    );
                  }
                } catch (e) {
                  BotToast.showText(
                    text: 'Error verifying email: $e',
                    duration: Duration(seconds: 3),
                  );
                } finally {
                  BotToast.closeAllLoading();
                }
              },
              child: Text('Verify Email'),
            ),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  BotToast.showLoading();
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginPage(),
                    ),
                  );
                } catch (e) {
                  BotToast.showText(
                    text: 'Error signing out: $e',
                    duration: Duration(seconds: 3),
                  );
                } finally {
                  BotToast.closeAllLoading();
                }
              },
              child: Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
