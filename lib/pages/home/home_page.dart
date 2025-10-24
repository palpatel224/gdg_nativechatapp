import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_event.dart';
import '../../blocs/home/home_state.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../widgets/home/chat_list_item.dart';
import '../../widgets/home/search_bar_widget.dart';
import '../chat/chat_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(const HomeLoadChats());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      context.read<HomeBloc>().add(const HomeClearSearch());
    } else {
      context.read<HomeBloc>().add(HomeSearchChats(query));
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    context.read<HomeBloc>().add(const HomeClearSearch());
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(AuthSignedOut());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              color: Colors.black87,
              size: 28,
            ),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87, size: 24),
            tooltip: 'Sign Out',
            onPressed: () => _showSignOutDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is HomeError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<HomeBloc>().add(const HomeLoadChats());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is HomeLoaded) {
            return Column(
              children: [
                Container(
                  color: Colors.white,
                  child: SearchBarWidget(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: _onClearSearch,
                  ),
                ),
                Expanded(
                  child: state.chats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No chats yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          color: Colors.white,
                          child: RefreshIndicator(
                            onRefresh: () async {
                              context.read<HomeBloc>().add(
                                const HomeRefreshChats(),
                              );
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: state.chats.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                indent: 88,
                                color: Colors.grey[200],
                              ),
                              itemBuilder: (context, index) {
                                final chat = state.chats[index];
                                return ChatListItem(
                                  chat: chat,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          chatId: chat.id,
                                          recipientId: chat.userId,
                                          recipientName: chat.userName,
                                          recipientPhotoUrl: chat.userAvatar,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
