class UserSettings {
  const UserSettings({
    this.whoCanMessage = 'everyone',
    this.profileVisibility = 'everyone',
    this.whoCanMention = 'everyone',
    this.notifyMessages = true,
    this.notifyLikes = true,
    this.notifyComments = true,
    this.notifyFollows = true,
    this.notifyCommunities = true,
    this.notifySystem = true,
  });

  final String whoCanMessage; // everyone | following | nobody
  final String profileVisibility; // everyone | followers
  final String whoCanMention; // everyone | following | nobody
  final bool notifyMessages;
  final bool notifyLikes;
  final bool notifyComments;
  final bool notifyFollows;
  final bool notifyCommunities;
  final bool notifySystem;

  UserSettings copyWith({
    String? whoCanMessage,
    String? profileVisibility,
    String? whoCanMention,
    bool? notifyMessages,
    bool? notifyLikes,
    bool? notifyComments,
    bool? notifyFollows,
    bool? notifyCommunities,
    bool? notifySystem,
  }) =>
      UserSettings(
        whoCanMessage: whoCanMessage ?? this.whoCanMessage,
        profileVisibility: profileVisibility ?? this.profileVisibility,
        whoCanMention: whoCanMention ?? this.whoCanMention,
        notifyMessages: notifyMessages ?? this.notifyMessages,
        notifyLikes: notifyLikes ?? this.notifyLikes,
        notifyComments: notifyComments ?? this.notifyComments,
        notifyFollows: notifyFollows ?? this.notifyFollows,
        notifyCommunities: notifyCommunities ?? this.notifyCommunities,
        notifySystem: notifySystem ?? this.notifySystem,
      );

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'who_can_message': whoCanMessage,
        'profile_visibility': profileVisibility,
        'who_can_mention': whoCanMention,
        'notify_messages': notifyMessages,
        'notify_likes': notifyLikes,
        'notify_comments': notifyComments,
        'notify_follows': notifyFollows,
        'notify_communities': notifyCommunities,
        'notify_system': notifySystem,
      };

  factory UserSettings.fromMap(Map<String, dynamic> m) => UserSettings(
        whoCanMessage: (m['who_can_message'] as String?) ?? 'everyone',
        profileVisibility: (m['profile_visibility'] as String?) ?? 'everyone',
        whoCanMention: (m['who_can_mention'] as String?) ?? 'everyone',
        notifyMessages: (m['notify_messages'] as bool?) ?? true,
        notifyLikes: (m['notify_likes'] as bool?) ?? true,
        notifyComments: (m['notify_comments'] as bool?) ?? true,
        notifyFollows: (m['notify_follows'] as bool?) ?? true,
        notifyCommunities: (m['notify_communities'] as bool?) ?? true,
        notifySystem: (m['notify_system'] as bool?) ?? true,
      );
}
