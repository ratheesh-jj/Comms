import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../models/channel_model.dart';
import '../services/company_service.dart';
import '../services/voice_room_service.dart';

class CompanyProvider with ChangeNotifier {
  final CompanyService _companyService = CompanyService();
  final VoiceRoomService _voiceRoomService = VoiceRoomService();

  String? _selectedCompanyId;
  String? _selectedChannelId;

  Company? _currentCompany;
  List<ChannelCategory> _categories = [];
  List<Channel> _channels = [];
  List<Company> _userCompanies = [];
  String? _currentUserId;

  StreamSubscription<List<Company>>? _userCompaniesSub;
  StreamSubscription<Company>? _companySub;
  StreamSubscription<List<ChannelCategory>>? _categoriesSub;
  StreamSubscription<List<Channel>>? _channelsSub;
  final Map<String, StreamSubscription<int>> _channelUnreadSubs = {};
  final Map<String, StreamSubscription<int>> _companyUnreadSubs = {};
  final Map<String, int> _channelUnreadCounts = {};
  final Map<String, int> _companyUnreadCounts = {};

  // Voice room state
  String? _activeVoiceChannelId;
  StreamSubscription<Map<String, List<VoiceRoomParticipant>>>? _voiceParticipantsSub;
  Map<String, List<VoiceRoomParticipant>> _voiceParticipants = {};

  @override
  void dispose() {
    _userCompaniesSub?.cancel();
    _companySub?.cancel();
    _categoriesSub?.cancel();
    _channelsSub?.cancel();
    _voiceParticipantsSub?.cancel();
    for (var sub in _channelUnreadSubs.values) sub.cancel();
    for (var sub in _companyUnreadSubs.values) sub.cancel();
    super.dispose();
  }

  // Hardcoded nUlL company
  final Company _nullCompany = Company(
    id: 'null-corp',
    name: 'nUlL',
    ownerId: 'system',
    iconUrl: '',
    bannerUrl: '',
    description: 'The default mock company.',
    tags: ['Community Hub'],
    members: ['system'],
    createdAt: DateTime.now(),
  );

  String? get selectedCompanyId => _selectedCompanyId;
  String? get selectedChannelId => _selectedChannelId;
  Company? get currentCompany => _currentCompany;
  List<ChannelCategory> get categories => _categories;
  List<Channel> get channels => _channels;
  Map<String, int> get channelUnreadCounts => _channelUnreadCounts;
  Map<String, int> get companyUnreadCounts => _companyUnreadCounts;
  String? get activeVoiceChannelId => _activeVoiceChannelId;
  Map<String, List<VoiceRoomParticipant>> get voiceParticipants => _voiceParticipants;
  VoiceRoomService get voiceRoomService => _voiceRoomService;

  // Combine real companies with nUlL
  List<Company> get userCompanies => [_nullCompany, ..._userCompanies];

  void init(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    _userCompaniesSub?.cancel();
    _userCompaniesSub = _companyService.getUserCompanies(userId).listen((
      companies,
    ) {
      _userCompanies = companies;
      _updateCompanyUnreadSubscriptions(userId);
      notifyListeners();
    });
  }

  void _updateCompanyUnreadSubscriptions(String userId) {
    // Clear old ones not in the list anymore
    final currentIds = _userCompanies.map((c) => c.id).toSet();
    _companyUnreadSubs.keys
        .where((id) => !currentIds.contains(id))
        .toList()
        .forEach((id) {
          _companyUnreadSubs[id]?.cancel();
          _companyUnreadSubs.remove(id);
          _companyUnreadCounts.remove(id);
        });

    // Add new ones
    for (var company in _userCompanies) {
      if (!_companyUnreadSubs.containsKey(company.id)) {
        _companyUnreadSubs[company.id] = _companyService
            .streamCompanyUnreadCount(userId, company.id)
            .listen((count) {
              _companyUnreadCounts[company.id] = count;
              notifyListeners();
            });
      }
    }
  }

  Future<void> createCompany(
    String name,
    String ownerId,
    String iconUrl,
    String bannerUrl,
    String description,
    List<String> tags, {
    File? logoFile,
    File? bannerFile,
  }) async {
    String finalIconUrl = iconUrl;
    String finalBannerUrl = bannerUrl;

    if (logoFile != null) {
      final uploadedUrl =
          await _companyService.uploadCompanyAsset(logoFile, 'logo');
      if (uploadedUrl != null) finalIconUrl = uploadedUrl;
    }

    if (bannerFile != null) {
      final uploadedUrl =
          await _companyService.uploadCompanyAsset(bannerFile, 'banner');
      if (uploadedUrl != null) finalBannerUrl = uploadedUrl;
    }

    await _companyService.createCompany(
      name,
      ownerId,
      finalIconUrl,
      finalBannerUrl,
      description,
      tags,
    );
  }

  Future<void> updateCompany({
    required String companyId,
    required String name,
    required String iconUrl,
    required String bannerUrl,
    required String description,
    required List<String> tags,
  }) async {
    await _companyService.updateCompany(
      companyId: companyId,
      name: name,
      iconUrl: iconUrl,
      bannerUrl: bannerUrl,
      description: description,
      tags: tags,
    );
  }

  Future<void> deleteCompany(String companyId) async {
    await _companyService.deleteCompany(companyId);
    if (_selectedCompanyId == companyId) {
      _selectedCompanyId = null;
      _currentCompany = null;
      _categories = [];
      _channels = [];
      notifyListeners();
    }
  }

