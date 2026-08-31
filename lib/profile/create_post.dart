import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

const _surfaceHigh = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _textPrimary = Color(0xFF111827);
const _textSecondary = Color(0xFF64748B);
const _primaryBlue = Color(0xFF2563EB);
const _primarySoft = Color(0xFFEAF2FF);

typedef CreatePostCallback =
    Future<bool> Function(String title, String content, {String? mediaPath});

class CreatePostSheet extends StatefulWidget {
  final CreatePostCallback onPost;
  final String Function()? errorMessage;

  const CreatePostSheet({super.key, required this.onPost, this.errorMessage});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  Uint8List? selectedImageBytes;
  String? selectedMediaName;
  String? selectedMediaPath;
  bool selectedMediaIsVideo = false;

  bool isSubmitting = false;
  Map<String, dynamic>? currentUser;

  String get currentUserName => (currentUser?["name"] ?? "Runner").toString();

  String get currentUserInitial {
    final name = currentUserName.trim();
    return name.isEmpty ? "R" : name[0].toUpperCase();
  }

  String? get currentUserAvatarUrl {
    final avatar = (currentUser?["avatar_url"] ?? "").toString();
    return avatar.isEmpty ? null : avatar;
  }

  @override
  void initState() {
    super.initState();
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    final user = await ApiService().getUser();

    if (!mounted) return;

    setState(() => currentUser = user);
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      setState(() {
        selectedImageBytes = bytes;
        selectedMediaName = picked.name;
        selectedMediaPath = picked.path;
        selectedMediaIsVideo = false;
      });
    }
  }

  Future<void> pickVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        selectedImageBytes = null;
        selectedMediaName = picked.name;
        selectedMediaPath = picked.path;
        selectedMediaIsVideo = true;
      });
    }
  }

  Future<void> submitPost() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (isSubmitting) return;

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please add a title.")));
      return;
    }

    if (content.isEmpty && selectedMediaPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Add some content, an image, or a video."),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    setState(() => isSubmitting = true);
    final posted = await widget.onPost(
      title,
      content,
      mediaPath: selectedMediaPath,
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!posted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.errorMessage?.call() ?? "Unable to create post.",
          ),
        ),
      );
      return;
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _Avatar(
                    letter: currentUserInitial,
                    size: 42,
                    imageUrl: currentUserAvatarUrl,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Create Post",
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Share something with the community",
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CreateTextField(
                controller: titleController,
                hint: "Title...",
                maxLines: 1,
              ),
              const SizedBox(height: 10),
              _CreateTextField(
                controller: contentController,
                hint: "What's on your mind? (optional with media)",
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              if (selectedMediaPath != null) ...[
                if (selectedMediaIsVideo)
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _surfaceHigh,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: _primaryBlue,
                        size: 52,
                      ),
                    ),
                  )
                else if (selectedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      selectedImageBytes!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  _MediaButton(icon: Icons.image_outlined, onTap: pickImage),
                  const SizedBox(width: 8),
                  _MediaButton(icon: Icons.videocam_outlined, onTap: pickVideo),
                  const Spacer(),
                  _PostButton(
                    onTap: submitPost,
                    label: isSubmitting ? "Posting..." : "Post",
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

class _Avatar extends StatelessWidget {
  final String letter;
  final double size;
  final String? imageUrl;

  const _Avatar({required this.letter, required this.size, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final avatar = imageUrl?.trim() ?? "";

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: _primarySoft,
        shape: BoxShape.circle,
      ),
      child: avatar.isNotEmpty
          ? Image.network(
              avatar,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarInitial(letter: letter, size: size),
            )
          : _AvatarInitial(letter: letter, size: size),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String letter;
  final double size;

  const _AvatarInitial({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          color: _primaryBlue,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CreateTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _CreateTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: _surfaceHigh,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MediaButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: _primarySoft,
        foregroundColor: _primaryBlue,
      ),
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

class _PostButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PostButton({required this.onTap, this.label = "Post"});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}
