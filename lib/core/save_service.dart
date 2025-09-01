import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';

class SaveService {
  static const String metaBox = 'metaBox';
  static const String runBox = 'runBox';

  static Future<void> init() async {
    // Hive is already initialized in main() via Hive.initFlutter('ProcDealer').
    // Use explicit paths inside that directory to avoid collisions.
  // hive_flutter sets a default path; we don't need to pass it explicitly.
  // Just open the boxes; they will use the path from Hive.initFlutter('ProcDealer').
  await Hive.openBox(metaBox);
  await Hive.openBox(runBox);
  }

  static String checksum(Map<String, dynamic> json) {
    final str = jsonEncode(json);
    return sha256.convert(utf8.encode(str)).toString();
  }

  static Future<void> saveRun(Map<String, dynamic> state) async {
    final box = Hive.box(runBox);
    final hash = checksum(state);
    await box.put('run', {'data': state, 'hash': hash});
  }

  static Map<String, dynamic>? loadRun() {
    final box = Hive.box(runBox);
    final saved = box.get('run');
    if (saved == null) return null;
    final data = Map<String, dynamic>.from(saved['data']);
    final hash = saved['hash'];
    if (checksum(data) != hash) {
      // Corrupted, try previous
      final prev = box.get('run_prev');
      if (prev != null && checksum(Map<String, dynamic>.from(prev['data'])) == prev['hash']) {
        return Map<String, dynamic>.from(prev['data']);
      }
      return null;
    }
    return data;
  }

  static Future<void> autosave(Map<String, dynamic> state) async {
    final box = Hive.box(runBox);
    final prev = box.get('run');
    if (prev != null) await box.put('run_prev', prev);
    await saveRun(state);
  }
}
