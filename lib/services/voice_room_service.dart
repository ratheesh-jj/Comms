import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceRoomParticipant {
  final String id;
  final String channelId;
  final String userId;
  final String userName;
  final DateTime joinedAt;
  final bool isMuted;

  VoiceRoomParticipant({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.userName,
    required this.joinedAt,
    required this.isMuted,
  });

  factory VoiceRoomParticipant.fromMap(Map<String, dynamic> data) {
    return VoiceRoomParticipant(
      id: data['id'] ?? '',
      channelId: data['channel_id'] ?? '',
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? 'Unknown',
      joinedAt: DateTime.tryParse(data['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      isMuted: data['is_muted'] ?? false,
    );
  }
}

class VoiceRoomService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Join a voice channel — inserts the user into voice_room_participants.
  Future<void> joinVoiceChannel({
    required String channelId,
    required String userId,
    required String userName,
  }) async {
    // Upsert to handle reconnects gracefully
    await _supabase.from('voice_room_participants').upsert(
      {
        'channel_id': channelId,
        'user_id': userId,
        'user_name': userName,
        'joined_at': DateTime.now().toIso8601String(),
        'is_muted': false,
      },
      onConflict: 'channel_id,user_id',
    );
  }

  /// Leave a voice channel — removes the user from voice_room_participants.
  Future<void> leaveVoiceChannel({
    required String channelId,
    required String userId,
  }) async {
    await _supabase
        .from('voice_room_participants')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }

  /// Stream the list of participants currently in a voice channel.
  Stream<List<VoiceRoomParticipant>> streamParticipants(String channelId) {
    return _supabase
        .from('voice_room_participants')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .map((snapshot) {
          return snapshot
              .map((doc) => VoiceRoomParticipant.fromMap(doc))
              .toList();
        });
  }

  /// Stream participants for multiple voice channels at once (for sidebar display).
  Stream<Map<String, List<VoiceRoomParticipant>>> streamAllVoiceParticipants(
    List<String> voiceChannelIds,
  ) {
    if (voiceChannelIds.isEmpty) {
      return Stream.value({});
    }

    return _supabase
        .from('voice_room_participants')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          final Map<String, List<VoiceRoomParticipant>> result = {};
          for (final id in voiceChannelIds) {
            result[id] = [];
          }
          for (final doc in snapshot) {
            final channelId = doc['channel_id'] as String?;
            if (channelId != null && voiceChannelIds.contains(channelId)) {
              result[channelId]!.add(VoiceRoomParticipant.fromMap(doc));
            }
          }
          return result;
        });
  }

  /// Update the user's mute state.
  Future<void> updateMuteState({
    required String channelId,
    required String userId,
    required bool isMuted,
  }) async {
    await _supabase
        .from('voice_room_participants')
        .update({'is_muted': isMuted})
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }

  /// Clean up — remove user from all voice rooms (e.g., on app close).
  Future<void> leaveAllRooms(String userId) async {
    await _supabase
        .from('voice_room_participants')
        .delete()
        .eq('user_id', userId);
  }
}
