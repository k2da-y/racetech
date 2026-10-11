import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as community_page.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _primary = Color(0xFF6366F1);
const _primaryDeep = Color(0xFF4F46E5);
const _accent = Color(0xFF0EA5E9);
const _primarySoft = Color(0xFFEEF2FF);

const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
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

ThemeData _brandTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _primary,
      secondary: _accent,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
      error: _danger,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _primary,
      selectionColor: Color(0x336366F1),
      selectionHandleColor: _primary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
  );
}

typedef CreatePostCallback =
    Future<bool> Function(String title, String content, {String? mediaPath});

/// Opens the Create Post dialog (centered, not a bottom sheet).
Future<void> showCreatePostDialog(
  BuildContext context, {
  required CreatePostCallback onPost,
  String Function()? errorMessage,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x8C0F172A),
    builder: (_) => CreatePostSheet(onPost: onPost, errorMessage: errorMessage),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE POST DIALOG
// (class name kept as CreatePostSheet so existing imports still work)
// ─────────────────────────────────────────────────────────────────────────────

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

  // Inline errors (UI only)
  String? titleError;
  String? bodyError;
  String? submitError;

  String get currentUserName => (currentUser?["name"] ?? "Runner").toString();

  String get currentUserInitial {
    final name = currentUserName.trim();
    return name.isEmpty ? "R" : name[0].toUpperCase();
  }

  String? get currentUserAvatarUrl {
    final avatar = (currentUser?["avatar_url"] ?? "").toString();
    return avatar.isEmpty ? null : avatar;
  }

  bool get hasDraft =>
      titleController.text.trim().isNotEmpty ||
      contentController.text.trim().isNotEmpty ||
      selectedMediaPath != null;

  @override
  void initState() {
    super.initState();
    titleController.addListener(_onTitleChanged);
    contentController.addListener(_onContentChanged);
    loadCurrentUser();
  }

  void _onTitleChanged() {
    if (!mounted) return;
    setState(() {
      titleError = null;
      submitError = null;
    });
  }

  void _onContentChanged() {
    if (!mounted) return;
    setState(() {
      bodyError = null;
      submitError = null;
    });
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

      if (!mounted) return;

      setState(() {
        selectedImageBytes = bytes;
        selectedMediaName = picked.name;
        selectedMediaPath = picked.path;
        selectedMediaIsVideo = false;
        bodyError = null;
        submitError = null;
      });
    }
  }

  Future<void> pickVideo() async {
    final picked = await picker.pickVideo(source: ImageSource.gallery);

    if (picked != null) {
      if (!mounted) return;

      setState(() {
        selectedImageBytes = null;
        selectedMediaName = picked.name;
        selectedMediaPath = picked.path;
        selectedMediaIsVideo = true;
        bodyError = null;
        submitError = null;
      });
    }
  }

  void removeMedia() {
    setState(() {
      selectedImageBytes = null;
      selectedMediaName = null;
      selectedMediaPath = null;
      selectedMediaIsVideo = false;
    });
  }

  Future<void> submitPost() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (isSubmitting) return;

    final missingTitle = title.isEmpty;
    final missingBody = content.isEmpty && selectedMediaPath == null;

    if (missingTitle || missingBody) {
      HapticFeedback.heavyImpact();
      setState(() {
        titleError = missingTitle ? "Please add a title." : null;
        bodyError = missingBody
            ? "Add some content, an image, or a video."
            : null;
      });
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() {
      isSubmitting = true;
      submitError = null;
    });

    final posted = await widget.onPost(
      title,
      content,
      mediaPath: selectedMediaPath,
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!posted) {
      HapticFeedback.heavyImpact();
      setState(() {
        submitError = widget.errorMessage?.call() ?? "Unable to create post.";
      });
      return;
    }

    // Navigator.pop skips the discard guard on purpose.
    Navigator.pop(context);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x8C0F172A),
      builder: (dialogContext) => Theme(
        data: _brandTheme(context),
        child: _DiscardDialog(
          onKeep: () => Navigator.pop(dialogContext, false),
          onDiscard: () => Navigator.pop(dialogContext, true),
        ),
      ),
    );

    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    titleController.removeListener(_onTitleChanged);
    contentController.removeListener(_onContentChanged);
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _brandTheme(context),
      child: PopScope(
        canPop: !isSubmitting && !hasDraft,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || isSubmitting) return;
          _confirmDiscard();
        },
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      _Avatar(
                        letter: currentUserInitial,
                        size: 44,
                        imageUrl: currentUserAvatarUrl,
                        ring: true,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create Post",
                              style: TextStyle(
                                color: _ink,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Share something with the community",
                              style: TextStyle(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CloseButton(
                        onTap: isSubmitting
                            ? null
                            : () => Navigator.maybePop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Server error banner
                  if (submitError != null) ...[
                    _ErrorBanner(message: submitError!),
                    const SizedBox(height: 14),
                  ],

                  // Title
                  const _FieldLabel("Title"),
                  _CreateTextField(
                    controller: titleController,
                    hint: "Title...",
                    maxLines: 1,
                    enabled: !isSubmitting,
                    errorText: titleError,
                    textInputAction: TextInputAction.next,
                  ),

                  const SizedBox(height: 14),

                  // Message
                  const _FieldLabel("Message"),
                  _CreateTextField(
                    controller: contentController,
                    hint: "What's on your mind? (optional with media)",
                    maxLines: 5,
                    enabled: !isSubmitting,
                    errorText: bodyError,
                  ),

                  const SizedBox(height: 14),

                  // Media preview
                  if (selectedMediaPath != null) ...[
                    _SelectedMediaPreview(
                      imageBytes: selectedImageBytes,
                      fileName: selectedMediaName,
                      isVideo: selectedMediaIsVideo,
                      onRemove: isSubmitting ? null : removeMedia,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Toolbar
                  Row(
                    children: [
                      _MediaChip(
                        icon: Icons.image_outlined,
                        label: "Photo",
                        onTap: isSubmitting ? null : pickImage,
                      ),
                      const SizedBox(width: 8),
                      _MediaChip(
                        icon: Icons.videocam_outlined,
                        label: "Video",
                        onTap: isSubmitting ? null : pickVideo,
                      ),
                      const Spacer(),
                      _PostButton(
                        label: isSubmitting ? "Posting..." : "Post",
                        icon: Icons.send_rounded,
                        loading: isSubmitting,
                        onTap: isSubmitting ? null : submitPost,
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

// ─────────────────────────────────────────────────────────────────────────────
// PIECES
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String letter;
  final double size;
  final String? imageUrl;
  final bool ring;

  const _Avatar({
    required this.letter,
    required this.size,
    this.imageUrl,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF0EA5E9),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    final safeLetter = letter.isEmpty ? "R" : letter;
    final color = colors[safeLetter.codeUnitAt(0) % colors.length];
    final url = imageUrl?.trim() ?? "";

    final avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: url.isNotEmpty
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarInitial(letter: safeLetter, size: size),
            )
          : _AvatarInitial(letter: safeLetter, size: size),
    );

    if (!ring) return avatar;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: avatar,
      ),
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
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Close",
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: _fieldFill,
        foregroundColor: _muted,
        side: const BorderSide(color: _border),
      ),
      icon: const Icon(Icons.close_rounded, size: 20),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: _body,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CreateTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool enabled;
  final String? errorText;
  final TextInputAction? textInputAction;

  const _CreateTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    this.enabled = true,
    this.errorText,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        color: _ink,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _faint,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        errorText: errorText,
        errorStyle: const TextStyle(
          color: _danger,
          fontWeight: FontWeight.w700,
        ),
        errorMaxLines: 2,
        filled: true,
        fillColor: errorText != null ? _dangerSoft : _fieldFill,
        enabledBorder: outline(_border),
        disabledBorder: outline(_border),
        focusedBorder: outline(_primary, 1.5),
        errorBorder: outline(_danger),
        focusedErrorBorder: outline(_danger, 1.5),
        border: outline(_border),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
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

class _SelectedMediaPreview extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? fileName;
  final bool isVideo;
  final VoidCallback? onRemove;

  const _SelectedMediaPreview({
    required this.imageBytes,
    required this.fileName,
    required this.isVideo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final Widget preview;

    if (!isVideo && imageBytes != null) {
      preview = Image.memory(
        imageBytes!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 140,
          color: _fieldFill,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: _faint),
        ),
      );
    } else {
      preview = Container(
        height: 160,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: _heroGradient),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.play_circle_fill_rounded : Icons.image_rounded,
              color: Colors.white,
              size: 52,
            ),
            if (fileName != null && fileName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          preview,
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVideo ? "Video" : "Photo",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 8,
              top: 8,
              child: Tooltip(
                message: "Remove",
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MediaChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _primarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: onTap == null ? _faint : _primary, size: 19),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: onTap == null ? _faint : _primaryDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool loading;

  const _PostButton({
    required this.onTap,
    this.label = "Post",
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null || loading;

    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Container(
        height: 48,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 18),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

class _DiscardDialog extends StatelessWidget {
  final VoidCallback onKeep;
  final VoidCallback onDiscard;

  const _DiscardDialog({required this.onKeep, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: const BoxDecoration(
                  color: _dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_sweep_outlined,
                  color: _danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Discard this post?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "What you've written and any selected media will be lost.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _body,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onKeep,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _body,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Keep editing",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onDiscard,
                      style: FilledButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Discard",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
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
