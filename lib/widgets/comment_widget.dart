// lib/widgets/comment_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class CommentWidget extends StatelessWidget {
  final Comment comment;

  const CommentWidget({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        border: Border.all(
          color: comment.isPro
              ? Colors.blue.withOpacity(0.3)
              : comment.isNeutral
              ? Colors.grey.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 찬반 뱃지
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenWidth * 0.01,
                ),
                decoration: BoxDecoration(
                  color: comment.isPro
                      ? Colors.blue.withOpacity(0.1)
                      : comment.isNeutral
                      ? Colors.grey.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  comment.isPro ? '찬성' : comment.isNeutral ? '중립' : '반대',
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    color: comment.isPro
                        ? Colors.blue
                        : comment.isNeutral
                        ? Colors.grey
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              // 닉네임
              Flexible(
                child: Text(
                  comment.nickname,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: screenWidth * 0.035,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // 작성 시간
              Text(
                DateFormat('MM/dd HH:mm').format(comment.createdAt),
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.02),
          // 댓글 내용
          Text(
            comment.content,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}