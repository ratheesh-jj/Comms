import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/call_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final bool isVideo;
  final String callId;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.isVideo,
    required this.callId,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    final callService = Provider.of<CallService>(context, listen: false);
    _callSubscription = callService.listenToCallState(widget.callId).listen((
      snapshot,
    ) {
      if (snapshot != null) {
        final data = snapshot;
        if (data['state'] == 'ended' || data['state'] == 'cancelled') {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Call Cancelled')));
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              widget.callerName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isVideo
                  ? 'Incoming Video Call...'
                  : 'Incoming Voice Call...',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 64),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject Button
                Column(
                  children: [
                    FloatingActionButton(
                      onPressed: widget.onReject,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Decline',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                // Accept Button
                Column(
                  children: [
                    FloatingActionButton(
                      onPressed: widget.onAccept,
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.call, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text('Accept', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
