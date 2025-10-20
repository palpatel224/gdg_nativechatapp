import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';
import '../../models/chat_model.dart';
import '../../repositories/chat_repository.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ChatRepository _chatRepository;

  HomeBloc(this._chatRepository) : super(const HomeInitial()) {
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

    // Use emit.forEach to properly handle the stream
    await emit.forEach<List<ChatModel>>(
      _chatRepository.getChatsStream(),
      onData: (chats) {
        return HomeLoaded(chats: chats);
      },
      onError: (error, stackTrace) {
        return HomeError(error.toString());
      },
    );
  }

  Future<void> _onRefreshChats(
    HomeRefreshChats event,
    Emitter<HomeState> emit,
  ) async {
    try {
      // The stream will automatically refresh, but we can trigger a reload
      add(const HomeLoadChats());
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onSearchChats(
    HomeSearchChats event,
    Emitter<HomeState> emit,
  ) async {
    try {
      emit(const HomeLoading());

      // Search chats using the repository
      final filteredChats = await _chatRepository.searchChats(event.query);

      emit(HomeLoaded(chats: filteredChats, searchQuery: event.query));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onClearSearch(
    HomeClearSearch event,
    Emitter<HomeState> emit,
  ) async {
    // Reload all chats by triggering the load event
    add(const HomeLoadChats());
  }

  Future<void> _onSelectChat(
    HomeSelectChat event,
    Emitter<HomeState> emit,
  ) async {
    // TODO: Handle chat selection navigation if needed
  }
}
