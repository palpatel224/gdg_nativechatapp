import 'package:equatable/equatable.dart';
import '../../models/chat_model.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeLoadChats extends HomeEvent {
  const HomeLoadChats();
}

class HomeRefreshChats extends HomeEvent {
  const HomeRefreshChats();
}

class HomeSearchChats extends HomeEvent {
  final String query;

  const HomeSearchChats(this.query);

  @override
  List<Object?> get props => [query];
}

class HomeClearSearch extends HomeEvent {
  const HomeClearSearch();
}

class HomeSelectChat extends HomeEvent {
  final String chatId;

  const HomeSelectChat(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class HomeChatsUpdated extends HomeEvent {
  final List<ChatModel> chats;

  const HomeChatsUpdated(this.chats);

  @override
  List<Object?> get props => [chats];
}
