# ProcDealer

A procedural crime-empire tycoon built with Flutter and Riverpod. Runs on Windows desktop and Android. Focuses on strategic trading, crew management, police/legal risk, and an adaptive AI opponent.

## Highlights
- Procedural city with district graph and travel costs/heat
- Dynamic market; buy/sell with profit-aware crew automation (autopilot)
- Banking with deposits/withdrawals, fees, interest, and loans
- Police pressure, arrests, bail, hearings, fines/jail, and lawyer quality/retainer
- Nightly AI opponent that poaches suppliers, pushes influence, pressures police, and scales with difficulty
- Start/End flow: one-button day runner; end-of-day breakdown with bank deltas
- Settings to tune autopilot: min profit margin, reserve cushion, smart banking
- Modern dark UI with badges (pressure/staff), recap/events, and intel views

## Quick Start (Windows)
1) Install Flutter (stable) and enable desktop: `flutter config --enable-windows-desktop`.
2) In this project folder:
	- flutter pub get
	- flutter run -d windows

Build Windows release:
- flutter build windows

## Quick Start (Android)
1) Ensure an emulator or device is connected.
2) In this project folder:
	- flutter pub get
	- flutter run

Build Android APK (release):
- flutter build apk --release

Downloadable APK:
- On tags (vX.Y.Z) or manual trigger, GitHub Actions publishes app-release.apk as an artifact under Actions > Android APK.
- A local copy of a profile build is kept in `releases/ProcDealer-profile-1.0.0.apk` for quick sideloading.

## Gameplay Notes
- Use the Start button to let crew autopilot buy/travel/sell intelligently and then end the day.
- Tune autopilot in Settings: minMarginPct, reserveCushion, smartBanking.
- Arrests create legal cases; hearings resolve at end of day; keep a retainer for better outcomes.
- Watch AI Intel to react to pressure and supplier moves.

## Development
- Analyze and test: `flutter analyze` and `flutter test`
- Project uses Riverpod providers and a central GameState for day orchestration.
- Desktop target validated on Windows; CI builds run on GitHub Actions.

## License
MIT. See LICENSE.

---

Built for extensibility. PRs and ideas welcome.
