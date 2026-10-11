import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dotenv/dotenv.dart';

// Represents a peer in the signalling server
class Peer {
  final String id;
  final WebSocketChannel socket;
  String? roomId;

  Peer(this.id, this.socket);
}

// Manages rooms and peers
class RoomManager {
  final Map<String, Peer> _peers = {};
  final Map<String, Set<String>> _rooms = {}; // roomId -> Set<peerId>

  void addPeer(Peer peer) {
    _peers[peer.id] = peer;
  }

  void removePeer(String peerId) {
    var peer = _peers[peerId];
    if (peer != null) {
      if (peer.roomId != null) {
        leaveRoom(peerId, peer.roomId!);
      }
      peer.socket.sink.close();
      _peers.remove(peerId);
      print('Peer $peerId disconnected');
    }
  }

  void joinRoom(String peerId, String roomId) {
    if (!_rooms.containsKey(roomId)) {
      _rooms[roomId] = {};
    }
    
    // Check if room is full (max 2 for 1-to-1)
    if (_rooms[roomId]!.length >= 2) {
      var peer = _peers[peerId];
      peer?.socket.sink.add(jsonEncode({
        'type': 'error',
        'message': 'Room is full'
      }));
      return;
    }

    _rooms[roomId]!.add(peerId);
    _peers[peerId]?.roomId = roomId;

    print('Peer $peerId joined room $roomId');

    // Notify other peer in the room
    broadcastToRoom(roomId, peerId, {
      'type': 'user_joined',
      'peer_id': peerId
    });
  }

  void leaveRoom(String peerId, String roomId) {
    if (_rooms.containsKey(roomId)) {
      _rooms[roomId]!.remove(peerId);
      if (_rooms[roomId]!.isEmpty) {
        _rooms.remove(roomId);
        print('Room $roomId destroyed');
      } else {
        // Notify others
        broadcastToRoom(roomId, peerId, {
          'type': 'user_left',
          'peer_id': peerId
        });
      }
    }
    _peers[peerId]?.roomId = null;
  }

  void broadcastToRoom(String roomId, String senderId, Map<String, dynamic> message) {
    if (_rooms.containsKey(roomId)) {
      for (var pId in _rooms[roomId]!) {
        if (pId != senderId) {
          _peers[pId]?.socket.sink.add(jsonEncode(message));
        }
      }
    }
  }

  void handleDisconnect(WebSocketChannel socket) {
    // Find peer by socket (inefficient linear search but fine for small scale demo)
    String? peerIdToRemove;
    _peers.forEach((id, peer) {
      if (peer.socket == socket) {
        peerIdToRemove = id;
      }
    });

    if (peerIdToRemove != null) {
      removePeer(peerIdToRemove!);
    }
  }

  void handleMessage(WebSocketChannel socket, String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      
      switch (type) {
        case 'login':
          final peerId = data['id'];
          final peer = Peer(peerId, socket);
          addPeer(peer);
          print('Peer $peerId logged in');
          socket.sink.add(jsonEncode({'type': 'login_success', 'id': peerId}));
          break;

        case 'join':
          final peerId = data['id'];
          final roomId = data['room_id'];
          joinRoom(peerId, roomId);
          break;
        
        case 'offer':
        case 'answer':
        case 'candidate':
          final peerId = data['id'];
          // Forward to the other peer in the room
          final peer = _peers[peerId];
          if (peer != null && peer.roomId != null) {
            broadcastToRoom(peer.roomId!, peerId, data);
          }
          break;

        case 'leave':
          final peerId = data['id'];
          var peer = _peers[peerId];
          if (peer != null && peer.roomId != null) {
             leaveRoom(peerId, peer.roomId!);
             print('Peer $peerId left room ${peer.roomId}');
          }
          break;
          
        default:
          print('Unknown message type: $type');
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }
}

void main() async {
  // Load environment variables
  var env = DotEnv(includePlatformEnvironment: true)..load();
  int port = int.tryParse(env['PORT'] ?? '8080') ?? 8080;

  final roomManager = RoomManager();

  var handler = webSocketHandler((WebSocketChannel webSocket) {
    webSocket.stream.listen((message) {
      roomManager.handleMessage(webSocket, message.toString());
    }, onDone: () {
      roomManager.handleDisconnect(webSocket);
    });
  });

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Signalling server listening on port ${server.port}');
}
