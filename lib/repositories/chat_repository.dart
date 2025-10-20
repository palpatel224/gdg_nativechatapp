import '../models/chat_model.dart';
import '../services/chat_service.dart';

abstract class IChatRepository {
  Stream<List<ChatModel>> getChatsStream();
  Future<String> getOrCreateChat(String otherUserId);
  Future<List<ChatModel>> searchChats(String query);
}

class ChatRepository implements IChatRepository {
  final ChatService _chatService;

  ChatRepository(this._chatService);

  @override
  Stream<List<ChatModel>> getChatsStream() {
    return _chatService.getChatsStream();
  }

  @override
  Future<String> getOrCreateChat(String otherUserId) {
    return _chatService.getOrCreateChat(otherUserId);
  }

  @override
  Future<List<ChatModel>> searchChats(String query) {
    return _chatService.searchChats(query);
  }
}
