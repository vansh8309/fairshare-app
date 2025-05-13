import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/expenses/models/expense_model.dart';
import 'package:fair_share/features/expenses/services/expense_service.dart';
import 'package:fair_share/features/groups/models/group_model.dart';
import 'package:fair_share/features/groups/services/group_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AddExpenseScreen extends StatefulWidget {
  final String groupId;
  final String groupCurrencyCode;

  const AddExpenseScreen({
    super.key,
    required this.groupId,
    required this.groupCurrencyCode,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final ExpenseService _expenseService = ExpenseService();
  final AuthService _authService = AuthService();
  final GroupService _groupService = GroupService();
  final UserService _userService = UserService();

  DateTime _paidAt = DateTime.now();
  String? _paidByUid;
  SplitType _selectedSplitType = SplitType.equal;

  Set<String> _selectedMembersForEqualSplit = {};
  Map<String, TextEditingController> _splitAmountControllers = {};

  bool _isScreenLoading = true;
  bool _isSaving = false;
  String? _loadingError;

  Group? _group;
  List<UserProfile> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchGroupAndMemberData();
  }

  Future<void> _fetchGroupAndMemberData() async {
    if (!mounted) return;
    setState(() { _isScreenLoading = true; _loadingError = null; });
    try {
       _group = await _groupService.getGroupStream(widget.groupId).firstWhere((g) => g != null);
       if (!mounted || _group == null) { throw Exception("Group not found."); }

       List<UserProfile> membersTemp = [];
       final profileFutures = _group!.members.map((uid) => _userService.getUserProfile(uid)).toList();
       final profiles = await Future.wait(profileFutures);
       for (final profile in profiles) { if (profile != null) { membersTemp.add(profile); } else { print("Warning: Could not fetch profile for a member UID."); } }
       if (!mounted) return;
       if (membersTemp.isEmpty && _group!.members.isNotEmpty) { throw Exception("Could not load member profiles."); }

       setState(() {
         _groupMembers = membersTemp;
         _paidByUid = _authService.getCurrentUser()?.uid ?? ((_groupMembers.isNotEmpty) ? _groupMembers.first.uid : null);
         _selectedMembersForEqualSplit = _groupMembers.map((m) => m.uid).toSet();
         _initializeSplitControllers();
         _isScreenLoading = false;
       });
    } catch (e) {
      print("Error fetching group/member data: $e");
      if (mounted) { setState(() { _loadingError = "Error loading group data."; _isScreenLoading = false; }); }
    }
  }

  void _initializeSplitControllers() {
    _splitAmountControllers.forEach((_, controller) => controller.dispose());
    _splitAmountControllers = {};
    for (var member in _groupMembers) {
      _splitAmountControllers[member.uid] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _splitAmountControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
     final DateTime? picked = await showDatePicker( context: context, initialDate: _paidAt, firstDate: DateTime(2020, 1), lastDate: DateTime.now(), );
     if (picked != null && picked != _paidAt) { setState(() { _paidAt = picked; }); }
  }

  Future<void> _saveExpense() async {
    if (_groupMembers.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member data not loaded.'))); return; }
    if (!_formKey.currentState!.validate()) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Please fix the errors in the form.'), backgroundColor: Colors.red), ); return; }
    if (_paidByUid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select who paid.'))); return; }

    // --- Split Validation ---
    double totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    bool splitIsValid = true; String splitValidationError = '';
    if (_selectedSplitType == SplitType.exact || _selectedSplitType == SplitType.percentage || _selectedSplitType == SplitType.share) { double splitSum = 0; _splitAmountControllers.forEach((uid, controller) { splitSum += double.tryParse(controller.text.trim()) ?? 0.0; }); if (_splitAmountControllers.isEmpty || _splitAmountControllers.values.every((c) => (double.tryParse(c.text.trim()) ?? 0) == 0)) { splitIsValid = false; splitValidationError = 'Please specify how the expense is split.'; } else if (_selectedSplitType == SplitType.exact && (splitSum - totalAmount).abs() > 0.01) { splitIsValid = false; splitValidationError = 'Split amounts must add up to ${totalAmount.toStringAsFixed(2)}. Sum: ${splitSum.toStringAsFixed(2)}'; } else if (_selectedSplitType == SplitType.percentage && (splitSum - 100.0).abs() > 0.01) { splitIsValid = false; splitValidationError = 'Percentages must add up to 100. Sum: ${splitSum.toStringAsFixed(2)}%'; } }
    else if (_selectedSplitType == SplitType.equal && _selectedMembersForEqualSplit.isEmpty) { splitIsValid = false; splitValidationError = 'Select at least one member.'; }
    if (!splitIsValid) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(splitValidationError), backgroundColor: Colors.red)); return; }

    if (mounted) setState(() => _isSaving = true);
    Map<String, double> finalSplitDetails = {};
    if (_selectedSplitType == SplitType.equal) { for (var uid in _selectedMembersForEqualSplit) { finalSplitDetails[uid] = 1.0; } }
    else { _splitAmountControllers.forEach((uid, controller) { double value = double.tryParse(controller.text.trim()) ?? 0.0; if (value > 0) { finalSplitDetails[uid] = value; } }); }

    final payerProfile = _groupMembers.firstWhere((m) => m.uid == _paidByUid, orElse: () => UserProfile(uid: _paidByUid!, name: 'Unknown Payer'));

    Map<String, dynamic> expenseData = { 'description': _descriptionController.text.trim(), 'amount': totalAmount, 'currencyCode': widget.groupCurrencyCode, 'paidAt': Timestamp.fromDate(_paidAt), 'paidByUid': _paidByUid!, 'paidByName': payerProfile.name, 'paidByPicUrl': payerProfile.profilePicUrl, 'splitType': _selectedSplitType.name.toUpperCase(), 'splitDetails': finalSplitDetails, };

    try {
      final newExpenseId = await _expenseService.addExpense(widget.groupId, expenseData);
      if (newExpenseId != null && mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added successfully!'))); }
      else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add expense.'), backgroundColor: Colors.red)); setState(() => _isSaving = false); }
    } catch(e) {
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving expense: ${e.toString()}'), backgroundColor: Colors.red)); setState(() => _isSaving = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final saveButtonFgColor = AppColors.getButtonForegroundColor(AppColors.primary);
    if (_isScreenLoading) { return Scaffold(appBar: AppBar(title: const Text('Add Expense')), body: const Center(child: CircularProgressIndicator())); }
    if (_loadingError != null) { return Scaffold(appBar: AppBar(title: const Text('Add Expense')), body: Center(child: Padding(padding: const EdgeInsets.all(AppDimens.kLargePadding), child: Text(_loadingError!, style: TextStyle(color: theme.colorScheme.error))))); }
    if (_group == null || _groupMembers.isEmpty) { return Scaffold(appBar: AppBar(title: const Text('Add Expense')), body: const Center(child: Text('Could not load group members.'))); }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Expense'),
        actions: [
          Padding( padding: const EdgeInsets.only(right: 8.0), child: _isSaving ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))) : TextButton( onPressed: _saveExpense, child: Text('SAVE', style: TextStyle(color: theme.appBarTheme.foregroundColor ?? (brightness == Brightness.dark ? Colors.white : Colors.black), fontWeight: FontWeight.bold)), ),),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.kLargePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description', hintText: 'E.g., Lunch, Groceries...'), textCapitalization: TextCapitalization.sentences, validator: (v)=>(v==null||v.trim().isEmpty)?'Enter desc':null,),
                const SizedBox(height: AppDimens.kSpacingMedium),

                Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded( flex: 2, child: TextFormField( controller: _amountController, decoration: InputDecoration(labelText: 'Amount (${widget.groupCurrencyCode})'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], validator: (v){if(v==null||v.trim().isEmpty)return'Enter amount'; final a=double.tryParse(v.trim());if(a==null||a<=0)return'Invalid amount';return null;},),),
                    const SizedBox(width: AppDimens.kSpacingSmall),
                    Expanded( flex: 1, child: InkWell( onTap: () => _selectDate(context), child: InputDecorator(
                          decoration: InputDecoration( labelText: 'Date', border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius))),
                            enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(AppDimens.kInputBorderRadius)), borderSide: BorderSide(color: AppColors.getInputBorderColor(brightness))),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), ),
                          child: Text( DateFormat.yMd().format(_paidAt), style: TextStyle(color: AppColors.getTextColor(brightness))),
                        ),),),
                  ],
                ),
                const SizedBox(height: AppDimens.kSpacingMedium),

                // Payer Dropdown
                DropdownButtonFormField<String>(
                  value: _paidByUid, decoration: const InputDecoration(labelText: 'Paid By'),
                  items: _groupMembers.map((UserProfile member) { return DropdownMenuItem<String>( value: member.uid, child: Text(member.uid == _authService.getCurrentUser()?.uid ? 'You (${member.name})' : member.name),); }).toList(),
                  onChanged: (String? newValue) { setState(() { _paidByUid = newValue; }); },
                  validator: (value) => (value == null) ? 'Please select who paid' : null,
                ),
                const SizedBox(height: AppDimens.kSpacingLarge),

                // Split Method Dropdown
                 Text('Split Method', style: theme.textTheme.titleMedium),
                 const SizedBox(height: AppDimens.kSpacingSmall),
                 DropdownButtonFormField<SplitType>( value: _selectedSplitType, decoration: const InputDecoration( labelText: 'Split Method',),
                    items: SplitType.values.map((SplitType type) => DropdownMenuItem<SplitType>(value: type, child: Text(_splitTypeToDisplayString(type)))).toList(),
                    onChanged: (SplitType? newValue) { if (newValue != null) { setState(() { _selectedSplitType = newValue; _initializeSplitControllers(); }); } },
                 ),
                 const SizedBox(height: AppDimens.kSpacingMedium),

                // Dynamic Split Input Area
                 Text('Split Details', style: theme.textTheme.titleMedium),
                 const SizedBox(height: AppDimens.kSpacingSmall),
                 _buildSplitDetailsInput(context, theme, brightness),
                 const SizedBox(height: AppDimens.kSpacingLarge * 2),

                 SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitDetailsInput(BuildContext context, ThemeData theme, Brightness brightness){
     switch (_selectedSplitType) {
       case SplitType.equal: return Column( children: _groupMembers.map((member) => CheckboxListTile( title: Text(member.name), value: _selectedMembersForEqualSplit.contains(member.uid), onChanged: (bool? value) { setState(() { if (value == true) { _selectedMembersForEqualSplit.add(member.uid); } else { _selectedMembersForEqualSplit.remove(member.uid); } }); }, secondary: CircleAvatar(radius: 15, backgroundImage: member.profilePicUrl != null ? NetworkImage(member.profilePicUrl!) : null, child: member.profilePicUrl == null ? const Icon(Icons.person, size: 15) : null,), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero,)).toList(),);
       case SplitType.exact: case SplitType.percentage: case SplitType.share:
          String inputLabel = ''; TextInputType keyboardType = TextInputType.number; List<TextInputFormatter>? formatters = [];
          if (_selectedSplitType == SplitType.exact) { inputLabel = 'Amount'; keyboardType = const TextInputType.numberWithOptions(decimal: true); formatters = [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]; }
          else if (_selectedSplitType == SplitType.percentage) { inputLabel = '%'; keyboardType = const TextInputType.numberWithOptions(decimal: true); formatters = [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]; }
          else { inputLabel = 'Shares'; keyboardType = TextInputType.number; formatters = [FilteringTextInputFormatter.digitsOnly];}
          return Column( children: _groupMembers.map((member) { final controller = _splitAmountControllers[member.uid] ?? TextEditingController(); _splitAmountControllers[member.uid] = controller; return Padding( padding: const EdgeInsets.only(bottom: AppDimens.kSpacingSmall), child: Row( children: [ CircleAvatar(radius: 18, backgroundImage: member.profilePicUrl != null ? NetworkImage(member.profilePicUrl!) : null, child: member.profilePicUrl == null ? const Icon(Icons.person, size: 18) : null,), const SizedBox(width: AppDimens.kSpacingMedium), Expanded(child: Text(member.name, overflow: TextOverflow.ellipsis)), const SizedBox(width: AppDimens.kSpacingMedium), SizedBox( width: 100, child: TextFormField( controller: controller, decoration: InputDecoration( labelText: inputLabel, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))), enabledBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.getInputBorderColor(brightness))), filled: true, fillColor: AppColors.getInputFillColor(brightness), ), style: TextStyle(color: AppColors.getTextColor(brightness)), textAlign: TextAlign.right, keyboardType: keyboardType, inputFormatters: formatters, ), ), ], ),); }).toList(),);
     }
  }

  String _splitTypeToDisplayString(SplitType type) {
      switch (type) { case SplitType.equal: return 'Equally'; case SplitType.exact: return 'By Exact Amounts'; case SplitType.percentage: return 'By Percentage'; case SplitType.share: return 'By Shares'; }
  }

}