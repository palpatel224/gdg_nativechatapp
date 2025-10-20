import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';
import '../../models/chat_model.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeInitial()) {
    on<HomeLoadChats>(_onLoadChats);
    on<HomeRefreshChats>(_onRefreshChats);
    on<HomeSearchChats>(_onSearchChats);
    on<HomeClearSearch>(_onClearSearch);
    on<HomeSelectChat>(_onSelectChat);
  }

  Future<void> _onLoadChats(
    HomeLoadChats event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    try {
      // TODO: Fetch chats from repository
      await Future.delayed(const Duration(seconds: 1));

      // Dummy data for UI
      final chats = _getDummyChats();
      emit(HomeLoaded(chats: chats));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onRefreshChats(
    HomeRefreshChats event,
    Emitter<HomeState> emit,
  ) async {
    try {
      // TODO: Refresh chats from repository
      await Future.delayed(const Duration(seconds: 1));

      final chats = _getDummyChats();
      emit(HomeLoaded(chats: chats));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onSearchChats(
    HomeSearchChats event,
    Emitter<HomeState> emit,
  ) async {
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      // TODO: Implement actual search logic
      final filteredChats = currentState.chats
          .where(
            (chat) =>
                chat.userName.toLowerCase().contains(event.query.toLowerCase()),
          )
          .toList();
      emit(HomeLoaded(chats: filteredChats, searchQuery: event.query));
    }
  }

  Future<void> _onClearSearch(
    HomeClearSearch event,
    Emitter<HomeState> emit,
  ) async {
    // TODO: Reload all chats
    final chats = _getDummyChats();
    emit(HomeLoaded(chats: chats));
  }

  Future<void> _onSelectChat(
    HomeSelectChat event,
    Emitter<HomeState> emit,
  ) async {
    // TODO: Handle chat selection navigation
  }

  List<ChatModel> _getDummyChats() {
    return [
      ChatModel(
        id: '1',
        userId: 'user1',
        userName: 'John Doe',
        userAvatar: '',
        lastMessage: 'Hey! How are you doing?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
      ),
      ChatModel(
        id: '2',
        userId: 'user2',
        userName: 'Jane Smith',
        userAvatar: '',
        lastMessage: 'See you tomorrow!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
        isOnline: false,
      ),
      ChatModel(
        id: '3',
        userId: 'user3',
        userName: 'Mike Johnson',
        userAvatar: '',
        lastMessage: 'Thanks for your help!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
        unreadCount: 1,
        isOnline: true,
      ),
    ];
  }
}
