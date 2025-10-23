import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/map/map_bloc.dart';
import 'repositories/auth_repository.dart';
import 'repositories/chat_repository.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/chat_service.dart';
import 'pages/auth/login_page.dart';
import 'pages/main_page.dart';
import 'theme/theme.dart';
import 'firebase_options.dart';
import 'services/presence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PresenceService _presenceService = PresenceService();

  @override
  void initState() {
    super.initState();
    _presenceService.init();
  }

  @override
  void dispose() {
    _presenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final profileService = ProfileService();
    final chatService = ChatService();
    final authRepo = AuthRepository(authService, profileService);
    final chatRepo = ChatRepository(chatService);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepo),
        RepositoryProvider.value(value: chatRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(authRepo)..add(AuthStarted())),
          BlocProvider(create: (_) => ChatBloc(chatService)),
          BlocProvider(create: (_) => MapBloc()),
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
