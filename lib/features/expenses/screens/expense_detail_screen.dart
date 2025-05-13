import 'dart:async';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/expenses/models/expense_model.dart';
import 'package:fair_share/features/expenses/services/expense_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fair_share/features/expenses/screens/edit_expense_screen.dart';
import 'package:fair_share/features/groups/models/group_model.dart'; 
import 'package:fair_share/features/groups/services/group_service.dart';


class ExpenseDetailScreen extends StatefulWidget {
  
  final String groupId;
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();

  Expense? _expense;
  UserProfile? _payerProfile;
  Map<String, UserProfile?> _splitMemberProfiles = {};
  List<UserProfile> _groupMembers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isDeleting = false;

  final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
   );

  @override
  void initState() {
    super.initState();
    _fetchExpenseAndMemberDetails();
  }

  Future<void> _fetchExpenseAndMemberDetails() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; _groupMembers = []; });
    try {
      final results = await Future.wait([
        _expenseService.getExpenseStream(widget.groupId, widget.expenseId).firstWhere((exp) => exp != null),
        _groupService.getGroupStream(widget.groupId).firstWhere((g) => g != null),
      ]);
      if (!mounted) return;
      _expense = results[0] as Expense?;
      final group = results[1] as Group?;

      if (_expense == null || group == null) { throw Exception("Expense or Group not found."); }

      final List<String> uidsToFetch = {
          _expense!.paidByUid, ..._expense!.splitDetails.keys
      }.toList();

      final profileFutures = uidsToFetch.map((uid) => _userService.getUserProfile(uid));
      final profiles = await Future.wait(profileFutures);

      if (!mounted) return;

      final allMemberFutures = group.members.map((uid) => _userService.getUserProfile(uid)).toList();
      final allMemberProfiles = await Future.wait(allMemberFutures);

      if (!mounted) return;

      Map<String, UserProfile?> profileMap = {};
      int i = 0;
      for (String uid in uidsToFetch) { profileMap[uid] = profiles[i]; i++; }

      setState(() {
        _payerProfile = profileMap[_expense!.paidByUid];
        _splitMemberProfiles = profileMap;
        _groupMembers = allMemberProfiles.where((p) => p != null).cast<UserProfile>().toList();
        _isLoading = false;
      });

    } catch (e) {
      print("Error fetching expense/member details: $e");
      if (mounted) { setState(() { _isLoading = false; _errorMessage = "Failed to load details."; }); }
    }
  }

  String _formatSplitDetail(double value) {
    if (_expense == null) return '';
    switch (_expense!.splitType) {
      case SplitType.exact: return currencyFormatter.format(value);
      case SplitType.percentage: return '${value.toStringAsFixed(1)}%';
      case SplitType.share: return '${value.toInt()} share${value.toInt() != 1 ? 's' : ''}';
      case SplitType.equal: return 'Split equally';
    }
  }

  // Delete Expense Logic
  Future<void> _deleteExpense() async {
     final bool? confirm = await showDialog<bool>( context: context, builder: (BuildContext context) {return AlertDialog( title: const Text("Delete Expense"), content: const Text("Are you sure? This cannot be undone."), actions: <Widget>[ TextButton( child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop(false)), TextButton( style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text("Delete"), onPressed: () => Navigator.of(context).pop(true)), ], ); }, );
     if (confirm == true) {
        if (!mounted) return;
        setState(() => _isDeleting = true);
        bool success = await _expenseService.deleteExpense(widget.groupId, widget.expenseId);
        if (mounted) {
           setState(() => _isDeleting = false);
           if (success) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Expense deleted."))); Navigator.pop(context); }
           else { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Failed to delete expense."), backgroundColor: Colors.red)); }
        }
     }
  }

  void _navigateToEditExpense() {
     if (_expense == null || _groupMembers.isEmpty) {
        print("Cannot edit: Expense or members data not loaded.");
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Data not loaded yet, cannot edit.')));
        return;
     }
     print("Navigating to Edit Expense Screen for ${widget.expenseId}");
     Navigator.push(
       context,
       MaterialPageRoute(builder: (_) => EditExpenseScreen(
           initialExpense: _expense!,
           members: _groupMembers,
          )
       )
     ).then((didUpdate) {
         if (didUpdate == true) {
             print("Returned from Edit screen with update flag. Refreshing...");
             _fetchExpenseAndMemberDetails();
         }
     });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    if (_isLoading) { return Scaffold(appBar: AppBar(title: const Text('Loading...')), body: const Center(child: CircularProgressIndicator())); }
    if (_errorMessage != null) { return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Padding(padding: const EdgeInsets.all(AppDimens.kLargePadding), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error))))); }
    if (_expense == null) { return Scaffold(appBar: AppBar(title: const Text('Error')), body: const Center(child: Text('Expense not found.'))); }

    return Scaffold(
      appBar: AppBar(
        title: Text(_expense!.description, overflow: TextOverflow.ellipsis),
        actions: [
           IconButton( icon: const Icon(Icons.edit_outlined), tooltip: 'Edit Expense', onPressed: _isDeleting ? null : _navigateToEditExpense,),
          _isDeleting ? const Padding( padding: EdgeInsets.all(14.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton( icon: const Icon(Icons.delete_outline), tooltip: 'Delete Expense', color: theme.colorScheme.error, onPressed: _deleteExpense,),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.kLargePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                currencyFormatter.format(_expense!.amount),
                style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: AppDimens.kSpacingSmall),
             Center(
              child: Text(
                _expense!.description,
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.getMutedTextColor(brightness)),
              ),
            ),
            const SizedBox(height: AppDimens.kSpacingLarge),
            ListTile(
                contentPadding: EdgeInsets.zero, leading: CircleAvatar( radius: 20, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: _payerProfile?.profilePicUrl != null ? NetworkImage(_payerProfile!.profilePicUrl!) : null, child: _payerProfile?.profilePicUrl == null ? const Icon(Icons.person_outline, size: 20) : null, ), title: Text("Paid by ${_payerProfile?.name ?? 'Unknown'}"), subtitle: Text("on ${DateFormat.yMMMd().format(_expense!.paidAt)}"),
            ),
            const Divider(height: AppDimens.kSpacingLarge),
            Text("Split Method: ${_splitTypeToDisplayString(_expense!.splitType)}", style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.kSpacingSmall),
            Text("Split Between:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppDimens.kSmallPadding),
             ListView.builder(
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               itemCount: _expense!.splitDetails.length,
               itemBuilder: (context, index) {
                   final uid = _expense!.splitDetails.keys.elementAt(index);
                   final value = _expense!.splitDetails.values.elementAt(index);
                   final memberProfile = _splitMemberProfiles[uid];

                   return ListTile(
                     contentPadding: const EdgeInsets.only(left: AppDimens.kSmallPadding, right: AppDimens.kSmallPadding),
                      leading: CircleAvatar( radius: 18, backgroundColor: theme.colorScheme.surfaceVariant, backgroundImage: memberProfile?.profilePicUrl != null ? NetworkImage(memberProfile!.profilePicUrl!) : null, child: memberProfile?.profilePicUrl == null ? const Icon(Icons.person_outline, size: 18) : null,),
                      title: Text(memberProfile?.name ?? 'Unknown User'),
                      trailing: _expense!.splitType != SplitType.equal
                        ? Text( _formatSplitDetail(value), style: const TextStyle(fontWeight: FontWeight.w500),)
                        : null,
                   );
               },
            ),
          ],
        ),
      ),
    );
  }
  String _splitTypeToDisplayString(SplitType type) {
      switch (type) { case SplitType.equal: return 'Equally'; case SplitType.exact: return 'By Exact Amounts'; case SplitType.percentage: return 'By Percentage'; case SplitType.share: return 'By Shares'; }
  }

}