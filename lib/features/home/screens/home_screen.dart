import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/friends/screens/friends_list_screen.dart';
import 'package:fair_share/features/groups/widgets/group_list_widget.dart';
import 'package:fair_share/features/profile/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:fair_share/features/expenses/screens/select_group_for_expense_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  int _selectedIndex = 0;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted && _searchQuery != _searchController.text) {
        setState(() { _searchQuery = _searchController.text; });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int bottomNavIndex) {
    int pageIndex = bottomNavIndex > 1 ? 1 : 0;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onQuickAddTapped() {
    print("Quick Add button tapped! Navigating to group selection.");
    Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => SelectGroupForExpenseScreen()),
    );
  }

  void _navigateToProfile() {
     Navigator.push( context, MaterialPageRoute(builder: (context) => const ProfileScreen()),);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _authService.getCurrentUser();
    final brightness = theme.brightness;
    final fabFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
           controller: _searchController,
           decoration: InputDecoration(
             hintText: _selectedIndex == 0 ? 'Search My Groups...' : 'Search Friends...',
             border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
             isDense: true,
             hintStyle: TextStyle(color: AppColors.getMutedTextColor(brightness).withOpacity(0.8)),
             prefixIcon: Icon(Icons.search, color: theme.iconTheme.color?.withOpacity(0.6)),
             suffixIcon: _searchQuery.isNotEmpty
                ? IconButton( icon: const Icon(Icons.clear, size: 20), color: AppColors.getMutedTextColor(brightness), onPressed: () { _searchController.clear(); }, tooltip: 'Clear search',)
                : null,
           ),
           style: TextStyle(color: AppColors.getTextColor(brightness), fontSize: 16),
         ),
        actions: [
          Padding(
             padding: const EdgeInsets.only(right: AppDimens.kSmallPadding, top: 4, bottom: 4), child: InkWell( onTap: _navigateToProfile, customBorder: const CircleBorder(), child: CircleAvatar( radius: 20, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null, child: currentUser?.photoURL == null ? Icon(Icons.person_outline, size: 22, color: theme.colorScheme.onSurfaceVariant) : null,),),
          ),
        ],
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
           if (mounted && index != _selectedIndex) {
               print("Page changed to: $index");
               setState(() { _selectedIndex = index; });
           }
        },
        children: [
          GroupListWidget(searchQuery: _searchQuery),
          FriendsListScreen(searchQuery: _searchQuery),
        ],  
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onQuickAddTapped, backgroundColor: AppColors.secondary, foregroundColor: fabFgColor, elevation: 2.0, shape: const CircleBorder(), child: const Icon(Icons.receipt_long_outlined), tooltip: 'Quick Add Expense',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.groups_2_outlined), tooltip: 'Groups',
              color: _selectedIndex == 0 ? theme.colorScheme.primary : theme.iconTheme.color,
              onPressed: () => _onItemTapped(0),
            ),
             const SizedBox(width: 40),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined), tooltip: 'Friends',
              color: _selectedIndex == 1 ? theme.colorScheme.primary : theme.iconTheme.color,
              onPressed: () => _onItemTapped(2),
            ),
          ],
        ),
      ),
    );
  }
}