import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/event_schedule_formatter.dart';
import '../utils/event_distance_formatter.dart';
import '../utils/payment_options.dart';
import '../utils/qualification_notes.dart';
import '../utils/event_gear_formatter.dart';
import '../utils/registration_readiness.dart';
import '../utils/registration_feedback.dart';
import '../utils/registration_certificate.dart';
import '../widgets/category_checkpoint_map.dart';
import '../widgets/event_feedback_sheet.dart';
import '../widgets/registration_certificate_card.dart';

class MyActivityPage extends StatefulWidget {
  const MyActivityPage({super.key});

  @override
  State<MyActivityPage> createState() => _MyActivityPageState();
}

class _MyActivityPageState extends State<MyActivityPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> registrations = [];
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    loadActivity();
  }

  Future<void> loadActivity() async {
    final loadedRegistrations = await ApiService().getMyRegistrations();
    final loadedResults = await ApiService().getMyResults();

    if (!mounted) return;

    setState(() {
      registrations = loadedRegistrations;
      results = loadedResults;
      isLoading = false;
    });
  }

  Future<void> refreshActivity() async {
    setState(() => isLoading = true);
    await loadActivity();
  }

  Future<void> openPaymentProofSheet(Map<String, dynamic> registration) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _ActivityPaymentProofSheet(registration: registration),
    );

    if (!mounted || updated != true) return;

    await refreshActivity();
  }

  Future<void> openFeedbackSheet(Map<String, dynamic> registration) async {
    final registrationId =
        (registration["id"] ?? registration["registration_id"] ?? "")
            .toString()
            .trim();
    if (registrationId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Feedback is unavailable.")));
      return;
    }

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => EventFeedbackSheet(
        initialFeedback: registrationFeedback(registration),
        canSubmitFeedback: registrationCanSubmitFeedback(registration),
        onLoad: () => ApiService().getRegistrationFeedback(registrationId),
        onSubmit: (values) => ApiService().submitRegistrationFeedback(
          registrationId: registrationId,
          overallRating: values["overall_rating"] as int,
          organizationRating: values["organization_rating"] as int?,
          routeRating: values["route_rating"] as int?,
          safetyRating: values["safety_rating"] as int?,
          experienceRating: values["experience_rating"] as int?,
          comment: values["comment"]?.toString(),
        ),
        onSaved: () {},
      ),
    );

    if (!mounted || updated != true) return;
    await refreshActivity();
  }

  Map<String, dynamic> feedbackRegistrationForResult(
    Map<String, dynamic> result,
  ) {
    final nested = result["registration"];
    final registrationId =
        (result["registration_id"] ??
                (nested is Map ? nested["id"] : null) ??
                "")
            .toString();
    Map<String, dynamic> registration = nested is Map
        ? Map<String, dynamic>.from(nested)
        : registrations.firstWhere(
            (item) => (item["id"] ?? "").toString() == registrationId,
            orElse: () => <String, dynamic>{"id": registrationId},
          );

    registration = Map<String, dynamic>.from(registration);
    for (final key in const [
      "feedback",
      "feedback_required",
      "can_submit_feedback",
      "readiness",
    ]) {
      if (result.containsKey(key)) registration[key] = result[key];
    }
    return registration;
  }

  Map<String, dynamic> nestedMap(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  String formatDate(String value) {
    if (value.isEmpty) return "TBA";

    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;

    return "${parsed.month}/${parsed.day}/${parsed.year}";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF3F9),
        body: SafeArea(
          child: Column(
            children: [
              _HeaderSection(
                onBack: () => Navigator.pop(context),
                onRefresh: refreshActivity,
                registrationsCount: registrations.length,
                resultsCount: results.length,
              ),

              Expanded(
                child: isLoading
                    ? const _LoadingState()
                    : Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            height: 50,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const TabBar(
                              indicator: BoxDecoration(
                                color: Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                              dividerColor: Colors.transparent,
                              labelColor: Color(0xFF2563EB),
                              unselectedLabelColor: Color(0xFF64748B),
                              labelStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                              unselectedLabelStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                              tabs: [
                                Tab(text: "Registrations"),
                                Tab(text: "Results"),
                              ],
                            ),
                          ),

                          Expanded(
                            child: TabBarView(
                              children: [
                                RefreshIndicator(
                                  onRefresh: refreshActivity,
                                  child: _RegistrationList(
                                    registrations: registrations,
                                    nestedMap: nestedMap,
                                    formatDate: formatDate,
                                    onSubmitPayment: openPaymentProofSheet,
                                    onFeedback: openFeedbackSheet,
                                  ),
                                ),
                                RefreshIndicator(
                                  onRefresh: refreshActivity,
                                  child: _ResultList(
                                    results: results,
                                    nestedMap: nestedMap,
                                    feedbackRegistrationForResult:
                                        feedbackRegistrationForResult,
                                    onFeedback: openFeedbackSheet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final int registrationsCount;
  final int resultsCount;

  const _HeaderSection({
    required this.onBack,
    required this.onRefresh,
    required this.registrationsCount,
    required this.resultsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  elevation: 2,
                ),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My Activity",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Track your registrations and results",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  elevation: 2,
                ),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.app_registration_outlined,
                  label: "Registrations",
                  value: "$registrationsCount",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoCard(
                  icon: Icons.emoji_events_outlined,
                  label: "Results",
                  value: "$resultsCount",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationList extends StatelessWidget {
  final List<Map<String, dynamic>> registrations;
  final Map<String, dynamic> Function(Map<String, dynamic>, String) nestedMap;
  final String Function(String) formatDate;
  final ValueChanged<Map<String, dynamic>> onSubmitPayment;
  final ValueChanged<Map<String, dynamic>> onFeedback;

  const _RegistrationList({
    required this.registrations,
    required this.nestedMap,
    required this.formatDate,
    required this.onSubmitPayment,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    if (registrations.isEmpty) {
      return const _EmptyActivityState(
        icon: Icons.app_registration_outlined,
        title: "No registrations yet",
        message: "Your joined or pending event registrations will appear here.",
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: registrations.length,
      itemBuilder: (context, index) {
        final registration = registrations[index];
        final event = nestedMap(registration, "event");
        final category = nestedMap(registration, "category");
        final title = (event["title"] ?? "Event").toString();
        final status = (registration["status"] ?? "pending").toString();
        final paymentRequired = registration["payment_required"] == true;
        final paymentStatus = (registration["payment_status"] ?? "").toString();
        final payment = registration["payment"];
        final paymentProvider =
            registration["payment_provider"] ??
            registration["provider"] ??
            (payment is Map ? payment["provider"] : null);
        final eventDate = formatEventDateRange(
          eventStartDate: event["event_start_date"],
          eventEndDate: event["event_end_date"],
          legacyEventDate: event["event_date"],
        );
        final schedule = categoryScheduleLabel(
          category,
          eventStartDate: event["event_start_date"],
          eventEndDate: event["event_end_date"],
          legacyEventDate: event["event_date"],
          eventStartTime: event["start_time"],
          eventEndTime: event["end_time"],
        );
        final segments = categorySegmentDistanceLabel(
          category,
          eventType:
              event["interest_type"] ?? event["event_type"] ?? event["type"],
          eventTypeDetails: event["type_details"],
          eventTypeDetailItems:
              event["type_detail_items"] ?? event["detail_items"],
        );
        final readiness = registrationReadiness(registration);
        final categoryNotes = categoryQualificationNotes(category);
        final qualificationNotes = categoryNotes.isNotEmpty
            ? categoryNotes
            : readinessText(readiness, const ["qualification_notes"]);
        final eventType =
            event["interest_type"] ?? event["event_type"] ?? event["type"];
        final categoryGear = categoryGearLabel(
          category,
          eventType: eventType,
          eventTypeDetails: event["type_details"],
          eventTypeDetailItems:
              event["type_detail_items"] ?? event["detail_items"],
        );
        final gear = categoryGear.isNotEmpty
            ? categoryGear
            : readinessText(readiness, const [
                "required_gear",
                "mandatory_gear",
                "gear",
              ]);
        final displayStatus = readiness == null
            ? status
            : readinessRegistrationStatus(readiness, status);
        final checkpointMapUrl = categoryCheckpointMapUrl(category);
        final showFeedback = shouldShowFeedbackPrompt(registration);
        final canSubmitPayment =
            paymentRequired &&
            status == "pending" &&
            ![
              "paid",
              "waived",
              "submitted",
              "expired",
            ].contains(paymentStatus.toLowerCase());

        return _ActivityCard(
          icon: Icons.app_registration_outlined,
          title: title,
          subtitle: [
            if ((category["name"] ?? "").toString().isNotEmpty)
              category["name"].toString(),
            if (eventDate.isNotEmpty) eventDate,
          ].join(" - "),
          chips: [
            _ActivityChip(
              label: "Status: $displayStatus",
              color: _registrationStatusColor(displayStatus),
            ),
            if ((registration["bib_number"] ?? "").toString().isNotEmpty)
              _ActivityChip(label: "BIB: ${registration["bib_number"]}"),
            if (schedule.isNotEmpty) _ActivityChip(label: schedule),
            if (segments.isNotEmpty) _ActivityChip(label: segments),
            if (paymentRequired)
              _ActivityChip(
                label: "Payment: ${paymentStatusLabel(paymentStatus)}",
                color: _paymentStatusColor(paymentStatus),
              ),
            if (paymentRequired &&
                paymentProviderKey(paymentProvider).isNotEmpty)
              _ActivityChip(
                label: "Method: ${paymentProviderLabel(paymentProvider)}",
              ),
          ],
          action: canSubmitPayment || showFeedback
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canSubmitPayment)
                      FilledButton.icon(
                        onPressed: () => onSubmitPayment(registration),
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text("Complete Payment"),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    if (showFeedback)
                      OutlinedButton.icon(
                        onPressed: () => onFeedback(registration),
                        icon: const Icon(Icons.star_outline_rounded, size: 18),
                        label: Text(_feedbackActionLabel(registration)),
                      ),
                  ],
                )
              : null,
          onTap: () => _showActivityDetailsSheet(
            context: context,
            icon: Icons.app_registration_outlined,
            title: title,
            label: "Registration Details",
            details: [
              _ActivityDetailItem(
                icon: Icons.flag_outlined,
                label: "Category",
                value: (category["name"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.calendar_month_outlined,
                label: "Event Dates",
                value: eventDate,
              ),
              _ActivityDetailItem(
                icon: Icons.schedule_outlined,
                label: "Category Schedule",
                value: schedule,
              ),
              if (segments.isNotEmpty)
                _ActivityDetailItem(
                  icon: Icons.route_outlined,
                  label: "Segment Distances",
                  value: segments,
                ),
              if (qualificationNotes.isNotEmpty)
                _ActivityDetailItem(
                  icon: Icons.fact_check_outlined,
                  label: "Qualification Notes",
                  value: qualificationNotes,
                ),
              if (gear.isNotEmpty)
                _ActivityDetailItem(
                  icon: Icons.backpack_outlined,
                  label: "Required Gear",
                  value: gear.replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
                ),
              _ActivityDetailItem(
                icon: Icons.verified_outlined,
                label: "Status",
                value: displayStatus,
              ),
              _ActivityDetailItem(
                icon: Icons.confirmation_number_outlined,
                label: "BIB Number",
                value: (registration["bib_number"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.checkroom_outlined,
                label: "Shirt Size",
                value: (registration["shirt_size"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.medical_information_outlined,
                label: "Medical Conditions",
                value: (registration["medical_conditions"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.payments_outlined,
                label: "Payment",
                value: paymentRequired
                    ? "${registration["payment_currency"] ?? "PHP"} ${registration["payment_amount"] ?? "0.00"} - ${paymentStatusLabel(paymentStatus)}"
                    : "Not required",
              ),
              if (paymentRequired &&
                  paymentProviderKey(paymentProvider).isNotEmpty)
                _ActivityDetailItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: "Payment Method",
                  value: paymentProviderLabel(paymentProvider),
                ),
            ],
            additionalContent:
                readiness == null && checkpointMapUrl.isEmpty && !showFeedback
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (readiness != null)
                        _RegistrationReadinessPanel(
                          readiness: readiness,
                          status: displayStatus,
                          onAction: (action) {
                            final normalized = action.trim().toLowerCase();
                            if (normalized == "complete_payment") {
                              Navigator.pop(context);
                              onSubmitPayment(registration);
                            } else if (normalized == "view_results" ||
                                normalized == "view_result") {
                              Navigator.pop(context);
                              DefaultTabController.of(context).animateTo(1);
                            }
                          },
                        ),
                      if (readiness != null && checkpointMapUrl.isNotEmpty)
                        const SizedBox(height: 14),
                      if (checkpointMapUrl.isNotEmpty)
                        CategoryCheckpointMap(imageUrl: checkpointMapUrl),
                      if ((readiness != null || checkpointMapUrl.isNotEmpty) &&
                          showFeedback)
                        const SizedBox(height: 14),
                      if (showFeedback)
                        _FeedbackPromptCard(
                          registration: registration,
                          onOpen: () => onFeedback(registration),
                        ),
                    ],
                  ),
            action: readiness == null && canSubmitPayment
                ? Builder(
                    builder: (sheetContext) {
                      return FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          onSubmitPayment(registration);
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text("Complete Payment"),
                      );
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _FeedbackPromptCard extends StatelessWidget {
  final Map<String, dynamic> registration;
  final VoidCallback onOpen;

  const _FeedbackPromptCard({required this.registration, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final feedback = registrationFeedback(registration);
    final canEdit = feedbackCanEdit(
      feedback,
      canSubmitFeedback: registrationCanSubmitFeedback(registration),
    );
    final deadline = feedbackEditableUntil(feedback);
    final buttonLabel = feedback == null
        ? "Rate This Event"
        : canEdit
        ? "Edit Feedback"
        : "View Feedback";

    return Container(
      key: const Key("feedback-prompt"),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Rate This Event",
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            feedback == null
                ? "Your official result is available. Share your event experience."
                : canEdit
                ? "Your feedback was submitted and can still be updated."
                : "Your submitted feedback is now read-only.",
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (deadline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Editable until: $deadline",
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

String _feedbackActionLabel(Map<String, dynamic> registration) {
  final feedback = registrationFeedback(registration);
  if (feedback == null) return "Rate This Event";
  return feedbackCanEdit(
        feedback,
        canSubmitFeedback: registrationCanSubmitFeedback(registration),
      )
      ? "Edit Feedback"
      : "View Feedback";
}

String paymentStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case "unpaid":
      return "Payment Required";
    case "submitted":
      return "Under Review";
    case "pending":
      return "Pending";
    case "paid":
      return "Paid";
    case "waived":
      return "Free";
    case "failed":
      return "Needs Resubmission";
    case "expired":
      return "Expired";
    case "refunded":
      return "Refunded";
    case "cancelled":
    case "canceled":
      return "Cancelled";
    default:
      return status.isEmpty ? "Not Required" : status;
  }
}

Color _paymentStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case "paid":
    case "waived":
      return const Color(0xFF16A34A);
    case "submitted":
    case "pending":
      return const Color(0xFF2563EB);
    case "failed":
    case "expired":
      return const Color(0xFFDC2626);
    case "unpaid":
      return const Color(0xFFF97316);
    default:
      return const Color(0xFF64748B);
  }
}

Color _registrationStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case "approved":
    case "registered":
    case "checked_in":
      return const Color(0xFF16A34A);
    case "completed":
      return const Color(0xFF0F766E);
    case "rejected":
    case "cancelled":
    case "canceled":
      return const Color(0xFFDC2626);
    case "pending":
      return const Color(0xFFF97316);
    default:
      return const Color(0xFF2563EB);
  }
}

class _ResultList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Map<String, dynamic> Function(Map<String, dynamic>, String) nestedMap;
  final Map<String, dynamic> Function(Map<String, dynamic>)
  feedbackRegistrationForResult;
  final ValueChanged<Map<String, dynamic>> onFeedback;

  const _ResultList({
    required this.results,
    required this.nestedMap,
    required this.feedbackRegistrationForResult,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const _EmptyActivityState(
        icon: Icons.emoji_events_outlined,
        title: "No results yet",
        message: "Your race results and rankings will appear here.",
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final event = nestedMap(result, "event");
        final category = nestedMap(result, "category");
        final title = (event["title"] ?? "Event").toString();
        final registration = feedbackRegistrationForResult(result);
        final showFeedback = shouldShowFeedbackPrompt(registration);

        return _ActivityCard(
          icon: Icons.emoji_events_outlined,
          title: title,
          subtitle: [
            if ((category["name"] ?? "").toString().isNotEmpty)
              category["name"].toString(),
            if ((result["finish_time"] ?? "").toString().isNotEmpty)
              "Finish: ${result["finish_time"]}",
          ].join(" - "),
          chips: [
            if ((result["rank_overall"] ?? "").toString().isNotEmpty)
              _ActivityChip(label: "Overall: ${result["rank_overall"]}"),
            if ((result["rank_category"] ?? "").toString().isNotEmpty)
              _ActivityChip(label: "Category: ${result["rank_category"]}"),
            if ((result["remarks"] ?? "").toString().isNotEmpty)
              _ActivityChip(label: result["remarks"].toString()),
          ],
          action: showFeedback
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => onFeedback(registration),
                    icon: const Icon(Icons.star_outline_rounded, size: 18),
                    label: Text(_feedbackActionLabel(registration)),
                  ),
                )
              : null,
          onTap: () => _showActivityDetailsSheet(
            context: context,
            icon: Icons.emoji_events_outlined,
            title: title,
            label: "Result Details",
            details: [
              _ActivityDetailItem(
                icon: Icons.flag_outlined,
                label: "Category",
                value: (category["name"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.timer_outlined,
                label: "Finish Time",
                value: (result["finish_time"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.leaderboard_outlined,
                label: "Overall Rank",
                value: (result["rank_overall"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.workspace_premium_outlined,
                label: "Category Rank",
                value: (result["rank_category"] ?? "").toString(),
              ),
              _ActivityDetailItem(
                icon: Icons.notes_outlined,
                label: "Remarks",
                value: (result["remarks"] ?? "").toString(),
              ),
            ],
            additionalContent: showFeedback
                ? _FeedbackPromptCard(
                    registration: registration,
                    onOpen: () => onFeedback(registration),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<_ActivityChip> chips;
  final Widget? action;
  final VoidCallback? onTap;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chips,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        shadowColor: Colors.black.withValues(alpha: 0.05),
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          height: 1.15,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: chips.map(_ActivityChipView.new).toList(),
                        ),
                      ],
                      if (action != null) ...[
                        const SizedBox(height: 12),
                        action!,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityChip {
  final String label;
  final Color color;

  const _ActivityChip({
    required this.label,
    this.color = const Color(0xFF2563EB),
  });
}

class _ActivityChipView extends StatelessWidget {
  final _ActivityChip chip;

  const _ActivityChipView(this.chip);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chip.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chip.color.withValues(alpha: 0.14)),
      ),
      child: Text(
        chip.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: chip.color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

void _showActivityDetailsSheet({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String label,
  required List<_ActivityDetailItem> details,
  Widget? additionalContent,
  Widget? action,
}) {
  final visibleDetails = details
      .where((detail) => detail.value.trim().isNotEmpty)
      .toList(growable: false);

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => _ActivityDetailsSheet(
      icon: icon,
      title: title,
      label: label,
      details: visibleDetails,
      additionalContent: additionalContent,
      action: action,
    ),
  );
}

class _ActivityDetailsSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String label;
  final List<_ActivityDetailItem> details;
  final Widget? additionalContent;
  final Widget? action;

  const _ActivityDetailsSheet({
    required this.icon,
    required this.title,
    required this.label,
    required this.details,
    this.additionalContent,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            icon,
                            color: const Color(0xFF2563EB),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (additionalContent != null) ...[
                      additionalContent!,
                      const SizedBox(height: 14),
                    ],
                    if (details.isEmpty)
                      const _ActivityDetailEmpty()
                    else
                      ...details.map(_ActivityDetailRow.new),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child:
                  action ??
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationReadinessPanel extends StatelessWidget {
  final Map<String, dynamic> readiness;
  final String status;
  final ValueChanged<String> onAction;

  const _RegistrationReadinessPanel({
    required this.readiness,
    required this.status,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final nextStep = readinessNextStep(readiness);
    final checklist = readinessChecklist(readiness);
    final certificate = readinessCertificate(readiness);
    final action = (nextStep["action"] ?? "").trim().toLowerCase();
    final supportsAction = const {
      "complete_payment",
      "view_results",
      "view_result",
    }.contains(action);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _registrationStatusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: _registrationStatusColor(status),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Current status: $status",
                  style: TextStyle(
                    color: _registrationStatusColor(status),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (nextStep.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NEXT STEP",
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextStep["title"] ?? "Next Step",
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((nextStep["message"] ?? "").isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    nextStep["message"]!,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
                if (supportsAction) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => onAction(action),
                    icon: Icon(
                      action == "complete_payment"
                          ? Icons.payments_outlined
                          : Icons.emoji_events_outlined,
                      size: 18,
                    ),
                    label: Text(nextStep["action_label"] ?? "Continue"),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (checklist.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "Progress Checklist",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < checklist.length; index++) ...[
                  _ReadinessChecklistRow(item: checklist[index]),
                  if (index != checklist.length - 1)
                    const Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: Color(0xFFE2E8F0),
                    ),
                ],
              ],
            ),
          ),
        ],
        if (certificate != null) ...[
          const SizedBox(height: 16),
          RegistrationCertificateCard(
            certificate: certificate,
            onOpenUrl: (url) => _openCertificateUrl(context, url),
          ),
        ],
      ],
    );
  }
}

Future<void> _openCertificateUrl(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Certificate link is unavailable.')),
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || opened) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Unable to open the certificate link.')),
  );
}

class _ReadinessChecklistRow extends StatelessWidget {
  final Map<String, String> item;

  const _ReadinessChecklistRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = (item["status"] ?? "pending").toLowerCase();
    final isComplete = const {
      "complete",
      "completed",
      "done",
      "ready",
      "passed",
    }.contains(status);
    final isSkipped = const {
      "not_required",
      "not_applicable",
      "skipped",
      "waived",
    }.contains(status);
    final isBlocked = const {
      "blocked",
      "failed",
      "rejected",
      "action_required",
    }.contains(status);
    final color = isComplete
        ? const Color(0xFF16A34A)
        : isBlocked
        ? const Color(0xFFDC2626)
        : isSkipped
        ? const Color(0xFF64748B)
        : const Color(0xFFF59E0B);
    final icon = isComplete
        ? Icons.check_circle_rounded
        : isBlocked
        ? Icons.error_outline_rounded
        : isSkipped
        ? Icons.remove_circle_outline
        : Icons.schedule_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["label"] ?? "Progress item",
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((item["message"] ?? "").isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item["message"]!,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDetailItem {
  final IconData icon;
  final String label;
  final String value;

  const _ActivityDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ActivityDetailRow extends StatelessWidget {
  final _ActivityDetailItem detail;

  const _ActivityDetailRow(this.detail);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(detail.icon, color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail.value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDetailEmpty extends StatelessWidget {
  const _ActivityDetailEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        "No additional details are available yet.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActivityPaymentProofSheet extends StatefulWidget {
  final Map<String, dynamic> registration;

  const _ActivityPaymentProofSheet({required this.registration});

  @override
  State<_ActivityPaymentProofSheet> createState() =>
      _ActivityPaymentProofSheetState();
}

class _ActivityPaymentProofSheetState
    extends State<_ActivityPaymentProofSheet> {
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final picker = ImagePicker();
  XFile? proofImage;
  bool isSubmitting = false;
  String? selectedPaymentProvider;

  @override
  void initState() {
    super.initState();
    final preferred =
        widget.registration["payment_provider"] ??
        widget.registration["provider"];
    final option = paymentOptionByProvider(paymentOptions, preferred);
    selectedPaymentProvider = option?["provider"]?.toString();
  }

  @override
  void dispose() {
    referenceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get category {
    final value = widget.registration["category"];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  Map<String, dynamic> get event {
    final value = widget.registration["event"];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<Map<String, dynamic>> get paymentOptions => enabledPaymentOptions(
    registration: widget.registration,
    category: category,
    event: event,
  );

  Map<String, dynamic>? get selectedPaymentOption =>
      paymentOptionByProvider(paymentOptions, selectedPaymentProvider);

  String get amount {
    final currency = (widget.registration["payment_currency"] ?? "PHP")
        .toString();
    final amount = (widget.registration["payment_amount"] ?? "").toString();
    if (amount.isNotEmpty) return "$currency $amount";

    final cents =
        int.tryParse(
          (widget.registration["payment_amount_cents"] ?? 0).toString(),
        ) ??
        0;
    return "$currency ${(cents / 100).toStringAsFixed(2)}";
  }

  Future<void> pickProof() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => proofImage = picked);
  }

  Future<void> submit() async {
    final registrationId = int.tryParse(
      (widget.registration["id"] ?? "").toString(),
    );

    if (registrationId == null) {
      showMessage("Registration payment details are missing.");
      return;
    }

    if (referenceController.text.trim().isEmpty && proofImage == null) {
      showMessage("Add a payment reference or upload proof of payment.");
      return;
    }

    setState(() => isSubmitting = true);

    final result = await ApiService().submitPaymentProof(
      registrationId: registrationId,
      provider: (selectedPaymentOption?["provider"] ?? "manual").toString(),
      providerReference: referenceController.text,
      notes: notesController.text,
      proofImagePath: proofImage?.path,
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    showMessage(result.message);
    Navigator.pop(context, true);
  }

  Future<void> startPayMongoCheckout() async {
    final registrationId = int.tryParse(
      (widget.registration["id"] ?? "").toString(),
    );

    if (registrationId == null) {
      showMessage("Registration payment details are missing.");
      return;
    }

    setState(() => isSubmitting = true);

    final result = await ApiService().createPayMongoCheckout(
      registrationId: registrationId,
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    final checkoutUrl = (result.data?["checkout_url"] ?? "").toString();
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null || checkoutUrl.isEmpty) {
      showMessage("Online checkout link is missing. Please try again.");
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;

    if (!opened) {
      showMessage("Unable to open PayMongo checkout.");
      return;
    }

    showMessage("Complete your payment in PayMongo, then return to the app.");
    Navigator.pop(context, true);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.86;
    final provider = paymentProviderLabel(selectedPaymentOption?["provider"]);
    final accountName = (selectedPaymentOption?["account_name"] ?? "")
        .toString();
    final accountNumber = (selectedPaymentOption?["account_number"] ?? "")
        .toString();
    final instructionText = (selectedPaymentOption?["instructions"] ?? "")
        .toString();
    final isPayMongo = isPayMongoOption(selectedPaymentOption);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isPayMongo ? "Pay Online" : "Submit Payment Proof",
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (paymentOptions.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedPaymentOption?["provider"]
                        ?.toString(),
                    decoration: const InputDecoration(
                      labelText: "Payment method",
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: paymentOptions.map((option) {
                      final value = option["provider"].toString();
                      return DropdownMenuItem(
                        value: value,
                        child: Text(paymentProviderLabel(value)),
                      );
                    }).toList(),
                    onChanged: isSubmitting
                        ? null
                        : (provider) {
                            setState(() {
                              selectedPaymentProvider = provider;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PaymentLine(label: "Amount", value: amount),
                      _PaymentLine(label: "Method", value: provider),
                      if (accountName.isNotEmpty)
                        _PaymentLine(label: "Account", value: accountName),
                      if (accountNumber.isNotEmpty)
                        _PaymentLine(label: "Number", value: accountNumber),
                      if (instructionText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          instructionText,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPayMongo) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: isSubmitting ? null : startPayMongoCheckout,
                    icon: const Icon(Icons.credit_card_outlined),
                    label: const Text("Open PayMongo Checkout"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: "Payment reference",
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSubmitting ? null : pickProof,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      proofImage == null
                          ? "Upload proof image"
                          : proofImage!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Notes (optional)",
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (!isPayMongo) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isSubmitting ? null : submit,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      isSubmitting ? "Submitting..." : "Submit Proof",
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentLine extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: 4,
      itemBuilder: (context, index) => const _ActivitySkeletonCard(),
    );
  }
}

class _ActivitySkeletonCard extends StatelessWidget {
  const _ActivitySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SkeletonBlock(height: 48, width: 48, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBlock(height: 15, width: double.infinity, radius: 8),
                SizedBox(height: 9),
                _SkeletonBlock(height: 12, width: 170, radius: 8),
                SizedBox(height: 14),
                Row(
                  children: [
                    _SkeletonBlock(height: 26, width: 86, radius: 999),
                    SizedBox(width: 8),
                    _SkeletonBlock(height: 26, width: 62, radius: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const _SkeletonBlock({
    required this.height,
    required this.width,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyActivityState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 54, color: const Color(0xFF2563EB)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
