import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/webrtc_service.dart';
import '../services/signalling.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';

class CallScreen extends StatefulWidget {
  final String roomId;
  final bool isVideo;
  final bool isCaller;
  final String? remoteName;
  final String? remoteUid;
  final String? callId;

  const CallScreen({
    super.key,
    required this.roomId,
    required this.isVideo,
    required this.isCaller,
    this.remoteName,
    this.remoteUid,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMicMuted = false;
  String? _remoteName;
  DateTime? _callConnectedTime;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  String? _remoteUid;

  @override
  void initState() {
    super.initState();
    _remoteName = widget.remoteName;
    _remoteUid = widget.remoteUid;

    // Listen for peer joining (if we are caller and waiting)
    final signalling = Provider.of<SignallingService>(context, listen: false);
    signalling.onPeerJoined = (name) {
      if (mounted) {
        setState(() {
          _remoteName = name ?? 'Unknown';
        });
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final webrtc = Provider.of<WebRTCService>(context, listen: false);
      webrtc.onRemoteStream = () {
        if (mounted) setState(() {});
      };
      webrtc.onConnectionState = (state) {
        if (mounted) {
          setState(() {});
          // Start timer when connected
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
              _callConnectedTime == null) {
            _callConnectedTime = DateTime.now();
            _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (mounted) {
                setState(() {
                  _callDurationSeconds = DateTime.now()
                      .difference(_callConnectedTime!)
                      .inSeconds;
                });
              }
            });
          }
        }
      };

      // Start listening to room events now that UI is ready
      signalling.listenToRoom(widget.roomId);

      if (webrtc.remoteRenderer.srcObject != null) {
        setState(() {});
      }

      if (widget.isCaller) {
        webrtc.startCall(widget.roomId);
      }
    });

    if (widget.callId != null) {
      final callService = Provider.of<CallService>(context, listen: false);
      _callSubscription = callService.listenToCallState(widget.callId!).listen((
        snapshot,
      ) {
        if (snapshot != null) {
          final data = snapshot;
          if (data['status'] == 'rejected') {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Call Declined')));
              Navigator.of(context).pop();
            }
          }
        }
      });
    }
  }

  StreamSubscription? _callSubscription;

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSubscription?.cancel();
    Provider.of<SignallingService>(context, listen: false).onPeerJoined = null;
    Provider.of<WebRTCService>(context, listen: false).hangUp();
    super.dispose();
  }

  void _hangUp() async {
    _durationTimer?.cancel();
    Provider.of<WebRTCService>(context, listen: false).hangUp();
    if (widget.callId != null) {
      Provider.of<CallService>(context, listen: false).endCall(widget.callId!);
    }

    // Save call to chat history if we had a connection
    if (_callDurationSeconds > 0 && _remoteUid != null) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final chatService = Provider.of<ChatService>(context, listen: false);
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        try {
          await chatService.saveCallToChat(
            callerUid: widget.isCaller ? currentUser.id : _remoteUid!,
            calleeUid: widget.isCaller ? _remoteUid! : currentUser.id,
            isVideo: widget.isVideo,
            durationSeconds: _callDurationSeconds,
          );
        } catch (e) {
          // Silent fail - don't block hangup
        }
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMic() {
    Provider.of<WebRTCService>(context, listen: false).toggleMic();
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
  }

  void _switchCamera() {
    Provider.of<WebRTCService>(context, listen: false).switchCamera();
  }

  void _connect() {
    // Manually trigger offer for now to simplify who starts
    Provider.of<WebRTCService>(context, listen: false).startCall(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final webrtc = Provider.of<WebRTCService>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Room: ${widget.roomId}'),
            const Spacer(),
            if (webrtc.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected)
              const Icon(Icons.circle, color: Colors.green, size: 12)
            else
              const Icon(Icons.circle, color: Colors.red, size: 12),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Remote Video (Full Screen)
          Positioned.fill(
            child:
                widget.isVideo &&
                    webrtc.connectionState ==
                        RTCPeerConnectionState
                            .RTCPeerConnectionStateConnected &&
                    webrtc.remoteRenderer.srcObject != null &&
                    webrtc.remoteRenderer.srcObject!.getVideoTracks().isNotEmpty
                ? RTCVideoView(
                    webrtc.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (webrtc.connectionState ==
                              RTCPeerConnectionState
                                  .RTCPeerConnectionStateConnected) ...[
                            const Icon(
                              Icons.mic,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Connected to ${_remoteName ?? 'Peer'}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ] else ...[
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.isCaller
                                  ? 'Waiting for others...'
                                  : 'Connecting...',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            'Room: ${widget.roomId}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Local Video (Overlay)
          if (widget.isVideo)
            Positioned(
              right: 20,
              top: 20,
              width: 120,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  color: Colors.black54,
                ),
                child: RTCVideoView(
                  webrtc.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Removed Manual Connect Button to favor auto-connection
                FloatingActionButton(
                  heroTag: 'mic',
                  backgroundColor: _isMicMuted ? Colors.red : Colors.white,
                  onPressed: _toggleMic,
                  child: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.black,
                  ),
                ),
                FloatingActionButton(
                  heroTag: 'call',
                  backgroundColor: Colors.red,
                  onPressed: _hangUp,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                if (widget.isVideo)
                  FloatingActionButton(
                    heroTag: 'cam',
                    backgroundColor: Colors.white,
                    onPressed: _switchCamera,
                    child: const Icon(Icons.switch_camera, color: Colors.black),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
