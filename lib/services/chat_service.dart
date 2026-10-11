import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Send Message
  Future<void> sendMessage({
    required String currentUid,
    required String friendUid,
    required String text,
  }) async {
    try {
      String conversationId = currentUid.compareTo(friendUid) < 0
          ? '${currentUid}_$friendUid'
          : '${friendUid}_$currentUid';

      await _supabase.from('direct_messages').insert({
        'sender_id': currentUid,
        'receiver_id': friendUid,
        'conversation_id': conversationId,
        'text': text,
        'type': 'text',
        'is_read': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Upload file to Supabase Storage
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final extension = fileName.split('.').last;
      final path = 'chat/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage.from('chat_media').upload(path, file);
      
      final String publicUrl = _supabase.storage.from('chat_media').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Send Media Message
  Future<void> sendMediaMessage({
    required String currentUid,
    required String friendUid,
    required MessageType type,
    required String mediaUrl,
    required String fileName,
    required int fileSize,
  }) async {
    try {
      String conversationId = currentUid.compareTo(friendUid) < 0
          ? '${currentUid}_$friendUid'
          : '${friendUid}_$currentUid';

      String typeStr;
      switch (type) {
        case MessageType.image: typeStr = 'image'; break;
        case MessageType.video: typeStr = 'video'; break;
        case MessageType.file: typeStr = 'file'; break;
        default: typeStr = 'text';
      }

      await _supabase.from('direct_messages').insert({
        'sender_id': currentUid,
        'receiver_id': friendUid,
        'conversation_id': conversationId,
        'text': 'Sent a ${typeStr}',
        'type': typeStr,
        'media_url': mediaUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'is_read': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending media message: $e');
      rethrow;
    }
  }

  // Send Location Message
  Future<void> sendLocationMessage({
    required String currentUid,
    required String friendUid,
    required double latitude,
    required double longitude,
  }) async {
    try {
      String conversationId = currentUid.compareTo(friendUid) < 0
          ? '${currentUid}_$friendUid'
          : '${friendUid}_$currentUid';

      await _supabase.from('direct_messages').insert({
        'sender_id': currentUid,
        'receiver_id': friendUid,
        'conversation_id': conversationId,
        'text': 'Shared location',
        'type': 'location',
        'latitude': latitude,
        'longitude': longitude,
        'is_read': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending location: $e');
      rethrow;
    }
  }

  // Stream messages
  Stream<List<ChatMessage>> streamMessages(
    String currentUid,
    String friendUid,
  ) {
    String conversationId = currentUid.compareTo(friendUid) < 0
        ? '${currentUid}_$friendUid'
        : '${friendUid}_$currentUid';

    return _supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: false)
        .map((snapshot) {
          return snapshot
              .map((data) => ChatMessage.fromMap(data, data['id']))
              .toList();
        });
  }

  // Mark specific messages as read
  Future<void> markMessagesAsRead(
    String currentUid,
    String friendUid,
    List<ChatMessage> unreadMessages,
  ) async {
    if (unreadMessages.isEmpty) return;

    final List<String> idsToUpdate = unreadMessages.map((m) => m.id).toList();

    try {
      await _supabase
          .from('direct_messages')
          .update({'is_read': true})
          .inFilter('id', idsToUpdate);
    } catch (e) {
      print('Error marking messages read: $e');
    }
  }

  // Stream unread message count
  Stream<int> streamUnreadCount(String currentUid, String friendUid) {
    return _supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUid)
        .map((snapshot) {
          return snapshot
              .where(
                (m) => m['sender_id'] == friendUid && m['is_read'] == false,
              )
              .length;
        });
  }

  // Save call record
  Future<void> saveCallToChat({
    required String callerUid,
    required String calleeUid,
    required bool isVideo,
    required int durationSeconds,
  }) async {
    final callText = isVideo ? 'Video call' : 'Voice call';

    String conversationId = callerUid.compareTo(calleeUid) < 0
        ? '${callerUid}_$calleeUid'
        : '${calleeUid}_$callerUid';

    await _supabase.from('direct_messages').insert({
      'sender_id': callerUid,
      'receiver_id': calleeUid,
      'conversation_id': conversationId,
      'text': callText,
      'type': 'call',
      'call_duration_seconds': durationSeconds,
      'is_video_call': isVideo,
      'is_read': true,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
