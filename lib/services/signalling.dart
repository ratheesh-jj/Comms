import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class SignallingService extends ChangeNotifier {
  final Logger _log = Logger('SignallingService');
  final SupabaseClient _db = Supabase.instance.client;

  String? _currentRoomId;
  bool _isCaller = false;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _candidatesSubscription;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String, String?)? onJoinSuccess;
  Function(String?)? onPeerJoined;

  void log(String message) {
    _log.info(message);
    _logController.add(
      "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $message",
    );
  }

  Future<bool> doesRoomExist(String roomId) async {
    try {
      final res = await _db
          .from('rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      log('Error checking room existence: $e');
      return false;
    }
  }

  Future<void> createRoom(String roomId, User user) async {
    _currentRoomId = roomId;
    _isCaller = true;

    await _db.from('rooms').insert({
      'id': roomId,
      'created_at': DateTime.now().toIso8601String(),
      'caller_id': user.id,
      'caller_name': user.userMetadata?['full_name'] ?? 'Unknown',
    });
  }

  Future<void> joinRoom(String roomId, User user) async {
    _currentRoomId = roomId;
    _isCaller = false;

    final roomSnapshot = await _db
        .from('rooms')
        .select()
        .eq('id', roomId)
        .maybeSingle();

    if (roomSnapshot != null) {
      await _db
          .from('rooms')
          .update({
            'callee_id': user.id,
            'callee_name': user.userMetadata?['full_name'] ?? 'Unknown',
          })
          .eq('id', roomId);

      String? callerName = roomSnapshot['caller_name'];
      onJoinSuccess?.call(roomId, callerName);
    } else {
      _log.warning('Room $roomId does not exist!');
    }
  }

  void listenToRoom(String roomId) {
    _roomSubscription = _db
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .listen((snapshot) {
          if (snapshot.isEmpty) {
            log('Room was deleted, hanging up.');
            return;
          }

          final data = snapshot.first;

          if (_isCaller) {
            if (data['callee_name'] != null) {
              onPeerJoined?.call(data['callee_name']);
            }

            if (data['answer'] != null) {
              Map<String, dynamic> answer = data['answer'];
              onMessageReceived?.call({
                'type': 'answer',
                'sdp': answer['sdp'],
                'type_sdp': answer['type'],
              });
            }
          } else {
            if (data['offer'] != null) {
              Map<String, dynamic> offer = data['offer'];
              onMessageReceived?.call({
                'type': 'offer',
                'sdp': offer['sdp'],
                'type_sdp': offer['type'],
              });
            }
          }
        });

    String collectionToListen = _isCaller
        ? 'callee_candidates'
        : 'caller_candidates';

    _candidatesSubscription = _db
        .from(collectionToListen)
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .listen((snapshot) {
          for (var data in snapshot) {
            onMessageReceived?.call({
              'type': 'candidate',
              'candidate': data['candidate_data'],
            });
          }
        });
  }

  Future<void> sendSdp(String type, String sdp) async {
    if (_currentRoomId == null) return;

    await _db
        .from('rooms')
        .update({
          type: {'type': type, 'sdp': sdp},
        })
        .eq('id', _currentRoomId!);
  }

  Future<void> sendCandidate(Map<String, dynamic> candidate) async {
    if (_currentRoomId == null) return;

    String collectionToWrite = _isCaller
        ? 'caller_candidates'
        : 'callee_candidates';

    await _db.from(collectionToWrite).insert({
      'room_id': _currentRoomId,
      'candidate_data': candidate,
    });
  }

  Future<void> leave() async {
    if (_currentRoomId != null) {
      if (_isCaller) {
        await _db.from('rooms').delete().eq('id', _currentRoomId!);
      } else {
        await _db
            .from('rooms')
            .update({'callee_left': true})
            .eq('id', _currentRoomId!);
      }
    }

    _roomSubscription?.cancel();
    _candidatesSubscription?.cancel();
    _currentRoomId = null;
    _isCaller = false;
  }
}