  Future<void> createChannel(
    String companyId,
    String categoryId,
    String name,
    ChannelType type,
  ) async {
    await _companyService.createChannel(companyId, categoryId, name, type);
  }

  Future<void> createCategory(String companyId, String name) async {
    await _companyService.createChannelCategory(companyId, name);
  }

  Future<void> deleteChannel(String channelId) async {
    await _companyService.deleteChannel(channelId);
    if (_selectedChannelId == channelId) {
      _selectedChannelId = null;
      notifyListeners();
    }
  }

  void selectCompany(String companyId) {
    if (_selectedCompanyId != companyId) {
      _selectedCompanyId = companyId;
      _selectedChannelId = null; // Reset channel on company switch
      _fetchCompanyData(companyId);
      notifyListeners();
    }
  }

  void selectChannel(String channelId) {
    if (_selectedChannelId != channelId) {
      _selectedChannelId = channelId;
      markSelectedChannelAsRead();
      notifyListeners();
    }
  }

  void setActiveVoiceChannel(String? channelId) {
    _activeVoiceChannelId = channelId;
    notifyListeners();
  }

  Future<void> markSelectedChannelAsRead() async {
    if (_currentUserId != null && _selectedChannelId != null) {
      await _companyService.markChannelAsRead(
        _currentUserId!,
        _selectedChannelId!,
      );
    }
  }

  void _fetchCompanyData(String companyId) {
    _companySub?.cancel();
    _categoriesSub?.cancel();
    _channelsSub?.cancel();

    // MOCK DATA FOR nUlL COMPANY
    if (companyId == 'null-corp') {
      _currentCompany = Company(
        id: 'null-corp',
        name: 'nUlL',
        ownerId: 'system',
        iconUrl: '',
        bannerUrl: '',
        description: 'The default mock company.',
        tags: ['Community Hub'],
        members: ['system'],
        createdAt: DateTime.now(),
      );

      _categories = [
        ChannelCategory(
          id: 'cat1',
          companyId: 'null-corp',
          name: 'Information',
          sortOrder: 0,
        ),
        ChannelCategory(
          id: 'cat2',
          companyId: 'null-corp',
          name: 'Text Channels',
          sortOrder: 1,
        ),
        ChannelCategory(
          id: 'cat3',
          companyId: 'null-corp',
          name: 'Voice Channels',
          sortOrder: 2,
        ),
      ];

      _channels = [
        Channel(
          id: 'c1',
          categoryId: 'cat1',
          companyId: 'null-corp',
          name: 'welcome',
          type: ChannelType.text,
          sortOrder: 0,
        ),
        Channel(
          id: 'c2',
          categoryId: 'cat1',
          companyId: 'null-corp',
          name: 'announcements',
          type: ChannelType.text,
          sortOrder: 1,
        ),
        Channel(
          id: 'c3',
          categoryId: 'cat2',
          companyId: 'null-corp',
          name: 'general',
          type: ChannelType.text,
          sortOrder: 0,
        ),
        Channel(
          id: 'c4',
          categoryId: 'cat2',
          companyId: 'null-corp',
          name: 'off-topic',
          type: ChannelType.text,
          sortOrder: 1,
        ),
        Channel(
          id: 'c5',
          categoryId: 'cat3',
          companyId: 'null-corp',
          name: 'Lounge',
          type: ChannelType.voice,
          sortOrder: 0,
        ),
        Channel(
          id: 'c6',
          categoryId: 'cat3',
          companyId: 'null-corp',
          name: 'Meeting Room',
          type: ChannelType.voice,
          sortOrder: 1,
        ),
      ];

      // Auto-select text channel
      if (_selectedChannelId == null && _channels.isNotEmpty) {
        _selectedChannelId = 'c3'; // Default to general
      }

      notifyListeners();
      return; // Return early to avoid real service call for mock
    }

    // Listen to Company details
    _companySub = _companyService.getCompanyStream(companyId).listen((company) {
      _currentCompany = company;
      notifyListeners();
    });

    // Listen to Categories
    _categoriesSub = _companyService.getCategories(companyId).listen((
      categories,
    ) {
      _categories = categories;
      notifyListeners();
    });

    // Listen to Channels
    _channelsSub = _companyService.getChannels(companyId).listen((channels) {
      _channels = channels;
      // Auto-select first text channel if none selected
      if (_selectedChannelId == null && channels.isNotEmpty) {
        final firstTextChannel = channels.firstWhere(
          (c) => c.type == ChannelType.text,
          orElse: () => channels.first,
        );
        _selectedChannelId = firstTextChannel.id;
      }
      // Update voice participant subscriptions
      _updateVoiceParticipantStreams(channels);
      notifyListeners();
    });
  }

  void _updateVoiceParticipantStreams(List<Channel> channels) {
    _voiceParticipantsSub?.cancel();

    final voiceChannelIds = channels
        .where((c) => c.type == ChannelType.voice)
        .map((c) => c.id)
        .toList();

    if (voiceChannelIds.isEmpty) {
      _voiceParticipants = {};
      return;
    }

    _voiceParticipantsSub = _voiceRoomService
        .streamAllVoiceParticipants(voiceChannelIds)
        .listen((participants) {
      _voiceParticipants = participants;
      notifyListeners();
    });
  }
}
