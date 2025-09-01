import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/game_state.dart';
import '../../core/save_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sound = true;
  bool _haptics = true;
  bool _autoEnabled = false;
  int _autoDepositAbove = 0;
  int _autoBuyMinUnits = 0;
  int _autoBuyMaxPct = 40;
  String _aiDifficulty = 'normal';
  // Crew autopilot
  bool _crewAutoEnabled = true;
  int _crewTargetUnits = 30;
  int _crewMaxSpendPctCash = 60;
  int _crewMaxWithdrawPerDay = 500;
  String _crewStrategy = 'value';
  // Profit and banking
  double _crewMinMarginPct = 7.0; // percent
  int _crewReserveCushion = 60; // dollars
  bool _crewSmartBanking = true;

  @override
  void initState() {
    super.initState();
    final box = Hive.box(SaveService.metaBox);
    _sound = box.get('sound', defaultValue: true) as bool;
    _haptics = box.get('haptics', defaultValue: true) as bool;
  }

  void _save() {
    final box = Hive.box(SaveService.metaBox);
    box.put('sound', _sound);
    box.put('haptics', _haptics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer(builder: (context, ref, _) {
        final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
        final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
        final autoRaw = meta['auto'];
        final auto = autoRaw is Map ? Map<String, dynamic>.from(autoRaw) : <String, dynamic>{};
  _aiDifficulty = (meta['aiDifficulty'] ?? 'normal') as String;
  final crewAutoRaw = meta['crewAuto'];
  final crewAuto = crewAutoRaw is Map ? Map<String, dynamic>.from(crewAutoRaw) : <String, dynamic>{};
  _crewAutoEnabled = (crewAuto['enabled'] ?? true) as bool;
  _crewTargetUnits = ((crewAuto['targetUnits'] ?? 30) as num).toInt();
  _crewMaxSpendPctCash = ((crewAuto['maxSpendPctCash'] ?? 60) as num).toInt();
  _crewMaxWithdrawPerDay = ((crewAuto['maxWithdrawPerDay'] ?? 500) as num).toInt();
  _crewStrategy = (crewAuto['strategy'] ?? 'value') as String;
  _crewMinMarginPct = (((crewAuto['minMarginPct'] ?? 7) as num).toDouble()).clamp(0, 100).toDouble();
  _crewReserveCushion = ((crewAuto['reserveCushion'] ?? 60) as num).toInt();
  _crewSmartBanking = (crewAuto['smartBanking'] ?? true) as bool;
        _autoEnabled = (auto['enabled'] ?? false) as bool;
        _autoDepositAbove = ((auto['depositAbove'] ?? 0) as num).toInt();
        _autoBuyMinUnits = ((auto['buyMinUnits'] ?? 0) as num).toInt();
        _autoBuyMaxPct = ((auto['buyMaxSpendPct'] ?? 40) as num).toInt();
        return ListView(
          children: [
            SwitchListTile(
              title: const Text('Sound effects'),
              value: _sound,
              onChanged: (v) => setState(() {
                _sound = v;
                _save();
              }),
              secondary: const Icon(Icons.volume_up),
            ),
            SwitchListTile(
              title: const Text('Haptics'),
              value: _haptics,
              onChanged: (v) => setState(() {
                _haptics = v;
                _save();
              }),
              secondary: const Icon(Icons.vibration),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('AI Difficulty'),
              subtitle: const Text('Affects rival aggression and tricks'),
              trailing: DropdownButton<String>(
                value: _aiDifficulty,
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _aiDifficulty = v);
                  ref.read(gameStateProvider.notifier).setAiDifficulty(v);
                },
              ),
            ),
            const Divider(),
            // Crew Autopilot section
            ListTile(
              leading: const Icon(Icons.rocket_launch),
              title: const Text('Crew Autopilot'),
              subtitle: const Text('Let crew restock and sell automatically'),
            ),
            SwitchListTile(
              title: const Text('Enable crew autopilot'),
              value: _crewAutoEnabled,
              onChanged: (v) {
                setState(() => _crewAutoEnabled = v);
                ref.read(gameStateProvider.notifier).setCrewAutopilot({
                  'enabled': _crewAutoEnabled,
                  'targetUnits': _crewTargetUnits,
                  'maxSpendPctCash': _crewMaxSpendPctCash,
                  'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                  'strategy': _crewStrategy,
                  'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                  'minMarginPct': _crewMinMarginPct,
                  'reserveCushion': _crewReserveCushion,
                  'smartBanking': _crewSmartBanking,
                });
              },
              secondary: const Icon(Icons.autorenew),
            ),
            if (_crewAutoEnabled)
              SwitchListTile(
                title: const Text('Auto-Travel for Better Prices'),
                subtitle: const Text('Crew may travel to districts with better prices when worthwhile'),
                value: (crewAuto['autoTravel'] ?? true) as bool,
                onChanged: (v) {
                  ref.read(gameStateProvider.notifier).setCrewAutopilot({
                    'enabled': _crewAutoEnabled,
                    'targetUnits': _crewTargetUnits,
                    'maxSpendPctCash': _crewMaxSpendPctCash,
                    'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                    'strategy': _crewStrategy,
                    'autoTravel': v,
                    'minMarginPct': _crewMinMarginPct,
                    'reserveCushion': _crewReserveCushion,
                    'smartBanking': _crewSmartBanking,
                  });
                },
                secondary: const Icon(Icons.explore),
              ),
            if (_crewAutoEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Target inventory units')),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: '$_crewTargetUnits',
                            keyboardType: TextInputType.number,
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? _crewTargetUnits;
                              setState(() => _crewTargetUnits = v.clamp(0, 10000).toInt());
                              ref.read(gameStateProvider.notifier).setCrewAutopilot({
                                'enabled': _crewAutoEnabled,
                                'targetUnits': _crewTargetUnits,
                                'maxSpendPctCash': _crewMaxSpendPctCash,
                                'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                                'strategy': _crewStrategy,
                                'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                                'minMarginPct': _crewMinMarginPct,
                                'reserveCushion': _crewReserveCushion,
                                'smartBanking': _crewSmartBanking,
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Max spend % of cash')),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: '$_crewMaxSpendPctCash',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixText: '\$'),
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? _crewMaxSpendPctCash;
                              setState(() => _crewReserveCushion = v.clamp(0, 1000000).toInt());
                              ref.read(gameStateProvider.notifier).setCrewAutopilot({
                                'enabled': _crewAutoEnabled,
                                'targetUnits': _crewTargetUnits,
                                'maxSpendPctCash': _crewMaxSpendPctCash,
                                'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                                'strategy': _crewStrategy,
                                'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                                'minMarginPct': _crewMinMarginPct,
                                'reserveCushion': _crewReserveCushion,
                                'smartBanking': _crewSmartBanking,
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Max withdraw from bank per day')),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: '$_crewMaxWithdrawPerDay',
                            keyboardType: TextInputType.number,
                              decoration: const InputDecoration(prefixText: '\$'),
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? _crewMaxWithdrawPerDay;
                                setState(() => _crewReserveCushion = v.clamp(0, 1000000).toInt());
                              ref.read(gameStateProvider.notifier).setCrewAutopilot({
                                'enabled': _crewAutoEnabled,
                                'targetUnits': _crewTargetUnits,
                                'maxSpendPctCash': _crewMaxSpendPctCash,
                                'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                                'strategy': _crewStrategy,
                                'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                                'minMarginPct': _crewMinMarginPct,
                                'reserveCushion': _crewReserveCushion,
                                'smartBanking': _crewSmartBanking,
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Buying strategy')),
                        DropdownButton<String>(
                          value: _crewStrategy,
                          items: const [
                            DropdownMenuItem(value: 'value', child: Text('Value (cheapest first)')),
                            DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
                            DropdownMenuItem(value: 'expensive', child: Text('Premium (expensive first)')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _crewStrategy = v);
                            ref.read(gameStateProvider.notifier).setCrewAutopilot({
                              'enabled': _crewAutoEnabled,
                              'targetUnits': _crewTargetUnits,
                              'maxSpendPctCash': _crewMaxSpendPctCash,
                              'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                              'strategy': _crewStrategy,
                              'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                              'minMarginPct': _crewMinMarginPct,
                              'reserveCushion': _crewReserveCushion,
                              'smartBanking': _crewSmartBanking,
                            });
                          },
                        ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Min profit margin')),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: '${_crewMinMarginPct.toStringAsFixed(1)}',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(suffixText: '%'),
                            onChanged: (s) {
                              final v = double.tryParse(s) ?? _crewMinMarginPct;
                              setState(() => _crewMinMarginPct = v.clamp(0, 100).toDouble());
                              ref.read(gameStateProvider.notifier).setCrewAutopilot({
                                'enabled': _crewAutoEnabled,
                                'targetUnits': _crewTargetUnits,
                                'maxSpendPctCash': _crewMaxSpendPctCash,
                                'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                                'strategy': _crewStrategy,
                                'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                                'minMarginPct': _crewMinMarginPct,
                                'reserveCushion': _crewReserveCushion,
                                'smartBanking': _crewSmartBanking,
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Reserve cushion')),
                        SizedBox(
                          width: 140,
                          child: TextFormField(
                            initialValue: '$_crewReserveCushion',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixText: '\$'),
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? _crewReserveCushion;
                              setState(() => _crewReserveCushion = v.clamp(0, 1000000).toInt());
                              ref.read(gameStateProvider.notifier).setCrewAutopilot({
                                'enabled': _crewAutoEnabled,
                                'targetUnits': _crewTargetUnits,
                                'maxSpendPctCash': _crewMaxSpendPctCash,
                                'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                                'strategy': _crewStrategy,
                                'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                                'minMarginPct': _crewMinMarginPct,
                                'reserveCushion': _crewReserveCushion,
                                'smartBanking': _crewSmartBanking,
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('Smart banking (auto withdraw/deposit)'),
                      value: _crewSmartBanking,
                      onChanged: (v) {
                        setState(() => _crewSmartBanking = v);
                        ref.read(gameStateProvider.notifier).setCrewAutopilot({
                          'enabled': _crewAutoEnabled,
                          'targetUnits': _crewTargetUnits,
                          'maxSpendPctCash': _crewMaxSpendPctCash,
                          'maxWithdrawPerDay': _crewMaxWithdrawPerDay,
                          'strategy': _crewStrategy,
                          'autoTravel': (crewAuto['autoTravel'] ?? true) as bool,
                          'minMarginPct': _crewMinMarginPct,
                          'reserveCushion': _crewReserveCushion,
                          'smartBanking': _crewSmartBanking,
                        });
                      },
                      secondary: const Icon(Icons.account_balance),
                    ),
                      ],
                    ),
                  ],
                ),
              ),
            // Automation section
            ListTile(
              leading: const Icon(Icons.smart_toy),
              title: const Text('Automation'),
              subtitle: const Text('Basic auto-deposit and auto-buy'),
            ),
            SwitchListTile(
              title: const Text('Enable automation'),
              value: _autoEnabled,
              onChanged: (v) {
                setState(() => _autoEnabled = v);
                final updated = {
                  'enabled': v,
                  'depositAbove': _autoDepositAbove,
                  'buyMinUnits': _autoBuyMinUnits,
                  'buyMaxSpendPct': _autoBuyMaxPct,
                };
                ref.read(gameStateProvider.notifier).setAutomation(updated);
              },
              secondary: const Icon(Icons.play_circle_fill),
            ),
            if (_autoEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Deposit cash above')),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: '$_autoDepositAbove',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(prefixText: '\$'),
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? 0;
                              setState(() => _crewReserveCushion = v.clamp(0, 1000000).toInt());
                              final updated = {
                                'enabled': _autoEnabled,
                                'depositAbove': _autoDepositAbove,
                                'buyMinUnits': _autoBuyMinUnits,
                                'buyMaxSpendPct': _autoBuyMaxPct,
                              };
                              ref.read(gameStateProvider.notifier).setAutomation(updated);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Keep at least units')),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: '$_autoBuyMinUnits',
                            keyboardType: TextInputType.number,
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? 0;
                              setState(() => _autoBuyMinUnits = v.clamp(0, 5000));
                              final updated = {
                                'enabled': _autoEnabled,
                                'depositAbove': _autoDepositAbove,
                                'buyMinUnits': _autoBuyMinUnits,
                                'buyMaxSpendPct': _autoBuyMaxPct,
                              };
                              ref.read(gameStateProvider.notifier).setAutomation(updated);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Buy max spend %')),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: '$_autoBuyMaxPct',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(suffixText: '%'),
                            onChanged: (s) {
                              final v = int.tryParse(s) ?? 0;
                              setState(() => _autoBuyMaxPct = v.clamp(0, 100));
                              final updated = {
                                'enabled': _autoEnabled,
                                'depositAbove': _autoDepositAbove,
                                'buyMinUnits': _autoBuyMinUnits,
                                'buyMaxSpendPct': _autoBuyMaxPct,
                              };
                              ref.read(gameStateProvider.notifier).setAutomation(updated);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.replay_circle_filled),
              title: const Text('Start Fresh Game'),
              subtitle: const Text('Reset everything without gaining perks'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Confirm Fresh Start'),
                    content: const Text('This will wipe your current run and start fresh. You will not gain any perk points.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start Fresh')),
                    ],
                  ),
                );
                if (ok == true) {
                  final read = ProviderScope.containerOf(context, listen: false).read;
                  read(gameStateProvider.notifier).freshGame();
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Prestige Reset'),
              subtitle: const Text('Start a new run and gain 1 perk point'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Confirm Prestige'),
                    content: const Text('This will reset your run but grant a permanent perk point.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Prestige')),
                    ],
                  ),
                );
                if (ok == true) {
                  // Use ProviderScope.containerOf to access GameState
                  final read = ProviderScope.containerOf(context, listen: false).read;
                  read(gameStateProvider.notifier).prestigeReset();
                  if (mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      }),
    );
  }
}
