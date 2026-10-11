import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CallService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Create a call request
  Future<Map<String, String>> startDirectCall({
    required String callerUid,
    required String callerName,
    required String calleeUid,
    required bool isVideo,
  }) async {
    final callId = _uuid.v4();
    final roomId = _uuid.v4();

    await _supabase.from('calls').insert({
      'id': callId,
      'caller_id': callerUid,
      'callee_id': calleeUid,
      'caller_name': callerName,
      'room_id': roomId,
      'is_video': isVideo,
      'status': 'ringing',
      'created_at': DateTime.now().toIso8601String(),
    });

    return {'callId': callId, 'roomId': roomId};
  }

  // Listen for incoming calls
  Stream<List<Map<String, dynamic>>> listenForIncomingCalls(String userUid) {
    return _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('callee_id', userUid)
        .map(
          (snapshot) =>
              snapshot.where((c) => c['status'] == 'ringing').toList(),
        );
  }

  // Accept a call
  Future<void> acceptCall(String callId) async {
    await _supabase
        .from('calls')
        .update({'status': 'accepted'})
        .eq('id', callId);
  }

  // Reject a call
  Future<void> rejectCall(String callId) async {
    await _supabase
        .from('calls')
        .update({'status': 'rejected'})
        .eq('id', callId);
  }

  // End a call (clean up)
  Future<void> endCall(String callId) async {
    await _supabase.from('calls').update({'status': 'ended'}).eq('id', callId);
  }

  // Listen to specific call state
  Stream<Map<String, dynamic>?> listenToCallState(String callId) {
    return _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((event) {
          if (event.isEmpty) return null;
          return event.first;
        });
  }

  // Get the last call time between two users
  Future<DateTime?> getLastCallTime(String uid1, String uid2) async {
    final query = await _supabase
        .from('calls')
        .select()
        .or(
          'and(caller_id.eq.$uid1,callee_id.eq.$uid2),and(caller_id.eq.$uid2,callee_id.eq.$uid1)',
        )
        .order('created_at', ascending: false)
        .limit(1);

    if (query.isEmpty) return null;
    final data = query.first;
    if (data['created_at'] != null) {
      return DateTime.tryParse(data['created_at'].toString());
    }
    return null;
  }

  Future<void> cleanupOldCalls(String userUid) async {}
}
