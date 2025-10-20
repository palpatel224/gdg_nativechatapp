import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/chat/chat_bloc.dart';
import 'repositories/auth_repository.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_page.dart';
import 'theme/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final profileService = ProfileService();
    final repo = AuthRepository(authService, profileService);

    return RepositoryProvider.value(
      value: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(repo)..add(AuthStarted())),
          BlocProvider(create: (_) => ChatBloc()),
        ],
        child: MaterialApp(
          title: 'Chat App',
          theme: AppTheme.light(),
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const MainPage();
        }
        return const LoginPage();
      },
    );
  }
}
