import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/company_service.dart';
import '../../services/file_service.dart';
import '../../screens/media_viewer_screen.dart';
import '../../providers/company_provider.dart';
import '../../theme.dart';

class CompanyChatArea extends StatefulWidget {
  final String companyId;
  final String channelId;
  final String channelName;
  final VoidCallback? onMenuPressed;

  const CompanyChatArea({
    super.key,
    required this.companyId,
    required this.channelId,
    required this.channelName,
    this.onMenuPressed,
  });

  @override
  State<CompanyChatArea> createState() => _CompanyChatAreaState();
}

class _CompanyChatAreaState extends State<CompanyChatArea> {
  final TextEditingController _controller = TextEditingController();
  final Map<String, String> _userNamesCache = {};
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMessageListener();
    });
  }

  @override
  void didUpdateWidget(CompanyChatArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _setupMessageListener();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    final companyService = Provider.of<CompanyService>(context, listen: false);
    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);

    _messageSubscription = companyService
        .streamChannelMessages(widget.companyId, widget.channelId)
        .listen((messages) {
      if (messages.isNotEmpty && mounted) {
        // If the last message is not from me and arrived after my last read
        // For simplicity, we just mark as read whenever the stream updates while looking at it
        companyProvider.markSelectedChannelAsRead();
      }
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final companyService = Provider.of<CompanyService>(context, listen: false);

    _controller.clear();

    try {
      await companyService.sendChannelMessage(
        companyId: widget.companyId,
        channelId: widget.channelId,
        senderId: user.id,
        text: text,
      );
      // Mark as read after sending
      if (mounted) {
        Provider.of<CompanyProvider>(context, listen: false).markSelectedChannelAsRead();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  Future<String> _fetchUserName(String uid) async {
    if (_userNamesCache.containsKey(uid)) {
      return _userNamesCache[uid]!;
    }
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();
      if (data != null) {
        final name = data['display_name'] ?? 'Unknown User';
        _userNamesCache[uid] = name;
        return name;
      }
    } catch (_) {}
    return 'Unknown User';
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, ThemeData theme) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMe)
          FutureBuilder<String>(
            future: _fetchUserName(msg.senderId),
            builder: (context, snapshot) {
              final name = snapshot.data ?? '...';
              return Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 2, top: 4),
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mediumGrey,
                  ),
                ),
              );
            },
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              top: isMe ? 4 : 0,
              bottom: 4,
              left: isMe ? 40 : 8,
              right: isMe ? 8 : 40,
            ),
            decoration: BoxDecoration(
              color: msg.type == MessageType.text
                  ? (isMe
                      ? AppColors.accentBlue.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: msg.type == MessageType.text && !isMe
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    )
                  : null,
              boxShadow: msg.type == MessageType.text
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: _buildMessageContent(msg, isMe, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContent(ChatMessage msg, bool isMe, ThemeData theme) {
    switch (msg.type) {
      case MessageType.image:
        return _buildImageBubble(msg);
      case MessageType.video:
        return _buildVideoBubble(msg);
      case MessageType.file:
        return _buildFileBubble(msg);
      case MessageType.location:
        return _buildLocationBubble(msg, isMe);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                msg.formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildImageBubble(ChatMessage msg) {
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
            color: Colors.grey[900],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
          fit: BoxFit.cover,
          width: 250,
        ),
      ),
    );
  }

  Widget _buildVideoBubble(ChatMessage msg) {
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
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black45,
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
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBubble(ChatMessage msg) {
    return GestureDetector(
      onTap: () async {
        final fileService = Provider.of<FileService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening file...')),
        );
        final file = await fileService.downloadToTemp(msg.mediaUrl!, msg.fileName ?? 'file');
        if (file != null) {
          await OpenFilex.open(file.path);
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
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: AppColors.accentBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.fileName ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    '${(msg.fileSize ?? 0) ~/ 1024} KB',
                    style: TextStyle(fontSize: 11, color: AppColors.mediumGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBubble(ChatMessage msg, bool isMe) {
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
          color: isMe ? AppColors.accentBlue : AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
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
                  color: Colors.white10,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.white10,
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
                      const Icon(Icons.location_on, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to view on Maps',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.deepNavy.withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(Icons.image, 'Image', AppColors.accentBlue, _pickImage),
                _buildAttachmentOption(Icons.videocam, 'Video', Colors.purple, _pickVideo),
                _buildAttachmentOption(Icons.insert_drive_file, 'File', Colors.orange, _pickDocument),
                _buildAttachmentOption(Icons.location_on, 'Location', Colors.green, _shareLocation),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _uploadAndSendMedia(image.path, image.name, MessageType.image);
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _uploadAndSendMedia(video.path, video.name, MessageType.video);
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.first;
      _uploadAndSendMedia(file.path!, file.name, MessageType.file, size: file.size);
    }
  }

  Future<void> _uploadAndSendMedia(String path, String name, MessageType type, {int? size}) async {
    final companyService = Provider.of<CompanyService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading...')));

    try {
      final url = await companyService.uploadFile(path, name);
      if (url != null) {
        final fileSize = size ?? await File(path).length();
        await companyService.sendChannelMediaMessage(
          companyId: widget.companyId,
          channelId: widget.channelId,
          senderId: user.id,
          type: type,
          mediaUrl: url,
          fileName: name,
          fileSize: fileSize,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
            const SnackBar(content: Text('Location permissions are permanently denied. Please enable them in app settings.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final companyService = Provider.of<CompanyService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        await companyService.sendChannelLocationMessage(
          companyId: widget.companyId,
          channelId: widget.channelId,
          senderId: user.id,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing location: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final companyService = Provider.of<CompanyService>(context);
    final user = authService.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Chat Header — glassmorphic
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (widget.onMenuPressed != null) ...[
                IconButton(
                  icon: Icon(Icons.menu, color: Colors.white.withValues(alpha: 0.5)),
                  onPressed: widget.onMenuPressed,
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chat_bubble_outline, color: Colors.white.withValues(alpha: 0.4), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.channelName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Chat Messages List
        Expanded(
          child: Container(
            color: Colors.transparent,
            child: StreamBuilder<List<ChatMessage>>(
              stream: companyService.streamChannelMessages(
                widget.companyId,
                widget.channelId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentBlue,
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: AppColors.mediumGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Welcome to the beginning of the channel!",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "This is the start of the #${widget.channelName} channel.",
                          style: const TextStyle(
                            color: AppColors.mediumGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == user.id;
                    return _buildMessageBubble(msg, isMe, Theme.of(context));
                  },
                );
              },
            ),
          ),
        ),

        // Message Input Area — glassmorphic
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message #${widget.channelName}',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                      prefixIcon: IconButton(
                        icon: Icon(Icons.add, color: Colors.white.withValues(alpha: 0.4)),
                        onPressed: _showAttachmentOptions,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentBlue,
                      AppColors.accentBlue.withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
