import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/channel_model.dart';
import '../../models/company_model.dart';
import '../../screens/company_details_screen.dart';
import '../../services/voice_room_service.dart';

class ChannelList extends StatefulWidget {
  final Company company;
  final List<ChannelCategory> categories;
  final List<Channel> channels;
  final String? selectedChannelId;
  final Function(String) onChannelSelected;
  final VoidCallback? onCollapse;
  final bool isAdmin;
  final VoidCallback? onInvite;
  final Map<String, int> unreadCounts;
  final Future<void> Function(String categoryId, String name, ChannelType type)?
      onCreateChannel;
  final Future<void> Function(String name)? onCreateCategory;
  final Function(String channelId, String channelName)? onVoiceChannelJoin;
  final Map<String, List<VoiceRoomParticipant>> voiceParticipants;

  const ChannelList({
    super.key,
    required this.company,
    required this.categories,
    required this.channels,
    required this.selectedChannelId,
    required this.onChannelSelected,
    this.onCollapse,
    this.isAdmin = false,
    this.onInvite,
    this.unreadCounts = const {},
    this.onCreateChannel,
    this.onCreateCategory,
    this.onVoiceChannelJoin,
    this.voiceParticipants = const {},
  });

  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // Glassmorphic channel list — translucent background instead of flat darkBlue
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
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
                if (widget.onCollapse != null)
                  IconButton(
                    icon:
                        const Icon(Icons.menu_open, color: AppColors.white),
                    onPressed: widget.onCollapse,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (widget.onCollapse != null) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CompanyDetailsScreen(
                              company: widget.company),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        if (widget.company.iconUrl.isNotEmpty) ...[
                          CircleAvatar(
                            radius: 12,
                            backgroundImage:
                                NetworkImage(widget.company.iconUrl),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            widget.company.name,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  IconButton(
                    icon: const Icon(
                      Icons.person_add,
                      color: AppColors.white,
                      size: 20,
                    ),
                    onPressed: widget.onInvite,
                    tooltip: 'Invite User',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...widget.categories
                    .map((category) => _buildCategory(category)),
                // Add Category button (admin only)
                if (widget.isAdmin)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: InkWell(
                      onTap: () => _showCreateCategoryDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              size: 16,
                              color: AppColors.mediumGrey,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Add Category',
                              style: TextStyle(
                                color: AppColors.mediumGrey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(ChannelCategory category) {
    final categoryChannels = widget.channels
        .where((c) => c.categoryId == category.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4, right: 8),
          child: Row(
            children: [
              const Icon(
                Icons.keyboard_arrow_down,
                size: 12,
                color: AppColors.mediumGrey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  category.name.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // Add channel button (admin only)
              if (widget.isAdmin)
                GestureDetector(
                  onTap: () =>
                      _showCreateChannelDialog(context, category),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...categoryChannels.map((channel) => _buildChannelItem(channel)),
      ],
    );
  }

  Widget _buildChannelItem(Channel channel) {
    bool isSelected = channel.id == widget.selectedChannelId;
    int unreadCount = widget.unreadCounts[channel.id] ?? 0;
    bool hasUnread = unreadCount > 0;

    IconData icon =
        channel.type == ChannelType.text ? Icons.chat_bubble_outline : Icons.mic_none;

    return GestureDetector(
      onTap: () {
        if (channel.type == ChannelType.voice) {
          widget.onVoiceChannelJoin?.call(channel.id, channel.name);
        } else {
          widget.onChannelSelected(channel.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          // Glassmorphic selected state
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: AppColors.accentBlue.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.accentBlue
                      : hasUnread
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    channel.name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : hasUnread
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: isSelected || hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (hasUnread)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            // Voice channel participants
            if (channel.type == ChannelType.voice &&
                widget.voiceParticipants[channel.id] != null &&
                widget.voiceParticipants[channel.id]!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Column(
                  children: widget.voiceParticipants[channel.id]!
                      .map((p) => _buildVoiceParticipantRow(p))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceParticipantRow(VoiceRoomParticipant participant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                participant.userName.isNotEmpty
                    ? participant.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              participant.userName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (participant.isMuted)
            Icon(
              Icons.mic_off,
              size: 12,
              color: Colors.red.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }

  // --- Dialogs ---

  void _showCreateChannelDialog(
      BuildContext context, ChannelCategory category) {
    final nameController = TextEditingController();
    ChannelType selectedType = ChannelType.text;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  // Glassmorphic bottom sheet
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.deepNavy.withValues(alpha: 0.95),
                      AppColors.blueGradientEnd.withValues(alpha: 0.98),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    const Text(
                      'Create Channel',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'in ${category.name.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Channel Type Selector
                    Text(
                      'CHANNEL TYPE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeOption(
                            icon: Icons.chat_bubble_outline,
                            label: 'Text',
                            isSelected: selectedType == ChannelType.text,
                            onTap: () => setModalState(
                                () => selectedType = ChannelType.text),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeOption(
                            icon: Icons.mic_none,
                            label: 'Voice',
                            isSelected: selectedType == ChannelType.voice,
                            onTap: () => setModalState(
                                () => selectedType = ChannelType.voice),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Channel Name
                    Text(
                      'CHANNEL NAME',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          selectedType == ChannelType.text
                              ? Icons.chat_bubble_outline
                              : Icons.mic_none,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 20,
                        ),
                        hintText: 'new-channel',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final name = nameController.text
                              .trim()
                              .toLowerCase()
                              .replaceAll(' ', '-');
                          if (name.isEmpty) return;

                          Navigator.pop(ctx);
                          if (widget.onCreateChannel != null) {
                            await widget.onCreateChannel!(
                              category.id,
                              name,
                              selectedType,
                            );
                          }
                        },
                        child: const Text(
                          'Create Channel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepNavy.withValues(alpha: 0.95),
                  AppColors.blueGradientEnd.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Create Category',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Category Name
                Text(
                  'CATEGORY NAME',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.folder_outlined,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    hintText: 'e.g. Voice Channels',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;

                      Navigator.pop(ctx);
                      if (widget.onCreateCategory != null) {
                        await widget.onCreateCategory!(name);
                      }
                    },
                    child: const Text(
                      'Create Category',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentBlue.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.accentBlue.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.5),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentBlue : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
