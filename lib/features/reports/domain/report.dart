const reportReasons = <String, String>{
  'spam': 'Spam',
  'harassment': 'Harassment or bullying',
  'hate': 'Hate speech',
  'sexual': 'Sexual or inappropriate content',
  'violence': 'Violence or threats',
  'impersonation': 'Impersonation',
  'other': 'Something else',
};

const reportTypeLabels = <String, String>{
  'user': 'User',
  'post': 'Post',
  'comment': 'Comment',
  'message': 'Message',
  'community': 'Community',
};

const reportStatuses = ['pending', 'reviewing', 'resolved', 'rejected'];

class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reporterUsername,
    this.targetOwnerId,
    this.ownerUsername,
    this.snapshot,
    this.description,
    this.resolutionNote,
    this.reviewerUsername,
    this.reviewedAt,
  });

  final String id;
  final String reporterId;
  final String? reporterUsername;
  final String targetType;
  final String targetId;
  final String? targetOwnerId;
  final String? ownerUsername;
  final String? snapshot;
  final String reason;
  final String? description;
  final String status;
  final String? resolutionNote;
  final String? reviewerUsername;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  String get reasonLabel => reportReasons[reason] ?? reason;
  String get typeLabel => reportTypeLabels[targetType] ?? targetType;
  bool get isOpen => status == 'pending' || status == 'reviewing';

  factory Report.fromMap(Map<String, dynamic> m) => Report(
        id: m['id'] as String,
        reporterId: m['reporter_id'] as String,
        reporterUsername: m['reporter_username'] as String?,
        targetType: m['target_type'] as String,
        targetId: m['target_id'] as String,
        targetOwnerId: m['target_owner_id'] as String?,
        ownerUsername: m['owner_username'] as String?,
        snapshot: m['target_snapshot'] as String?,
        reason: m['reason'] as String,
        description: m['description'] as String?,
        status: m['status'] as String,
        resolutionNote: m['resolution_note'] as String?,
        reviewerUsername: m['reviewer_username'] as String?,
        reviewedAt: m['reviewed_at'] == null ? null : DateTime.parse(m['reviewed_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
