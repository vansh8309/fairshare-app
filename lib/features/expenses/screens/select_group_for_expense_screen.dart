import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/expenses/screens/add_expense_screen.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:flutter/material.dart';

class SelectGroupForExpenseScreen extends StatelessWidget {
 SelectGroupForExpenseScreen({super.key});
  final GroupService _groupService = GroupService();
  Widget _getGroupIcon(String groupType, BuildContext context) {
     final theme = Theme.of(context);
     IconData iconData;
     switch (groupType.toLowerCase()) {
       case 'travel': iconData = Icons.flight_takeoff; break;
       case 'rent': iconData = Icons.house_outlined; break;
       case 'food': iconData = Icons.restaurant; break;
       case 'shopping': iconData = Icons.shopping_bag_outlined; break;
       case 'car pool': iconData = Icons.directions_car_filled; break;
       default: iconData = Icons.group_outlined;
     }
     return Icon(iconData, size: 20, color: theme.colorScheme.onSurfaceVariant);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Group for Expense'),
      ),
      body: StreamBuilder<List<Group>>(
        stream: _groupService.getUserGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading groups: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.kLargePadding),
                child: Text(
                  'You need to be in a group to add an expense.\nCreate or join a group first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          final List<Group> groups = snapshot.data!;
          return ListView.separated(
            itemCount: groups.length,
            padding: const EdgeInsets.symmetric(vertical: AppDimens.kSmallPadding),
            separatorBuilder: (context, index) => const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding),
            itemBuilder: (context, index) {
              final Group group = groups[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.kLargePadding, vertical: AppDimens.kSmallPadding / 2),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  child: _getGroupIcon(group.groupType, context),
                ),
                title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${group.members.length} Member(s)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  print('Selected group ${group.id} for new expense.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        groupId: group.id,
                        groupCurrencyCode: group.currencyCode,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}