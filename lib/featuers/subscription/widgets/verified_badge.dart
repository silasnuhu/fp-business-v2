import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/subscription/provider/subscription_provider.dart';

/// The blue verification tick.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 22});

  final double size;

  static const Color blue = Color(0xFF1D9BF0);

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified_rounded, color: blue, size: size);
  }
}

/// A [VerifiedBadge] shown only while the logged-in user is premium.
class OwnVerifiedBadge extends StatelessWidget {
  const OwnVerifiedBadge({super.key, this.size = 22, this.leading = 0});

  final double size;

  /// Space before the tick (only built while the tick is shown).
  final double leading;

  @override
  Widget build(BuildContext context) {
    final premium = context.select<SubscriptionProvider, bool>(
      (p) => p.premiumUser,
    );
    if (!premium) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: leading),
      child: VerifiedBadge(size: size),
    );
  }
}

/// A user's name followed by the blue tick when the backend marks them
/// `premiumUser`. The name ellipsizes before the tick is pushed out.
class UserNameWithBadge extends StatelessWidget {
  const UserNameWithBadge({
    super.key,
    required this.userId,
    required this.name,
    this.style,
    this.badgeSize = 16,
    this.maxLines = 1,
    this.textAlign,
  });

  /// Null for groups and anything that is not a single user.
  final int? userId;
  final String name;
  final TextStyle? style;
  final double badgeSize;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (userId == null) return text;

    return ValueListenableBuilder<Set<int>>(
      valueListenable: ContactNameService.instance.premiumUsers,
      builder: (context, premium, _) {
        if (!premium.contains(userId)) return text;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              textAlign == TextAlign.center
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
          children: [
            Flexible(child: text),
            const SizedBox(width: 4),
            VerifiedBadge(size: badgeSize),
          ],
        );
      },
    );
  }
}

/// Just the blue tick for [userId], when the backend marks them `premiumUser`
/// (nothing otherwise). For places that build their own name text.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.userId, this.size = 15});

  final int? userId;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();
    return ValueListenableBuilder<Set<int>>(
      valueListenable: ContactNameService.instance.premiumUsers,
      builder: (context, premium, _) {
        if (!premium.contains(userId)) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: VerifiedBadge(size: size),
        );
      },
    );
  }
}
