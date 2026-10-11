import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../widgets/gradient_background.dart';
import '../providers/company_provider.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'add_connection_screen.dart';
import 'company_screen.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Stream<UserModel?>? _userStream;
  Stream<List<UserModel>>? _friendsStream;
  Stream<List<Map<String, dynamic>>>? _incomingRequestsStream;
  String? _streamUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStreams();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initStreams(force: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initStreams();
  }

  void _initStreams({bool force = false}) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      Provider.of<CompanyProvider>(context, listen: false).init(user.id);

      if (_streamUserId != user.id || force) {
        final friendsService = Provider.of<FriendsService>(
          context,
          listen: false,
        );
        setState(() {
          _streamUserId = user.id;
          _userStream = friendsService.streamUser(user.id);
          _friendsStream = friendsService.streamFriends(user.id);
          _incomingRequestsStream = friendsService.streamIncomingRequestsRaw(user.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final chatService = Provider.of<ChatService>(context);

    if (user == null || _userStream == null || _friendsStream == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'comms.',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: StreamBuilder<UserModel?>(
              stream: _userStream,
              builder: (context, snapshot) {
                final userModel = snapshot.data;
                final avatarUrl = userModel?.avatarUrl ??
                    user.userMetadata?['avatar_url'] ??
                    user.userMetadata?['picture'];
                return CircleAvatar(
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? const Icon(Icons.person, size: 20) : null,
                );
              },
            ),
          ),
        ),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey('badge_stream_${user.id}'),
            stream: _incomingRequestsStream,
            initialData: const [],
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
              final count = requests.length;
              
              // If we are waiting for first data, don't show badge
              final isVisible = count > 0 && snapshot.hasData;

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Badge(
                  isLabelVisible: isVisible,
                  label: Text(count.toString()),
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddConnectionScreen(),
                        ),
                      ).then((_) {
                        if (mounted) _initStreams(force: true);
                      });
                    },
                    tooltip: 'Add Connection ($count pending)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // User Info
                StreamBuilder<UserModel?>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            const Text(
                              'Failed to connect to live updates.',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            TextButton(
                              onPressed: () => _initStreams(force: true),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentBlue,
                        ),
                      );
                    final userModel = snapshot.data!;
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentBlue.withOpacity(0.15),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.accentBlue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentBlue.withOpacity(0.3),
                                  blurRadius: 16,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.darkBlue,
                              backgroundImage: userModel.avatarUrl != null
                                  ? NetworkImage(userModel.avatarUrl!)
                                  : (user.userMetadata?['avatar_url'] != null
                                      ? NetworkImage(user.userMetadata!['avatar_url']!)
                                      : (user.userMetadata?['picture'] != null
                                          ? NetworkImage(user.userMetadata!['picture']!)
                                          : null)),
                              child: (userModel.avatarUrl == null &&
                                      user.userMetadata?['avatar_url'] == null &&
                                      user.userMetadata?['picture'] == null)
                                  ? const Icon(
                                      Icons.person,
                                      size: 36,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userModel.displayName,
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // My Company Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'My Company',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<CompanyProvider>(
                  builder: (context, companyProvider, child) {
                    final companies = companyProvider.userCompanies;
                    if (companies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "No companies found.",
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: companies.length,
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        return GestureDetector(
                          onTap: () {
                            companyProvider.selectCompany(company.id);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CompanyScreen(),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.02),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.activityGrey,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                        image: company.iconUrl.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  company.iconUrl,
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          if (company.iconUrl.isEmpty)
                                            Center(
                                              child: Text(
                                                company.name.isNotEmpty
                                                    ? company.name[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          // Notification Badge
                                          if (companyProvider.companyUnreadCounts[company.id] != null && 
                                              companyProvider.companyUnreadCounts[company.id]! > 0)
                                            Positioned(
                                              top: -5,
                                              right: -5,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 16,
                                                  minHeight: 16,
                                                ),
                                                child: Text(
                                                  '${companyProvider.companyUnreadCounts[company.id]}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      company.name,
                                      style: GoogleFonts.nunito(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      company.tags.join(', '),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Connections List
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Connections',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<UserModel>>(
                  stream: _friendsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentBlue,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            const Text(
                              'Failed to load connections.',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            TextButton(
                              onPressed: () => _initStreams(force: true),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    }
                    final friends = snapshot.data ?? [];

                    if (friends.isEmpty)
                      return const Text(
                        "You'll get some eventually!",
                        style: TextStyle(color: AppColors.mediumGrey),
                      );

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withOpacity(0.06),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.activityGrey,
                                  backgroundImage: friend.avatarUrl != null
                                      ? NetworkImage(friend.avatarUrl!)
                                      : null,
                                  child: friend.avatarUrl == null
                                      ? Text(
                                          friend.displayName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: friend.isOnline
                                          ? Colors.greenAccent
                                          : AppColors.mediumGrey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.deepNavy,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              friend.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              friend.isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: friend.isOnline
                                    ? Colors.greenAccent.withOpacity(0.8)
                                    : AppColors.mediumGrey,
                                fontSize: 13,
                              ),
                            ),
                            trailing: StreamBuilder<int>(
                              stream: chatService.streamUnreadCount(user.id, friend.uid),
                              builder: (context, unreadSnapshot) {
                                final unreadCount = unreadSnapshot.data ?? 0;
                                return Badge(
                                  label: Text(unreadCount.toString()),
                                  isLabelVisible: unreadCount > 0,
                                  backgroundColor: Colors.red,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentBlue.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      color: AppColors.accentBlue,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    friendUid: friend.uid,
                                    friendName: friend.displayName,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
