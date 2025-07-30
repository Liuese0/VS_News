class Vote {
  final int id;
  final int issueId;
  final String userId;
  final String vote;
  final DateTime createdAt;

  Vote({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.vote,
    required this.createdAt,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id'],
      issueId: json['issue_id'],
      userId: json['user_id'],
      vote: json['vote'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_id': issueId,
      'user_id': userId,
      'vote': vote,
    };
  }
}