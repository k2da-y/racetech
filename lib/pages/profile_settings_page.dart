import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../widgets/health_conditions_selector.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final birthdateController = TextEditingController();
  final addressController = TextEditingController();
  final emergencyNameController = TextEditingController();
  final emergencyNumberController = TextEditingController();
  final medicalConditionsController = TextEditingController();

  String? selectedGender;
  String avatarUrl = "";
  File? selectedAvatar;
  bool isLoading = true;
  bool isSaving = false;
  bool profileCompletionExpanded = true;
  final imagePicker = ImagePicker();

  final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in [
      nameController,
      phoneController,
      birthdateController,
      addressController,
      emergencyNameController,
      emergencyNumberController,
    ]) {
      controller.addListener(refreshCompletionStatus);
    }
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    birthdateController.dispose();
    addressController.dispose();
    emergencyNameController.dispose();
    emergencyNumberController.dispose();
    medicalConditionsController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    final user = await ApiService().getUser();

    if (!mounted) return;

    if (user != null) {
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
    }

    setState(() {
      isLoading = false;
      profileCompletionExpanded = !isProfileComplete;
    });
  }

  Future<void> pickAvatar() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 900,
    );

    if (picked == null) return;

    setState(() => selectedAvatar = File(picked.path));
  }

  String? normalizeGender(String value) {
    final normalized = value.trim().toLowerCase();

    return switch (normalized) {
      "male" => "Male",
      "female" => "Female",
      "other" => "Other",
      _ => null,
    };
  }

  Future<void> pickBirthdate() async {
    final initialDate = DateTime.tryParse(birthdateController.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      birthdateController.text = picked.toIso8601String().split("T").first;
    });
  }

  void refreshCompletionStatus() {
    if (!mounted) return;
    setState(() {});
  }

  bool get isProfileComplete {
    return profileChecklist.every((item) => item.isComplete);
  }

  int get completedProfileItems {
    return profileChecklist.where((item) => item.isComplete).length;
  }

  void toggleProfileCompletionPanel() {
    setState(() {
      profileCompletionExpanded = !profileCompletionExpanded;
    });
  }

  List<_ProfileChecklistItem> get profileChecklist {
    return [
      _ProfileChecklistItem(
        label: "Full name",
        isComplete: nameController.text.trim().isNotEmpty,
        icon: Icons.person_outline,
      ),
      _ProfileChecklistItem(
        label: "Phone number",
        isComplete: phoneController.text.trim().length == 11,
        icon: Icons.phone_outlined,
      ),
      _ProfileChecklistItem(
        label: "Gender",
        isComplete: (selectedGender ?? "").trim().isNotEmpty,
        icon: Icons.wc_outlined,
      ),
      _ProfileChecklistItem(
        label: "Birthdate",
        isComplete: birthdateController.text.trim().isNotEmpty,
        icon: Icons.cake_outlined,
      ),
      _ProfileChecklistItem(
        label: "Address",
        isComplete: addressController.text.trim().isNotEmpty,
        icon: Icons.location_on_outlined,
      ),
      _ProfileChecklistItem(
        label: "Emergency name",
        isComplete: emergencyNameController.text.trim().isNotEmpty,
        icon: Icons.contact_emergency_outlined,
      ),
      _ProfileChecklistItem(
        label: "Emergency phone",
        isComplete: emergencyNumberController.text.trim().length == 11,
        icon: Icons.phone_in_talk_outlined,
      ),
    ];
  }

  Future<void> saveProfile() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final gender = selectedGender ?? "";
    final birthdate = birthdateController.text.trim();
    final address = addressController.text.trim();
    final emergencyName = emergencyNameController.text.trim();
    final emergencyNumber = emergencyNumberController.text.trim();
    final medicalConditions = medicalConditionsController.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        gender.isEmpty ||
        birthdate.isEmpty ||
        address.isEmpty ||
        emergencyName.isEmpty ||
        emergencyNumber.isEmpty) {
      showMessage("Please complete all required fields.");
      return;
    }

    if (phone.length != 11 || emergencyNumber.length != 11) {
      showMessage("Phone numbers must be 11 digits.");
      return;
    }

    setState(() => isSaving = true);

    final result = await ApiService().updateProfile(
      name: name,
      phone: phone,
      gender: gender,
      birthdate: birthdate,
      address: address,
      emergencyContactName: emergencyName,
      emergencyContactNumber: emergencyNumber,
      medicalConditions: medicalConditions,
      avatarPath: selectedAvatar?.path,
    );

    if (!mounted) return;

    setState(() => isSaving = false);

    if (result.success) {
      showMessage(result.message);
      Navigator.pop(context, true);
    } else {
      showMessage(result.message);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Widget profileCompletionPanel() {
    final checklist = profileChecklist;
    final completed = completedProfileItems;
    final total = checklist.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final complete = isProfileComplete;
    final expanded = profileCompletionExpanded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: toggleProfileCompletionPanel,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: complete
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    complete
                        ? Icons.verified_user_outlined
                        : Icons.assignment_late_outlined,
                    color: complete
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF97316),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complete ? "Profile Complete" : "Missing Details",
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "$completed of $total required items completed",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                complete ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: checklist.map(profileChecklistChip).toList(),
                ),
              ],
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOut,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }

  Widget profileChecklistChip(_ProfileChecklistItem item) {
    final color = item.isComplete
        ? const Color(0xFF16A34A)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: item.isComplete
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: item.isComplete
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.isComplete ? Icons.check_circle : item.icon,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            item.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: Column(
          children: [
            _HeaderSection(
              isSaving: isSaving,
              onBack: () => Navigator.pop(context),
            ),

            Expanded(
              child: isLoading
                  ? const _ProfileSettingsLoadingState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => isLoading = true);
                        await loadProfile();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Column(
                          children: [
                            profileCompletionPanel(),

                            const SizedBox(height: 15),

                            section(
                              title: "Personal Details",
                              subtitle:
                                  "Used for registrations and race day records.",
                              icon: Icons.person_outline,
                              children: [
                                _AvatarPicker(
                                  avatarUrl: avatarUrl,
                                  selectedAvatar: selectedAvatar,
                                  displayName: nameController.text.trim(),
                                  onTap: isSaving ? null : pickAvatar,
                                ),
                                const SizedBox(height: 18),
                                inputField(
                                  controller: nameController,
                                  label: "Full Name",
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 15),
                                inputField(
                                  controller: phoneController,
                                  label: "Phone Number",
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: phoneFormatters,
                                ),
                                const SizedBox(height: 15),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedGender,
                                  decoration: fieldDecoration(
                                    "Gender *",
                                    Icons.wc_outlined,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: "Male",
                                      child: Text("Male"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Female",
                                      child: Text("Female"),
                                    ),
                                    DropdownMenuItem(
                                      value: "Other",
                                      child: Text("Other"),
                                    ),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setState(
                                            () => selectedGender = value,
                                          );
                                        },
                                ),
                                const SizedBox(height: 15),
                                GestureDetector(
                                  onTap: isSaving ? null : pickBirthdate,
                                  child: AbsorbPointer(
                                    child: inputField(
                                      controller: birthdateController,
                                      label: "Birthdate",
                                      icon: Icons.cake_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                inputField(
                                  controller: addressController,
                                  label: "Address",
                                  icon: Icons.location_on_outlined,
                                  maxLines: 2,
                                ),
                              ],
                            ),

                            const SizedBox(height: 15),

                            section(
                              title: "Emergency and Medical",
                              subtitle:
                                  "Helpful details for safer event support.",
                              icon: Icons.health_and_safety_outlined,
                              children: [
                                inputField(
                                  controller: emergencyNameController,
                                  label: "Emergency Contact Name",
                                  icon: Icons.contact_emergency_outlined,
                                ),
                                const SizedBox(height: 15),
                                inputField(
                                  controller: emergencyNumberController,
                                  label: "Emergency Contact Number",
                                  icon: Icons.phone_in_talk_outlined,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: phoneFormatters,
                                ),
                                const SizedBox(height: 15),
                                HealthConditionsSelector(
                                  controller: medicalConditionsController,
                                  enabled: !isSaving,
                                  title: "Health notes",
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: isSaving ? null : saveProfile,
                                icon: isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  isSaving ? "Saving..." : "Save Profile",
                                  style: const TextStyle(
                                    fontSize: 16,
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
          ],
        ),
      ),
    );
  }

  Widget section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
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

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextField(
      controller: controller,
      enabled: !isSaving,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontWeight: FontWeight.w600,
      ),
      decoration: fieldDecoration(required ? "$label *" : label, icon),
    );
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final String avatarUrl;
  final File? selectedAvatar;
  final String displayName;
  final VoidCallback? onTap;

  const _AvatarPicker({
    required this.avatarUrl,
    required this.selectedAvatar,
    required this.displayName,
    required this.onTap,
  });

  String get initial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? "R" : trimmed[0].toUpperCase();
  }

  ImageProvider? get imageProvider {
    if (selectedAvatar != null) {
      return FileImage(selectedAvatar!);
    }

    if (avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final image = imageProvider;

    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 104,
              width: 104,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD8E7FF), width: 4),
                image: image == null
                    ? null
                    : DecorationImage(image: image, fit: BoxFit.cover),
              ),
              child: image == null
                  ? Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
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

class _ProfileSettingsLoadingState extends StatelessWidget {
  const _ProfileSettingsLoadingState();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        children: const [
          _ProfileSkeletonCard(
            rows: [
              _SkeletonRow(width: 170),
              _SkeletonRow(width: double.infinity),
              _SkeletonRow(width: 240),
            ],
          ),
          SizedBox(height: 15),
          _ProfileSkeletonCard(
            rows: [
              _SkeletonRow(width: 150),
              _SkeletonRow(width: double.infinity),
              _SkeletonRow(width: double.infinity),
              _SkeletonRow(width: double.infinity),
            ],
          ),
          SizedBox(height: 15),
          _ProfileSkeletonCard(
            rows: [
              _SkeletonRow(width: 190),
              _SkeletonRow(width: double.infinity),
              _SkeletonRow(width: double.infinity),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeletonCard extends StatelessWidget {
  final List<_SkeletonRow> rows;

  const _ProfileSkeletonCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _SkeletonBlock(height: 40, width: 40, radius: 14),
              SizedBox(width: 11),
              Expanded(
                child: _SkeletonBlock(
                  height: 16,
                  width: double.infinity,
                  radius: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...rows,
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  final double width;

  const _SkeletonRow({required this.width});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SkeletonBlock(height: 50, width: width, radius: 18),
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

class _ProfileChecklistItem {
  final String label;
  final bool isComplete;
  final IconData icon;

  const _ProfileChecklistItem({
    required this.label,
    required this.isComplete,
    required this.icon,
  });
}

class _HeaderSection extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onBack;

  const _HeaderSection({required this.isSaving, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEAF2FF),
                foregroundColor: const Color(0xFF2563EB),
              ),
              onPressed: isSaving ? null : onBack,
              icon: const Icon(Icons.arrow_back),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Profile Settings",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSaving
                        ? "Saving your profile..."
                        : "Complete your event profile",
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.manage_accounts_outlined,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
