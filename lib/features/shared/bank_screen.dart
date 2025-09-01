import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import '../../core/balance.dart';

class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({Key? key}) : super(key: key);
  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  final _dep = TextEditingController(text: '100');
  final _wd = TextEditingController(text: '100');
  final _loan = TextEditingController(text: '500');
  final Map<String, TextEditingController> _repayCtrls = {};
  @override
  void dispose() {
    _dep.dispose();
    _wd.dispose();
    _loan.dispose();
    for (final c in _repayCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }
  TextEditingController _repayCtrlFor(String id) {
    return _repayCtrls[id] ??= TextEditingController(text: '100');
  }
  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final bank = (gs['meta']['bank'] ?? 0) as int;
    final cash = gs['cash'] as int;
  final lastInt = (gs['meta']['lastInterest'] ?? 0) as int;
  final lastFee = (gs['meta']['lastBankFee'] ?? 0) as int;
  final lastLoanInt = (gs['meta']['lastLoanInterest'] ?? 0) as int;
  final shellFund = (gs['meta']['shellFund'] ?? 0) as int;
  final cryptoFund = (gs['meta']['cryptoFund'] ?? 0) as int;
  final lastShellDrift = (gs['meta']['lastShellDrift'] ?? 0) as int;
  final lastCryptoPnl = (gs['meta']['lastCryptoPnl'] ?? gs['meta']['lastCryptoPnl'] ?? gs['meta']['lastCryptoPnl'] ?? 0) as int; // tolerate absence
  final lastInsPrem = (gs['meta']['lastInsurancePremium'] ?? 0) as int;
  final insuranceEnabled = (gs['meta']['insuranceEnabled'] ?? false) as bool;
  final compound = (gs['meta']['bankCompound'] ?? true) as bool;
  final autopayPreferBank = (gs['meta']['autopayPreferBank'] ?? true) as bool;
  final credit = (gs['meta']['creditScore'] ?? Balance.creditScoreStart) as int;
  final loansRaw = (gs['meta']['loans'] as List<dynamic>?) ?? const [];
  final loans = loansRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  int totalMinDue() {
    int sum = 0;
    for (final l in loans) {
      final bal = ((l['balance'] ?? 0) as num).toDouble();
      if (bal <= 0) continue;
      final minByRate = (bal * Balance.loanMinPaymentRate).round();
      final minPay = minByRate < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate;
      sum += minPay;
    }
    return sum;
  }
    return Scaffold(
      appBar: AppBar(title: const Text('Bank')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Cash: \$${cash}'),
            Text('Bank: \$${bank}'),
            if (lastInt > 0) Text('Interest yesterday: \$${lastInt}', style: const TextStyle(color: Colors.tealAccent)),
            if (lastFee > 0) Text('Last withdrawal fee: -\$${lastFee}', style: const TextStyle(color: Colors.orangeAccent)),
            if (lastLoanInt > 0) Text('Loan interest accrued: -\$${lastLoanInt}', style: const TextStyle(color: Colors.orangeAccent)),
            if (lastShellDrift != 0) Text('Shell drift: ${lastShellDrift >= 0 ? '+' : ''}\$${lastShellDrift}', style: const TextStyle(color: Colors.lightBlueAccent)),
            if (lastCryptoPnl != 0) Text('Crypto P/L: ${lastCryptoPnl >= 0 ? '+' : ''}\$${lastCryptoPnl}', style: const TextStyle(color: Colors.lightBlueAccent)),
            if (lastInsPrem > 0) Text('Insurance premium: -\$${lastInsPrem}', style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Compound interest into Bank (else pay to Cash)'),
              value: compound,
              onChanged: (v) => ref.read(gameStateProvider.notifier).setBankCompound(v),
            ),
            SwitchListTile(
              title: const Text('Use bank for loan autopay (enforced)'),
              subtitle: const Text('We’ll withdraw to cover minimums so you can’t skip payments.'),
              value: autopayPreferBank,
              onChanged: null, // enforced
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(controller: _dep, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Deposit amount')), 
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final n = int.tryParse(_dep.text.trim()) ?? 0;
                  if (n > 0) ref.read(gameStateProvider.notifier).depositBank(n);
                },
                child: const Text('Deposit'),
              )
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(controller: _wd, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Withdraw amount')), 
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final n = int.tryParse(_wd.text.trim()) ?? 0;
                  if (n > 0) ref.read(gameStateProvider.notifier).withdrawBank(n);
                },
                child: const Text('Withdraw'),
              )
            ]),
            const Divider(height: 24),
            Text('Shell Company Fund: \$${shellFund}'),
            Row(children: [
              Expanded(child: TextField(controller: _dep, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Move cash to Shell'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () { final n = int.tryParse(_dep.text.trim()) ?? 0; if (n > 0) ref.read(gameStateProvider.notifier).shellDeposit(n); },
                child: const Text('Deposit'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () { final n = int.tryParse(_dep.text.trim()) ?? 0; if (n > 0) ref.read(gameStateProvider.notifier).shellWithdraw(n); },
                child: const Text('Withdraw'),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Crypto Wallet: \$${cryptoFund}'),
            Row(children: [
              Expanded(child: TextField(controller: _wd, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Move cash to Crypto'))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () { final n = int.tryParse(_wd.text.trim()) ?? 0; if (n > 0) ref.read(gameStateProvider.notifier).cryptoDeposit(n); },
                child: const Text('Buy'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () { final n = int.tryParse(_wd.text.trim()) ?? 0; if (n > 0) ref.read(gameStateProvider.notifier).cryptoWithdraw(n); },
                child: const Text('Sell'),
              ),
            ]),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Insurance (limits losses)'),
              subtitle: Text(insuranceEnabled ? 'Enabled · Premium auto-charged nightly' : 'Disabled'),
              value: insuranceEnabled,
              onChanged: (v) => ref.read(gameStateProvider.notifier).setInsurance(v),
            ),
            const Divider(height: 24),
            Text('Credit score: ${credit} · Max loan: \$${Balance.maxLoanForScore(credit)}'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(controller: _loan, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Take loan amount')), 
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final n = int.tryParse(_loan.text.trim()) ?? 0;
                  if (n > 0) ref.read(gameStateProvider.notifier).takeLoan(n);
                },
                child: const Text('Take Loan'),
              )
            ]),
            const SizedBox(height: 12),
            if (loans.isNotEmpty) const Text('Loans:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (loans.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Tomorrow minimum due (auto): -\$${totalMinDue()}', style: const TextStyle(color: Colors.orangeAccent)),
              ),
            if (loans.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    int remaining = cash;
                    for (final l in loans) {
                      if (remaining <= 0) break;
                      final id = (l['id'] ?? '') as String;
                      final bal = ((l['balance'] ?? 0) as num).round();
                      if (bal <= 0) continue;
                      final minByRate = (bal * Balance.loanMinPaymentRate).round();
                      final minPay = minByRate < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate;
                      final pay = minPay.clamp(0, remaining);
                      if (pay > 0) {
                        ref.read(gameStateProvider.notifier).repayLoan(id, pay);
                        remaining -= pay;
                      }
                    }
                  },
                  icon: const Icon(Icons.payments),
                  label: const Text('Pay minimum on all loans now'),
                ),
              ),
            if (loans.isNotEmpty)
              ...loans.map((l) {
                final id = (l['id'] ?? '') as String;
                final bal = ((l['balance'] ?? 0) as num).round();
                final rate = (((l['dailyRate'] ?? 0.0) as num).toDouble() * 100).toStringAsFixed(2);
                final minByRate = ((l['balance'] ?? 0) as num).toDouble() * Balance.loanMinPaymentRate;
                final minPay = bal <= 0 ? 0 : (minByRate.round() < Balance.loanMinPaymentBase ? Balance.loanMinPaymentBase : minByRate.round());
                final projectedInterest = ((l['balance'] ?? 0) as num).toDouble() * (((l['dailyRate'] ?? 0.0) as num).toDouble());
                final ctrl = _repayCtrlFor(id);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Loan ${id.isNotEmpty && id.length > 4 ? id.substring(id.length - 4) : id} · Balance: \$${bal} @ ${rate}%/day'),
                        if (minPay > 0) Text('Minimum due tomorrow (auto): -\$${minPay}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        if (projectedInterest > 0) Text('Projected interest tomorrow: -\$${projectedInterest.round()}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Repay amount')), 
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final n = int.tryParse(ctrl.text.trim()) ?? 0;
                              if (n > 0) ref.read(gameStateProvider.notifier).repayLoan(id, n);
                            },
                            child: const Text('Repay'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => ref.read(gameStateProvider.notifier).repayLoan(id, bal),
                            child: const Text('Pay Off'),
                          )
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          ElevatedButton(
                            onPressed: minPay > 0 && cash >= minPay ? () => ref.read(gameStateProvider.notifier).repayLoan(id, minPay) : null,
                            child: Text('Pay min (\$${minPay})'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: (minPay * 2) > 0 && cash >= (minPay * 2) ? () => ref.read(gameStateProvider.notifier).repayLoan(id, minPay * 2) : null,
                            child: Text('Pay 2x min (\$${minPay * 2})'),
                          ),
                        ])
                      ],
                    ),
                  ),
                );
              }),
            const Text('Daily interest is paid into Cash at end of day.'),
          ],
        ),
      ),
    );
  }
}
