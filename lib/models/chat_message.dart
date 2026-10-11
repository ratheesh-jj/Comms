import 'package:intl/intl.dart';

enum MessageType { text, call, image, video, file, location }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final int? callDurationSeconds; // For call type messages
  final bool? isVideoCall; // For call type messages
  final bool isRead; // Whether the message has been read by receiver
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final double? latitude;
  final double? longitude;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.callDurationSeconds,
    this.isVideoCall,
    this.isRead = false,
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.latitude,
    this.longitude,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    MessageType type;
    switch (map['type']) {
      case 'call':
        type = MessageType.call;
        break;
      case 'image':
        type = MessageType.image;
        break;
      case 'video':
        type = MessageType.video;
        break;
      case 'file':
        type = MessageType.file;
        break;
      case 'location':
        type = MessageType.location;
        break;
      default:
        type = MessageType.text;
    }

    return ChatMessage(
      id: id,
      senderId: map['sender_id'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'].toString())
          : DateTime.now(),
      type: type,
      callDurationSeconds: map['call_duration_seconds'],
      isVideoCall: map['is_video_call'],
      isRead: map['is_read'] ?? false,
      mediaUrl: map['media_url'],
      fileName: map['file_name'],
      fileSize: map['file_size'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    String typeStr;
    switch (type) {
      case MessageType.call:
        typeStr = 'call';
        break;
      case MessageType.image:
        typeStr = 'image';
        break;
      case MessageType.video:
        typeStr = 'video';
        break;
      case MessageType.file:
        typeStr = 'file';
        break;
      case MessageType.location:
        typeStr = 'location';
        break;
      default:
        typeStr = 'text';
    }

    return {
      'sender_id': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'type': typeStr,
      'is_read': isRead,
      if (callDurationSeconds != null)
        'call_duration_seconds': callDurationSeconds,
      if (isVideoCall != null) 'is_video_call': isVideoCall,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Get formatted time (e.g., "2:30 PM")
  String get formattedTime {
    return DateFormat.jm().format(timestamp);
  }

  /// Get DateTime from timestamp
  DateTime get dateTime => timestamp;

  /// Format call duration as "Xm Ys" or "Xh Ym"
  String get formattedCallDuration {
    if (callDurationSeconds == null) return '';
    final mins = callDurationSeconds! ~/ 60;
    final secs = callDurationSeconds! % 60;
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remainMins = mins % 60;
      return '${hours}h ${remainMins}m';
    }
    return '${mins}m ${secs}s';
  }
}
