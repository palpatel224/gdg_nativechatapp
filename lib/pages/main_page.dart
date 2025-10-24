import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../widgets/common/custom_bottom_nav_bar.dart';
import 'home/home_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // Start with Home (Chats) tab

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(context.read<ChatRepository>()),
      child: Scaffold(
        body: Stack(
          children: [
            // Only show HomePage - other navigation handled by CustomBottomNavBar
            const HomePage(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: CustomBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                authRepository: context.read<AuthRepository>(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
