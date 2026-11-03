import 'package:whoxa/featuers/chat/data/chats_model.dart' as chats;

class PollOption {
  final int id;

  /// NEW's server-assigned opaque option id — the value the vote endpoint
  /// expects. Falls back to the positional `id` only for legacy polls.
  final String? serverOptionId;
  final String text;
  final List<chats.Votes> voters;

  PollOption({
    required this.id,
    this.serverOptionId,
    required this.text,
    this.voters = const [],
  });

  /// The id to send when voting for this option.
  String get voteId => serverOptionId ?? id.toString();

  int get voteCount => voters.length;

  bool hasVoted(String userId) =>
      voters.any((v) => v.userId.toString() == userId);

  chats.Votes? get firstVoter => voters.isNotEmpty ? voters.first : null;

  PollOption copyWith({List<chats.Votes>? voters}) {
    return PollOption(
      id: id,
      serverOptionId: serverOptionId,
      text: text,
      voters: voters ?? this.voters,
    );
  }
}

class PollData {
  final String question;
  final List<PollOption> options;
  final bool allowMultipleVotes;
  final String createdBy;
  final DateTime createdAt;

  PollData({
    required this.question,
    required this.options,
    this.allowMultipleVotes = false,
    required this.createdBy,
    required this.createdAt,
  });

  int get totalVotes =>
      options.fold(0, (sum, option) => sum + option.voteCount);

  // ✅ FIXED: Correctly maps chats.PollData → local PollData
  factory PollData.fromApiPollData({
    required chats.PollData apiPoll,
    required String currentUserId,
  }) {
    final rawOptions = apiPoll.options ?? [];
    // ✅ Use userVotes list now
    final userVotes = apiPoll.userVotes ?? [];

    final mappedOptions =
        rawOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final opt = entry.value;
          final voters = List<chats.Votes>.from(opt.votes ?? []);

          // ✅ Check against userVotes list instead of single userVote string
          final hasUserVotedThis = userVotes.contains(opt.option);
          if (hasUserVotedThis &&
              !voters.any((v) => v.userId.toString() == currentUserId)) {
            voters.add(
              chats.Votes(
                userId: int.tryParse(currentUserId),
                fullName: 'You',
                userName: '',
                profilePic: '',
              ),
            );
          }

          return PollOption(
            id: index,
            serverOptionId: opt.optionId,
            text: opt.option ?? '',
            voters: voters,
          );
        }).toList();

    return PollData(
      question: apiPoll.question ?? '',
      options: mappedOptions,
      allowMultipleVotes: apiPoll.allowMultipleVotes ?? false,
      createdBy: apiPoll.createdBy?.userId.toString() ?? '',
      createdAt: DateTime.now(),
    );
  }
}
