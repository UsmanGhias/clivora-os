import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/plan_features.dart';
import '../../data/providers/app_providers.dart';

final vaultFilesProvider = FutureProvider<List<FileSystemEntity>>((ref) async {
  return VaultService.listFiles();
});

final vaultPlanProvider = FutureProvider<String>((ref) async {
  return ref.read(planLimitServiceProvider).currentPlan();
});

/// Local file vault with free (100 MB) and Pro (5 GB+) tiers.
class VaultService {
  static const freeLimitBytes = 100 * 1024 * 1024;
  static const proLimitBytes = 5 * 1024 * 1024 * 1024;
  static const chatPrefix = 'chat_';

  static int limitBytesForPlan(String? plan) =>
      PlanFeatures.isPro(plan) ? proLimitBytes : freeLimitBytes;

  static bool isChatArchive(String path) => p.basename(path).startsWith(chatPrefix);

  static Future<Directory> _vaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final vault = Directory(p.join(dir.path, 'vault'));
    if (!await vault.exists()) {
      await vault.create(recursive: true);
    }
    return vault;
  }

  static Future<List<FileSystemEntity>> listFiles() async {
    final vault = await _vaultDir();
    final files = vault.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  static int totalBytes(List<FileSystemEntity> files) {
    return files.fold<int>(0, (sum, f) => sum + (f as File).lengthSync());
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static Future<VaultSaveResult> pickAndSave({required String? plan}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 90);
    if (file == null) return VaultSaveResult.cancelled();
    final bytes = await File(file.path).readAsBytes();
    return saveBytes(bytes, ext: p.extension(file.path), plan: plan);
  }

  static Future<VaultSaveResult> archiveChatImageBytes({
    required Uint8List bytes,
    required String? plan,
    String ext = '.jpg',
  }) =>
      saveBytes(bytes, ext: ext, plan: plan, chatArchive: true);

  static Future<VaultSaveResult> saveBytes(
    Uint8List bytes, {
    required String? plan,
    String ext = '.jpg',
    bool chatArchive = false,
  }) async {
    final limit = limitBytesForPlan(plan);
    final existing = await listFiles();
    final used = totalBytes(existing);
    if (used + bytes.length > limit) {
      return VaultSaveResult.quotaExceeded(limit: limit, used: used);
    }

    final vault = await _vaultDir();
    final prefix = chatArchive ? chatPrefix : 'vault_';
    final dest = p.join(vault.path, '$prefix${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(dest).writeAsBytes(bytes);
    return VaultSaveResult.saved(dest);
  }

  static Future<VaultSaveResult> archiveChatImageFromUrl({
    required String url,
    required String? plan,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return VaultSaveResult.failed('Download failed (${response.statusCode})');
      }
      final ext = url.contains('.png') ? '.png' : '.jpg';
      return archiveChatImageBytes(bytes: response.bodyBytes, plan: plan, ext: ext);
    } catch (e) {
      debugPrint('Vault archive from URL: $e');
      return VaultSaveResult.failed('$e');
    }
  }

  static Future<void> deleteFile(String path) async {
    if (isChatArchive(path)) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class VaultSaveResult {
  VaultSaveResult._({this.path, this.error, this.limit, this.used});

  factory VaultSaveResult.saved(String path) => VaultSaveResult._(path: path);
  factory VaultSaveResult.cancelled() => VaultSaveResult._();
  factory VaultSaveResult.quotaExceeded({required int limit, required int used}) =>
      VaultSaveResult._(error: 'quota', limit: limit, used: used);
  factory VaultSaveResult.failed(String message) => VaultSaveResult._(error: message);

  final String? path;
  final String? error;
  final int? limit;
  final int? used;

  bool get ok => path != null;
  bool get isQuota => error == 'quota';
}
