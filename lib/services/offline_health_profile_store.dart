import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PendingHealthUpdate {
  final String id;
  final String clientUpdatedAt;
  final String? baseVersion;
  final double? heightCm;
  final double? weightKg;
  final String? measuredAt;
  final bool conflict;

  /// Keep the date in the capture timestamp's original offset. Parsing and
  /// converting it to the device's current timezone can change the day.
  String? get capturedOn {
    if (heightCm == null ||
        weightKg == null ||
        DateTime.tryParse(clientUpdatedAt) == null) {
      return null;
    }
    return RegExp(r'^\d{4}-\d{2}-\d{2}').stringMatch(clientUpdatedAt);
  }

  const PendingHealthUpdate({
    required this.id,
    required this.clientUpdatedAt,
    required this.baseVersion,
    required this.heightCm,
    required this.weightKg,
    required this.measuredAt,
    this.conflict = false,
  });

  factory PendingHealthUpdate.fromJson(Map<String, dynamic> json) =>
      PendingHealthUpdate(
        id: '${json['client_update_id']}',
        clientUpdatedAt: '${json['client_updated_at']}',
        baseVersion: json['base_version']?.toString(),
        heightCm: _number(json['height_cm']),
        weightKg: _number(json['weight_kg']),
        measuredAt: json['bmi_measured_at']?.toString(),
        conflict: json['conflict'] == true,
      );

  static double? _number(dynamic value) {
    if (value == null) return null;
    return double.tryParse('$value');
  }

  Map<String, dynamic> toJson() => {
    'client_update_id': id,
    'client_updated_at': clientUpdatedAt,
    'base_version': baseVersion,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    if (measuredAt != null && measuredAt!.isNotEmpty)
      'bmi_measured_at': measuredAt,
    if (conflict) 'conflict': true,
  };

  PendingHealthUpdate markConflict() => PendingHealthUpdate(
    id: id,
    clientUpdatedAt: clientUpdatedAt,
    baseVersion: baseVersion,
    heightCm: heightCm,
    weightKg: weightKg,
    measuredAt: measuredAt,
    conflict: true,
  );
}

abstract class HealthProfileStore {
  Future<Map<String, dynamic>?> readCachedUser();
  Future<void> writeCachedUser(Map<String, dynamic> user);
  Future<PendingHealthUpdate?> readPending();
  Future<void> writePending(PendingHealthUpdate update);
  Future<void> clearPending();
  Future<void> clearAll();
}

class SecureHealthProfileStore implements HealthProfileStore {
  static const _userKey = 'racetech.cached_user.v1';
  static const _pendingKey = 'racetech.pending_health_update.v1';
  final FlutterSecureStorage storage;

  const SecureHealthProfileStore({
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  });

  @override
  Future<Map<String, dynamic>?> readCachedUser() async {
    final value = await storage.read(key: _userKey);
    if (value == null || value.isEmpty) return null;
    final decoded = jsonDecode(value);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }

  @override
  Future<void> writeCachedUser(Map<String, dynamic> user) =>
      storage.write(key: _userKey, value: jsonEncode(user));

  @override
  Future<PendingHealthUpdate?> readPending() async {
    final value = await storage.read(key: _pendingKey);
    if (value == null || value.isEmpty) return null;
    final decoded = jsonDecode(value);
    return decoded is Map
        ? PendingHealthUpdate.fromJson(Map<String, dynamic>.from(decoded))
        : null;
  }

  @override
  Future<void> writePending(PendingHealthUpdate update) =>
      storage.write(key: _pendingKey, value: jsonEncode(update.toJson()));

  @override
  Future<void> clearPending() => storage.delete(key: _pendingKey);

  @override
  Future<void> clearAll() async {
    await storage.delete(key: _userKey);
    await storage.delete(key: _pendingKey);
  }
}

class MemoryHealthProfileStore implements HealthProfileStore {
  Map<String, dynamic>? user;
  PendingHealthUpdate? pending;

  @override
  Future<Map<String, dynamic>?> readCachedUser() async =>
      user == null ? null : Map<String, dynamic>.from(user!);

  @override
  Future<void> writeCachedUser(Map<String, dynamic> value) async {
    user = Map<String, dynamic>.from(value);
  }

  @override
  Future<PendingHealthUpdate?> readPending() async => pending;

  @override
  Future<void> writePending(PendingHealthUpdate value) async {
    pending = value;
  }

  @override
  Future<void> clearPending() async => pending = null;

  @override
  Future<void> clearAll() async {
    user = null;
    pending = null;
  }
}
