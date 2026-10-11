import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/sign_in_screen.dart';
import 'screens/call_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/theme_selection_screen.dart';
import 'services/signalling.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'services/webrtc_service.dart';
import 'services/auth_service.dart';
import 'services/friends_service.dart';
import 'services/call_service.dart';
import 'services/chat_service.dart';
import 'services/theme_provider.dart';
import 'services/company_service.dart';
import 'services/file_service.dart';
import 'providers/company_provider.dart';

import 'services/logging_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await LoggingService().init(); // Initialize file logging
  _setupLogging();

  await Supabase.initialize(
    url: 'https://miztdzdtziapgjoxqsdx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1penRkemR0emlhcGdqb3hxc2R4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NDgzNTksImV4cCI6MjA4ODEyNDM1OX0.aX8_ulf9QPfP0riA-8iF90QkzjYlBn6MOrZnopVeqZE',
  );

  // Initialize theme provider before running app
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider<FriendsService>(create: (_) => FriendsService()),
        Provider<CallService>(create: (_) => CallService()),
        Provider<ChatService>(create: (_) => ChatService()),
        Provider<FileService>(create: (_) => FileService()),
        Provider<CompanyService>(create: (_) => CompanyService()),
        ChangeNotifierProvider(
          create: (_) => CompanyProvider(),
        ), // Added CompanyProvider
        ChangeNotifierProvider(create: (_) => SignallingService()),
        ProxyProvider<SignallingService, WebRTCService>(
          update: (_, signalling, previous) =>
              previous ?? WebRTCService(signalling),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((rec) {
    // Console output
    debugPrint('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Flutter WebRTC',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.currentTheme,
          home: themeProvider.isInitialized
              ? (themeProvider.isFirstLaunch
                    ? const ThemeSelectionScreen()
                    : const AuthWrapper())
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Use early exit for loading state if needed
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final Session? session = snapshot.data?.session;
        if (session == null) {
          // Reset initialization state on sign out
          _initialized = false;
          return const SignInScreen();
        } else {
          if (!_initialized) {
            return CallManager(
              user: session.user,
              child: SplashScreen(
                onInitializationComplete: () {
                  setState(() {
                    _initialized = true;
                  });
                },
              ),
            );
          }
          // Initialization complete, show home screen
          return CallManager(user: session.user, child: const HomeScreen());
        }
      },
    );
  }
}

class CallManager extends StatefulWidget {
  final User user;
  final Widget child;

  const CallManager({super.key, required this.user, required this.child});

  @override
  State<CallManager> createState() => _CallManagerState();
}

class _CallManagerState extends State<CallManager> {
  StreamSubscription? _callSubscription;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    final friendsService = Provider.of<FriendsService>(context, listen: false);
    friendsService.createOrUpdateUser(widget.user);
    friendsService.setUserStatus(widget.user.id, 'online');

    // Start heartbeat timer to update lastSeen every 60 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      friendsService.setUserStatus(widget.user.id, 'online');
    });

    final callService = Provider.of<CallService>(context, listen: false);
    _callSubscription = callService
        .listenForIncomingCalls(widget.user.id)
        .listen((calls) {
          if (calls.isNotEmpty) {
            // We have an incoming call
            final call = calls.first;
            _handleIncomingCall(call);
          }
        });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _callSubscription?.cancel();
    Provider.of<FriendsService>(
      context,
      listen: false,
    ).setUserStatus(widget.user.id, 'offline');
    super.dispose();
  }

  void _handleIncomingCall(Map<String, dynamic> callData) {
    if (callData['status'] != 'ringing') return;

    final callId = callData['id'];
    final callService = Provider.of<CallService>(context, listen: false);

    // Naive check to prevent spamming navigation on every stream update
    // In a real app, track 'currentCallId'
    // For now, we rely on the fact that we push a modal.
    // Ideally we check if we are already showing this call.

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: callData['callerName'] ?? 'Unknown',
          isVideo: callData['is_video'] == true,
          callId: callId,
          onAccept: () async {
            Navigator.of(context).pop(); // Close incoming screen
            await callService.acceptCall(callId);

            if (!mounted) return;
            final roomId = callData['room_id'];
            final signalling = Provider.of<SignallingService>(
              context,
              listen: false,
            );
            final webrtc = Provider.of<WebRTCService>(context, listen: false);

            // Initialize WebRTC
            await webrtc.init();
            await webrtc.openUserMedia(callData['is_video'] == true);
            await webrtc.initializePeerConnection(null);

            // Join the room
            signalling.onJoinSuccess = (id, remoteName) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    roomId: id,
                    isVideo: callData['is_video'] == true,
                    isCaller: false,
                    remoteName: callData['callerName'],
                  ),
                ),
              );
            };

            await signalling.joinRoom(roomId, widget.user);
          },
          onReject: () async {
            Navigator.of(context).pop();
            await callService.rejectCall(callId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
