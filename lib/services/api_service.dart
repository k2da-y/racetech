import 'dart:async';
import 'dart:math' show Random;
import '../utils/registration_group.dart';
import '../utils/health_profile.dart';
import '../utils/participant_birthdate.dart';
import 'offline_health_profile_store.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum LoginResult {
  success,
  invalidCredentials,
  emailVerificationRequired,
  webOnlyAccount,
  networkError,
  serverError,
}

enum ForgotPasswordResult { success, invalidEmail, networkError, serverError }

enum VerifyEmailResult { success, invalidCode, networkError, serverError }

enum ResendVerificationCodeResult {
  success,
  invalidEmail,
  networkError,
  serverError,
}

enum ResetPasswordResult {
  success,
  invalidCodeOrPassword,
  networkError,
  serverError,
}

enum VerifyResetCodeResult { success, invalidCode, networkError, serverError }

class ApiActionResult {
  final bool success;
  final String message;
  final bool queued;
  final bool conflict;
  final Map<String, dynamic>? user;
  final String? capturedOn;

  const ApiActionResult({
    required this.success,
    required this.message,
    this.queued = false,
    this.conflict = false,
    this.user,
    this.capturedOn,
  });

  const ApiActionResult.success([String message = "Success"])
    : this(success: true, message: message);

  const ApiActionResult.failure(String message)
    : this(success: false, message: message);

  const ApiActionResult.queued(
    String message, {
    Map<String, dynamic>? user,
    String? capturedOn,
  }) : this(
         success: true,
         message: message,
         queued: true,
         user: user,
         capturedOn: capturedOn,
       );

  const ApiActionResult.conflict(String message, {Map<String, dynamic>? user})
    : this(success: false, message: message, conflict: true, user: user);
}

enum UserFetchState { online, cached, unauthorized, signedOut, unavailable }

class UserFetchResult {
  final UserFetchState state;
  final Map<String, dynamic>? user;
  const UserFetchResult(this.state, [this.user]);

  bool get isUsable => user != null;
  bool get isCached => state == UserFetchState.cached;
}

class ApiDataResult<T> {
  final bool success;
  final T? data;
  final String message;

  const ApiDataResult({
    required this.success,
    required this.data,
    required this.message,
  });

  const ApiDataResult.success(T data, [String message = "Success"])
    : this(success: true, data: data, message: message);

  const ApiDataResult.failure(String message)
    : this(success: false, data: null, message: message);
}

class PaginatedApiResult<T> {
  final List<T> data;
  final String? nextPageUrl;

  const PaginatedApiResult({required this.data, required this.nextPageUrl});

  const PaginatedApiResult.empty() : this(data: const [], nextPageUrl: null);
}

class AchievementData {
  final List<Map<String, dynamic>> achievements;
  final List<Map<String, dynamic>> issuedBadges;

  const AchievementData({
    required this.achievements,
    required this.issuedBadges,
  });

  const AchievementData.empty()
    : this(achievements: const [], issuedBadges: const []);
}

class AppConfigData {
  final List<String> profileInterests;
  final List<String> eventInterestTypes;
  final List<String> trainingFocusTypes;

  const AppConfigData({
    required this.profileInterests,
    required this.eventInterestTypes,
    required this.trainingFocusTypes,
  });

  const AppConfigData.empty()
    : this(
        profileInterests: const [],
        eventInterestTypes: const [],
        trainingFocusTypes: const [],
      );
}

