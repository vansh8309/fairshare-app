import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/expenses/models/expense_model.dart';
import 'package:fair_share/features/expenses/screens/expense_detail_screen.dart';
import 'package:fair_share/features/groups/widgets/group_expenses_tab.dart';
import 'package:fair_share/features/groups/widgets/group_members_tab.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:fair_share/features/groups/screens/group_settings_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GroupService _groupService = GroupService();
  final UserService _userService = UserService();

  StreamSubscription? _groupSubscription;
  Group? _currentGroup; 
  List<UserProfile> _currentMembers = [];
  bool _isDataLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToGroupUpdates();
    _searchController.addListener(() {
      if (mounted) {
        setState(() { _searchQuery = _searchController.text; });
      }
    });
  }

  void _listenToGroupUpdates() {
     setState(() { _isDataLoading = true; _errorMessage = null; });
    _groupSubscription = _groupService.getGroupStream(widget.groupId).listen(
      (group) async {
        if (!mounted) return;
        if (group != null) {
          bool membersChanged = _currentGroup == null || !_listEquals(group.members, _currentGroup!.members);
          _currentGroup = group;

          if (membersChanged) {
             print("Members list changed or initial load, fetching profiles...");
             try {
                final profileFutures = group.members.map((uid) => _userService.getUserProfile(uid)).toList();
                final profiles = await Future.wait(profileFutures);
                if (mounted) {
                   setState(() {
                      _currentMembers = profiles.where((p) => p != null).cast<UserProfile>().toList();
                      _isDataLoading = false;
                      print("Fetched ${_currentMembers.length} member profiles.");
                   });
                }
             } catch (e) {
                 print("Error fetching member profiles in listener: $e");
                 if(mounted) setState(() { _errorMessage = "Error loading member details."; _isDataLoading = false;});
             }
          } else {
             if(mounted) setState(() { _isDataLoading = false; });
          }
        } else {
           if(mounted) setState(() { _errorMessage = "Group not found or error loading."; _isDataLoading = false; _currentGroup = null; _currentMembers = []; });
        }
      },
      onError: (error) {
         print("Error in group stream listener: $error");
         if (mounted) { setState(() { _errorMessage = "Error loading group data."; _isDataLoading = false; });}
      }
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToGroupSettings() {
     print("Navigate to Group Settings (Not Implemented)");
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group Settings (Not Implemented Yet)'), duration: Duration(seconds: 1))
     );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextField(
           controller: _searchController,
           decoration: InputDecoration(
             hintText: 'Search Expenses...',
             border: InputBorder.none,
             enabledBorder: InputBorder.none,
             focusedBorder: InputBorder.none,
             isDense: true,
             hintStyle: TextStyle(color: AppColors.getMutedTextColor(brightness).withOpacity(0.8)),
             suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    color: AppColors.getMutedTextColor(brightness),
                    onPressed: () { _searchController.clear(); },
                  )
                : null,
           ),
           style: TextStyle(color: AppColors.getTextColor(brightness), fontSize: 16),
         ),
        actions: [
           IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Group Settings',
              onPressed: () {
                if ( _currentGroup != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GroupSettingsScreen(group:  _currentGroup!)),
                    );
                }
              },
          ),
        ], 
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expenses', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Members', icon: Icon(Icons.people_outline)),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isDataLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_currentGroup == null) {
       return const Center(child: Text("Group data not available."));
    }
    return TabBarView(
      controller: _tabController,
      children: [
        GroupExpensesTab(group: _currentGroup!,members: _currentMembers, searchQuery: _searchQuery),
        GroupMembersTab(group: _currentGroup!, members: _currentMembers),
      ],
    );
  }
}