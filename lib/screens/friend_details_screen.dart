import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../services/friends_service.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/signalling.dart';
import '../services/webrtc_service.dart';
import '../widgets/gradient_background.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';

class FriendDetailsScreen extends StatefulWidget {
  final UserModel friend;

  const FriendDetailsScreen({super.key, required this.friend});

  @override
  State<FriendDetailsScreen> createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends State<FriendDetailsScreen> {
  DateTime? _lastCallTime;
  bool _isLoadingCallTime = true;

  @override
  void initState() {
    super.initState();
    _fetchLastCallTime();
  }

  void _fetchLastCallTime() async {
    final callService = Provider.of<CallService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      final time = await callService.getLastCallTime(
        user.id,
        widget.friend.uid,
      );
      if (mounted) {
        setState(() {
          _lastCallTime = time;
          _isLoadingCallTime = false;
        });
      }
    }
  }

  // Reuse the logic from HomeScreen, but adapted
  void _startDirectCall(bool isVideo) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    final signalling = Provider.of<SignallingService>(context, listen: false);
    final webrtc = Provider.of<WebRTCService>(context, listen: false);

    final currentUser = authService.currentUser;

    if (currentUser == null) return;

    try {
      // 1. Create Call Document & Room ID
      final callInfo = await callService.startDirectCall(
        callerUid: currentUser.id,
        callerName: currentUser.userMetadata?['full_name'] ?? 'Unknown',
        calleeUid: widget.friend.uid,
        isVideo: isVideo,
      );

      final roomId = callInfo['roomId']!;
      final callId = callInfo['callId']!;

      // 2. Initialize WebRTC
      await webrtc.init();
      await webrtc.openUserMedia(isVideo);
      await webrtc.initializePeerConnection(null);

      // 3. Create Room (Caller Side)
      await signalling.createRoom(roomId, currentUser);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              roomId: roomId,
              callId: callId,
              isVideo: isVideo,
              isCaller: true,
              remoteName: widget.friend.displayName,
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

  void _removeFriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Connection'),
        content: Text(
          'Are you sure you want to remove ${widget.friend.displayName} from your connections?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;

    final friendsService = Provider.of<FriendsService>(context, listen: false);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    if (user == null) return;

    try {
      await friendsService.removeFriend(user.id, widget.friend.uid);
      if (mounted) {
        Navigator.of(
          context,
        ).popUntil((route) => route.isFirst); // Go straight to Home
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed connection: ${widget.friend.displayName}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing friend: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.friend.displayName),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundImage: widget.friend.avatarUrl != null
                      ? NetworkImage(widget.friend.avatarUrl!)
                      : null,
                  child: widget.friend.avatarUrl == null
                      ? Text(
                          widget.friend.displayName[0],
                          style: const TextStyle(fontSize: 40),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                // Name
                Text(
                  widget.friend.displayName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                // Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: widget.friend.status == 'online'
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.friend.status.toUpperCase(),
                      style: const TextStyle(letterSpacing: 1.2),
                    ),
                  ],
                ),
                // Last Seen & Last Call
                const SizedBox(height: 24),
                _buildInfoRow(
                  context,
                  'Last Seen',
                  _formatLastSeen(widget.friend),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Last Call',
                  _formatLastCall(_lastCallTime),
                ),
                const SizedBox(height: 40),

                // Actions Grid
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ActionButton(
                      icon: Icons.videocam,
                      label: 'Video',
                      color: Colors.blue,
                      onTap: () => _startDirectCall(true),
                    ),
                    _ActionButton(
                      icon: Icons.phone,
                      label: 'Voice',
                      color: Colors.green,
                      onTap: () => _startDirectCall(false),
                    ),
                    StreamBuilder<int>(
                      stream: chatService.streamUnreadCount(
                        authService.currentUser!.id,
                        widget.friend.uid,
                      ),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return Badge(
                          label: Text(unreadCount.toString()),
                          isLabelVisible: unreadCount > 0,
                          backgroundColor: Colors.red,
                          child: _ActionButton(
                            icon: Icons.chat_bubble,
                            label: 'Message',
                            color: Colors.orange,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    friendUid: widget.friend.uid,
                                    friendName: widget.friend.displayName,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Remove Connection Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _removeFriend,
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Remove Connection'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }

  String _formatLastSeen(UserModel user) {
    if (user.status == 'online') return 'Online Now';
    if (user.lastSeen == null) return 'Unknown';
    return timeago.format(user.lastSeen!);
  }

  String _formatLastCall(DateTime? lastCall) {
    if (_isLoadingCallTime) return 'Loading...';
    if (lastCall == null) return 'No calls yet';
    return DateFormat.yMMMd().add_jm().format(lastCall);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(40),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
