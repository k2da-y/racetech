import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/registration_group.dart';
import '../widgets/registration_group_page.dart';
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

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile pages)
// ============================================================

const Color _primary = Color(0xFF6366F1); // indigo-500
const Color _primaryDeep = Color(0xFF4F46E5); // indigo-600
const Color _accent = Color(0xFF0EA5E9); // sky-500
const Color _primarySoft = Color(0xFFEEF2FF); // indigo-50
const Color _primaryBorder = Color(0xFFC7D2FE); // indigo-200
const Color _ink = Color(0xFF1E293B);
const Color _body = Color(0xFF475569);
const Color _muted = Color(0xFF64748B);
const Color _faint = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);
const Color _background = Color(0xFFF5F7FB);
const Color _fieldFill = Color(0xFFF8FAFC);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

const OutlineInputBorder _roundedField = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
);

/// Keeps buttons, inputs and focus colors in sheets on the indigo palette,
/// whatever the app-wide theme is.
ThemeData _brandTheme(BuildContext context) {
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _primary,
      onPrimary: Colors.white,
      secondaryContainer: _primarySoft,
      onSecondaryContainer: _primaryDeep,
      surfaceTint: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _primary),
    ),
  );
}

/// "checked_in" → "Checked In", "pending" → "Pending".
String _prettyStatus(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r"[_\-]+"), " ");
  if (cleaned.isEmpty) return "Pending";
  return cleaned
      .split(" ")
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(" ");
}

class MyActivityPage extends StatefulWidget {
  const MyActivityPage({super.key});

  @override
  State<MyActivityPage> createState() => _MyActivityPageState();
}

