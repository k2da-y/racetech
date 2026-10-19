import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/health_conditions_selector.dart';
import '../utils/health_profile.dart';
import '../widgets/health_profile_section.dart';
import '../utils/participant_birthdate.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _success = Color(0xFF16A34A);
const _successSoft = Color(0xFFDCFCE7);
const _error = Color(0xFFE11D48);
const _warning = Color(0xFFB45309);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

// ============================================================
// PROFILE SETTINGS PAGE
// ============================================================

class ProfileSettingsPage extends StatefulWidget {
  final ApiService? apiService;
  const ProfileSettingsPage({super.key, this.apiService});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage>
    with WidgetsBindingObserver {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final birthdateController = TextEditingController();
  final addressController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyNumberController = TextEditingController();
  final medicalConditionsController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  HealthProfile healthProfile = const HealthProfile();
  String savedMeasurements = '';
  String savedPersonalSnapshot = '';
  Map<String, String> healthErrors = {};
  Map<String, dynamic> profileUser = {};
  bool profileLoadedFromCache = false;
  bool healthUpdateQueued = false;
  bool healthUpdateConflict = false;
  ApiService get api => widget.apiService ?? ApiService();
  HealthMeasurements get measurements =>
      HealthMeasurements(heightController.text, weightController.text);
  String get measurementSnapshot =>
      [heightController.text, weightController.text].join('\u0000');

  String? selectedGender;

  String avatarUrl = "";
  File? selectedAvatar;

  bool isLoading = true;
  bool isSaving = false;

  /// Missing fields are only highlighted after the first Save attempt.
  bool showValidationErrors = false;

  /// Form values right after loading — used to detect unsaved edits.
  String savedSnapshot = "";

  final imagePicker = ImagePicker();

  final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ];

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    for (final controller in [
      nameController,
      phoneController,
      birthdateController,
      addressController,
      emergencyNameController,
      emergencyNumberController,
      medicalConditionsController,
      heightController,
      weightController,
    ]) {
      controller.addListener(onFormChanged);
    }

    loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nameController.dispose();
    phoneController.dispose();
    birthdateController.dispose();
    addressController.dispose();
    emergencyNameController.dispose();
    emergencyNumberController.dispose();
    medicalConditionsController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !hasUnsavedChanges) {
      api.startHealthProfileSync();
      loadProfile(showFailure: false);
    }
  }

  void onFormChanged() {
    if (mounted) setState(() {});
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> loadProfile({bool showFailure = true}) async {
    final session = await api.fetchUser();
    final user = session.user;

    if (!mounted) return;

    if (user == null) {
      setState(() => isLoading = false);
      if (showFailure) {
        showMessage('Unable to refresh your profile. Please try again.');
      }
      return;
    }
    profileUser = user;
    profileLoadedFromCache = session.isCached;
    healthProfile = HealthProfile.fromUser(user);
    heightController.text = healthProfile.height?.toString() ?? '';
    weightController.text = healthProfile.weight?.toString() ?? '';
    nameController.text = (user["name"] ?? "").toString();
    phoneController.text = (user["phone"] ?? "").toString();
    selectedGender = normalizeGender((user["gender"] ?? "").toString());
    birthdateController.text = (user["birthdate"] ?? "").toString();
    addressController.text = (user["address"] ?? "").toString();
    emergencyNameController.text = (user["emergency_contact_name"] ?? "")
        .toString();
    emergencyNumberController.text = (user["emergency_contact_number"] ?? "")
        .toString();
    medicalConditionsController.text = (user["medical_conditions"] ?? "")
        .toString();
    avatarUrl = (user["avatar_url"] ?? "").toString();

    final pending = await api.pendingHealthUpdate();
    if (!mounted) return;
    healthUpdateQueued = pending != null && !pending.conflict;
    healthUpdateConflict = pending?.conflict == true;
    if (pending != null && !pending.conflict) {
      heightController.text = pending.heightCm?.toString() ?? '';
      weightController.text = pending.weightKg?.toString() ?? '';
      healthProfile = HealthProfile.offlinePreview(
        user,
        measurements,
        measuredAt: pending.capturedOn,
      );
    }

    selectedAvatar = null;

    setState(() {
      isLoading = false;
      showValidationErrors = false;
      savedSnapshot = formSnapshot();
      savedMeasurements = measurementSnapshot;
      savedPersonalSnapshot = formSnapshot(includeMeasurements: false);
      healthErrors = {};
    });
  }

  Future<void> refreshProfile() async {
    if (isLoading || isSaving) return;
    if (hasUnsavedChanges && !await confirmDiscardChanges()) return;
    if (!mounted) return;

    setState(() => isLoading = true);
    await loadProfile();
  }

  // ============================================================
  // UNSAVED CHANGES
  // ============================================================

  String formSnapshot({bool includeMeasurements = true}) {
    return [
      nameController.text,
      phoneController.text,
      selectedGender ?? "",
      birthdateController.text,
      addressController.text,
      emergencyNameController.text,
      emergencyNumberController.text,
      medicalConditionsController.text,
      if (includeMeasurements) measurementSnapshot,
      selectedAvatar?.path ?? "",
    ].map((value) => value.trim()).join("\u0000");
  }

  bool get hasUnsavedChanges => !isLoading && formSnapshot() != savedSnapshot;

  Future<bool> confirmDiscardChanges() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const _IconTile(
          icon: Icons.edit_note_rounded,
          size: 60,
          iconSize: 30,
        ),
        title: const Text(
          "Discard changes?",
          style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
        ),
        content: const Text(
          "You have unsaved edits to your profile. They will be lost if you leave now.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _muted),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Discard"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep editing"),
          ),
        ],
      ),
    );

    return discard == true;
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Future<void> pickAvatar() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 900,
    );

    if (picked == null || !mounted) return;

    setState(() => selectedAvatar = File(picked.path));
  }

  // ============================================================
  // GENDER
  // ============================================================

  String? normalizeGender(String value) {
    return switch (value.trim().toLowerCase()) {
      "male" => "Male",
      "female" => "Female",
      "other" => "Other",
      _ => null,
    };
  }

  // ============================================================
  // BIRTHDATE
  // ============================================================

  Future<void> pickBirthdate() async {
    FocusScope.of(context).unfocus();

    final limits = birthdateLimits();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialParticipantBirthdate(birthdateController.text),
      firstDate: limits.first,
      lastDate: limits.last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            onSurface: _ink,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      birthdateController.text = formatParticipantBirthdate(picked);
    });
  }

  String? get birthdateHelper {
    final parsed = DateTime.tryParse(birthdateController.text);
    if (parsed == null) return null;

    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final now = DateTime.now();
    var age = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }

    return "${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · $age years old";
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool get nameValid => nameController.text.trim().isNotEmpty;
  bool get phoneValid => phoneController.text.trim().length == 11;
  bool get genderValid => (selectedGender ?? "").isNotEmpty;
  bool get birthdateValid =>
      validateParticipantBirthdate(birthdateController.text) == null;
  bool get addressValid => addressController.text.trim().isNotEmpty;
  bool get emergencyNameValid => emergencyNameController.text.trim().isNotEmpty;
  bool get emergencyNumberValid =>
      emergencyNumberController.text.trim().length == 11;

  List<bool> get personalChecks => [nameValid, genderValid, birthdateValid];
  List<bool> get contactChecks => [phoneValid, addressValid];
  List<bool> get emergencyChecks => [emergencyNameValid, emergencyNumberValid];

  int get completedCount => [
    ...personalChecks,
    ...contactChecks,
    ...emergencyChecks,
  ].where((done) => done).length;

  static const int totalRequired = 7;

  bool get isProfileComplete => completedCount == totalRequired;

  String? errorFor(bool valid, String message) =>
      showValidationErrors && !valid ? message : null;

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> saveProfile() async {
    if (isSaving || isLoading) return;
    FocusScope.of(context).unfocus();
    final changedMeasurements = measurementSnapshot != savedMeasurements;
    final healthOnly =
        changedMeasurements &&
        formSnapshot(includeMeasurements: false) == savedPersonalSnapshot;
    final errors = changedMeasurements
        ? measurements.validate()
        : <String, String>{};
    setState(() => healthErrors = errors);
    if (errors.isNotEmpty) {
      showMessage(errors.values.first);
      return;
    }

    if (!healthOnly && !birthdateValid) {
      setState(() => showValidationErrors = true);
      showMessage(validateParticipantBirthdate(birthdateController.text)!);
      return;
    }

    if (!nameValid ||
        (!healthOnly &&
            (phoneController.text.trim().isEmpty ||
                !genderValid ||
                !birthdateValid ||
                !addressValid ||
                !emergencyNameValid ||
                emergencyNumberController.text.trim().isEmpty))) {
      setState(() => showValidationErrors = true);
      showMessage("Please complete all required fields.");
      return;
    }

    if (!healthOnly && (!phoneValid || !emergencyNumberValid)) {
      setState(() => showValidationErrors = true);
      showMessage("Phone numbers must be 11 digits.");
      return;
    }

    setState(() => isSaving = true);

    ApiActionResult result;
    if (!healthOnly) {
      result = await api.updateProfile(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        gender: selectedGender ?? "",
        birthdate: birthdateController.text.trim(),
        address: addressController.text.trim(),
        emergencyContactName: emergencyNameController.text.trim(),
        emergencyContactNumber: emergencyNumberController.text.trim(),
        medicalConditions: medicalConditionsController.text.trim(),
        avatarPath: selectedAvatar?.path,
      );
      if (result.success && changedMeasurements) {
        result = await api.updateHealthProfile(measurements);
      }
    } else {
      result = await api.updateHealthProfile(measurements);
    }

    if (!mounted) return;

    setState(() => isSaving = false);

    showMessage(result.message);

    if (result.success) {
      if (result.queued) {
        setState(() {
          profileUser = result.user ?? profileUser;
          healthProfile = HealthProfile.offlinePreview(
            profileUser,
            measurements,
            measuredAt: result.capturedOn,
          );
          healthUpdateQueued = true;
          healthUpdateConflict = false;
          profileLoadedFromCache = true;
          savedMeasurements = measurementSnapshot;
          savedSnapshot = formSnapshot();
          savedPersonalSnapshot = formSnapshot(includeMeasurements: false);
        });
        api.startHealthProfileSync();
        return;
      }
      if (!changedMeasurements) {
        savedSnapshot = formSnapshot();
        Navigator.pop(context, true);
        return;
      }
      // Fetch the authoritative BMI instead of calculating a preview locally.
      setState(() => isLoading = true);
      await loadProfile();
    } else if (result.conflict) {
      setState(() {
        healthUpdateQueued = false;
        healthUpdateConflict = true;
      });
      await loadProfile(showFailure: false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final unsaved = hasUnsavedChanges;

    return PopScope(
      canPop: !isSaving && !unsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || isSaving) return;
        if (await confirmDiscardChanges() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          body: RefreshIndicator(
            color: _primary,
            onRefresh: refreshProfile,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHero(
                    isLoading: isLoading,
                    isSaving: isSaving,
                    hasUnsavedChanges: unsaved,
                    name: nameController.text.trim(),
                    avatarUrl: avatarUrl,
                    selectedAvatar: selectedAvatar,
                    completed: completedCount,
                    total: totalRequired,
                    onBack: () => Navigator.maybePop(context),
                    onPickAvatar: isSaving || isLoading ? null : pickAvatar,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: isLoading
                            ? const _LoadingSections()
                            : formSections(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isLoading ? null : saveBar(unsaved),
        ),
      ),
    );
  }

  Widget formSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isProfileComplete) ...[
          _NoticeBanner(
            icon: Icons.event_available_outlined,
            color: _primaryDeep,
            background: _primarySoft,
            message:
                "Complete all required details to join events. "
                "${totalRequired - completedCount} left.",
          ),
          const SizedBox(height: 16),
        ],

        // ---------------- PERSONAL ----------------
        _SectionCard(
          title: "Personal",
          icon: Icons.person_outline_rounded,
          checks: personalChecks,
          children: [
            inputField(
              controller: nameController,
              label: "Full Name",
              icon: Icons.badge_outlined,
              errorText: errorFor(nameValid, "Enter your full name"),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 16),
            _GenderSelector(
              value: selectedGender,
              enabled: !isSaving,
              errorText: errorFor(genderValid, "Select your gender"),
              onChanged: (value) => setState(() => selectedGender = value),
            ),
            const SizedBox(height: 16),
            inputField(
              controller: birthdateController,
              label: "Birthdate",
              icon: Icons.cake_outlined,
              readOnly: true,
              onTap: isSaving ? null : pickBirthdate,
              helperText: birthdateHelper,
              errorText: showValidationErrors
                  ? validateParticipantBirthdate(birthdateController.text)
                  : null,
              suffixIcon: const Icon(
                Icons.edit_calendar_outlined,
                color: _faint,
                size: 20,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ---------------- CONTACT ----------------
        _SectionCard(
          title: "Contact",
          icon: Icons.call_outlined,
          checks: contactChecks,
          children: [
            inputField(
              controller: phoneController,
              label: "Phone Number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneFormatters,
              hintText: "09XXXXXXXXX",
              errorText: errorFor(phoneValid, "Must be 11 digits"),
              counterFor: phoneController,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 16),
            inputField(
              controller: addressController,
              label: "Address",
              icon: Icons.location_on_outlined,
              maxLines: 2,
              errorText: errorFor(addressValid, "Enter your address"),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.fullStreetAddress],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ---------------- EMERGENCY ----------------
        _SectionCard(
          title: "Emergency Contact",
          icon: Icons.contact_emergency_outlined,
          checks: emergencyChecks,
          children: [
            const _NoticeBanner(
              icon: Icons.info_outline_rounded,
              color: _primaryDeep,
              background: _primarySoft,
              message:
                  "Organizers will call this person if something happens during an event.",
            ),
            const SizedBox(height: 16),
            inputField(
              controller: emergencyNameController,
              label: "Contact Name",
              icon: Icons.person_pin_outlined,
              errorText: errorFor(emergencyNameValid, "Enter a contact name"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            inputField(
              controller: emergencyNumberController,
              label: "Contact Number",
              icon: Icons.phone_in_talk_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: phoneFormatters,
              hintText: "09XXXXXXXXX",
              errorText: errorFor(emergencyNumberValid, "Must be 11 digits"),
              counterFor: emergencyNumberController,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ---------------- HEALTH ----------------
        _SectionCard(
          title: "Health Profile",
          subtitle: "Optional",
          icon: Icons.health_and_safety_outlined,
          children: [
            HealthProfileSection(
              profile: healthProfile,
              height: heightController,
              weight: weightController,
              errors: healthErrors,
              enabled: !isSaving,
              hasChanges: measurementSnapshot != savedMeasurements,
              syncMessage: healthUpdateConflict
                  ? 'Sync conflict—newer measurements are saved online. Review them, then edit and save again if needed.'
                  : healthUpdateQueued
                  ? 'Offline—queued for sync. This BMI is a private on-device preview; the server remains authoritative.'
                  : profileLoadedFromCache
                  ? 'Offline—showing the latest securely cached Health Profile.'
                  : '',
              syncWarning: healthUpdateConflict || healthUpdateQueued,
            ),
            const SizedBox(height: 20),
            HealthConditionsSelector(
              controller: medicalConditionsController,
              enabled: !isSaving,
              title: "Health notes",
            ),
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          "Train smarter. Perform better.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _faint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget saveBar(bool unsaved) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A94A3B8),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        key: ValueKey(unsaved),
                        unsaved
                            ? "You have unsaved changes"
                            : "All changes saved",
                        style: TextStyle(
                          color: unsaved ? _warning : _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primary.withValues(
                          alpha: 0.5,
                        ),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSaving ? null : saveProfile,
                      icon: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        isSaving ? "Saving..." : "Save",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FIELDS
  // ============================================================

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hintText,
    String? helperText,
    String? errorText,
    Widget? suffixIcon,
    TextEditingController? counterFor,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
  }) {
    // Live "7/11" counter for phone fields so users see how many digits remain.
    final counter = counterFor == null || counterFor.text.isEmpty
        ? null
        : "${counterFor.text.length}/11";

    return TextField(
      controller: controller,
      enabled: !isSaving,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
      autofillHints: autofillHints,
      cursorColor: _primary,
      style: const TextStyle(
        color: _ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        label: "$label *",
        icon: icon,
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        suffixIcon: suffixIcon,
        counterText: counter,
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  String? hintText,
  String? helperText,
  String? errorText,
  String? counterText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    counterText: counterText,
    hintStyle: const TextStyle(color: _faint, fontWeight: FontWeight.w500),
    helperStyle: const TextStyle(
      color: _primaryDeep,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    ),
    errorStyle: const TextStyle(
      color: _error,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    ),
    counterStyle: const TextStyle(
      color: _faint,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
    labelStyle: const TextStyle(
      color: _muted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
      (states) => TextStyle(
        color: states.contains(WidgetState.error) ? _error : _primary,
        fontWeight: FontWeight.w700,
      ),
    ),
    prefixIcon: Icon(icon, color: _primary, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _fieldFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    enabledBorder: outline(_border),
    disabledBorder: outline(_border),
    focusedBorder: outline(_primary, 1.5),
    errorBorder: outline(_error.withValues(alpha: 0.6)),
    focusedErrorBorder: outline(_error, 1.5),
    border: outline(_border),
  );
}

// ============================================================
// HERO HEADER
// ============================================================

class _ProfileHero extends StatelessWidget {
  final bool isLoading;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final String name;
  final String avatarUrl;
  final File? selectedAvatar;
  final int completed;
  final int total;
  final VoidCallback onBack;
  final VoidCallback? onPickAvatar;

  const _ProfileHero({
    required this.isLoading,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.name,
    required this.avatarUrl,
    required this.selectedAvatar,
    required this.completed,
    required this.total,
    required this.onBack,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final progress = total == 0 ? 0.0 : completed / total;
    final complete = completed == total;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 28),
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
              // ---- Top bar ----
              Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: "Back",
                    onTap: isSaving ? null : onBack,
                  ),
                  const Expanded(
                    child: Text(
                      "Profile Settings",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  // Keeps the title centered; shows "Unsaved" when relevant.
                  SizedBox(
                    width: 44,
                    child: hasUnsavedChanges
                        ? const Tooltip(
                            message: "Unsaved changes",
                            child: Icon(
                              Icons.circle,
                              color: Color(0xFFFCD34D),
                              size: 12,
                            ),
                          )
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ---- Avatar ----
              _HeroAvatar(
                avatarUrl: avatarUrl,
                selectedAvatar: selectedAvatar,
                name: name,
                onTap: onPickAvatar,
              ),

              const SizedBox(height: 14),

              Text(
                isLoading ? "Loading..." : (name.isEmpty ? "Your name" : name),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                selectedAvatar != null
                    ? "New photo selected — save to apply"
                    : "Tap your photo to change it",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              // ---- Completion card ----
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          complete
                              ? Icons.verified_rounded
                              : Icons.assignment_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            complete
                                ? "Profile complete — ready to join events"
                                : "Profile completion",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          isLoading ? "–" : "$completed/$total",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: isLoading ? 0 : progress),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: complete
                              ? const Color(0xFF86EFAC)
                              : Colors.white,
                        ),
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

class _HeroAvatar extends StatelessWidget {
  final String avatarUrl;
  final File? selectedAvatar;
  final String name;
  final VoidCallback? onTap;

  const _HeroAvatar({
    required this.avatarUrl,
    required this.selectedAvatar,
    required this.name,
    required this.onTap,
  });

  Widget initialFallback() {
    final trimmed = name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? "R" : trimmed[0].toUpperCase(),
        style: const TextStyle(
          color: _primary,
          fontSize: 40,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget image() {
    if (selectedAvatar != null) {
      return Image.file(
        selectedAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => initialFallback(),
      );
    }

    if (avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : initialFallback(),
        errorBuilder: (context, error, stackTrace) => initialFallback(),
      );
    }

    return initialFallback();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Change profile photo",
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 112,
              width: 112,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: _primarySoft,
                  child: SizedBox.expand(child: image()),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: _primary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION CARD
// ============================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<bool>? checks;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.checks,
  });

  @override
  Widget build(BuildContext context) {
    final done = checks?.where((value) => value).length ?? 0;
    final total = checks?.length ?? 0;
    final complete = checks != null && done == total;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconTile(icon: icon, size: 40, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (checks != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: complete ? _successSoft : _fieldFill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (complete) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: _success,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        complete ? "Done" : "$done/$total",
                        style: TextStyle(
                          color: complete ? _success : _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _faint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================
// GENDER SELECTOR — three tappable pills instead of a dropdown
// ============================================================

class _GenderSelector extends StatelessWidget {
  final String? value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _GenderSelector({
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  static const _options = [
    ("Male", Icons.male_rounded),
    ("Female", Icons.female_rounded),
    ("Other", Icons.transgender_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Gender *",
            style: TextStyle(
              color: hasError ? _error : _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Row(
          children: [
            for (final (index, option) in _options.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _GenderPill(
                  label: option.$1,
                  icon: option.$2,
                  selected: value == option.$1,
                  hasError: hasError,
                  onTap: enabled ? () => onChanged(option.$1) : null,
                ),
              ),
            ],
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: _error,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _GenderPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool hasError;
  final VoidCallback? onTap;

  const _GenderPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _primary : _fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _primary
                : hasError
                ? _error.withValues(alpha: 0.5)
                : _border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : _primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : _body,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

// ============================================================
// SMALL PIECES
// ============================================================

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;

  const _IconTile({
    required this.icon,
    required this.size,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: _primary, size: iconSize),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String message;

  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.background,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _LoadingSections extends StatefulWidget {
  const _LoadingSections();

  @override
  State<_LoadingSections> createState() => _LoadingSectionsState();
}

class _LoadingSectionsState extends State<_LoadingSections>
    with SingleTickerProviderStateMixin {
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

  Widget block({double? width, required double height, double radius = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget card(int rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              block(width: 40, height: 40, radius: 13),
              const SizedBox(width: 12),
              block(width: 120, height: 16, radius: 8),
            ],
          ),
          for (var i = 0; i < rows; i++) ...[
            const SizedBox(height: 16),
            block(height: 54, radius: 16),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(children: [card(3), card(2), card(2)]);

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return FadeTransition(opacity: opacity, child: content);
  }
}
