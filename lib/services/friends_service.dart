import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import '../models/user_model.dart';

class FriendsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _log = Logger('FriendsService');

  // Generate a short, unique friend code
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<bool> _isCodeUnique(String code) async {
    final res = await _supabase
        .from('users')
        .select('id')
        .eq('friend_code', code)
        .limit(1);
    return res.isEmpty;
  }

  Future<String> _generateUniqueFriendCode() async {
    while (true) {
      String code = _generateRandomCode();
      if (await _isCodeUnique(code)) return code;
    }
  }

  // Ensure user has a profile doc with a friend code
  Future<void> createOrUpdateUser(User user) async {
    final res = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) {
      // Create new user doc
      String code = await _generateUniqueFriendCode();
      await _supabase.from('users').insert({
        'id': user.id,
        'email': user.email ?? '',
        'display_name': user.userMetadata?['full_name'] ?? 'Unknown',
        'friend_code': code,
        'friends': [],
        'status': 'online',
        'last_seen': DateTime.now().toIso8601String(),
      });
    } else {
      // Update status to online
      Map<String, dynamic> updates = {
        'status': 'online',
        'display_name':
            user.userMetadata?['full_name'] ?? res['display_name'] ?? 'Unknown',
        'last_seen': DateTime.now().toIso8601String(),
      };

      // Backfill friend code if missing
      if (res['friend_code'] == null || res['friend_code'] == '') {
        updates['friend_code'] = await _generateUniqueFriendCode();
      }

      await _supabase.from('users').update(updates).eq('id', user.id);
    }
  }

  Future<void> setUserStatus(String uid, String status) async {
    await _supabase
        .from('users')
        .update({
          'status': status,
          'last_seen': DateTime.now().toIso8601String(),
        })
        .eq('id', uid);
  }

  // Send Connection Request
  Future<String> sendConnectionRequest(
    String currentUid,
    String friendCode,
  ) async {
    final res = await _supabase
        .from('users')
        .select()
        .eq('friend_code', friendCode)
        .limit(1);

    if (res.isEmpty) {
      throw 'Invalid Connect Code';
    }

    final friendMap = res.first;
    final receiverId = friendMap['id'];

    if (receiverId == currentUid) {
      throw 'You cannot connect with yourself';
    }

    final currentUserRes = await _supabase
        .from('users')
        .select('friends')
        .eq('id', currentUid)
        .single();
    List<dynamic> userFriends = currentUserRes['friends'] ?? [];

    if (userFriends.contains(receiverId)) {
      throw 'User is already your connection';
    }

    final existingRequests = await _supabase
        .from('connection_requests')
        .select()
        .or(
          'and(sender_id.eq.$currentUid,receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.$currentUid)',
        );

    for (var req in existingRequests) {
      if (req['status'] == 'pending') {
        throw 'Connection request already sent or pending';
      } else {
        await _supabase
            .from('connection_requests')
            .delete()
            .eq('id', req['id']);
      }
    }

    try {
      await _supabase.from('connection_requests').insert({
        'sender_id': currentUid,
        'receiver_id': receiverId,
        'status': 'pending',
      });
    } catch (e) {
      throw 'Connection request already sent or pending';
    }

    return friendMap['display_name'] ?? 'User';
  }

  // Refresh Connect Code
  Future<String> refreshConnectCode(String uid) async {
    String newCode = await _generateUniqueFriendCode();
    await _supabase
        .from('users')
        .update({'friend_code': newCode})
        .eq('id', uid);
    return newCode;
  }

  Stream<List<Map<String, dynamic>>> streamIncomingRequestsRaw(String uid) {
    _log.info('Subscribing to incoming requests for $uid');
    return _supabase
        .from('connection_requests')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', uid)
        .map((requests) {
          final pending = requests.where((req) => req['status'] == 'pending').toList();
          _log.info('Incoming requests update for $uid: raw=${requests.length}, pending=${pending.length}');
          for (var r in requests) {
            _log.finer('Request detail: id=${r['id']}, status=${r['status']}, receiver=${r['receiver_id']}');
          }
          return pending;
        });
  }

  Stream<List<Map<String, dynamic>>> streamIncomingRequests(String uid) {
    return streamIncomingRequestsRaw(uid).asyncMap((requests) async {
      if (requests.isEmpty) return [];

      final senderIds = requests.map((req) => req['sender_id'] as String).toList();
      
      try {
        final sendersRes = await _supabase
            .from('users')
            .select('id, display_name, email')
            .inFilter('id', senderIds);

        final senderMap = {for (var s in sendersRes) s['id']: s};

        return requests.map((req) {
          final sender = senderMap[req['sender_id']];
          return {
            ...req,
            'sender_name': sender?['display_name'] ?? 'Unknown',
            'sender_email': sender?['email'] ?? '',
          };
        }).toList();
      } catch (e) {
        // If enrichment fails, still return the raw requests so they can be dismissed/accepted
        return requests;
      }
    });
  }

  Stream<List<Map<String, dynamic>>> streamOutgoingRequestsRaw(String uid) {
    return _supabase
        .from('connection_requests')
        .stream(primaryKey: ['id'])
        .eq('sender_id', uid)
        .map((requests) =>
            requests.where((req) => req['status'] == 'pending').toList());
  }

  Stream<List<Map<String, dynamic>>> streamOutgoingRequests(String uid) {
    return streamOutgoingRequestsRaw(uid).asyncMap((requests) async {
      if (requests.isEmpty) return [];

      final receiverIds = requests.map((req) => req['receiver_id'] as String).toList();

      try {
        final receiversRes = await _supabase
            .from('users')
            .select('id, display_name, email')
            .inFilter('id', receiverIds);

        final receiverMap = {for (var r in receiversRes) r['id']: r};

        return requests.map((req) {
          final receiver = receiverMap[req['receiver_id']];
          return {
            ...req,
            'receiver_name': receiver?['display_name'] ?? 'Unknown',
            'receiver_email': receiver?['email'] ?? '',
          };
        }).toList();
      } catch (e) {
        return requests;
      }
    });
  }

  // Accept Connection Request
  Future<void> acceptRequest(String requestId, String currentUid) async {
    // Call the RPC function to bypass RLS and securely update both users' friend arrays
    await _supabase.rpc(
      'accept_connection_request',
      params: {'request_id': requestId},
    );
  }

  // Reject Request or Cancel Outgoing Request
  Future<void> rejectOrCancelRequest(String requestId) async {
    // Delete the request entirely to allow users to retry later, or we could set 'rejected' status. Let's delete it so they can resend later.
    await _supabase.from('connection_requests').delete().eq('id', requestId);
  }

  // Remove friend
  Future<void> removeFriend(String currentUid, String friendUid) async {
    await _supabase.rpc(
      'remove_connection',
      params: {'user1_id': currentUid, 'user2_id': friendUid},
    );
  }

  // Stream current user's profile
  Stream<UserModel?> streamUser(String uid) {
    return _supabase.from('users').stream(primaryKey: ['id']).eq('id', uid).map(
      (event) {
        if (event.isEmpty) return null;
        return UserModel.fromMap(event.first, event.first['id']);
      },
    );
  }

  // Stream list of friend UserModels
  Stream<List<UserModel>> streamFriends(String uid) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .asyncMap((userEvents) async {
          if (userEvents.isEmpty) return <UserModel>[];

          final data = userEvents.first;
          dynamic rawFriends = data['friends'];
          List<dynamic> friendIds = [];

          if (rawFriends is List) {
            friendIds = rawFriends;
          } else if (rawFriends is String) {
            String str = rawFriends.trim();
            if (str.startsWith('{') && str.endsWith('}')) {
              str = str.substring(1, str.length - 1);
              if (str.isNotEmpty) {
                friendIds = str.split(',').map((s) => s.trim()).toList();
              }
            }
          }

          if (friendIds.isEmpty) return <UserModel>[];

          List<UserModel> friends = [];

          for (var i = 0; i < friendIds.length; i += 10) {
            var end = (i + 10 < friendIds.length) ? i + 10 : friendIds.length;
            var subList = friendIds.sublist(i, end);

            final query = await _supabase
                .from('users')
                .select()
                .inFilter('id', subList);

            friends.addAll(query.map((d) => UserModel.fromMap(d, d['id'])));
          }

          return friends;
        });
  }

  // Get basic user info (for UI enrichment)
  Future<Map<String, dynamic>> getUserInfo(String uid) async {
    final res = await _supabase
        .from('users')
        .select('display_name, email')
        .eq('id', uid)
        .maybeSingle();
    return res ?? {'display_name': 'Unknown', 'email': ''};
  }
}
