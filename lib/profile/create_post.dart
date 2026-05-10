import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

const _bg = Color(0xFFFFFFFF);
const _surface = Color(0xFFFFFFFF);
const _surfaceHigh = Color(0xFFF5F5F5);
const _textPrimary = Color(0xFF000000);
const _textSecondary = Color(0xFF666666);
const _greenAvatar = Color(0xFF4CD070);

class CreatePostSheet extends StatefulWidget {
  final Future<bool> Function(String, String) onPost;
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
  String? selectedImageName;

  bool hasVideo = false;
  String? selectedVideoName;
  bool isSubmitting = false;

  Future<void> pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      setState(() {
        selectedImageBytes = bytes;
        selectedImageName = picked.name;
        hasVideo = false;
        selectedVideoName = null;
      });
    }
  }

  Future<void> pickVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        hasVideo = true;
        selectedVideoName = picked.name;
        selectedImageBytes = null;
        selectedImageName = null;
      });
    }
  }

  Future<void> submitPost() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty || content.isEmpty || isSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a title and content.")),
      );
      return;
    }

    HapticFeedback.lightImpact();

    setState(() => isSubmitting = true);
    final posted = await widget.onPost(title, content);

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
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const _Avatar(letter: "Y", size: 48),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Text(
                          "New thread",
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),

                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: _textSecondary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _CreateTextField(
                    controller: titleController,
                    hint: "Title...",
                    maxLines: 1,
                    height: 58,
                  ),

                  const SizedBox(height: 14),

                  _CreateTextField(
                    controller: contentController,
                    hint: "What's on your mind?",
                    maxLines: 5,
                    height: 160,
                  ),

                  const SizedBox(height: 14),

                  if (selectedImageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        selectedImageBytes!,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedImageName ?? "Image selected",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (hasVideo) ...[
                    Container(
                      height: 95,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _surfaceHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_fill,
                              size: 36,
                              color: _textPrimary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              selectedVideoName ?? "Video selected",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      _MediaButton(
                        icon: Icons.image_outlined,
                        onTap: pickImage,
                      ),

                      const SizedBox(width: 12),

                      _MediaButton(
                        icon: Icons.videocam_outlined,
                        onTap: pickVideo,
                      ),

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
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;
  final double size;

  const _Avatar({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _greenAvatar,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: _bg,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CreateTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final double height;

  const _CreateTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: _textSecondary,
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _textSecondary, size: 24),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PostButton({required this.onTap, this.label = "Post"});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        height: 50,
        decoration: BoxDecoration(
          color: _textPrimary,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: _bg,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
