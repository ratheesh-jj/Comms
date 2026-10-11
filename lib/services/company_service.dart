import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/company_model.dart';
import '../models/channel_model.dart';
import '../models/chat_message.dart';

class CompanyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Company Methods
  Future<String> createCompany(
    String name,
    String ownerId,
    String iconUrl,
    String bannerUrl,
    String description,
    List<String> tags,
  ) async {
    final response = await _supabase
        .from('companies')
        .insert({
          'name': name,
          'owner_id': ownerId,
          'icon_url': iconUrl,
          'banner_url': bannerUrl,
          'description': description,
          'tags': tags,
          'members': [ownerId],
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    final String companyId = response['id'];

    // Create default 'Text Channels' category
    final categoryId = await createChannelCategoryReturnsId(
      companyId,
      'Text Channels',
    );

    // Create default 'general' channel
    await createChannel(companyId, categoryId, 'general', ChannelType.text);

    return companyId;
  }

  Future<void> updateCompany({
    required String companyId,
    required String name,
    required String iconUrl,
    required String bannerUrl,
    required String description,
    required List<String> tags,
  }) async {
    await _supabase
        .from('companies')
        .update({
          'name': name,
          'icon_url': iconUrl,
          'banner_url': bannerUrl,
          'description': description,
          'tags': tags,
        })
        .eq('id', companyId);
  }

  Future<void> deleteCompany(String companyId) async {
    await _supabase.from('companies').delete().eq('id', companyId);
  }

  Stream<List<Company>> getUserCompanies(String userId) {
    return _supabase.from('companies').stream(primaryKey: ['id']).map((
      snapshot,
    ) {
      // Filter locally because arrayContains isn't natively supported in stream filters
      return snapshot
          .where((doc) => (doc['members'] as List<dynamic>).contains(userId))
          .map((doc) => Company.fromMap(doc, doc['id']))
          .toList();
    });
  }

  Stream<Company> getCompanyStream(String companyId) {
    return _supabase
        .from('companies')
        .stream(primaryKey: ['id'])
        .eq('id', companyId)
        .map((snapshot) {
          if (snapshot.isEmpty) throw 'Company not found';
          final data = snapshot.first;
          return Company.fromMap(data, data['id']);
        });
  }

  Future<void> inviteUser(String companyId, String targetFriendCode) async {
    final query = await _supabase
        .from('users')
        .select('id')
        .eq('friend_code', targetFriendCode)
        .limit(1);

    if (query.isEmpty) {
      throw 'Invalid Connect Code';
    }

    final targetUserId = query.first['id'];

    final companySnapshot = await _supabase
        .from('companies')
        .select('members')
        .eq('id', companyId)
        .single();
    List<dynamic> members = companySnapshot['members'] ?? [];

    if (!members.contains(targetUserId)) {
      members.add(targetUserId);
      await _supabase
          .from('companies')
          .update({'members': members})
          .eq('id', companyId);
    }
  }

  // Channel & Category Methods
  Future<void> createChannelCategory(String companyId, String name) async {
    await createChannelCategoryReturnsId(companyId, name);
  }

  Future<String> createChannelCategoryReturnsId(
    String companyId,
    String name,
  ) async {
    final response = await _supabase
        .from('channel_categories')
        .insert({'company_id': companyId, 'name': name, 'sort_order': 0})
        .select('id')
        .single();

    return response['id'];
  }

  Future<void> createChannel(
    String companyId,
    String categoryId,
    String name,
    ChannelType type,
  ) async {
    await _supabase.from('channels').insert({
      'company_id': companyId,
      'category_id': categoryId,
      'name': name,
      'type': type.toString().split('.').last,
      'sort_order': 0,
    });
  }

  Future<void> deleteChannel(String channelId) async {
    // Delete related messages first
    await _supabase
        .from('channel_messages')
        .delete()
        .eq('channel_id', channelId);

    // Delete read states
    await _supabase
        .from('channel_read_states')
        .delete()
        .eq('channel_id', channelId);

    // Delete voice room participants if any
    await _supabase
        .from('voice_room_participants')
        .delete()
        .eq('channel_id', channelId);

    // Delete the channel itself
    await _supabase.from('channels').delete().eq('id', channelId);
  }


  Stream<List<ChannelCategory>> getCategories(String companyId) {
    return _supabase
        .from('channel_categories')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('sort_order', ascending: true)
        .map(
          (snapshot) => snapshot
              .map((doc) => ChannelCategory.fromMap(doc, doc['id']))
              .toList(),
        );
  }

  Stream<List<Channel>> getChannels(String companyId) {
    return _supabase
        .from('channels')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('sort_order', ascending: true)
        .map(
          (snapshot) =>
              snapshot.map((doc) => Channel.fromMap(doc, doc['id'])).toList(),
        );
  }

  // Channel Messaging Methods
  Future<void> sendChannelMessage({
    required String companyId,
    required String channelId,
    required String senderId,
    required String text,
  }) async {
    await _supabase.from('channel_messages').insert({
      'channel_id': channelId,
      'sender_id': senderId,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'text',
      'is_read': false,
    });
  }

  Stream<List<ChatMessage>> streamChannelMessages(
    String companyId,
    String channelId,
  ) {
    return _supabase
        .from('channel_messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('timestamp', ascending: false)
        .map((snapshot) {
          return snapshot.map((doc) {
            return ChatMessage.fromMap(doc, doc['id']);
          }).toList();
        });
  }

  // Mark channel as read for a user
  Future<void> markChannelAsRead(String userId, String channelId) async {
    await _supabase.from('channel_read_states').upsert({
      'user_id': userId,
      'channel_id': channelId,
      'last_read_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,channel_id');
  }

  // Stream unread count for a specific channel
  Stream<int> streamChannelUnreadCount(String userId, String channelId) {
    // 1. Get the last read timestamp
    final readStateStream = _supabase
        .from('channel_read_states')
        .stream(primaryKey: ['id']);

    // 2. Combine with message stream to count unreads
    return readStateStream.asyncExpand((readStates) {
      final myReadStates = readStates.where((r) => r['user_id'] == userId && r['channel_id'] == channelId);
      final DateTime lastReadAt = myReadStates.isEmpty
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(myReadStates.first['last_read_at'].toString());

      return _supabase
          .from('channel_messages')
          .stream(primaryKey: ['id'])
          .map((messages) {
            return messages.where((m) {
              final DateTime msgTime = DateTime.parse(m['timestamp'].toString());
              return m['channel_id'] == channelId && m['sender_id'] != userId && msgTime.isAfter(lastReadAt);
            }).length;
          });
    });
  }

  // Stream total unread count for a company
  Stream<int> streamCompanyUnreadCount(String userId, String companyId) {
    return _supabase
        .from('channels')
        .stream(primaryKey: ['id'])
        .asyncExpand((allChannels) {
      final channels = allChannels.where((c) => c['company_id'] == companyId).toList();
      if (channels.isEmpty) return Stream.value(0);

      return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        int total = 0;
        for (final channelData in channels) {
          final count = await streamChannelUnreadCount(userId, channelData['id']).first;
          total += count;
        }
        return total;
      }).distinct();
    });
  }

  // Upload company asset (logo or banner) to Supabase Storage
  Future<String?> uploadCompanyAsset(File file, String assetType) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final extension = fileName.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'company_$assetType/$timestamp.$extension';

      await _supabase.storage.from('uploads').upload(storagePath, file);
      
      final String publicUrl = _supabase.storage.from('uploads').getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      print('Error uploading company asset: $e');
      throw Exception('Failed to upload company ${assetType}: $e');
    }
  }

  // Upload file to Supabase Storage
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final extension = fileName.split('.').last;
      final path = 'channel_media/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _supabase.storage.from('chat_media').upload(path, file);
      
      final String publicUrl = _supabase.storage.from('chat_media').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Send Channel Media Message
  Future<void> sendChannelMediaMessage({
    required String companyId,
    required String channelId,
    required String senderId,
    required MessageType type,
    required String mediaUrl,
    required String fileName,
    required int fileSize,
  }) async {
    String typeStr;
    switch (type) {
      case MessageType.image: typeStr = 'image'; break;
      case MessageType.video: typeStr = 'video'; break;
      case MessageType.file: typeStr = 'file'; break;
      default: typeStr = 'text';
    }

    await _supabase.from('channel_messages').insert({
      'channel_id': channelId,
      'sender_id': senderId,
      'text': 'Sent a ${typeStr}',
      'type': typeStr,
      'media_url': mediaUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'is_read': false,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Send Channel Location Message
  Future<void> sendChannelLocationMessage({
    required String companyId,
    required String channelId,
    required String senderId,
    required double latitude,
    required double longitude,
  }) async {
    await _supabase.from('channel_messages').insert({
      'channel_id': channelId,
      'sender_id': senderId,
      'text': 'Shared location',
      'type': 'location',
      'latitude': latitude,
      'longitude': longitude,
      'is_read': false,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
