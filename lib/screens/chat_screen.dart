import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';

import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/file_service.dart';
import '../services/call_service.dart';
import '../services/signalling.dart';
import '../services/webrtc_service.dart';
import '../widgets/gradient_background.dart';
import 'call_screen.dart';
import 'friend_details_screen.dart';
import 'media_viewer_screen.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  final String friendUid;
  final String friendName;

  const ChatScreen({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    final chatService = Provider.of<ChatService>(context, listen: false);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _messageSubscription = chatService
          .streamMessages(user.id, widget.friendUid)
          .listen((messages) {
            final unreadMessages = messages
                .where((m) => m.senderId == widget.friendUid && !m.isRead)
                .toList();

            if (unreadMessages.isNotEmpty) {
              chatService.markMessagesAsRead(
                user.id,
                widget.friendUid,
                unreadMessages,
              );
            }
          });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startDirectCall(bool isVideo) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    final signalling = Provider.of<SignallingService>(context, listen: false);
    final webrtc = Provider.of<WebRTCService>(context, listen: false);

    final currentUser = authService.currentUser;

    if (currentUser == null) return;

    try {
      final callInfo = await callService.startDirectCall(
        callerUid: currentUser.id,
        callerName: currentUser.userMetadata?['full_name'] ?? 'Unknown',
        calleeUid: widget.friendUid,
        isVideo: isVideo,
      );

      final roomId = callInfo['roomId']!;
      final callId = callInfo['callId']!;

      await webrtc.init();
      await webrtc.openUserMedia(isVideo);
      await webrtc.initializePeerConnection(null);

      await signalling.createRoom(roomId, currentUser);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              roomId: roomId,
              callId: callId,
              isVideo: isVideo,
              isCaller: true,
              remoteName: widget.friendName,
              remoteUid: widget.friendUid,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        await chatService.sendMessage(
          currentUid: user.id,
          friendUid: widget.friendUid,
          text: text,
        );
        _controller.clear();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')),
          );
        }
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location'),
              onTap: () {
                Navigator.pop(context);
                _shareLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _handleUploadAndSend(image.path, image.name, MessageType.image);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _handleUploadAndSend(video.path, video.name, MessageType.video);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      _handleUploadAndSend(file.path!, file.name, MessageType.file);
    }
  }

  Future<void> _handleUploadAndSend(
    String filePath,
    String fileName,
    MessageType type,
  ) async {
    final file = File(filePath);
    final size = await file.length();

    // 5MB Limit
    if (size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File size must be under 5MB')),
        );
      }
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading...')),
        );
      }

      final url = await chatService.uploadFile(filePath, fileName);
      if (url != null) {
        await chatService.sendMediaMessage(
          currentUid: user.id,
          friendUid: widget.friendUid,
          type: type,
          mediaUrl: url,
          fileName: fileName,
          fileSize: size,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed')),
          );
        }
      }
    }
  }

  Future<void> _shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // WhatsApp-like prompt
        if (mounted) {
          bool? shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.darkBlue,
              title: const Text('Location Services Disabled', style: TextStyle(color: Colors.white)),
              content: const Text(
                'To share your location, please turn on location services in your device settings.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL', style: TextStyle(color: AppColors.accentBlue)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('SETTINGS', style: TextStyle(color: AppColors.accentBlue)),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await Geolocator.openLocationSettings();
          }
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable them in app settings.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final authService = Provider.of<AuthService>(context, listen: false);
      final chatService = Provider.of<ChatService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        await chatService.sendLocationMessage(
          currentUid: user.id,
          friendUid: widget.friendUid,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing location: $e')),
        );
      }
    }
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    bool isMe,
    ThemeData theme, {
    bool showSeen = false,
  }) {
    Widget content;
    switch (msg.type) {
      case MessageType.image:
        content = _buildImageBubble(msg, theme);
        break;
      case MessageType.video:
        content = _buildVideoBubble(msg, theme);
        break;
      case MessageType.file:
        content = _buildFileBubble(msg, theme);
        break;
      case MessageType.location:
        content = _buildLocationBubble(msg, theme);
        break;
      case MessageType.call:
        content = _buildCallBubble(msg, isMe, theme);
        break;
      default:
        content = Text(
          msg.text,
          style: TextStyle(
            color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        );
    }

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: msg.type == MessageType.text
                ? const EdgeInsets.symmetric(vertical: 10, horizontal: 14)
                : EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: msg.type == MessageType.text
                  ? (isMe ? theme.colorScheme.primary : theme.colorScheme.surface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: (isMe || msg.type != MessageType.text)
                  ? null
                    : Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
            ),
            child: content,
          ),
        ),
        if (showSeen && isMe && msg.isRead)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Text(
              'Seen',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageBubble(ChatMessage msg, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              url: msg.mediaUrl!,
              fileName: msg.fileName ?? 'Image',
              type: MessageType.image,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: msg.mediaUrl!,
          placeholder: (context, url) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          fit: BoxFit.cover,
          width: 250,
        ),
      ),
    );
  }

  Widget _buildVideoBubble(ChatMessage msg, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              url: msg.mediaUrl!,
              fileName: msg.fileName ?? 'Video',
              type: MessageType.video,
            ),
          ),
        );
      },
      child: Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
              const SizedBox(height: 8),
              Text(
                msg.fileName ?? 'Video',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBubble(ChatMessage msg, ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        final fileService = Provider.of<FileService>(context, listen: false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening file...')),
        );

        final file = await fileService.downloadToTemp(msg.mediaUrl!, msg.fileName ?? 'file');
        if (file != null) {
          await OpenFilex.open(file.path);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to open file')),
            );
          }
        }
      },
      onLongPress: () async {
        final fileService = Provider.of<FileService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading...')),
        );
        final result = await fileService.saveToPublicStorage(msg.mediaUrl!, msg.fileName ?? 'file');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result?.contains('/') == true ? 'Saved to Downloads' : result ?? 'Download failed')),
          );
        }
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.fileName ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(msg.fileSize ?? 0) ~/ 1024} KB',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBubble(ChatMessage msg, ThemeData theme) {
    final lat = msg.latitude!;
    final lng = msg.longitude!;
    // Yandex Static API: ll=long,lat  pt=long,lat,style
    final mapUrl = 'https://static-maps.yandex.ru/1.x/?ll=$lng,$lat&z=13&l=map&size=450,250&pt=$lng,$lat,pm2rdm';
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
          await launchUrl(
            Uri.parse(googleMapsUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: mapUrl,
                width: 250,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.grey[800],
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.grey[900],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, color: Colors.white24, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Map Preview Unavailable',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Info Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Shared Location',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view on Maps',
                    style: TextStyle(color: AppColors.accentBlue, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallBubble(ChatMessage msg, bool isMe, ThemeData theme) {
    final isVideo = msg.isVideoCall ?? false;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.phone,
              size: 18,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVideo ? 'Video call' : 'Voice call',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${msg.formattedCallDuration} • ${msg.formattedTime}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: InkWell(
          onTap: () async {
            final userDoc = await Supabase.instance.client
                .from('users')
                .select()
                .eq('id', widget.friendUid)
                .maybeSingle();
            if (userDoc != null && mounted) {
              final friendModel = UserModel.fromMap(userDoc, userDoc['id']);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FriendDetailsScreen(friend: friendModel),
                ),
              );
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.friendName),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _startDirectCall(true),
          ),
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _startDirectCall(false),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: chatService.streamMessages(user.id, widget.friendUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data ?? [];

                    // Find the most recent message sent by ME that is read
                    String? lastSeenId;
                    for (final m in messages) {
                      if (m.senderId == user.id && m.isRead) {
                        lastSeenId = m.id;
                        break;
                      }
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet. Say hi!',
                          style: TextStyle(
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == user.id;

                        // Check if we need to show a date header
                        bool showDateHeader = false;
                        bool showTimeHeader = false;

                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final msgDay = DateTime(
                          msg.dateTime.year,
                          msg.dateTime.month,
                          msg.dateTime.day,
                        );
                        final isToday = msgDay == today;

                        if (index == messages.length - 1) {
                          showDateHeader = true;
                          if (isToday) showTimeHeader = true;
                        } else {
                          final prevMsg = messages[index + 1];
                          final prevDate = DateTime(
                            prevMsg.dateTime.year,
                            prevMsg.dateTime.month,
                            prevMsg.dateTime.day,
                          );
                          if (msgDay != prevDate) {
                            showDateHeader = true;
                            if (isToday) showTimeHeader = true;
                          } else if (isToday) {
                            final msgTime5 = (msg.dateTime.hour * 60 + msg.dateTime.minute) ~/ 5;
                            final prevTime5 = (prevMsg.dateTime.hour * 60 + prevMsg.dateTime.minute) ~/ 5;
                            if (msgTime5 != prevTime5) {
                              showTimeHeader = true;
                            }
                          }
                        }

                        String formatDateHeader(DateTime dt) {
                          final yesterday = today.subtract(const Duration(days: 1));
                          final dDay = DateTime(dt.year, dt.month, dt.day);

                          if (dDay == today) return 'Today';
                          if (dDay == yesterday) return 'Yesterday';
                          if (now.difference(dt).inDays < 7) {
                            return DateFormat.EEEE().format(dt);
                          }
                          return DateFormat.yMMMd().format(dt);
                        }

                        return Column(
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  formatDateHeader(msg.dateTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            if (showTimeHeader && !showDateHeader)
                              Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 4),
                                child: Text(
                                  msg.formattedTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                            if (msg.type == MessageType.call)
                              _buildCallBubble(msg, isMe, theme)
                            else
                              _buildMessageBubble(
                                msg,
                                isMe,
                                theme,
                                showSeen: msg.id == lastSeenId,
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: theme.colorScheme.primary,
                      onPressed: _showAttachmentOptions,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant ??
                              (isDark ? Colors.grey[900] : Colors.grey[200]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: theme.colorScheme.primary,
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
