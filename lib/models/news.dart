class News {
  final int id;
  final int issueId;
  final String stance;
  final String title;
  final String summary;
  final String url;
  final DateTime createdAt;

  News({
    required this.id,
    required this.issueId,
    required this.stance,
    required this.title,
    required this.summary,
    required this.url,
    required this.createdAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'],
      issueId: json['issue_id'],
      stance: json['stance'],
      title: json['title'],
      summary: json['summary'],
      url: json['url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isPro => stance == 'pro';
}