class ApiService {
  final http.Client? profileClient;
  final HealthProfileStore healthStore;
  final DateTime Function()? healthClock;
  ApiService({
    this.profileClient,
    HealthProfileStore? healthStore,
    this.healthClock,
  }) : healthStore = healthStore ?? const SecureHealthProfileStore();
  Future<ApiDataResult<Map<String, dynamic>>> groupRequest(
    String groupId, {
    String action = '',
    String? memberRegistrationId,
  }) async {
    final token = (await SharedPreferences.getInstance()).getString('token');
    if (token == null) {
      return const ApiDataResult.failure('Please log in again.');
    }
    final suffix = switch (action) {
      'rotate' => '/invitation-code',
      'lock' => '/lock',
      'remove' => '/members/${Uri.encodeComponent(memberRegistrationId!)}',
      'leave' => '/membership',
      _ => '',
    };
    final method = action == 'remove' || action == 'leave'
        ? 'DELETE'
        : action.isEmpty
        ? 'GET'
        : 'POST';
    final request = http.Request(
      method,
      Uri.parse(
        '$baseUrl/registration-groups/${Uri.encodeComponent(groupId)}$suffix',
      ),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    try {
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 15)),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map;
        return ApiDataResult.success(Map<String, dynamic>.from(decoded));
      }
      return ApiDataResult.failure(
        messageFromResponse(response, 'Unable to update group.'),
      );
    } catch (_) {
      return const ApiDataResult.failure(
        'Unable to connect. Please try again.',
      );
    }
  }

  static const String _defaultBaseUrl = bool.fromEnvironment("dart.vm.product")
      ? "https://conquer-web-production.up.railway.app/api"
      : "http://127.0.0.1:8000/api";

  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: _defaultBaseUrl,
  );

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static AppConfigData? _cachedConfig;
  static Timer? _healthSyncTimer;

  String messageFromResponse(
    http.Response response,
    String fallback, {
    String? preferredField,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return fallback;
      }

      final fieldErrors = decoded['errors'];
      if (preferredField != null && fieldErrors is Map) {
        final value = fieldErrors[preferredField];
        final values = value is List ? value : [value];
        for (final item in values) {
          final message = item?.toString().trim() ?? '';
          if (message.isNotEmpty) return message;
        }
      }

      final message = decoded["message"]?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errors = decoded["errors"];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value != null) {
            final error = value.toString().trim();
            if (error.isNotEmpty) {
              return error;
            }
          }
        }
      }
    } catch (_) {
      // Some infrastructure errors return HTML or plain text.
    }

    return fallback;
  }

  Future<LoginResult> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/login"),
            headers: {"Accept": "application/json"},
            body: {"email": email, "password": password},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await _safeClearHealthStore();
        final apiToken = data["token"].toString();
        await prefs.setString("token", apiToken);
        await registerDeviceToken(apiToken);

        return LoginResult.success;
      }

      if (response.statusCode == 401 || response.statusCode == 422) {
        return LoginResult.invalidCredentials;
      }

      if (response.statusCode == 403) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data["email_verification_required"] == true) {
            return LoginResult.emailVerificationRequired;
          }
        } catch (_) {
          // Fall through to the older web-only account behavior.
        }

        return LoginResult.webOnlyAccount;
      }

      return LoginResult.serverError;
    } catch (e) {
      log("Login error: $e");
      return LoginResult.networkError;
    }
  }

  Future<ApiActionResult> register({
    required String firstName,
    required String lastName,
    required String gender,
    required String birthday,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final birthdateError = validateParticipantBirthdate(birthday);
    if (birthdateError != null) return ApiActionResult.failure(birthdateError);
    try {
      final response = await (profileClient?.post ?? http.post)(
        Uri.parse("$baseUrl/register"),
        headers: {"Accept": "application/json"},
        body: {
          "name": "$firstName $lastName",
          "first_name": firstName,
          "last_name": lastName,
          "gender": gender,
          "birthdate": birthday,
          "email": email,
          "password": password,
          "password_confirmation": passwordConfirmation,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.body.trim();
        final data = body.isEmpty ? null : jsonDecode(body);

        if (data is Map && data["token"] != null) {
          final prefs = await SharedPreferences.getInstance();
          await _safeClearHealthStore();
          final apiToken = data["token"].toString();
          await prefs.setString("token", apiToken);
          await registerDeviceToken(apiToken);
        }

        return ApiActionResult.success(
          messageFromResponse(
            response,
            "Registration successful. Please verify your email.",
          ),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(
          response,
          "Please check your details and try again.",
          preferredField: 'birthdate',
        ),
      );
    } catch (e) {
      log("Register error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Check your API connection.",
      );
    }
  }

  Future<VerifyEmailResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/verify-email"),
            headers: {"Accept": "application/json"},
            body: {"email": email, "code": code},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return VerifyEmailResult.success;
      }

      if (response.statusCode == 422) {
        return VerifyEmailResult.invalidCode;
      }

      return VerifyEmailResult.serverError;
    } catch (e) {
      log("Verify email error: $e");
      return VerifyEmailResult.networkError;
    }
  }

  Future<ResendVerificationCodeResult> resendVerificationCode(
    String email,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/resend-verification-code"),
            headers: {"Accept": "application/json"},
            body: {"email": email},
          )
          .timeout(const Duration(seconds: 60));

      log(response.body);

      if (response.statusCode == 200) {
        return ResendVerificationCodeResult.success;
      }

      if (response.statusCode == 422 || response.statusCode == 404) {
        return ResendVerificationCodeResult.invalidEmail;
      }

      return ResendVerificationCodeResult.serverError;
    } catch (e) {
      log("Resend verification code error: $e");
      return ResendVerificationCodeResult.networkError;
    }
  }

  Future<String?> getFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      return messaging.getToken();
    } catch (e) {
      log("Get FCM token error: $e");
      return null;
    }
  }

  Future<void> registerDeviceToken(String apiToken) async {
    final fcmToken = await getFcmToken();

    if (fcmToken == null) {
      return;
    }

    await saveDeviceTokenToServer(apiToken: apiToken, fcmToken: fcmToken);

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen((newToken) async {
          await saveDeviceTokenToServer(apiToken: apiToken, fcmToken: newToken);
        });
  }

  Future<void> saveDeviceTokenToServer({
    required String apiToken,
    required String fcmToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/device-tokens"),
            headers: {
              "Authorization": "Bearer $apiToken",
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "token": fcmToken,
              "platform": Platform.isAndroid ? "android" : "ios",
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        log(
          "Save device token failed: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      log("Save device token error: $e");
    }
  }

  Future<ForgotPasswordResult> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/forgot-password"),
            headers: {"Accept": "application/json"},
            body: {"email": email},
          )
          .timeout(const Duration(seconds: 60));

      log(response.body);

      if (response.statusCode == 200) {
        return ForgotPasswordResult.success;
      }

      if (response.statusCode == 422) {
        return ForgotPasswordResult.invalidEmail;
      }

      return ForgotPasswordResult.serverError;
    } catch (e) {
      log("Forgot password error: $e");
      return ForgotPasswordResult.networkError;
    }
  }

  Future<ResetPasswordResult> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/reset-password"),
            headers: {"Accept": "application/json"},
            body: {
              "email": email,
              "code": code,
              "password": password,
              "password_confirmation": passwordConfirmation,
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ResetPasswordResult.success;
      }

      if (response.statusCode == 422) {
        return ResetPasswordResult.invalidCodeOrPassword;
      }

      return ResetPasswordResult.serverError;
    } catch (e) {
      log("Reset password error: $e");
      return ResetPasswordResult.networkError;
    }
  }

  Future<VerifyResetCodeResult> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/verify-reset-code"),
            headers: {"Accept": "application/json"},
            body: {"email": email, "code": code},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return VerifyResetCodeResult.success;
      }

      if (response.statusCode == 422) {
        return VerifyResetCodeResult.invalidCode;
      }

      return VerifyResetCodeResult.serverError;
    } catch (e) {
      log("Verify reset code error: $e");
      return VerifyResetCodeResult.networkError;
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/health"),
        headers: {"Accept": "application/json"},
      );

      log(response.body);
      return response.statusCode == 200;
    } catch (e) {
      log("API connection error: $e");
      return false;
    }
  }

  List<String> interestNamesFrom(dynamic source) {
    final interests = _interestListFrom(source);

    return interests
        .map(_interestNameFrom)
        .where((interest) => interest.isNotEmpty)
        .toSet()
        .toList();
  }

  List<dynamic> _interestListFrom(dynamic source) {
    return _listFromKeys(source, const [
      "interests",
      "profile_interests",
      "profileInterests",
      "interest_types",
      "interestTypes",
      "event_interest_types",
      "eventInterestTypes",
      "event_types",
      "eventTypes",
      "types",
    ]);
  }

  List<dynamic> _listFromKeys(dynamic source, List<String> keys) {
    if (source is List) {
      return source;
    }

    if (source is Map) {
      for (final key in keys) {
        final value = source[key];
        if (value is List) {
          return value;
        }
      }

      final data = source["data"];
      if (data != source) {
        return _listFromKeys(data, keys);
      }
    }

    return [];
  }

  String _interestNameFrom(dynamic interest) {
    if (interest is Map) {
      const keys = [
        "name",
        "title",
        "label",
        "interest_type",
        "interestType",
        "event_type",
        "eventType",
        "type",
      ];

      for (final key in keys) {
        final value = interest[key];
        final name = _interestNameFrom(value);
        if (name.isNotEmpty) {
          return name;
        }
      }

      return "";
    }

    return interest?.toString().trim() ?? "";
  }

  List<String> namesFromKeys(dynamic source, List<String> keys) {
    return _listFromKeys(
      source,
      keys,
    ).map(_interestNameFrom).where((name) => name.isNotEmpty).toSet().toList();
  }

  Future<AppConfigData> getAppConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedConfig != null) {
      return _cachedConfig!;
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/config"),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final config = AppConfigData(
          profileInterests: namesFromKeys(data, const [
            "profile_interests",
            "profileInterests",
            "interests",
            "interest_types",
            "interestTypes",
          ]),
          eventInterestTypes: namesFromKeys(data, const [
            "event_interest_types",
            "eventInterestTypes",
            "event_types",
            "eventTypes",
            "interest_types",
            "interestTypes",
          ]),
          trainingFocusTypes: namesFromKeys(data, const [
            "training_focus_types",
            "trainingFocusTypes",
            "focus_types",
            "focusTypes",
            "training_types",
            "trainingTypes",
          ]),
        );

        _cachedConfig = config;
        return config;
      }
    } catch (e) {
      log("Get app config error: $e");
    }

    return _cachedConfig ?? const AppConfigData.empty();
  }

  Future<List<String>> getInterestTypes() async {
    return (await getAppConfig()).profileInterests;
  }

  Future<List<String>> getEventInterestTypes() async {
    return (await getAppConfig()).eventInterestTypes;
  }

  Future<List<String>> getTrainingFocusTypes() async {
    return (await getAppConfig()).trainingFocusTypes;
  }

  Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    Future<void> clearLocalSession() async {
      await prefs.remove("token");
      await prefs.remove("isProfiled");
      await prefs.remove("activities");
      await _safeClearHealthStore();
      _healthSyncTimer?.cancel();
      _healthSyncTimer = null;
    }

    if (token == null) {
      await clearLocalSession();
      return true;
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/logout"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await clearLocalSession();
        return true;
      }

      log("Logout failed: ${response.statusCode} ${response.body}");
      await clearLocalSession();
      return true;
    } catch (e) {
      log("Logout error: $e");
      await clearLocalSession();
      return true;
    }
  }

  Future<UserFetchResult> fetchUser({bool allowCache = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const UserFetchResult(UserFetchState.signedOut);
    }

    try {
      final response = await (profileClient?.get ?? http.get)(
        Uri.parse("$baseUrl/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawUser = data["user"];
        if (rawUser is Map) {
          final user = Map<String, dynamic>.from(rawUser);
          await _safeCacheUser(user);
          return UserFetchResult(UserFetchState.online, user);
        }
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        await _safeClearHealthStore();
        _healthSyncTimer?.cancel();
        _healthSyncTimer = null;
        return const UserFetchResult(UserFetchState.unauthorized);
      }

      return allowCache
          ? await _cachedUserResult()
          : const UserFetchResult(UserFetchState.unavailable);
    } catch (e) {
      log("Get user error: $e");
      return allowCache
          ? await _cachedUserResult()
          : const UserFetchResult(UserFetchState.unavailable);
    }
  }

  Future<Map<String, dynamic>?> getUser() async => (await fetchUser()).user;

  Future<UserFetchResult> _cachedUserResult() async {
    try {
      final user = await healthStore.readCachedUser();
      return user == null
          ? const UserFetchResult(UserFetchState.unavailable)
          : UserFetchResult(UserFetchState.cached, user);
    } catch (e) {
      log('Read cached user error: $e');
      return const UserFetchResult(UserFetchState.unavailable);
    }
  }

  Future<void> _safeCacheUser(Map<String, dynamic> user) async {
    try {
      await healthStore.writeCachedUser(user);
    } catch (e) {
      log('Cache user error: $e');
    }
  }

  Future<void> _safeClearHealthStore() async {
    try {
      await healthStore.clearAll();
    } catch (e) {
      log('Clear Health Profile cache error: $e');
    }
  }

  Future<PendingHealthUpdate?> pendingHealthUpdate() async {
    try {
      return await healthStore.readPending();
    } catch (e) {
      log('Read pending Health Profile update error: $e');
      return null;
    }
  }

  void startHealthProfileSync() {
    _healthSyncTimer ??= Timer.periodic(const Duration(seconds: 20), (_) async {
      final service = ApiService();
      if (await service.pendingHealthUpdate() != null) {
        await service.syncPendingHealthProfile();
      }
    });
    unawaited(syncPendingHealthProfile());
  }

  Future<ApiActionResult> updateHealthProfile(
    HealthMeasurements measurements,
  ) async {
    final errors = measurements.validate();
    if (errors.isNotEmpty) {
      return ApiActionResult.failure(errors.values.first);
    }

    Map<String, dynamic>? cachedUser;
    try {
      cachedUser = await healthStore.readCachedUser();
    } catch (_) {}

    final values = measurements.toJson();
    final now = healthClock?.call() ?? DateTime.now();
    final measuredAt = values['height_cm'] == null
        ? null
        : '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';
    final update = PendingHealthUpdate(
      id: _newUuid(),
      clientUpdatedAt: _healthCaptureTimestamp(now),
      baseVersion: cachedUser?['health_profile_updated_at']?.toString(),
      heightCm: values['height_cm'] as double?,
      weightKg: values['weight_kg'] as double?,
      measuredAt: measuredAt,
    );

    try {
      await healthStore.writePending(update);
    } catch (e) {
      log('Queue Health Profile update error: $e');
      return const ApiActionResult.failure(
        'Unable to protect this update on your device. Please try again.',
      );
    }

    return _sendHealthUpdate(update, cachedUser: cachedUser);
  }

  Future<ApiActionResult> syncPendingHealthProfile() async {
    final pending = await pendingHealthUpdate();
    if (pending == null) {
      return const ApiActionResult.success('No Health Profile update pending.');
    }
    if (pending.conflict) {
      return const ApiActionResult.conflict(
        'Review the latest Health Profile before saving this offline edit again.',
      );
    }
    return _sendHealthUpdate(pending);
  }

  Future<ApiActionResult> _sendHealthUpdate(
    PendingHealthUpdate update, {
    Map<String, dynamic>? cachedUser,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      return const ApiActionResult.failure('Please log in again.');
    }

    try {
      final response = await (profileClient?.put ?? http.put)(
        Uri.parse('$baseUrl/me/health-profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(
          update.toJson()
            ..remove('conflict')
            ..remove('bmi_measured_at'),
        ),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic>? responseUser;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['user'] is Map) {
          responseUser = Map<String, dynamic>.from(decoded['user'] as Map);
          await _safeCacheUser(responseUser);
        }
      } catch (_) {}

      if (response.statusCode == 200) {
        await healthStore.clearPending();
        return ApiActionResult(
          success: true,
          message: messageFromResponse(
            response,
            'Health Profile synchronized successfully.',
          ),
          user: responseUser,
        );
      }

      if (response.statusCode == 409) {
        await healthStore.writePending(update.markConflict());
        return ApiActionResult.conflict(
          messageFromResponse(
            response,
            'Your Health Profile changed elsewhere. Review the latest measurements before saving again.',
          ),
          user: responseUser,
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('isProfiled');
        await prefs.remove('activities');
        await _safeClearHealthStore();
        return const ApiActionResult.failure(
          'Your session expired. Please log in again.',
        );
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        await healthStore.clearPending();
        return ApiActionResult.failure(
          messageFromResponse(response, 'Unable to save Health Profile.'),
        );
      }

      return ApiActionResult.queued(
        'Offline—your Health Profile update is queued for automatic sync.',
        user: cachedUser,
        capturedOn: update.capturedOn,
      );
    } catch (e) {
      log('Health Profile sync error: $e');
      return ApiActionResult.queued(
        'Offline—your Health Profile update is queued for automatic sync.',
        user: cachedUser,
        capturedOn: update.capturedOn,
      );
    }
  }

  String _healthCaptureTimestamp(DateTime captured) {
    if (captured.isUtc) return captured.toIso8601String();
    final offset = captured.timeZoneOffset.inMinutes;
    final hours = (offset.abs() ~/ 60).toString().padLeft(2, '0');
    final minutes = (offset.abs() % 60).toString().padLeft(2, '0');
    return '${captured.toIso8601String()}${offset < 0 ? '-' : '+'}$hours:$minutes';
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<ApiActionResult> updateProfile({
    required String name,
    required String phone,
    required String gender,
    required String birthdate,
    required String address,
    required String emergencyContactName,
    required String emergencyContactNumber,
    required String medicalConditions,
    String? avatarPath,
    HealthMeasurements? measurements,
    bool healthOnly = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    if (measurements != null && measurements.validate().isNotEmpty) {
      return ApiActionResult.failure(measurements.validate().values.first);
    }
    if (!healthOnly) {
      final birthdateError = validateParticipantBirthdate(birthdate);
      if (birthdateError != null) {
        return ApiActionResult.failure(birthdateError);
      }
    }
    try {
      final fields = <String, dynamic>{
        "name": name,
        if (!healthOnly) ...{
          "phone": phone,
          "gender": gender,
          "birthdate": birthdate,
          "address": address,
          "emergency_contact_name": emergencyContactName,
          "emergency_contact_number": emergencyContactNumber,
          "medical_conditions": medicalConditions,
        },
        if (measurements != null) ...measurements.toJson(),
      };

      final response = await (profileClient?.patch ?? http.patch)(
        Uri.parse("$baseUrl/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(fields),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['user'] is Map) {
            await _safeCacheUser(
              Map<String, dynamic>.from(decoded['user'] as Map),
            );
          }
        } catch (_) {}
      }

      if (response.statusCode == 200 && avatarPath != null) {
        final avatarRequest = http.MultipartRequest(
          "POST",
          Uri.parse("$baseUrl/me/avatar"),
        );
        avatarRequest.headers.addAll({
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        });
        avatarRequest.files.add(
          await http.MultipartFile.fromPath("avatar", avatarPath),
        );

        final streamedResponse = await avatarRequest.send().timeout(
          const Duration(seconds: 30),
        );
        final avatarResponse = await http.Response.fromStream(streamedResponse);

        if (avatarResponse.statusCode == 200) {
          return ApiActionResult.success(
            messageFromResponse(
              avatarResponse,
              "Profile updated successfully.",
            ),
          );
        }

        return ApiActionResult.failure(
          messageFromResponse(
            avatarResponse,
            "Profile details were saved, but the profile picture could not be uploaded.",
          ),
        );
      }

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Profile updated successfully."),
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        await _safeClearHealthStore();
        return const ApiActionResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(
          response,
          "Unable to update profile.",
          preferredField: 'birthdate',
        ),
      );
    } catch (e) {
      log("Update profile error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> updateInterests(List<String> interests) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .patch(
            Uri.parse("$baseUrl/me/interests"),
            headers: {
              "Accept": "application/json",
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({"interests": interests}),
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Interests updated successfully."),
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        return const ApiActionResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to save interests."),
      );
    } catch (e) {
      log("Update interests error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<List<Map<String, dynamic>>> getEvents({
    bool recommended = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final uri = Uri.parse("$baseUrl/events").replace(
        queryParameters: recommended && token != null
            ? {"recommended": "1"}
            : null,
      );
      final response = await http
          .get(
            uri,
            headers: {
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data["data"] as List? ?? [];

        return events
            .whereType<Map>()
            .map((event) => Map<String, dynamic>.from(event))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get events error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getEvent(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/events/$eventId"),
            headers: {
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final event = data["data"];

        return event is Map ? Map<String, dynamic>.from(event) : null;
      }

      return null;
    } catch (e) {
      log("Get event error: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/announcements"),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final announcements = data["data"] as List? ?? [];

        return announcements
            .whereType<Map>()
            .map((announcement) => Map<String, dynamic>.from(announcement))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get announcements error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/notifications"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = data["data"] as List? ?? [];

        return notifications
            .whereType<Map>()
            .map((notification) => Map<String, dynamic>.from(notification))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get notifications error: $e");
      return [];
    }
  }

  Future<ApiActionResult> markNotificationRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/notifications/$notificationId/read"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Notification marked as read."),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to mark notification as read."),
      );
    } catch (e) {
      log("Mark notification read error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> markAllNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/notifications/read-all"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Notifications marked as read."),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to mark notifications as read."),
      );
    } catch (e) {
      log("Mark all notifications read error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<List<Map<String, dynamic>>> getTrainingModules({
    bool recommended = true,
  }) async {
    return (await getTrainingModulesPage(recommended: recommended)).data;
  }

  Future<PaginatedApiResult<Map<String, dynamic>>> getTrainingModulesPage({
    bool recommended = true,
    String? pageUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final uri = pageUrl == null
          ? Uri.parse("$baseUrl/training-modules").replace(
              queryParameters: recommended && token != null
                  ? {"recommended": "1"}
                  : null,
            )
          : Uri.parse(pageUrl);
      final response = await http
          .get(
            uri,
            headers: {
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final modules = data["data"] as List? ?? [];
        final links = data["links"];
        final nextPageUrl = links is Map ? links["next"]?.toString() : null;

        return PaginatedApiResult(
          data: modules
              .whereType<Map>()
              .map((module) => Map<String, dynamic>.from(module))
              .toList(),
          nextPageUrl: nextPageUrl != null && nextPageUrl.trim().isNotEmpty
              ? nextPageUrl
              : null,
        );
      }

      return const PaginatedApiResult.empty();
    } catch (e) {
      log("Get training modules error: $e");
      return const PaginatedApiResult.empty();
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final response = await http
          .get(
            Uri.parse(
              token == null
                  ? "$baseUrl/community-posts"
                  : "$baseUrl/community-posts/feed",
            ),
            headers: {
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final posts = data["data"] as List? ?? [];

        return posts
            .whereType<Map>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get community posts error: $e");
      return [];
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> createCommunityPost({
    required String title,
    required String content,
    String? mediaPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/community-posts"),
      );

      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      request.fields["title"] = title;
      request.fields["content"] = content;

      if (mediaPath != null) {
        final extension = mediaPath.split(".").last.toLowerCase();
        final fieldName = ["mp4", "mov", "webm", "m4v"].contains(extension)
            ? "video"
            : "image";
        request.files.add(
          await http.MultipartFile.fromPath(fieldName, mediaPath),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiDataResult.success(
          Map<String, dynamic>.from(data["data"] ?? {}),
          messageFromResponse(response, "Post created successfully."),
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        return const ApiDataResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to create post."),
      );
    } catch (e) {
      log("Create community post error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<bool> deleteCommunityPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return false;
    }

    try {
      final response = await http
          .delete(
            Uri.parse("$baseUrl/community-posts/$postId"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);
      return response.statusCode == 200;
    } catch (e) {
      log("Delete community post error: $e");
      return false;
    }
  }

  Future<ApiDataResult<List<Map<String, dynamic>>>>
  getArchivedCommunityPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/community-posts/archived"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        dynamic rawPosts = decoded;
        if (decoded is Map) rawPosts = decoded["data"];
        if (rawPosts is Map) rawPosts = rawPosts["data"];
        final posts = rawPosts is List ? rawPosts : const [];

        return ApiDataResult.success(
          posts
              .whereType<Map>()
              .map((post) => Map<String, dynamic>.from(post))
              .toList(),
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to load recently deleted posts."),
      );
    } catch (e) {
      log("Get archived community posts error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> restoreArchivedCommunityPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/community-posts/$postId/restore"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiActionResult.success(
          messageFromResponse(response, "Post restored successfully."),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to restore this post."),
      );
    } catch (e) {
      log("Restore archived community post error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<List<Map<String, dynamic>>> getHiddenCommunityPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/community-posts/hidden"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final posts = data["data"] as List? ?? [];

        return posts
            .whereType<Map>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get hidden community posts error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReportedCommunityPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/community-posts/reported"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final posts = data["data"] as List? ?? [];

        return posts
            .whereType<Map>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get reported community posts error: $e");
      return [];
    }
  }

  Future<ApiActionResult> hideCommunityPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/community-posts/$postId/hide"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Post hidden from your feed."),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to hide post."),
      );
    } catch (e) {
      log("Hide community post error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> unhideCommunityPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .delete(
            Uri.parse("$baseUrl/community-posts/$postId/hide"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Post restored to your feed."),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to restore post."),
      );
    } catch (e) {
      log("Unhide community post error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> updateCommunityPost({
    required String postId,
    required String title,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .patch(
            Uri.parse("$baseUrl/community-posts/$postId"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"title": title, "content": content}),
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiDataResult.success(
          Map<String, dynamic>.from(data["data"] ?? {}),
          messageFromResponse(response, "Post updated successfully."),
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to update post."),
      );
    } catch (e) {
      log("Update community post error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> reportCommunityPost({
    required String postId,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/community-posts/$postId/report"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"reason": reason}),
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Post reported for review."),
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to report post."),
      );
    } catch (e) {
      log("Report community post error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<Map<String, dynamic>?> addCommunityComment({
    required String postId,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/community-posts/$postId/comments"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
            body: {"content": content},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data["data"] ?? {});
      }

      return null;
    } catch (e) {
      log("Add community comment error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> toggleCommunityLike(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/community-posts/$postId/like"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }

      return null;
    } catch (e) {
      log("Toggle community like error: $e");
      return null;
    }
  }

  Future<AchievementData> getAchievementData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const AchievementData.empty();
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/achievements"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Map<dynamic, dynamic> payload = data is Map
            ? data
            : <String, dynamic>{};
        final nestedData = payload["data"];
        final Map<dynamic, dynamic>? nestedPayload = nestedData is Map
            ? nestedData
            : null;

        List<dynamic> listFromKeys(
          Map<dynamic, dynamic>? source,
          List<String> keys,
        ) {
          if (source == null) return const [];

          for (final key in keys) {
            final value = source[key];
            if (value is List) return value;
          }

          return const [];
        }

        const achievementKeys = [
          "achievements",
          "badges",
          "e_badges",
          "available_badges",
          "all_badges",
        ];
        const issuedBadgeKeys = [
          "issued_badges",
          "issuedBadges",
          "earned_badges",
          "unlocked_badges",
        ];
        var achievements = listFromKeys(payload, achievementKeys);
        if (achievements.isEmpty) {
          achievements = listFromKeys(nestedPayload, achievementKeys);
        }
        if (achievements.isEmpty && nestedData is List) {
          achievements = nestedData;
        }

        var issuedBadges = listFromKeys(payload, issuedBadgeKeys);
        if (issuedBadges.isEmpty) {
          issuedBadges = listFromKeys(nestedPayload, issuedBadgeKeys);
        }

        return AchievementData(
          achievements: achievements
              .whereType<Map>()
              .map((achievement) => Map<String, dynamic>.from(achievement))
              .toList(),
          issuedBadges: issuedBadges
              .whereType<Map>()
              .map((badge) => Map<String, dynamic>.from(badge))
              .toList(),
        );
      }

      return const AchievementData.empty();
    } catch (e) {
      log("Get achievements error: $e");
      return const AchievementData.empty();
    }
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final data = await getAchievementData();
    return data.achievements;
  }

  Future<ApiDataResult<List<Map<String, dynamic>>>> getCertificates() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/certificates"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));
      log(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        dynamic value = decoded is Map
            ? decoded["data"] ?? decoded["certificates"]
            : decoded;
        if (value is Map) {
          value = value["certificates"] ?? value["data"];
        }
        final certificates = value is List
            ? value
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
        return ApiDataResult.success(
          certificates,
          messageFromResponse(response, "Certificates loaded."),
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to load certificates."),
      );
    } catch (e) {
      log("Get certificates error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/leaderboard"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final users = data["data"] as List? ?? [];

        return users
            .whereType<Map>()
            .map((user) => Map<String, dynamic>.from(user))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get leaderboard error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyRegistrations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/my-registrations"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final registrations = data["data"] as List? ?? [];

        final flattened = <Map<String, dynamic>>[];
        for (final item in registrations.whereType<Map>()) {
          final parent = Map<String, dynamic>.from(item);
          final nested = parent["registrations"];
          if (nested is! List) {
            flattened.add(parent);
            continue;
          }

          final parentEvent =
              parent["event"] is Map
                    ? Map<String, dynamic>.from(parent["event"] as Map)
                    : Map<String, dynamic>.from(parent)
                ..remove("registrations");
          for (final registration in nested.whereType<Map>()) {
            final normalized = Map<String, dynamic>.from(registration);
            normalized.putIfAbsent("event", () => parentEvent);
            flattened.add(normalized);
          }
        }
        return flattened;
      }

      return [];
    } catch (e) {
      log("Get registrations error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyResults() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/my-results"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data["data"] as List? ?? [];

        return results
            .whereType<Map>()
            .map((result) => Map<String, dynamic>.from(result))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get results error: $e");
      return [];
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> getRegistrationFeedback(
    String registrationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/registrations/$registrationId/feedback"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));
      log(response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded["data"] : null;
        return ApiDataResult.success(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
          messageFromResponse(response, "Feedback loaded."),
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to load feedback."),
      );
    } catch (e) {
      log("Get registration feedback error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> submitRegistrationFeedback({
    required String registrationId,
    required int overallRating,
    int? organizationRating,
    int? routeRating,
    int? safetyRating,
    int? experienceRating,
    String? comment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    final payload = <String, dynamic>{
      "overall_rating": overallRating,
      "organization_rating": ?organizationRating,
      "route_rating": ?routeRating,
      "safety_rating": ?safetyRating,
      "experience_rating": ?experienceRating,
      if (comment != null && comment.trim().isNotEmpty)
        "comment": comment.trim(),
    };

    try {
      final response = await http
          .put(
            Uri.parse("$baseUrl/registrations/$registrationId/feedback"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded["data"] : null;
        return ApiDataResult.success(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
          messageFromResponse(response, "Feedback saved successfully."),
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to save feedback."),
      );
    } catch (e) {
      log("Submit registration feedback error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> registerForEvent({
    required int eventId,
    required int categoryId,
    required String shirtSize,
    required String medicalConditions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/events/$eventId/register/$categoryId"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
            body: {
              "shirt_size": shirtSize,
              "medical_conditions": medicalConditions,
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiActionResult.success(
          messageFromResponse(response, "Successfully registered."),
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        return const ApiActionResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to register for this event."),
      );
    } catch (e) {
      log("Register event error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> registerForEventWithData({
    required int eventId,
    required int categoryId,
    required String shirtSize,
    required String medicalConditions,
    required bool firstAidKitConfirmed,
    required bool waiverAccepted,
    String? waiverName,
    String? medicalCertificatePath,
    String? groupAction,
    String? groupName,
    String? invitationCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/events/$eventId/register/$categoryId"),
      );

      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      request.fields["shirt_size"] = shirtSize;
      request.fields.addAll(
        groupRegistrationFields(
          action: groupAction,
          name: groupName,
          code: invitationCode,
        ),
      );
      request.fields["medical_conditions"] = medicalConditions;
      request.fields["first_aid_kit_confirmed"] = firstAidKitConfirmed
          ? "1"
          : "0";
      request.fields["waiver_accepted"] = waiverAccepted ? "1" : "0";
      if (waiverName != null && waiverName.trim().isNotEmpty) {
        request.fields["waiver_name"] = waiverName.trim();
      }
      if (medicalCertificatePath != null &&
          medicalCertificatePath.trim().isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            "medical_certificate",
            medicalCertificatePath,
          ),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded["data"] : null;
        return ApiDataResult.success({
          if (data is Map) ...Map<String, dynamic>.from(data),
          if (decoded is Map && decoded['invitation_code'] != null)
            'invitation_code': decoded['invitation_code'],
        }, messageFromResponse(response, "Successfully registered."));
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        return const ApiDataResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to register for this event."),
      );
    } catch (e) {
      log("Register event error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> submitPaymentProof({
    required int registrationId,
    required String provider,
    required String providerReference,
    required String notes,
    String? proofImagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/registrations/$registrationId/payment-proof"),
      );

      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      request.fields["provider"] = provider;
      if (providerReference.trim().isNotEmpty) {
        request.fields["provider_reference"] = providerReference.trim();
      }
      if (notes.trim().isNotEmpty) {
        request.fields["notes"] = notes.trim();
      }
      if (proofImagePath != null && proofImagePath.trim().isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath("proof_image", proofImagePath),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded["data"] : null;

        return ApiDataResult.success(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
          messageFromResponse(response, "Payment proof submitted."),
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to submit payment proof."),
      );
    } catch (e) {
      log("Submit payment proof error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiDataResult<Map<String, dynamic>>> createPayMongoCheckout({
    required int registrationId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiDataResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              "$baseUrl/registrations/$registrationId/paymongo-checkout",
            ),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 20));

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final data = decoded["data"];
          final checkoutUrl = decoded["checkout_url"]?.toString();

          return ApiDataResult.success(
            {
              "checkout_url": checkoutUrl,
              "registration": data is Map
                  ? Map<String, dynamic>.from(data)
                  : <String, dynamic>{},
            },
            messageFromResponse(response, "PayMongo checkout session created."),
          );
        }

        return const ApiDataResult.failure(
          "Online checkout response was incomplete.",
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        return const ApiDataResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiDataResult.failure(
        messageFromResponse(response, "Unable to create online checkout."),
      );
    } catch (e) {
      log("Create PayMongo checkout error: $e");
      return const ApiDataResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  Future<ApiActionResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .patch(
            Uri.parse("$baseUrl/me/password"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
            body: {
              "current_password": currentPassword,
              "password": newPassword,
              "password_confirmation": passwordConfirmation,
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        return ApiActionResult.success(
          messageFromResponse(response, "Password changed successfully."),
        );
      }

      if (response.statusCode == 401) {
        await prefs.remove("token");
        await prefs.remove("isProfiled");
        await prefs.remove("activities");
        return const ApiActionResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to update password."),
      );
    } catch (e) {
      log("Change password error: $e");
      return const ApiActionResult.failure(
        "Cannot connect to the server. Please try again.",
      );
    }
  }

  bool profileIsComplete(Map<String, dynamic>? user) {
    if (user == null) {
      return false;
    }
    if (registrationBlockReason(const {}, user: user).isNotEmpty) return false;

    final requiredFields = [
      user["name"],
      user["phone"],
      user["gender"],
      user["birthdate"],
      user["address"],
      user["emergency_contact_name"],
      user["emergency_contact_number"],
    ];

    return requiredFields.every(
      (field) => field?.toString().trim().isNotEmpty == true,
    );
  }
}
