import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/balances/services/balance_service.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/groups/screens/create_group_screen.dart';
import 'package:fair_share/features/groups/screens/group_detail_screen.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:flutter/material.dart';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class GroupListWidget extends StatefulWidget {
  final String searchQuery;

  const GroupListWidget({
    super.key,
    required this.searchQuery,
  });

  @override
  State<GroupListWidget> createState() => _GroupListWidgetState();
}

class _GroupListWidgetState extends State<GroupListWidget> {
  final GroupService _groupService = GroupService();
  final BalanceService _balanceService = BalanceService();
  final AuthService _authService = AuthService();

  final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final String? currentUserId = _authService.getCurrentUser()?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB( AppDimens.kLargePadding, AppDimens.kDefaultPadding, AppDimens.kLargePadding, AppDimens.kSmallPadding),
          child: SizedBox( width: double.infinity, child: ElevatedButton.icon( icon: const Icon(Icons.add_circle_outline), label: const Text("Create New Group"), style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.kInputBorderRadius)),), onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => const CreateGroupScreen()), ); },),),
        ),
        const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding,),

        Expanded(
          child: StreamBuilder<List<Group>>(
            stream: _groupService.getUserGroupsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
              if (snapshot.hasError) { return Center(child: Text('Error: ${snapshot.error}')); }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                 return Center( child: Padding( padding: const EdgeInsets.all(AppDimens.kLargePadding), child: Text( widget.searchQuery.isEmpty ? 'You have no groups yet.\nUse the button above to create one!' : 'No groups found.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey), ),), );
              }

              final List<Group> allGroups = snapshot.data!;

              final List<Group> filteredGroups = allGroups.where((group) {
                  if (widget.searchQuery.isEmpty) {
                      return true;
                  }
                  return group.groupName.toLowerCase().contains(widget.searchQuery.toLowerCase());
              }).toList();

              if (filteredGroups.isEmpty && allGroups.isNotEmpty) {
                 return Center( child: Padding( padding: const EdgeInsets.all(AppDimens.kLargePadding), child: Text( 'No groups found matching "${widget.searchQuery}".', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey), ),), );
              }

              return ListView.separated(
                itemCount: filteredGroups.length,
                padding: const EdgeInsets.only(top: AppDimens.kSmallPadding, bottom: 80),
                separatorBuilder: (context, index) => const Divider(height: 1, indent: AppDimens.kLargePadding + 56, endIndent: AppDimens.kLargePadding,),
                itemBuilder: (context, index) {
                  final Group group = filteredGroups[index];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding / 2),
                    leading: CircleAvatar( backgroundColor: theme.colorScheme.surfaceVariant, foregroundColor: theme.colorScheme.onSurfaceVariant, child: _getGroupIcon(group.groupType), ),
                    title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${group.members.length} Member(s) - ${group.groupType}'),
                    trailing: currentUserId == null ? const SizedBox.shrink() : StreamBuilder<Map<String, double>>( stream: _balanceService.getGroupBalancesStream(group.id), builder: (context, balanceMapSnapshot) { if (balanceMapSnapshot.connectionState == ConnectionState.waiting && !balanceMapSnapshot.hasData) { return const SizedBox(width: 40, height: 20, child: Center(child: Text("--", style: TextStyle(color: Colors.grey)))); } if (balanceMapSnapshot.hasError) { return Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18); } final Map<String, double> balances = balanceMapSnapshot.data ?? {}; final double netBalance = balances[currentUserId] ?? 0.0; final bool isSettled = netBalance.abs() < 0.01; if (isSettled) { return const SizedBox(width: 40); } final bool isOwedToUser = netBalance >= -0.005; final Color balanceColor = isOwedToUser ? AppColors.success : theme.colorScheme.error; final String prefix = isOwedToUser ? '+' : '-'; final String formattedAmount = currencyFormatter.format(netBalance.abs()); return Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [ Text( '$prefix$formattedAmount', style: theme.textTheme.bodyMedium?.copyWith( color: balanceColor, fontWeight: FontWeight.bold,),), Text( (isOwedToUser ? 'Owed' : 'You owe'), style: theme.textTheme.labelSmall?.copyWith(color: balanceColor),), ],); }, ),
                    onTap: () { Navigator.push( context, MaterialPageRoute( builder: (_) => GroupDetailScreen(groupId: group.id), ), ); },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _getGroupIcon(String groupType) {
    IconData iconData;
    switch (groupType.toLowerCase()) {
       case 'travel': iconData = Icons.flight_takeoff; break;
       case 'rent': iconData = Icons.house_outlined; break;
       case 'food': iconData = Icons.restaurant; break;
       case 'shopping': iconData = Icons.shopping_bag_outlined; break;
       case 'car pool': iconData = Icons.directions_car_filled; break;
       default: iconData = Icons.group_outlined;
    }
    return Icon(iconData, size: 20);
 }

}