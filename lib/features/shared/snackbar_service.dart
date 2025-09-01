import 'package:flutter/material.dart';
import '../../core/audio_service.dart';

class SnackbarService {
  static void show(BuildContext context, String message, {Color? color}) {
  // Respect settings by playing a subtle click
  AudioService.click();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
