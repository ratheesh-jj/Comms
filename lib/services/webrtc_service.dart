import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logging/logging.dart';
import 'signalling.dart';

class WebRTCService {
  final SignallingService _signallingService;
  final Logger _log = Logger('WebRTCService');

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // Renderers to bind to the UI
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  Function()? onRemoteStream;
  Function(RTCPeerConnectionState)? onConnectionState;

  RTCPeerConnectionState? _connectionState;
  RTCPeerConnectionState? get connectionState => _connectionState;

  bool _isVideoCall = false; // Store call type preference

  WebRTCService(this._signallingService) {
    _signallingService.onMessageReceived = _handleSignallingMessage;
  }

  Future<void> init() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openUserMedia(bool isVideo) async {
    _isVideoCall = isVideo;
    // Ensure clean slate
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo ? {
        'facingMode': 'user',
      } : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      _log.info('User media opened, video: $isVideo');
    } catch (e) {
      _log.severe('Error opening user media: $e');
    }
  }

  Future<void> initializePeerConnection(String? iceServer) async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': [iceServer ?? 'stun:stun.l.google.com:19302']},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': _isVideoCall,
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _log.info('Got ICE candidate: ${candidate.candidate}');
      _signallingService.sendCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      _log.info('Got remote track: ${event.streams[0].id}');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        onRemoteStream?.call();
      }
    };

    // Add local stream
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }
    
    _peerConnection!.onConnectionState = (state) {
        _connectionState = state;
        onConnectionState?.call(state);
    };
  }

  Future<void> startCall(String remoteId) async {
    if (_peerConnection == null) await initializePeerConnection(null);

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    _signallingService.sendSdp('offer', offer.sdp!);
  }

  Future<void> _handleSignallingMessage(Map<String, dynamic> data) async {
    String type = data['type'];
    switch (type) {
      case 'offer':
        await _handleOffer(data);
        break;
      case 'answer':
        await _handleAnswer(data);
        break;
      case 'candidate':
        await _handleCandidate(data);
        break;
      case 'user_joined':
        _log.info('User joined: ${data['peer_id']}');
        await startCall(data['peer_id']);
        break;
      case 'user_left':
        await _handleRemoteDisconnect();
        break;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (_peerConnection == null) await initializePeerConnection(null); // Assuming initialized context

    var sdp = data['sdp'];
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    
    RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': _isVideoCall,
      },
      'optional': [],
    });
    await _peerConnection!.setLocalDescription(answer);
    
    _signallingService.sendSdp('answer', answer.sdp!);
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    var sdp = data['sdp'];
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _handleCandidate(Map<String, dynamic> data) async {
    var candidateMap = data['candidate'];
    RTCIceCandidate candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> _handleRemoteDisconnect() async {
    _log.info('Remote user disconnected, keeping local session alive');
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }
    remoteRenderer.srcObject = null;
    onRemoteStream?.call(); // Notify UI to update
  }

  Future<void> hangUp() async {
    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        await _localStream!.dispose();
        _localStream = null;
      }
    } catch (e) {
      _log.warning('Error disposing local stream: $e');
    } finally {
       // Always clear renderers and peer connection
       localRenderer.srcObject = null;
       remoteRenderer.srcObject = null;
    }
    
    try {
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }
      _signallingService.leave();
    } catch (e) {
      _log.warning('Error closing peer connection: $e');
    }
  }

  void switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
  }

  void toggleMic() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }
  
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    hangUp();
  }
}
