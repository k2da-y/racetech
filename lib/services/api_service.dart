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
  webOnlyAccount,
  networkError,
  serverError,
}

enum ForgotPasswordResult { success, invalidEmail, networkError, serverError }

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

class ApiService {
  // Real phone connected by USB with:
  // adb reverse tcp:8000 tcp:8000
  static const String baseUrl = "http://127.0.0.1:8000/api";

  // Real phone on the same Wi-Fi as this PC.
  // static const String baseUrl = "http://192.168.1.23:8000/api";

  // Android emulator talking to a Laravel server running on this PC:
  // static const String baseUrl = "http://10.0.2.2:8000/api";

  static StreamSubscription<String>? _tokenRefreshSubscription;

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
        return LoginResult.webOnlyAccount;
      }

      return LoginResult.serverError;
    } catch (e) {
      log("Login error: $e");
      return LoginResult.networkError;
    }
  }

  Future<bool> register({
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
        final data = jsonDecode(response.body);

        if (data["token"] != null) {
          final prefs = await SharedPreferences.getInstance();
          final apiToken = data["token"].toString();
          await prefs.setString("token", apiToken);
          await registerDeviceToken(apiToken);
        }

        return true;
      }

      return false;
    } catch (e) {
      log("Register error: $e");
      return false;
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

  Future<List<String>> getInterestTypes() async {
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
        final interests = data["interests"] as List? ?? [];

        return interests
            .map((interest) => interest.toString().trim())
            .where((interest) => interest.isNotEmpty)
            .toSet()
            .toList();
      }

      return [];
    } catch (e) {
      log("Get interest types error: $e");
      return [];
    }
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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return const ApiActionResult.failure("Please log in again.");
    }

    try {
      final response = await http
          .patch(
            Uri.parse("$baseUrl/me"),
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
            body: {
              "name": name,
              "phone": phone,
              "gender": gender,
              "birthdate": birthdate,
              "address": address,
              "emergency_contact_name": emergencyContactName,
              "emergency_contact_number": emergencyContactNumber,
              "medical_conditions": medicalConditions,
            },
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

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

  Future<List<Map<String, dynamic>>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/events"),
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

  Future<List<Map<String, dynamic>>> getTrainingModules() async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/training-modules"),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 15));

      log(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final modules = data["data"] as List? ?? [];

        return modules
            .whereType<Map>()
            .map((module) => Map<String, dynamic>.from(module))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get training modules error: $e");
      return [];
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
        final fieldName = ["mp4", "mov", "webm"].contains(extension)
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

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      return [];
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
        final achievements = data["data"] as List? ?? [];

        return achievements
            .whereType<Map>()
            .map((achievement) => Map<String, dynamic>.from(achievement))
            .toList();
      }

      return [];
    } catch (e) {
      log("Get achievements error: $e");
      return [];
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

        return registrations
            .whereType<Map>()
            .map((registration) => Map<String, dynamic>.from(registration))
            .toList();
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
