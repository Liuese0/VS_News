class Comment {
  final int id;
  final int issueId;
  final String userId;
  final String nickname;
  final String stance;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.nickname,
    required this.stance,
    required this.content,
    required this.createdAt,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_id': issueId,
      'user_id': userId,
      'nickname': nickname,
      'stance': stance,
      'content': content,
    };
  }

  bool get isPro => stance == 'pro';
}
