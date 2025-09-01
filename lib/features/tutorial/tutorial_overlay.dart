import 'package:flutter/material.dart';

class TutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const TutorialOverlay({Key? key, required this.onDismiss}) : super(key: key);
  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _step = 0;
  final List<String> _steps = [
  'Step 1: Tap the Market tab and buy a drug.',
  'Step 2: Tap the City tab and travel to a district to refresh customers.',
  'Tip: In the Market, look for offers marked "In stock" to sell what you have.',
  'Step 3: Tap an offer and negotiate. If not busted, you get paid.',
  ];
  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onDismiss();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          Align(
            alignment: _step == 0
                ? Alignment.bottomCenter
                : _step == 1
                    ? Alignment.bottomLeft
                    : Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_steps[_step], style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: widget.onDismiss,
                            child: const Text('Skip'),
                          ),
                          ElevatedButton(
                            onPressed: _next,
                            child: Text(_step < _steps.length - 1 ? 'Next' : 'Finish'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
