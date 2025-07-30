// lib/widgets/issue_card.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class IssueCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback onTap;

  const IssueCard({
    super.key,
    required this.issue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.padding),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 논쟁 지수 뱃지와 참여자 수
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getDebateScoreColor(issue.debateScore),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.whatshot,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '논쟁도 ${issue.debateScore.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${issue.totalVotes}명 참여',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 제목
            Text(
              issue.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // 요약
            Text(
              issue.summary,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // 찬반 비율 바
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: issue.positivePercent / 100,
                minHeight: 32,
                backgroundColor: Colors.red.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 찬반 비율 텍스트
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '찬성 ${issue.positivePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '반대 ${issue.negativePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getDebateScoreColor(double score) {
    if (score >= 80) return Colors.red;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.amber;
    return Colors.green;
  }
}