import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'signup_page2.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as login_page.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _primary = Color(0xFF6366F1);
const _primaryDeep = Color(0xFF4F46E5);
const _accent = Color(0xFF0EA5E9);
const _primarySoft = Color(0xFFEEF2FF);

const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);

const _border = Color(0xFFE2E8F0);
const _fieldFill = Color(0xFFF8FAFC);

const _danger = Color(0xFFEF4444);
const _dangerSoft = Color(0xFFFEF2F2);

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_primaryDeep, _primary, _accent],
);

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String? selectedGender;
  DateTime? selectedBirthday;

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final lastNameFocus = FocusNode();

  /// Inline errors appear only after the first "Continue" tap.
  bool showErrors = false;

  @override
  void initState() {
    super.initState();
    firstNameController.addListener(_refreshErrors);
    lastNameController.addListener(_refreshErrors);
  }

  void _refreshErrors() {
    if (showErrors) setState(() {});
  }

  @override
  void dispose() {
    firstNameController.removeListener(_refreshErrors);
    lastNameController.removeListener(_refreshErrors);
    firstNameController.dispose();
    lastNameController.dispose();
    lastNameFocus.dispose();
    super.dispose();
  }

  String? get firstNameError => showErrors &&
      firstNameController.text.trim().isEmpty
      ? "Please enter your first name"
      : null;

  String? get lastNameError => showErrors &&
      lastNameController.text.trim().isEmpty
      ? "Please enter your last name"
      : null;

  String? get genderError =>
      showErrors && selectedGender == null ? "Please select your gender" : null;

  String? get birthdayError => showErrors && selectedBirthday == null
      ? "Please select your birthday"
      : null;

  // ============================================================
  // LOGIC — same checks and same data passed to SignUpPage2
  // ============================================================

  void goToAccountDetails() {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        selectedGender == null ||
        selectedBirthday == null) {
      HapticFeedback.heavyImpact();
      setState(() => showErrors = true);
      return;
    }

    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpPage2(
          firstName: firstName,
          lastName: lastName,
          gender: selectedGender!,
          birthday: selectedBirthday!.toIso8601String().split("T").first,
        ),
      ),
    );
  }

  Future<void> pickBirthday() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: "Select your birthday",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              onSurface: _ink,
              surface: Colors.white,
              surfaceTint: Colors.transparent,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: _primary,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedBirthday = picked;
      });
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static const _months = [
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

  int _ageOn(DateTime birthday) {
    final now = DateTime.now();
    var age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final hasError = errorText != null;

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _faint, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, size: 21, color: hasError ? _danger : _muted),
      errorText: errorText,
      errorStyle: const TextStyle(color: _danger, fontWeight: FontWeight.w700),
      filled: true,
      fillColor: hasError ? _dangerSoft : _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: outline(_border),
      enabledBorder: outline(_border),
      focusedBorder: outline(_primary, 1.6),
      errorBorder: outline(_danger),
      focusedErrorBorder: outline(_danger, 1.6),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
    );
  }

  Widget _errorLine(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 7),
      child: Text(
        message,
        style: const TextStyle(
          color: _danger,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // FIELDS
  // ============================================================

  Widget _buildNameFields() {
    final first = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("First name"),
        TextField(
          controller: firstNameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          onSubmitted: (_) => lastNameFocus.requestFocus(),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: _inputDecoration(
            hint: "Enter your first name",
            icon: Icons.person_outline_rounded,
            errorText: firstNameError,
          ),
        ),
      ],
    );

    final last = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("Last name"),
        TextField(
          controller: lastNameController,
          focusNode: lastNameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.familyName],
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: _inputDecoration(
            hint: "Enter your last name",
            icon: Icons.badge_outlined,
            errorText: lastNameError,
          ),
        ),
      ],
    );

    return Column(children: [first, const SizedBox(height: 17), last]);
  }

  Widget _buildGenderField() {
    const options = [
      ("Male", Icons.male_rounded),
      ("Female", Icons.female_rounded),
      ("Other", Icons.transgender_rounded),
    ];
    final hasError = genderError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("Gender"),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _GenderPill(
                  label: options[i].$1,
                  icon: options[i].$2,
                  selected: selectedGender == options[i].$1,
                  hasError: hasError,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => selectedGender = options[i].$1);
                  },
                ),
              ),
            ],
          ],
        ),
        if (hasError) _errorLine(genderError!),
      ],
    );
  }

  Widget _buildBirthdayField() {
    final birthday = selectedBirthday;
    final hasBirthday = birthday != null;
    final hasError = birthdayError != null;

    final birthdayText = hasBirthday
        ? "${_months[birthday.month - 1]} ${birthday.day}, ${birthday.year}"
        : "Select your birthday";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("Birthday"),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: pickBirthday,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: hasError ? _dangerSoft : _fieldFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hasError ? _danger : _border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(
                      Icons.cake_outlined,
                      size: 21,
                      color: hasError ? _danger : _muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      birthdayText,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: hasBirthday ? _ink : _faint,
                      ),
                    ),
                  ),
                  if (hasBirthday)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _primarySoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        "${_ageOn(birthday)} yrs",
                        style: const TextStyle(
                          color: _primaryDeep,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: hasError ? _danger : _primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) _errorLine(birthdayError!),
      ],
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgress() {
    Widget step(int number, String label, {required bool active}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                gradient: active ? _heroGradient : null,
                color: active ? null : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  height: 18,
                  width: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? _primary : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "$number",
                    style: TextStyle(
                      color: active ? Colors.white : _faint,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: active ? _primaryDeep : _faint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        step(1, "Personal details", active: true),
        const SizedBox(width: 10),
        step(2, "Account details", active: false),
      ],
    );
  }

  // ============================================================
  // SIGNUP CARD
  // ============================================================

  Widget _buildSignUpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40312E81),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _heroGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x406366F1),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    "Step 1 of 2",
                    style: TextStyle(
                      color: _primaryDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Create your account",
              style: TextStyle(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              "Tell us a little about yourself to get started.",
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),

            const SizedBox(height: 22),

            _buildProgress(),

            const SizedBox(height: 24),

            _buildNameFields(),

            const SizedBox(height: 17),

            _buildGenderField(),

            const SizedBox(height: 17),

            _buildBirthdayField(),

            const SizedBox(height: 26),

            // NEXT
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _heroGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D6366F1),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: goToAccountDetails,
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Continue",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // LOGIN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account?",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    "Sign in",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: _primary,
          error: _danger,
          surfaceTint: Colors.transparent,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _primary,
          selectionColor: Color(0x336366F1),
          selectionHandleColor: _primary,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: const Color(0xFF1E1B4B),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Same background as Landing + Login
              Image.asset(
                "assets/login_bg.jpg",
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (context, error, stackTrace) =>
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: _heroGradient),
                ),
              ),

              // Indigo overlay
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xB34F46E5),
                      Color(0xCC312E81),
                      Color(0xF21E1B4B),
                    ],
                  ),
                ),
              ),

              // Soft glows
              Positioned(
                top: -90,
                right: -70,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(alpha: 0.22),
                  ),
                ),
              ),
              Positioned(
                bottom: -110,
                left: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.25),
                  ),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        children: [
                          // TOP BAR
                          Row(
                            children: [
                              Tooltip(
                                message: "Back",
                                child: Material(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.24,
                                      ),
                                    ),
                                  ),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => Navigator.pop(context),
                                    child: const SizedBox(
                                      height: 42,
                                      width: 42,
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.speed_rounded,
                                      color: Colors.white,
                                      size: 23,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "RACETECH",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Balances the back button
                              const SizedBox(width: 42, height: 42),
                            ],
                          ),

                          const SizedBox(height: 24),

                          _buildSignUpCard(),

                          const SizedBox(height: 22),

                          Text(
                            "Train smarter. Perform better.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
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

// ─────────────────────────────────────────────────────────────────────────────
// GENDER PILL
// ─────────────────────────────────────────────────────────────────────────────

class _GenderPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  const _GenderPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? _primary
        : hasError
        ? _danger
        : _border;

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 54,
        decoration: BoxDecoration(
          color: selected
              ? _primarySoft
              : hasError
              ? _dangerSoft
              : _fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : icon,
                  size: 18,
                  color: selected ? _primary : _muted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _primaryDeep : _ink,
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}