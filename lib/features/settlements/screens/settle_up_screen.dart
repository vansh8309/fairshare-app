import 'package:fair_share/core/constants/app_dimens.dart';
import 'package:fair_share/core/services/user_service.dart';
import 'package:fair_share/core/theme/app_colors.dart';
import 'package:fair_share/features/auth/services/auth_service.dart';
import 'package:fair_share/features/balances/models/simplified_debt.dart';
import 'package:fair_share/features/expenses/services/expense_service.dart';
import 'package:fair_share/features/profile/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SettleUpScreen extends StatefulWidget {
  final String groupId;
  final String groupCurrencyCode;
  final List<SimplifiedDebt> simplifiedDebts;

  const SettleUpScreen({
    super.key,
    required this.groupId,
    required this.groupCurrencyCode,
    required this.simplifiedDebts,
  });

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  final Map<String, bool> _settlingState = {};
  final Set<String> _settledInSession = {};

  final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  String _getDebtKey(SimplifiedDebt debt) {
     return '${debt.fromUid}-${debt.toUid}';
  }

  // Record Settlement Logic
  Future<void> _recordSettlement(SimplifiedDebt debt) async {
    final String debtKey = _getDebtKey(debt);
    if (_settlingState[debtKey] == true || _settledInSession.contains(debtKey)) {
        return;
    }

    if (mounted) setState(() => _settlingState[debtKey] = true);

    final UserProfile? payerProfile = await _userService.getUserProfile(debt.fromUid);

    if(payerProfile == null) {
        print("SettleUpScreen: Could not find payer profile (${debt.fromUid}). Cannot record settlement.");
         if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Payer details not found.'), backgroundColor: Colors.red));
             setState(() => _settlingState.remove(debtKey));
         }
         return;
    }


    bool success = await _expenseService.recordSettlementPayment(
      widget.groupId,
      widget.groupCurrencyCode,
      debt,
    );

    if (mounted) {
       setState(() {
          _settlingState.remove(debtKey);
          if (success) {
             _settledInSession.add(debtKey);
          }
       });
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(success ? "Settlement recorded!" : "Failed to record settlement."),
           backgroundColor: success ? AppColors.success : Theme.of(context).colorScheme.error,
         ),
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? myUid = _authService.getCurrentUser()?.uid;

    final List<SimplifiedDebt> debtsToShow = widget.simplifiedDebts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up Debts'),
      ),
      body: debtsToShow.isEmpty
          ? const Center(child: Text('No outstanding settlements needed!'))
          : ListView.separated(
              padding: const EdgeInsets.all(AppDimens.kDefaultPadding),
              itemCount: debtsToShow.length,
              separatorBuilder: (_, __) => const Divider(height: AppDimens.kSpacingMedium),
              itemBuilder: (context, index) {
                final debt = debtsToShow[index];
                final String debtKey = _getDebtKey(debt);
                final bool isLoading = _settlingState[debtKey] ?? false;
                final bool isSettledThisSession = _settledInSession.contains(debtKey);
                final bool isCurrentUserPayer = myUid == debt.fromUid;
                final bool isCurrentUserReceiver = myUid == debt.toUid;

                return FutureBuilder<List<UserProfile?>>(
                  future: Future.wait([
                     _userService.getUserProfile(debt.fromUid),
                     _userService.getUserProfile(debt.toUid),
                  ]),
                  builder: (context, snapshot) {
                    String payerName = 'User...';
                    String receiverName = 'User...';
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                       payerName = snapshot.data?[0]?.name ?? 'Unknown';
                       receiverName = snapshot.data?[1]?.name ?? 'Unknown';
                    } else if (snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
                       payerName = 'Error';
                       receiverName = 'Error';
                    }

                    return Opacity(
                      opacity: isSettledThisSession ? 0.5 : 1.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppDimens.kSmallPadding),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: theme.textTheme.bodyLarge,
                                  children: [
                                     TextSpan(text: isCurrentUserPayer ? 'You' : payerName, style: TextStyle(fontWeight: isCurrentUserPayer ? FontWeight.bold : FontWeight.normal)),
                                     const TextSpan(text: ' pay '),
                                     TextSpan(text: isCurrentUserReceiver ? 'You' : receiverName, style: TextStyle(fontWeight: isCurrentUserReceiver ? FontWeight.bold : FontWeight.normal)),
                                     const TextSpan(text: ' '),
                                     TextSpan(text: currencyFormatter.format(debt.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ]
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimens.kDefaultPadding),
                            ElevatedButton(
                              onPressed: isLoading || isSettledThisSession ? null : () => _recordSettlement(debt),
                              style: ElevatedButton.styleFrom(
                                 padding: const EdgeInsets.symmetric(horizontal: AppDimens.kDefaultPadding, vertical: AppDimens.kSmallPadding),
                                 backgroundColor: isSettledThisSession ? Colors.grey : AppColors.primary,
                                 foregroundColor: AppColors.getButtonForegroundColor(isSettledThisSession ? Colors.grey : AppColors.primary),
                              ),
                              child: isLoading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(isSettledThisSession ? 'Paid' : 'Mark Paid'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}