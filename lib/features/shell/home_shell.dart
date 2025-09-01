import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nav_tab.dart';
import '../market/market_screen.dart';
import '../city/city_screen.dart';
import '../upgrades/upgrades_screen.dart';
import '../staff/staff_screen.dart';
import '../../theme/app_theme.dart';
import '../../state/game_state.dart';
import '../../state/event_provider.dart';
import '../../state/objective_provider.dart';
import '../shared/snackbar_service.dart';
import '../shared/ticker_overlay.dart';
import '../../theme/neon_background.dart';
import '../day/event_popup.dart';
import '../day/events_log_screen.dart';
import '../shared/settings_screen.dart';
import '../shared/toast_overlay.dart';
import '../day/recap_screen.dart';
import '../shared/bank_screen.dart';
import '../../state/crew_provider.dart';
import '../../state/market_provider.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({Key? key}) : super(key: key);
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  NavTab _tab = NavTab.market;
  bool _busy = false;
  Widget _forecastChip() {
    final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
  final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
  final rumorRaw = meta['rumorNext'];
  final Map<String, dynamic>? rumor = rumorRaw is Map ? Map<String, dynamic>.from(rumorRaw) : null;
  // If any temporary police pressure active, show a warning icon
  bool policeHot = false;
  try {
    final ppRaw = meta['policePressureByDid'];
    final Map<String, int> pp = ppRaw is Map
        ? Map<String, int>.from(ppRaw.map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        : <String, int>{};
    policeHot = pp.values.any((v) => v > 0);
  } catch (_) {}
    String text = 'Quiet tomorrow?';
    if (rumor != null) {
      switch (rumor['type']) {
        case 'Drought':
          text = 'Rumor: Scarcity looming';
          break;
        case 'Festival':
          text = 'Rumor: Festival season';
          break;
        case 'Raid':
          text = 'Rumor: Crackdowns ahead';
          break;
        case 'Gang War':
          text = 'Rumor: Turf tensions rising';
          break;
        default:
          text = 'Quiet tomorrow?';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          if (policeHot)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.local_police, size: 18, color: Colors.redAccent.withOpacity(0.9)),
            ),
          Chip(label: Text(text), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }

  Widget _tabView() {
    switch (_tab) {
      case NavTab.market:
        return const MarketScreen();
      case NavTab.city:
        return const CityScreen();
      case NavTab.upgrades:
        return const UpgradesScreen();
      case NavTab.staff:
        return const StaffScreen();
    }
  }

  bool _showTicker = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Stack(
        children: [
          const Positioned.fill(child: NeonBackground(speed: 0.35, intensity: 0.65)),
          Scaffold(
        appBar: AppBar(
          title: const Text('Proc Dealer'),
          actions: [
            _forecastChip(),
            // Objectives panel with badge when rewards were granted
            Consumer(builder: (context, ref, _) {
              final metaRaw = ref.watch(gameStateProvider.select((s) => s['meta']));
              final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
              final hasReward = (meta['objectiveRewarded'] ?? false) as bool;
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.checklist_rtl),
                    tooltip: 'Objectives',
                    onPressed: () async {
                      // Clear badge
                      ref.read(gameStateProvider.notifier).clearObjectiveBadge();
                      // Show compact sheet
                      final list = ref.read(objectivesProvider);
                      await showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        backgroundColor: Colors.grey[900],
                        builder: (_) {
                          return SafeArea(
                            child: ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                const Text('Today\'s Objectives', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...list.map((o) => Card(
                                      child: ListTile(
                                        leading: Icon(o.done ? Icons.check_circle : Icons.radio_button_unchecked,
                                            color: o.done ? Colors.tealAccent : Colors.grey),
                                        title: Text(o.desc),
                                        subtitle: Text('Reward: \$${o.reward}'),
                                      ),
                                    )),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (hasReward)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            }),
            IconButton(
              icon: const Icon(Icons.account_balance),
              tooltip: 'Bank',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BankScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.event_note),
              tooltip: 'Events',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EventsLogScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            )
          ],
        ),
  body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _tabView(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab.index,
          onTap: (i) => setState(() => _tab = NavTab.values[i]),
          items: NavTab.values
              .map((tab) => BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ))
              .toList(),
          selectedFontSize: 18,
          unselectedFontSize: 16,
          iconSize: 36,
          type: BottomNavigationBarType.fixed,
        ),
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: 'startDay',
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final gs = ref.read(gameStateProvider.notifier);
                      final current = ref.read(gameStateProvider);
                      final hadFront = (current['upgrades']['laundromat'] ?? 0) > 0;
                      try {
                        // Skip generic automation if Crew Autopilot is enabled
                        final metaRaw = ref.read(gameStateProvider.select((s) => s['meta']));
                        final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
                        final autoRaw = meta['crewAuto'];
                        final auto = autoRaw is Map ? Map<String, dynamic>.from(autoRaw) : const <String, dynamic>{};
                        final autoEnabled = (auto['enabled'] ?? false) as bool;
                        if (!autoEnabled) {
                          final prices = ref.read(marketProvider);
                          gs.runAutomationWithPrices(prices);
                        }
                      } catch (_) {}
                      await Future.delayed(const Duration(milliseconds: 200));
                      try {
                        // Simulate crew day (includes autopilot restock and selling)
                        final crewCtrl = ref.read(crewProvider.notifier);
                        final result = crewCtrl.simulateDay();
                        // Lightweight playback: show per-member earnings
                        final per = (result['memberEarnings'] as List<dynamic>?);
                        if (per != null && per.isNotEmpty) {
                          for (final m in per.map((e) => Map<String, dynamic>.from(e))) {
                            final role = (m['role'] ?? 'Crew') as String;
                            final earned = (m['earned'] ?? 0) as int;
                            if (earned > 0) {
                              ToastOverlay.show(context, '$role +\$${earned}', color: Colors.tealAccent);
                              await Future.delayed(const Duration(milliseconds: 450));
                            }
                          }
                        }
                        gs.applyCrewDay(result);
                        // Immediate deposit toast
                        try {
                          final metaRawNow = ref.read(gameStateProvider.select((s) => s['meta']));
                          final metaNow = metaRawNow is Map ? Map<String, dynamic>.from(metaRawNow) : <String, dynamic>{};
                          final int crewCredited = (metaNow['crewBankCreditToday'] ?? 0) as int;
                          if (crewCredited > 0) {
                            ToastOverlay.show(context, 'Crew deposited +\$${crewCredited}', color: Colors.deepPurpleAccent);
                          }
                        } catch (_) {}
                      } catch (_) {}
                      // Roll night and show events + recap
                      gs.endDay();
                      final events = ref.read(eventProvider);
                      if (events.isEmpty) {
                        SnackbarService.show(context, 'A quiet day passes.');
                      } else if (events.length <= 2) {
                        await showEventPopups(context, events);
                      } else {
                        for (final e in events) {
                          ToastOverlay.show(context, e.desc, color: Colors.deepPurple);
                          await Future.delayed(const Duration(milliseconds: 900));
                        }
                      }
                      if (hadFront) {
                        setState(() => _showTicker = true);
                        await Future.delayed(const Duration(milliseconds: 1200));
                        if (mounted) setState(() => _showTicker = false);
                      }
                      if (mounted) {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecapScreen()));
                        final metaRaw = ref.read(gameStateProvider.select((s) => s['meta']));
                        final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
                        final over = (meta['gameOver'] ?? false) as bool;
                        if (over) {
                          await showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => AlertDialog(
                              title: const Text('Game Over'),
                              content: const Text('You went bankrupt. Start a fresh game?'),
                              actions: [
                                TextButton(
                                  onPressed: () { Navigator.of(context).pop(); },
                                  child: const Text('Close'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    ref.read(gameStateProvider.notifier).freshGame();
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Start Fresh'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                      if (mounted) setState(() => _busy = false);
                    },
              label: const Text('Start'),
              icon: const Icon(Icons.play_arrow),
            ),
            const SizedBox(width: 12),
            FloatingActionButton.extended(
              heroTag: 'endDay',
              onPressed: _busy
                  ? null
                  : () async {
            // End Day: run crew sim, update state, show events, show passive income ticker
            final gs = ref.read(gameStateProvider.notifier);
            final current = ref.read(gameStateProvider);
            final hadFront = (current['upgrades']['laundromat'] ?? 0) > 0;
             try {
               // Skip generic automation if Crew Autopilot is enabled
               final metaRaw = ref.read(gameStateProvider.select((s) => s['meta']));
               final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
               final autoRaw = meta['crewAuto'];
               final auto = autoRaw is Map ? Map<String, dynamic>.from(autoRaw) : const <String, dynamic>{};
               final autoEnabled = (auto['enabled'] ?? false) as bool;
               if (!autoEnabled) {
                 final prices = ref.read(marketProvider);
                 gs.runAutomationWithPrices(prices);
               }
             } catch (_) {}
            try {
              final crewCtrl = ref.read(crewProvider.notifier);
              final result = crewCtrl.simulateDay();
              gs.applyCrewDay(result);
              // Immediate feedback: show crew bank credit before rolling to next day
              try {
                final metaRawNow = ref.read(gameStateProvider.select((s) => s['meta']));
                final metaNow = metaRawNow is Map ? Map<String, dynamic>.from(metaRawNow) : <String, dynamic>{};
                final int crewCredited = (metaNow['crewBankCreditToday'] ?? 0) as int;
                if (crewCredited > 0) {
                  ToastOverlay.show(context, 'Crew deposited +\$${crewCredited}', color: Colors.deepPurpleAccent);
                }
              } catch (_) {}
            } catch (_) {}
            gs.endDay();
            final events = ref.read(eventProvider);
            if (events.isEmpty) {
              SnackbarService.show(context, 'A quiet day passes.');
            } else if (events.length <= 2) {
              // Few events: show popups
              await showEventPopups(context, events);
            } else {
              // Many events: use lightweight toast overlay per event
              for (final e in events) {
                ToastOverlay.show(context, e.desc, color: Colors.deepPurple);
                await Future.delayed(const Duration(milliseconds: 900));
              }
            }
            if (hadFront) {
              setState(() => _showTicker = true);
              await Future.delayed(const Duration(milliseconds: 1200));
              if (mounted) setState(() => _showTicker = false);
            }
            if (mounted) {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecapScreen()));
              // After recap, if game over, show dialog to Fresh Start
              final metaRaw = ref.read(gameStateProvider.select((s) => s['meta']));
              final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{};
              final over = (meta['gameOver'] ?? false) as bool;
              if (over) {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    title: const Text('Game Over'),
                    content: const Text('You went bankrupt. Start a fresh game?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Close'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(gameStateProvider.notifier).freshGame();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Start Fresh'),
                      ),
                    ],
                  ),
                );
              }
            }
                  },
              label: const Text('End Day'),
              icon: const Icon(Icons.nightlight_round),
            ),
            const SizedBox(width: 12),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        persistentFooterButtons: [
          if (_showTicker) TickerOverlay(text: '+\$250 from Laundromat')
        ],
          ),
        ],
      ),
    );
  }
}
