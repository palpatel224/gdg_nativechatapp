import 'package:equatable/equatable.dart';
import '../../models/chat_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final List<ChatModel> chats;
  final String searchQuery;

  const HomeLoaded({required this.chats, this.searchQuery = ''});

  @override
  List<Object?> get props => [chats, searchQuery];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
