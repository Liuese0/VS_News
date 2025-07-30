// lib/models/issue.dart
class Issue {
  final int id;
  final String title;
  final String summary;
  final DateTime createdAt;
  final double positivePercent;
  final double negativePercent;
  final double debateScore;
  final int totalVotes;

  Issue({
    required this.id,
    required this.title,
    required this.summary,
    required this.createdAt,
    required this.positivePercent,
    required this.negativePercent,
    required this.debateScore,
    required this.totalVotes,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      createdAt: DateTime.parse(json['created_at']),
      positivePercent: (json['positive_percent'] ?? 0.0).toDouble(),
      negativePercent: (json['negative_percent'] ?? 0.0).toDouble(),
      debateScore: (json['debate_score'] ?? 0.0).toDouble(),
      totalVotes: json['total_votes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'created_at': createdAt.toIso8601String(),
      'positive_percent': positivePercent,
      'negative_percent': negativePercent,
      'debate_score': debateScore,
      'total_votes': totalVotes,
    };
  }
}