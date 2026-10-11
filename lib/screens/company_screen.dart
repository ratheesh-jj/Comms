import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../models/channel_model.dart';
import '../providers/company_provider.dart';
import '../widgets/company/company_sidebar.dart';
import '../widgets/company/channel_list.dart';
import '../widgets/company/company_chat_area.dart';
import '../theme.dart';
import 'create_company_screen.dart';
import 'voice_room_screen.dart';
import '../widgets/gradient_background.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  bool _isChannelListVisible = true;

  @override
  void initState() {
    super.initState();
    // Default visibility based on screen width can be handled in build,
    // but we want state to persist user toggle.
    // We'll init to true and let LayoutBuilder adjust initial render if needed
    // or just rely on manual toggle for "vertical devices" prompt.
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Consumer<CompanyProvider>(
            builder: (context, companyProvider, child) {
              // Fetch companies from provider
              final companies = companyProvider.userCompanies;

              final categories = companyProvider.categories;
              final channels = companyProvider.channels;

              return LayoutBuilder(
                builder: (context, constraints) {
                  // Determine if we are on a narrow screen (vertical device expectation)
                  bool isNarrow = constraints.maxWidth < 800;

                  return Row(
                    children: [
                      // 1. Company Sidebar (Always visible)
                      CompanySidebar(
                        companies: companies,
                        selectedCompanyId: companyProvider.selectedCompanyId,
                        onCompanySelected: (id) {
                          if (id == 'dm') {
                            Navigator.of(context).pop();
                            companyProvider.selectCompany('');
                          } else {
                            companyProvider.selectCompany(id);
                          }
                        },
                        onAddCompany: () {
                          _showAddCompanyDialog(context);
                        },
                        unreadCounts: companyProvider.companyUnreadCounts,
                      ),

                      // 2. Channel List
                      if (_isChannelListVisible &&
                          companyProvider.selectedCompanyId != null &&
                          companyProvider.currentCompany != null)
                        (isNarrow)
                            ? Expanded(
                                // Mobile: Expand to fill remaining space
                                child: ChannelList(
                                  company: companyProvider.currentCompany!,
                                  categories: categories,
                                  channels: channels,
                                  selectedChannelId:
                                      companyProvider.selectedChannelId,
                                  isAdmin:
                                      companyProvider.currentCompany!.ownerId ==
                                      user.id,
                                  onInvite: () => _showInviteDialog(
                                    context,
                                    companyProvider.currentCompany!.id,
                                  ),
                                  onChannelSelected: (id) {
                                    companyProvider.selectChannel(id);
                                    setState(
                                      () => _isChannelListVisible = false,
                                    );
                                  },
                                  onCollapse: () => setState(
                                    () => _isChannelListVisible = false,
                                  ),
                                  onCreateChannel: (categoryId, name, type) =>
                                      companyProvider.createChannel(
                                    companyProvider.currentCompany!.id,
                                    categoryId,
                                    name,
                                    type,
                                  ),
                                  onCreateCategory: (name) =>
                                      companyProvider.createCategory(
                                    companyProvider.currentCompany!.id,
                                    name,
                                  ),
                                  voiceParticipants: companyProvider.voiceParticipants,
                                  onVoiceChannelJoin: (channelId, channelName) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VoiceRoomScreen(
                                          channelId: channelId,
                                          channelName: channelName,
                                          companyId: companyProvider.currentCompany!.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : SizedBox(
                                // Desktop: Fixed width
                                width: 240,
                                child: ChannelList(
                                  company: companyProvider.currentCompany!,
                                  categories: categories,
                                  channels: channels,
                                  selectedChannelId:
                                      companyProvider.selectedChannelId,
                                  isAdmin:
                                      companyProvider.currentCompany!.ownerId ==
                                      user.id,
                                  onInvite: () => _showInviteDialog(
                                    context,
                                    companyProvider.currentCompany!.id,
                                  ),
                                  onChannelSelected: (id) =>
                                      companyProvider.selectChannel(id),
                                  onCollapse: () => setState(
                                    () => _isChannelListVisible = false,
                                  ),
                                  onCreateChannel: (categoryId, name, type) =>
                                      companyProvider.createChannel(
                                    companyProvider.currentCompany!.id,
                                    categoryId,
                                    name,
                                    type,
                                  ),
                                  onCreateCategory: (name) =>
                                      companyProvider.createCategory(
                                    companyProvider.currentCompany!.id,
                                    name,
                                  ),
                                  voiceParticipants: companyProvider.voiceParticipants,
                                  onVoiceChannelJoin: (channelId, channelName) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VoiceRoomScreen(
                                          channelId: channelId,
                                          channelName: channelName,
                                          companyId: companyProvider.currentCompany!.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                      // 3. Main Content Area (Chat/Voice)
                      if (!isNarrow || !_isChannelListVisible)
                        Expanded(
                          flex: 3,
                          child: Container(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                // Chat Header with Toggle was removed since its now in CompanyChatArea.
                                // If there is no channel selected, provide a small spacer or simple handle.
                                if (companyProvider.selectedChannelId == null)
                                  Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (!_isChannelListVisible)
                                          IconButton(
                                            icon: Icon(
                                              Icons.menu,
                                              color: Colors.white.withValues(alpha: 0.5),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isChannelListVisible = true;
                                              });
                                            },
                                            tooltip: "Show Channels",
                                          ),
                                      ],
                                    ),
                                  ),

                                // Chat Content
                                Expanded(
                                  child:
                                      companyProvider.selectedChannelId !=
                                              null &&
                                          companyProvider.currentCompany != null
                                      ? CompanyChatArea(
                                          companyId: companyProvider
                                              .currentCompany!
                                              .id,
                                          channelId: companyProvider
                                              .selectedChannelId!,
                                          channelName: channels
                                              .firstWhere(
                                                (c) =>
                                                    c.id ==
                                                    companyProvider
                                                        .selectedChannelId,
                                                orElse: () => Channel(
                                                  id: '',
                                                  categoryId: '',
                                                  companyId: '',
                                                  name: 'Unknown',
                                                  type: ChannelType.text,
                                                  sortOrder: 0,
                                                ),
                                              )
                                              .name,
                                          onMenuPressed: !_isChannelListVisible
                                              ? () {
                                                  setState(() {
                                                    _isChannelListVisible =
                                                        true;
                                                  });
                                                }
                                              : null,
                                        )
                                      : const Center(
                                          child: Text(
                                            "Select a channel to start chatting",
                                            style: TextStyle(
                                              color: AppColors.mediumGrey,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddCompanyDialog(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateCompanyScreen()));
  }

  void _showInviteDialog(BuildContext context, String companyId) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.deepNavy.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          title: const Text(
            'Invite User',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter 6-character Connect Code',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.accentBlue.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.mediumGrey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
              ),
              onPressed: () async {
                final targetId = controller.text.trim();
                if (targetId.isNotEmpty) {
                  try {
                    await CompanyService().inviteUser(companyId, targetId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Target invited successfully!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Invite'),
            ),
          ],
        );
      },
    );
  }
}
