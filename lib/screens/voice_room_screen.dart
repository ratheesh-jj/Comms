import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/voice_room_service.dart';
import '../services/webrtc_service.dart';
import '../services/signalling.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/gradient_background.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final String companyId;

  const VoiceRoomScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.companyId,
  });

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen>
    with TickerProviderStateMixin {
  final VoiceRoomService _voiceRoomService = VoiceRoomService();
  StreamSubscription<List<VoiceRoomParticipant>>? _participantsSub;
  List<VoiceRoomParticipant> _participants = [];

  bool _isMuted = false;
  bool _isDeafened = false;
  bool _isConnecting = true;
  String? _userId;
  String? _userName;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });
  }

  Future<void> _joinRoom() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    _userId = user.id;
    _userName = user.userMetadata?['full_name'] ?? 'Unknown';

    // Join the voice room in Supabase
    await _voiceRoomService.joinVoiceChannel(
      channelId: widget.channelId,
      userId: _userId!,
      userName: _userName!,
    );

    // Listen to participants
    _participantsSub =
        _voiceRoomService.streamParticipants(widget.channelId).listen((
      participants,
    ) {
      if (mounted) {
        setState(() {
          _participants = participants;
          _isConnecting = false;
        });
        _fadeController.forward();
      }
    });

    // Initialize WebRTC audio
    try {
      final webrtc = Provider.of<WebRTCService>(context, listen: false);
      await webrtc.openUserMedia(false); // Audio only

      final signalling =
          Provider.of<SignallingService>(context, listen: false);

      // Use channel ID as the room ID for signalling
      final roomId = 'voice-${widget.channelId}';

      // Check if room exists, create or join
      final exists = await signalling.doesRoomExist(roomId);
      if (!exists) {
        await signalling.createRoom(
          roomId,
          Supabase.instance.client.auth.currentUser!,
        );
      } else {
        await signalling.joinRoom(
          roomId,
          Supabase.instance.client.auth.currentUser!,
        );
      }

      signalling.listenToRoom(roomId);

      // If we created the room, wait for others. If we joined, auto-connect.
      if (exists) {
        await webrtc.startCall(roomId);
      }
    } catch (e) {
      debugPrint('Voice room WebRTC error: $e');
    }
  }

  Future<void> _leaveRoom() async {
    // Cancel the participant stream subscription first
    _participantsSub?.cancel();

    // Navigate away immediately so the user is never stuck
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Clean up in the background — errors should not block navigation
    try {
      if (_userId != null) {
        await _voiceRoomService.leaveVoiceChannel(
          channelId: widget.channelId,
          userId: _userId!,
        );
      }
    } catch (e) {
      debugPrint('Error leaving voice channel: $e');
    }

    try {
      final webrtc = Provider.of<WebRTCService>(context, listen: false);
      await webrtc.hangUp();
    } catch (e) {
      debugPrint('Error hanging up: $e');
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    try {
      Provider.of<WebRTCService>(context, listen: false).toggleMic();
    } catch (e) {
      debugPrint('Error toggling mic: $e');
    }

    if (_userId != null) {
      _voiceRoomService.updateMuteState(
        channelId: widget.channelId,
        userId: _userId!,
        isMuted: _isMuted,
      );
    }
  }

  void _toggleDeafen() {
    setState(() {
      _isDeafened = !_isDeafened;
      if (_isDeafened && !_isMuted) {
        _isMuted = true;
        try {
          Provider.of<WebRTCService>(context, listen: false).toggleMic();
        } catch (e) {
          debugPrint('Error toggling mic: $e');
        }
      }
    });

    if (_userId != null) {
      _voiceRoomService.updateMuteState(
        channelId: widget.channelId,
        userId: _userId!,
        isMuted: _isMuted,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _participantsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: _leaveRoom,
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Room Header
              _buildRoomHeader(),

              const SizedBox(height: 32),

              // Participants Grid
              Expanded(
                child: _isConnecting
                    ? _buildConnectingState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildParticipantsGrid(),
                      ),
              ),

              // Bottom Controls
              _buildBottomControls(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mic_none,
              color: AppColors.accentBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.channelName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isConnecting
                      ? 'Connecting...'
                      : '${_participants.length} ${_participants.length == 1 ? 'participant' : 'participants'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Connection indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isConnecting
                      ? Colors.amber
                      : Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isConnecting
                              ? Colors.amber
                              : Colors.greenAccent)
                          .withValues(alpha: _pulseAnimation.value * 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.accentBlue.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.headset,
                    size: 40,
                    color: AppColors.accentBlue.withValues(alpha: 0.7),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Joining voice channel...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid() {
    if (_participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No one else is here yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite others to join this voice channel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _participants.length <= 2 ? 1 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: _participants.length <= 2 ? 2.5 : 1.0,
        ),
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          return _buildParticipantTile(_participants[index]);
        },
      ),
    );
  }

  Widget _buildParticipantTile(VoiceRoomParticipant participant) {
    final isCurrentUser = participant.userId == _userId;
    final isSpeaking = !participant.isMuted; // Simplified speaking indicator

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final speakingScale =
            isSpeaking ? 1.0 + (_pulseAnimation.value - 1.0) * 0.3 : 1.0;

        return Transform.scale(
          scale: isSpeaking ? speakingScale : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSpeaking
                    ? AppColors.accentBlue.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
                width: isSpeaking ? 2 : 1,
              ),
              boxShadow: isSpeaking
                  ? [
                      BoxShadow(
                        color: AppColors.accentBlue.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isCurrentUser
                              ? [
                                  AppColors.accentBlue.withValues(alpha: 0.6),
                                  AppColors.lightBlue.withValues(alpha: 0.4),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                        ),
                        border: Border.all(
                          color: isSpeaking
                              ? AppColors.accentBlue.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          participant.userName.isNotEmpty
                              ? participant.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Mute indicator
                    if (participant.isMuted)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Name
                Text(
                  isCurrentUser
                      ? '${participant.userName} (You)'
                      : participant.userName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight:
                        isCurrentUser ? FontWeight.bold : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Unmute' : 'Mute',
            isActive: _isMuted,
            activeColor: Colors.red,
            onTap: _toggleMute,
          ),

          // Deafen Button
          _buildControlButton(
            icon: _isDeafened ? Icons.headset_off : Icons.headset,
            label: _isDeafened ? 'Undeafen' : 'Deafen',
            isActive: _isDeafened,
            activeColor: Colors.red,
            onTap: _toggleDeafen,
          ),

          // Disconnect Button
          _buildControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: true,
            activeColor: Colors.red,
            isDestructive: true,
            onTap: _leaveRoom,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red.withValues(alpha: 0.8)
                  : isActive
                      ? activeColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDestructive
                    ? Colors.red
                    : isActive
                        ? activeColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: isDestructive
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isDestructive
                  ? Colors.white
                  : isActive
                      ? activeColor
                      : Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isDestructive
                  ? Colors.red.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
