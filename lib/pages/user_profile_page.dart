import 'package:flutter/material.dart';
import 'package:racetechph/profile/badges_page.dart';
import '../data/rank_data.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../profile/help_support_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/community_activity_page.dart';
import '../profile/community_page.dart';
import '../profile/recently_deleted_posts_page.dart';
import '../profile/edit_password.dart';
import '../profile/my_activity_page.dart';
import 'edit_interests_page.dart';
import 'profile_settings_page.dart';
import '../widgets/bottom_nav_bar.dart';

class _ProfileAvatar extends StatelessWidget {
  final String avatarUrl;
  final String initial;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD8E7FF), width: 4),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      height: 86,
                      width: 86,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _AvatarInitial(initial: initial);
                      },
                    )
                  : _AvatarInitial(initial: initial),
            ),
          ),
          if (!isLoading)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 15),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfilePhotoPreviewDialog extends StatelessWidget {
  final String avatarUrl;
  final String initial;
  final String displayName;

  const _ProfilePhotoPreviewDialog({
    required this.avatarUrl,
    required this.initial,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1,
                child: avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return _LargeAvatarInitial(initial: initial);
                        },
                      )
                    : _LargeAvatarInitial(initial: initial),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeAvatarInitial extends StatelessWidget {
  final String initial;

  const _LargeAvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 76,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: const TextStyle(
        color: Color(0xFF2563EB),
        fontSize: 34,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ProfileRankPill extends StatelessWidget {
  final String title;

  const _ProfileRankPill({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFD8E7FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.military_tech_outlined,
            color: Color(0xFF2563EB),
            size: 15,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CommunityMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CommunityActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunitySummarySkeleton extends StatelessWidget {
  const _CommunitySummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Row(
          children: [
            Expanded(child: _ProfileSkeletonBlock(height: 64, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: _ProfileSkeletonBlock(height: 64, radius: 18)),
            SizedBox(width: 10),
            Expanded(child: _ProfileSkeletonBlock(height: 64, radius: 18)),
          ],
        ),
        SizedBox(height: 14),
        _ProfileSkeletonBlock(height: 14, radius: 8),
        SizedBox(height: 14),
        _ProfileSkeletonBlock(height: 72, radius: 18),
      ],
    );
  }
}

class _ProfileSkeletonBlock extends StatelessWidget {
  final double height;
  final double radius;

  const _ProfileSkeletonBlock({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? user;
  bool isLoadingUser = true;
  bool isLoadingCommunity = true;
  int myCommunityPostCount = 0;
  int myCommunityLikeCount = 0;
  int myCommunityCommentCount = 0;
  int profileBadgeCount = 0;
  String latestCommunityPostTitle = "";

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final apiService = ApiService();
    final currentUser = await apiService.getUser();
    final userBadgeCount = badgeCountFromUser(currentUser);
    final achievements = userBadgeCount == null
        ? await apiService.getAchievements()
        : <Map<String, dynamic>>[];
    final resolvedBadgeCount =
        userBadgeCount ??
        achievements.where((item) => item["unlocked"] == true).length;

    if (!mounted) return;

    setState(() {
      user = currentUser;
      profileBadgeCount = resolvedBadgeCount;
      isLoadingUser = false;
    });

    await loadCommunitySummary(currentUser);
  }

  int? badgeCountFromUser(Map<String, dynamic>? data) {
    if (data == null) return null;

    for (final key in [
      "badges_count",
      "badge_count",
      "unlocked_badges_count",
      "achievements_count",
    ]) {
      final value = data[key];
      if (value != null) {
        return int.tryParse(value.toString());
      }
    }

    return null;
  }

  Future<void> loadCommunitySummary(Map<String, dynamic>? currentUser) async {
    final userId = (currentUser?["id"] ?? "").toString();

    if (userId.isEmpty) {
      if (!mounted) return;

      setState(() => isLoadingCommunity = false);
      return;
    }

    final posts = await ApiService().getCommunityPosts();

    if (!mounted) return;

    final myPosts = posts.where((post) {
      final postUser = Map<String, dynamic>.from(post["user"] ?? {});
      return (postUser["id"] ?? "").toString() == userId;
    }).toList();

    final likeCount = myPosts.fold<int>(
      0,
      (total, post) =>
          total + (int.tryParse((post["likes_count"] ?? 0).toString()) ?? 0),
    );
    final commentCount = myPosts.fold<int>(
      0,
      (total, post) => total + (((post["comments"] as List?) ?? []).length),
    );
    final latestTitle = myPosts.isEmpty
        ? ""
        : (myPosts.first["title"] ?? "Community post").toString();

    setState(() {
      myCommunityPostCount = myPosts.length;
      myCommunityLikeCount = likeCount;
      myCommunityCommentCount = commentCount;
      latestCommunityPostTitle = latestTitle;
      isLoadingCommunity = false;
    });
  }

  Future<void> refreshProfile() async {
    setState(() {
      isLoadingUser = true;
      isLoadingCommunity = true;
    });

    await loadUser();
  }

  Future<void> handleLogout(BuildContext context) async {
    final success = await ApiService().logout();

    if (!context.mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logout failed. Please try again.")),
      );
    }
  }

  Future<void> confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout, color: Color(0xFFE11D48)),
        title: const Text("Log out?"),
        content: const Text(
          "You will need to sign in again to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await handleLogout(context);
    }
  }

  Widget menuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF2563EB),
    Color iconBackgroundColor = const Color(0xFFEAF2FF),
    Color titleColor = const Color(0xFF111827),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader({
    required String displayName,
    required String displayEmail,
    required String initial,
    required String avatarUrl,
    required String rankTitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              const SizedBox(width: 48),

              const Expanded(
                child: Text(
                  "My Profile",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              const SizedBox(width: 48),
            ],
          ),

          const SizedBox(height: 24),

          _ProfileAvatar(
            avatarUrl: avatarUrl,
            initial: initial,
            isLoading: isLoadingUser,
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (_) => _ProfilePhotoPreviewDialog(
                  avatarUrl: avatarUrl,
                  initial: initial,
                  displayName: displayName,
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Text(
            isLoadingUser ? "Loading..." : displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          _ProfileRankPill(title: rankTitle),

          const SizedBox(height: 7),

          Text(
            displayEmail.isEmpty ? "No email available" : displayEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
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
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0));
  }

  Widget _communitySummarySection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My Community",
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Your posts and engagement",
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CommunityPage(showOnlyMyPosts: true),
                    ),
                  ).then((_) => loadCommunitySummary(user));
                },
                child: const Text("Open"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingCommunity)
            const _CommunitySummarySkeleton()
          else ...[
            Row(
              children: [
                Expanded(
                  child: _CommunityMetric(
                    label: "Posts",
                    value: myCommunityPostCount.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CommunityMetric(
                    label: "Likes",
                    value: myCommunityLikeCount.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CommunityMetric(
                    label: "Comments",
                    value: myCommunityCommentCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              latestCommunityPostTitle.isEmpty
                  ? "You have not posted in the community yet."
                  : "Latest: $latestCommunityPostTitle",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _CommunityActionTile(
              icon: Icons.shield_outlined,
              title: "Hidden and Reported Posts",
              subtitle: "Review posts you hid or sent to moderators",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunityActivityPage(),
                  ),
                ).then((_) => loadCommunitySummary(user));
              },
            ),
            const SizedBox(height: 10),
            _CommunityActionTile(
              icon: Icons.delete_outline_rounded,
              title: "Recently Deleted",
              subtitle: "Restore your posts before they expire",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecentlyDeletedPostsPage(),
                  ),
                ).then((_) => loadCommunitySummary(user));
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (user?["name"] ?? "Runner").toString();
    final displayEmail = (user?["email"] ?? "").toString();
    final avatarUrl = (user?["avatar_url"] ?? "").toString();
    final rankTitle = rankTitleForBadges(profileBadgeCount);
    final initial = displayName.trim().isEmpty
        ? "R"
        : displayName.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      bottomNavigationBar: const AppBottomNavBar(
        currentPage: AppNavPage.profile,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              children: [
                _profileHeader(
                  displayName: displayName,
                  displayEmail: displayEmail,
                  initial: initial,
                  avatarUrl: avatarUrl,
                  rankTitle: rankTitle,
                ),

                const SizedBox(height: 18),

                _menuSection(
                  title: "ACCOUNT",
                  children: [
                    menuItem(
                      title: "Profile Settings",
                      icon: Icons.manage_accounts_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileSettingsPage(),
                          ),
                        ).then((_) => loadUser());
                      },
                    ),

                    _sectionDivider(),

                    menuItem(
                      title: "Edit Interests",
                      icon: Icons.interests_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditInterestsPage(),
                          ),
                        ).then((_) => loadUser());
                      },
                    ),

                    _sectionDivider(),

                    menuItem(
                      title: "My Activity",
                      icon: Icons.receipt_long_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyActivityPage(),
                          ),
                        );
                      },
                    ),

                    _sectionDivider(),

                    menuItem(
                      title: "Badges",
                      icon: Icons.emoji_events_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BadgesPage(),
                          ),
                        );
                      },
                    ),

                    _sectionDivider(),

                    menuItem(
                      title: "Edit Password",
                      icon: Icons.lock_outline,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditPasswordPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                _communitySummarySection(),

                _menuSection(
                  title: "MORE",
                  children: [
                    menuItem(
                      title: "Privacy Policy",
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                    ),

                    _sectionDivider(),

                    menuItem(
                      title: "Help & Support",
                      icon: Icons.support_agent_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                _menuSection(
                  title: "SESSION",
                  children: [
                    menuItem(
                      title: "Log Out",
                      icon: Icons.logout,
                      iconColor: const Color(0xFFE11D48),
                      iconBackgroundColor: const Color(0xFFFFE4E6),
                      titleColor: const Color(0xFFE11D48),
                      onTap: () => confirmLogout(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
