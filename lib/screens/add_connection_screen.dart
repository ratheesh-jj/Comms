import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../models/user_model.dart';
import '../widgets/gradient_background.dart';

class AddConnectionScreen extends StatefulWidget {
  const AddConnectionScreen({super.key});

  @override
  State<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends State<AddConnectionScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  Stream<List<Map<String, dynamic>>>? _incomingRequestsStream;
  Stream<List<Map<String, dynamic>>>? _outgoingRequestsStream;
  bool _streamsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_streamsInitialized) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null) {
        final friendsService = Provider.of<FriendsService>(
          context,
          listen: false,
        );
        _incomingRequestsStream = friendsService.streamIncomingRequestsRaw(user.id);
        _outgoingRequestsStream = friendsService.streamOutgoingRequestsRaw(user.id);
        _streamsInitialized = true;
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addConnection() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showSnack('Please enter a connect code');
      return;
    }

    setState(() => _isLoading = true);

    final friendsService = Provider.of<FriendsService>(context, listen: false);
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      String friendName = await friendsService.sendConnectionRequest(
        user.id,
        code,
      );
      _showSnack('Connection request sent to $friendName!');
      _codeController.clear();
      // Keep them on the screen to view requests
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final friendsService = Provider.of<FriendsService>(context);
    final user = authService.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Add Connection'),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // My Connect Code Section
                  if (user != null)
                    StreamBuilder<UserModel?>(
                      stream: friendsService.streamUser(user.id),
                      builder: (context, snapshot) {
                        final myCode = snapshot.data?.friendCode ?? '...';
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'MY CONNECT CODE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    myCode,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: myCode == '...'
                                        ? null
                                        : () {
                                            Clipboard.setData(
                                              ClipboardData(text: myCode),
                                            );
                                            _showSnack('Copied!');
                                          },
                                    icon: Icon(
                                      Icons.copy_rounded,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: myCode == '...'
                                        ? null
                                        : () async {
                                            bool?
                                            confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Refresh Connect Code',
                                                ),
                                                content: const Text(
                                                  'Are you sure you want to generate a new connect code? Your old code will no longer work.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Generate',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true && mounted) {
                                              try {
                                                await friendsService
                                                    .refreshConnectCode(
                                                      user.id,
                                                    );
                                                _showSnack(
                                                  'New Connect Code Generated!',
                                                );
                                              } catch (e) {
                                                _showSnack(
                                                  'Error generating code: $e',
                                                );
                                              }
                                            }
                                          },
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Share this code with colleagues to connect',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),

                  // Divider with text
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[600])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[600])),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Add Friend Section
                  Text(
                    'ENTER CONNECT CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        letterSpacing: 2,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addConnection,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Send Connect Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),

                  const SizedBox(height: 32),

                  // Pending Requests Sections
                  if (user != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PENDING REQUESTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                          onPressed: () {
                            setState(() {
                              _streamsInitialized = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Incoming Requests
                    _buildIncomingRequests(context, friendsService, user.id),
                    const SizedBox(height: 24),
                    // Outgoing Requests
                    _buildOutgoingRequests(context, friendsService, user.id),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingRequests(
    BuildContext context,
    FriendsService friendsService,
    String uid,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _incomingRequestsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();

        final requests = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'INCOMING REQUESTS (${requests.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Colors.orangeAccent[400],
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map(
              (req) => _RequestTile(
                requestId: req['id'],
                userId: req['sender_id'],
                isIncoming: true,
                onAccept: () async {
                  try {
                    await friendsService.acceptRequest(req['id'], uid);
                    if (mounted) _showSnack('Request accepted!');
                  } catch (e) {
                    if (mounted) _showSnack('Error: $e');
                  }
                },
                onRejectOrCancel: () async {
                  try {
                    await friendsService.rejectOrCancelRequest(req['id']);
                    if (mounted) _showSnack('Request rejected');
                  } catch (e) {
                    if (mounted) _showSnack('Error: $e');
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutgoingRequests(
    BuildContext context,
    FriendsService friendsService,
    String uid,
  ) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _outgoingRequestsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const SizedBox.shrink();

        final requests = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PENDING OUTGOING REQUESTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map(
              (req) => _RequestTile(
                requestId: req['id'],
                userId: req['receiver_id'],
                isIncoming: false,
                onRejectOrCancel: () async {
                  try {
                    await friendsService.rejectOrCancelRequest(req['id']);
                    if (mounted) _showSnack('Request cancelled');
                  } catch (e) {
                    if (mounted) _showSnack('Error: $e');
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestTile extends StatefulWidget {
  final String requestId;
  final String userId;
  final bool isIncoming;
  final VoidCallback? onAccept;
  final VoidCallback onRejectOrCancel;

  const _RequestTile({
    required this.requestId,
    required this.userId,
    required this.isIncoming,
    this.onAccept,
    required this.onRejectOrCancel,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  Future<Map<String, dynamic>>? _userInfoFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userInfoFuture ??=
        Provider.of<FriendsService>(context, listen: false).getUserInfo(
          widget.userId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _userInfoFuture,
        builder: (context, snapshot) {
          final name = snapshot.data?['display_name'] ?? 'Loading...';
          final email = snapshot.data?['email'] ?? '';

          return ListTile(
            title: Text(name),
            subtitle: Text(widget.isIncoming ? email : 'Waiting for approval...'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isIncoming)
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    onPressed: widget.onAccept,
                  ),
                IconButton(
                  icon: Icon(
                    widget.isIncoming ? Icons.cancel_outlined : Icons.close,
                    color: widget.isIncoming ? Colors.red : Colors.grey,
                  ),
                  onPressed: widget.onRejectOrCancel,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
