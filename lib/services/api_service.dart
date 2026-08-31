import 'dart:async';
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

  const ApiActionResult({required this.success, required this.message});

  const ApiActionResult.success([String message = "Success"])
    : this(success: true, message: message);

  const ApiActionResult.failure(String message)
    : this(success: false, message: message);
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
  static const String _defaultBaseUrl = bool.fromEnvironment("dart.vm.product")
      ? "https://conquer-web-production.up.railway.app/api"
      : "http://127.0.0.1:8000/api";

  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: _defaultBaseUrl,
  );

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static AppConfigData? _cachedConfig;

  String messageFromResponse(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return fallback;
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
    try {
      final response = await http.post(
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

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.body.trim();
        final data = body.isEmpty ? null : jsonDecode(body);

        if (data is Map && data["token"] != null) {
          final prefs = await SharedPreferences.getInstance();
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

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return null;
    }

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/me"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["user"] as Map<String, dynamic>?;
      }

      return null;
    } catch (e) {
      log("Get user error: $e");
      return null;
    }
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final fields = {
        "name": name,
        "phone": phone,
        "gender": gender,
        "birthdate": birthdate,
        "address": address,
        "emergency_contact_name": emergencyContactName,
        "emergency_contact_number": emergencyContactNumber,
        "medical_conditions": medicalConditions,
      };

      final response = await http
          .patch(
            Uri.parse("$baseUrl/me"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
            body: fields,
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

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

        log(avatarResponse.body);

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
        return const ApiActionResult.failure(
          "Your session expired. Please log in again.",
        );
      }

      return ApiActionResult.failure(
        messageFromResponse(response, "Unable to update profile."),
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

      log(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? decoded["data"] : null;

        return ApiDataResult.success(
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
          messageFromResponse(response, "Successfully registered."),
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
