import 'package:flutter/material.dart';

enum NavTab { market, city, upgrades, staff }

extension NavTabExt on NavTab {
  IconData get icon {
    switch (this) {
      case NavTab.market:
        return Icons.shopping_cart;
      case NavTab.city:
        return Icons.map;
      case NavTab.upgrades:
        return Icons.upgrade;
      case NavTab.staff:
        return Icons.people;
    }
  }
  String get label {
    switch (this) {
      case NavTab.market:
        return 'Market';
      case NavTab.city:
        return 'City';
      case NavTab.upgrades:
        return 'Upgrades';
      case NavTab.staff:
        return 'Staff';
    }
  }
}
