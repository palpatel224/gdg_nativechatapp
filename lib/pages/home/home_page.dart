import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/home/home_bloc.dart';
import '../../blocs/home/home_event.dart';
import '../../blocs/home/home_state.dart';
import '../../widgets/home/chat_list_item.dart';
import '../../widgets/home/search_bar_widget.dart';
import '../chat/chat_page.dart';

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

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat, color: Colors.blue),
              ),
              title: const Text('Chat'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open new chat
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add, color: Colors.green),
              ),
              title: const Text('Contact'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Add contact
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group, color: Colors.purple),
              ),
              title: const Text('Group'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Create group
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign, color: Colors.orange),
              ),
              title: const Text('Broadcast'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Create broadcast
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups, color: Colors.red),
              ),
              title: const Text('Team'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Create team
              },
            ),
          ],
        ),
      ),
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
            return Stack(
              children: [
                Column(
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
                                            builder: (context) => ChatPage(
                                              chatId: chat.id,
                                              userName: chat.userName,
                                              userAvatar: chat.userAvatar,
                                              isOnline: chat.isOnline,
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
                ),
                // Floating Action Button
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: FloatingActionButton(
                    onPressed: () {
                      _showNewChatOptions(context);
                    },
                    backgroundColor: Colors.black87,
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
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