class _MyActivityPageState extends State<MyActivityPage>
    with WidgetsBindingObserver {
  bool isLoading = true;
  List<Map<String, dynamic>> registrations = [];
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from PayMongo / email etc. — refresh quietly.
    if (state == AppLifecycleState.resumed && !isLoading) {
      loadActivity();
    }
  }

  /// Prevents overlapping reloads (e.g. resume + pull-to-refresh at once).
  bool isFetching = false;

  Future<void> loadActivity() async {
    if (isFetching) return;
    isFetching = true;

    try {
      // Same two calls as before, now fetched in parallel.
      final responses = await Future.wait([
        ApiService().getMyRegistrations(),
        ApiService().getMyResults(),
      ]);

      if (!mounted) return;

      setState(() {
        registrations = responses[0];
        results = responses[1];
        isLoading = false;
      });
    } finally {
      isFetching = false;
    }
  }

  Future<void> refreshActivity() async {
    setState(() => isLoading = true);
    await loadActivity();
  }

  Future<void> openPaymentProofSheet(Map<String, dynamic> registration) async {
    final group = registrationGroup(registration);
    if (group != null) {
      final fresh = await ApiService().groupRequest('${group['id']}');
      if (!mounted) return;
      if (!fresh.success || fresh.data?['data'] is! Map) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(fresh.message)));
        return;
      }
      registration = {
        ...registration,
        'registration_group': fresh.data!['data'],
      };
      if (!groupAllowsPayment(registration)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(groupPaymentReason(registration))),
        );
        await loadActivity();
        return;
      }
    }
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Theme(
        data: _brandTheme(sheetContext),
        child: _ActivityPaymentProofSheet(registration: registration),
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Theme(
        data: _brandTheme(sheetContext),
        child: EventFeedbackSheet(
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          body: Column(
            children: [
              _ActivityHero(
                isLoading: isLoading,
                registrationsCount: registrations.length,
                resultsCount: results.length,
                onBack: () => Navigator.pop(context),
                onRefresh: isLoading ? null : refreshActivity,
              ),

              // Tab bar sits half over the bottom edge of the hero.
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _softShadow,
                        ),
                        child: TabBar(
                          indicator: const BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: _body,
                          splashBorderRadius: BorderRadius.circular(14),
                          labelStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                          tabs: [
                            Tab(
                              child: _TabLabel(
                                label: "Registrations",
                                count: isLoading ? null : registrations.length,
                              ),
                            ),
                            Tab(
                              child: _TabLabel(
                                label: "Results",
                                count: isLoading ? null : results.length,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 632),
                      child: isLoading
                          ? const _LoadingState()
                          : TabBarView(
                        children: [
                          RefreshIndicator(
                            color: _primary,
                            onRefresh: refreshActivity,
                            child: _RegistrationList(
                              registrations: registrations,
                              nestedMap: nestedMap,
                              formatDate: formatDate,
                              onSubmitPayment: openPaymentProofSheet,
                              onGroupChanged: loadActivity,
                              onFeedback: openFeedbackSheet,
                            ),
                          ),
                          RefreshIndicator(
                            color: _primary,
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO HEADER
// ============================================================

class _ActivityHero extends StatelessWidget {
  final bool isLoading;
  final int registrationsCount;
  final int resultsCount;
  final VoidCallback onBack;
  final Future<void> Function()? onRefresh;

  const _ActivityHero({
    required this.isLoading,
    required this.registrationsCount,
    required this.resultsCount,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDeep, _primary, _accent],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: "Back",
                    onTap: onBack,
                  ),
                  const Expanded(
                    child: Text(
                      "My Activity",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _GlassButton(
                    icon: Icons.refresh_rounded,
                    tooltip: "Refresh",
                    onTap: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                "Track your registrations, payments and race results.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.app_registration_rounded,
                      label: "Registrations",
                      value: registrationsCount,
                      isLoading: isLoading,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.emoji_events_outlined,
                      label: "Results",
                      value: resultsCount,
                      isLoading: isLoading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool isLoading;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isLoading
                    ? Container(
                  height: 20,
                  width: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
                    : Text(
                  "$value",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int? count;

  const _TabLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? _body;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RegistrationList extends StatelessWidget {
  final List<Map<String, dynamic>> registrations;
  final Map<String, dynamic> Function(Map<String, dynamic>, String) nestedMap;
  final String Function(String) formatDate;
  final ValueChanged<Map<String, dynamic>> onSubmitPayment;
  final Future<void> Function() onGroupChanged;
  final ValueChanged<Map<String, dynamic>> onFeedback;

  const _RegistrationList({
    required this.registrations,
    required this.nestedMap,
    required this.formatDate,
    required this.onSubmitPayment,
    required this.onGroupChanged,
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
            groupAllowsPayment(registration) &&
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
              label: _prettyStatus(displayStatus),
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
          action:
          canSubmitPayment ||
              showFeedback ||
              registrationGroup(registration) != null
              ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (registrationGroup(registration) != null) ...[
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RegistrationGroupPage(
                        groupId:
                        '${registrationGroup(registration)!['id']}',
                        onChanged: onGroupChanged,
                      ),
                    ),
                  ),
                  child: const Text('Group Details'),
                ),
                if (!groupAllowsPayment(registration))
                  _InlineNote(text: groupPaymentReason(registration)),
              ],
              if (canSubmitPayment)
                FilledButton.icon(
                  onPressed: () => onSubmitPayment(registration),
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text("Complete Payment"),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
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
                value: _prettyStatus(displayStatus),
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
                    paymentAllowed: groupAllowsPayment(registration),
                    paymentBlockedReason: groupPaymentReason(
                      registration,
                    ),
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
                    color: _ink,
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
              color: _body,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (deadline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Editable until: $deadline",
              style: const TextStyle(
                color: _muted,
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
      return _primary;
    case "failed":
    case "expired":
      return const Color(0xFFDC2626);
    case "unpaid":
      return const Color(0xFFF97316);
    default:
      return _muted;
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
      return _primary;
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: _softShadow,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: _primary, size: 24),
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
                            color: _ink,
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
                              color: _muted,
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
                    color: _faint,
                  ),
                ],
              ),
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
    this.color = _primary,
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
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Theme(
      data: _brandTheme(sheetContext),
      child: _ActivityDetailsSheet(
        icon: icon,
        title: title,
        label: label,
        details: visibleDetails,
        additionalContent: additionalContent,
        action: action,
      ),
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
                            color: _primarySoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            icon,
                            color: _primary,
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
                                  color: _primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: _ink,
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
                      backgroundColor: _primary,
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
  final bool paymentAllowed;
  final String paymentBlockedReason;
  final Map<String, dynamic> readiness;
  final String status;
  final ValueChanged<String> onAction;

  const _RegistrationReadinessPanel({
    this.paymentAllowed = true,
    this.paymentBlockedReason = '',
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
                  "Current status: ${_prettyStatus(status)}",
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
              color: _primarySoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _primaryBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NEXT STEP",
                  style: TextStyle(
                    color: _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextStep["title"] ?? "Next Step",
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((nextStep["message"] ?? "").isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    nextStep["message"]!,
                    style: const TextStyle(
                      color: _body,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
                if (supportsAction) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: action == 'complete_payment' && !paymentAllowed
                        ? null
                        : () => onAction(action),
                    icon: Icon(
                      action == "complete_payment"
                          ? Icons.payments_outlined
                          : Icons.emoji_events_outlined,
                      size: 18,
                    ),
                    label: Text(nextStep["action_label"] ?? "Continue"),
                  ),
                  if (action == 'complete_payment' && !paymentAllowed) ...[
                    const SizedBox(height: 8),
                    _InlineNote(text: paymentBlockedReason),
                  ],
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
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
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
        ? _muted
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
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((item["message"] ?? "").isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item["message"]!,
                    style: const TextStyle(
                      color: _muted,
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
        color: _fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(detail.icon, color: _primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail.value,
                  style: const TextStyle(
                    color: _ink,
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
        color: _fieldFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Text(
        "No additional details are available yet.",
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
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
    if (!await checkGroupPayment(context, widget.registration) || !mounted) {
      return;
    }
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
    if (!await checkGroupPayment(context, widget.registration) || !mounted) {
      return;
    }
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
                    color: _ink,
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
                      border: _roundedField,
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
                    color: _fieldFill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
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
                            color: _body,
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
                    label: Text(
                      isSubmitting
                          ? "Opening checkout..."
                          : "Open PayMongo Checkout",
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
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
                      border: _roundedField,
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
                      border: _roundedField,
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
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink,
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
    return _Pulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: 4,
        itemBuilder: (context, index) => const _ActivitySkeletonCard(),
      ),
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
        boxShadow: _softShadow,
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
        color: _border,
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
            boxShadow: _softShadow,
          ),
          child: Column(
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, size: 30, color: _primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
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

// ============================================================
// SMALL SHARED PIECES
// ============================================================

class _InlineNote extends StatelessWidget {
  final String text;

  const _InlineNote({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gentle fade pulse for loading skeletons.
class _Pulse extends StatefulWidget {
  final Widget child;

  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(opacity: opacity, child: widget.child);
  }
}