import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/balances/models/simplified_debt.dart';
import 'package:fair_share/features/balances/services/balance_service.dart';
import 'package:fair_share/features/expenses/models/expense_model.dart';
import 'package:fair_share/features/expenses/screens/add_expense_screen.dart';
import 'package:fair_share/features/expenses/screens/expense_detail_screen.dart';
import 'package:fair_share/features/expenses/services/expense_service.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:fair_share/features/settlements/screens/settle_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GroupExpensesTab extends StatelessWidget {
  final Group group;
  final List<UserProfile> members;
  final String searchQuery;

  final ExpenseService _expenseService = ExpenseService();
  final BalanceService _balanceService = BalanceService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  GroupExpensesTab({
    super.key,
    required this.group,
    required this.members,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFgColor = AppColors.getButtonForegroundColor(AppColors.secondary);
    final brightness = theme.brightness;
    final String? myUid = _authService.getCurrentUser()?.uid;

    return Column(
      children: [
        _buildBalanceSummaryHeader(context, group, myUid),  

        const Divider(height: AppDimens.kSpacingSmall, thickness: 1),

        Expanded(
          child: StreamBuilder<List<Expense>>(
            stream: _expenseService.getGroupExpensesStream(group.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
              if (snapshot.hasError) { return Center(child: Text('Error: ${snapshot.error}')); }
              if (!snapshot.hasData || snapshot.data!.isEmpty) { return const Center(child: Text('No expenses added yet.', style: TextStyle(fontSize: 16, color: Colors.grey))); }

              final List<Expense> allExpenses = snapshot.data!;
              final List<Expense> filteredExpenses = allExpenses.where((expense) {
                 if (searchQuery.isEmpty) {
                    return true;
                 }
                 return expense.description.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

              if (filteredExpenses.isEmpty && allExpenses.isNotEmpty) {
                 return Center(child: Text('No expenses found matching "$searchQuery"', style: const TextStyle(fontSize: 16, color: Colors.grey)));
              }
              if (allExpenses.isEmpty) {
                 return const Center(child: Text('No expenses added yet.', style: TextStyle(fontSize: 16, color: Colors.grey)));
              }

              return ListView.separated(
                padding: const EdgeInsets.only(top: AppDimens.kSmallPadding, bottom: AppDimens.kLargePadding),
                itemCount: allExpenses.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: AppDimens.kLargePadding, endIndent: AppDimens.kLargePadding),
                itemBuilder: (context, index) {
                  final Expense expense = allExpenses[index];
                  double myShare = 0.0; if (myUid != null) { myShare = _balanceService.calculateMyShareOfExpense(expense, myUid); }
                  double paidByMe = (expense.paidByUid == myUid) ? expense.amount : 0.0;
                  double netEffect = paidByMe - myShare;
                  final bool isSettled = netEffect.abs() < 0.01;
                  final bool isOwedToUser = netEffect >= -0.005;
                  final Color balanceColor = isSettled ? AppColors.getMutedTextColor(brightness) : (isOwedToUser ? AppColors.success : theme.colorScheme.error);
                  final String prefix = isOwedToUser ? (isSettled ? '' : '+') : '-';
                  final String formattedNetEffect = currencyFormatter.format(netEffect.abs());

                  return ListTile(
                    leading: CircleAvatar( child: Icon(Icons.receipt, color: theme.colorScheme.secondary), backgroundColor: theme.colorScheme.secondaryContainer,),
                    title: Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Paid by ${expense.paidByName} • ${DateFormat.yMd().format(expense.paidAt)}'), Text('Total: ${currencyFormatter.format(expense.amount)}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.getMutedTextColor(brightness))), ], ),
                    trailing: Tooltip( message: isSettled ? 'Settled for this expense' : (isOwedToUser ? 'You lent' : 'You owe'), child: Text( isSettled ? ' ' : '$prefix$formattedNetEffect', style: theme.textTheme.titleMedium?.copyWith( color: balanceColor, fontWeight: FontWeight.bold,), textAlign: TextAlign.right,), ),
                    onTap: () { Navigator.push( context, MaterialPageRoute(builder: (_) => ExpenseDetailScreen( groupId: group.id, expenseId: expense.id ) ) ); },
                  );
                },
              );
            },
          ),
        ),

        Padding(
           padding: const EdgeInsets.fromLTRB(AppDimens.kLargePadding, AppDimens.kSmallPadding, AppDimens.kLargePadding, AppDimens.kDefaultPadding),
           child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add), label: const Text("Add New Expense"),
              style: ElevatedButton.styleFrom( backgroundColor: AppColors.secondary, foregroundColor: buttonFgColor, padding: AppDimens.kContinueButtonPadding,),
              onPressed: () { Navigator.push( context, MaterialPageRoute( builder: (context) => AddExpenseScreen( groupId: group.id, groupCurrencyCode: group.currencyCode,) ),); },
            ),
           ),
         ),
      ],
    );
  }

  Widget _buildBalanceSummaryHeader(BuildContext context, Group group, String? myUid) {
     final theme = Theme.of(context);
     final brightness = theme.brightness;

     if (myUid == null) {
         return const Padding( padding: EdgeInsets.all(AppDimens.kDefaultPadding), child: Text("Cannot load balances - user not identified."),);
     }

     return Padding(
       padding: const EdgeInsets.all(AppDimens.kDefaultPadding),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text( group.groupName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis,),
             const SizedBox(height: AppDimens.kSpacingMedium),

             StreamBuilder<List<SimplifiedDebt>>(
               stream: _balanceService.getSimplifiedDebtsForUserStream(group.id),
               builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox(height: 20, child: Text("Calculating balances...", style: TextStyle(color: Colors.grey))));
                  }
                  if (snapshot.hasError) {
                    print("Balance Summary Error: ${snapshot.error}");
                    return Center(child: Text("Error calculating balances.", style: TextStyle(color: theme.colorScheme.error)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text("✅ You are all settled up!", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)));
                  }

                  final List<SimplifiedDebt> debts = snapshot.data!;
                  final List<SimplifiedDebt> debtsOwedByMe = debts.where((d) => d.fromUid == myUid).toList();
                  final List<SimplifiedDebt> debtsOwedToMe = debts.where((d) => d.toUid == myUid).toList();

                  return Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                        SizedBox(
                           height: 70,
                           child: ListView(
                             scrollDirection: Axis.horizontal,
                             children: [
                                if (debtsOwedByMe.isNotEmpty)
                                  ...debtsOwedByMe.map((debt) => Padding(
                                      padding: const EdgeInsets.only(right: AppDimens.kSpacingSmall),
                                      child: _buildBalanceChip(context, debt.toUid, debt.amount, false)
                                    )).toList(),
                                 if (debtsOwedToMe.isNotEmpty)
                                  ...debtsOwedToMe.map((debt) => Padding(
                                     padding: const EdgeInsets.only(right: AppDimens.kSpacingSmall),
                                     child: _buildBalanceChip(context, debt.fromUid, debt.amount, true)
                                   )).toList(),
                             ],
                           ),
                        ),

                        const SizedBox(height: AppDimens.kSpacingMedium),
                         Center(
                          child: SizedBox( 
                            width: double.infinity,
                            child: ElevatedButton.icon(
                                icon: const Icon(Icons.compare_arrows_outlined),
                                label: const Text("Settle Up"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.getButtonForegroundColor(AppColors.primary),
                                ),
                                onPressed: () {
                                  print("Settle Up tapped. Debts: $debts");
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettleUpScreen(
                                        groupId: group.id,
                                        groupCurrencyCode: group.currencyCode,
                                        simplifiedDebts: debts,
                                      )));
                                },
                            ),
                          ),
                         ),
                     ],
                  );
               },
             ),
          ],
       ),
     );
  }

  Widget _buildBalanceChip(BuildContext context, String otherUserUid, double amount, bool theyOweMe) {
    final theme = Theme.of(context);
    final Color color = theyOweMe ? AppColors.success : theme.colorScheme.error;
    final String prefix = theyOweMe ? '+' : '-';

    return FutureBuilder<UserProfile?>(
      future: _userService.getUserProfile(otherUserUid),
      builder: (context, userSnapshot) {
        String name = 'User...';
        Widget avatarChild = const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5));

        if (userSnapshot.connectionState == ConnectionState.done) {
           if(userSnapshot.hasData && userSnapshot.data != null) {
              name = userSnapshot.data!.name; 
              avatarChild = userSnapshot.data!.profilePicUrl == null
                 ? const Icon(Icons.person, size: 12)
                 : CircleAvatar(radius: 12, backgroundImage: NetworkImage(userSnapshot.data!.profilePicUrl!));
           } else {
               name = 'Unknown User';
               avatarChild = const Icon(Icons.error_outline, size: 12);
           }
        }

        return Chip(
           avatar: CircleAvatar( radius: 12, backgroundColor: theme.colorScheme.surfaceVariant, child: avatarChild),
           label: Text.rich(
             TextSpan( children: [
                 TextSpan(text: theyOweMe ? '$name owes ' : 'You owe $name '),
                 TextSpan(text: currencyFormatter.format(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
               ]
             ),
             style: theme.textTheme.bodyMedium,
           ),
           backgroundColor: color.withOpacity(0.1),
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
           labelPadding: const EdgeInsets.only(left: 4),
           visualDensity: VisualDensity.compact,
           side: BorderSide.none,
        );
      }
    );
  }

}