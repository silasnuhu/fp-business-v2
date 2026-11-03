import 'package:flutter/material.dart';
import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/design/fp_components.dart';
import 'package:whoxa/design/fp_tokens.dart';
import 'package:whoxa/featuers/story/provider/story_provider.dart';
import 'package:whoxa/featuers/story/screens/story_view.dart';
import 'package:whoxa/utils/preference_key/constant/app_routes.dart';

/// Redesigned stories surface.
///
/// Structure differs from the stock status list:
///   * an own-story hero card (add or open) instead of a leading ListTile row,
///   * recent and viewed stories as card groups with gradient rings,
///   * designed empty state, pull-to-refresh.
///
/// Viewing still opens the existing `StoriesView` with the same arguments the
/// stock list passes, so playback, gestures and reply behaviour are unchanged.
class FpStoriesScreen extends StatefulWidget {
  const FpStoriesScreen({super.key});

  @override
  State<FpStoriesScreen> createState() => _FpStoriesScreenState();
}

class _FpStoriesScreenState extends State<FpStoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<StoryProvider>();
      if (!p.isGetStory) p.getAllStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    // theme dependency: rebuild this screen when the theme changes
    // so the static Fp tokens are re-read (they are not InheritedWidgets).
    context.watch<ThemeProvider>();
    final p = context.watch<StoryProvider>();
    final recent = p.getRecentStoryList;
    final viewed = p.getViewedStoryList;
    final mine = p.getMyStories;

    return Scaffold(
      backgroundColor: Fp.ink,
      body: FpCanvas(
        child: RefreshIndicator(
          color: Fp.violet,
          backgroundColor: Fp.inkRaised,
          onRefresh: () => p.getAllStories(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Fp.s16, Fp.s12, Fp.s16, 40),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Fp.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STORIES',
                        style: Fp.label.copyWith(color: Fp.violetGlow)),
                    const SizedBox(height: Fp.s4),
                    Text('24 hours, then gone', style: Fp.h1),
                  ],
                ),
              ),
              const SizedBox(height: Fp.s20),

              _MyStoryCard(
                hasStory: mine.isNotEmpty,
                onTap: () {
                  if (mine.isNotEmpty) {
                    Navigator.pushNamed(context, AppRoutes.myStoryView);
                  } else {
                    Navigator.pushNamed(context, AppRoutes.storyUpload)
                        .then((_) => p.getAllStories());
                  }
                },
              ),
              const SizedBox(height: Fp.s24),

              if (p.isGetStory && recent.isEmpty && viewed.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Fp.s40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Fp.violet),
                    ),
                  ),
                )
              else if (recent.isEmpty && viewed.isEmpty)
                const FpEmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'No stories yet',
                  message:
                      'Stories from people you talk to will appear here for 24 hours.',
                )
              else ...[
                if (recent.isNotEmpty) ...[
                  FpSectionLabel('Recent'),
                  const SizedBox(height: Fp.s12),
                  for (var i = 0; i < recent.length; i++) ...[
                    _StoryRow(
                      name: _name(recent[i].fullName, recent[i].firstName,
                          recent[i].userName),
                      imageUrl: recent[i].profilePic,
                      unseen: true,
                      onTap: () => _open(context, p, i, true),
                    ),
                    const SizedBox(height: Fp.s8),
                  ],
                  const SizedBox(height: Fp.s16),
                ],
                if (viewed.isNotEmpty) ...[
                  FpSectionLabel('Already seen'),
                  const SizedBox(height: Fp.s12),
                  for (var i = 0; i < viewed.length; i++) ...[
                    _StoryRow(
                      name: _name(viewed[i].fullName, viewed[i].firstName,
                          viewed[i].userName),
                      imageUrl: viewed[i].profilePic,
                      unseen: false,
                      onTap: () => _open(context, p, i, false),
                    ),
                    const SizedBox(height: Fp.s8),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, StoryProvider p, int index, bool recent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoriesView(
          isMyStory: false,
          recentStories: p.getRecentStoryList,
          viewedStories: p.getViewedStoryList,
          initialIndex: index,
          isRecentStoryView: recent,
        ),
      ),
    );
  }

  static String _name(String? full, String? first, String? user) {
    final f = (full ?? '').trim();
    if (f.isNotEmpty) return f;
    final fi = (first ?? '').trim();
    if (fi.isNotEmpty) return fi;
    final u = (user ?? '').trim();
    return u.isNotEmpty ? u : 'Someone';
  }
}

class _MyStoryCard extends StatelessWidget {
  const _MyStoryCard({required this.hasStory, required this.onTap});
  final bool hasStory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FpSurface(
      padding: const EdgeInsets.all(Fp.s16),
      radius: Fp.rLg,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: hasStory ? Fp.accent : null,
              color: hasStory ? null : Fp.violet.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasStory ? Icons.play_arrow_rounded : Icons.add_rounded,
              color: hasStory ? Colors.white : Fp.violet,
              size: 28,
            ),
          ),
          const SizedBox(width: Fp.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasStory ? 'Your story' : 'Add to your story',
                    style: Fp.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  hasStory
                      ? 'Tap to watch what you shared'
                      : 'Share a moment — it disappears in 24 hours',
                  style: Fp.caption.copyWith(color: Fp.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Fp.textFaint),
        ],
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.name,
    required this.imageUrl,
    required this.unseen,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool unseen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FpSurface(
      padding: const EdgeInsets.symmetric(
          horizontal: Fp.s16, vertical: Fp.s12),
      radius: Fp.rMd,
      onTap: onTap,
      child: Row(
        children: [
          Opacity(
            opacity: unseen ? 1 : 0.55,
            child: FpAvatar(
              imageUrl: imageUrl,
              label: name,
              size: 48,
              ring: unseen ? Fp.violet : Fp.textFaint,
            ),
          ),
          const SizedBox(width: Fp.s16),
          Expanded(
            child: Text(
              name,
              style: Fp.bodyStrong.copyWith(
                color: unseen ? Fp.text : Fp.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(unseen ? 'New' : 'Seen',
              style: Fp.caption.copyWith(
                color: unseen ? Fp.violet : Fp.textFaint,
              )),
        ],
      ),
    );
  }
}
