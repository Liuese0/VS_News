// lib/models/comment.dart
class Comment {
  final int id;
  final int issueId;
  final String userId;
  final String nickname;
  final String stance;
  final String content;
  final DateTime createdAt;
  final String? badge; // 배지 ('intellectual' 또는 'sophist')

  Comment({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.nickname,
    required this.stance,
    required this.content,
    required this.createdAt,
    this.badge,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      issueId: json['issue_id'],
      userId: json['user_id'],
      nickname: json['nickname'],
      stance: json['stance'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      badge: json['badge'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_id': issueId,
      'user_id': userId,
      'nickname': nickname,
      'stance': stance,
      'content': content,
      'badge': badge,
    };
  }

  bool get isPro => stance == 'pro';
  bool get isNeutral => stance == 'neutral';
  bool get isCon => stance == 'con';
  bool get hasIntellectualBadge => badge == 'intellectual';
  bool get hasSophistBadge => badge == 'sophist';
}