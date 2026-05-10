import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

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
  bool isLoading = true;
  bool isSaving = false;

  final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ];

  @override
  void initState() {
    super.initState();
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
    }

    setState(() => isLoading = false);
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

    birthdateController.text = picked.toIso8601String().split("T").first;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      "Profile Settings",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.manage_accounts, color: Colors.white),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          section(
                            title: "Personal Details",
                            children: [
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
                                  "Gender",
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
                                onChanged: (value) {
                                  setState(() => selectedGender = value);
                                },
                              ),
                              const SizedBox(height: 15),
                              GestureDetector(
                                onTap: pickBirthdate,
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
                              inputField(
                                controller: medicalConditionsController,
                                label: "Medical Conditions",
                                icon: Icons.medical_information_outlined,
                                maxLines: 3,
                                required: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isSaving ? null : saveProfile,
                              child: Text(
                                isSaving ? "Saving..." : "Save Profile",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget section({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
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
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: fieldDecoration(required ? "$label *" : label, icon),
    );
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
