// lib/widgets/vote_dialog.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class VoteDialog extends StatefulWidget {
  final Issue issue;
  final Function(String) onVote;

  const VoteDialog({
    super.key,
    required this.issue,
    required this.onVote,
  });

  @override
  State<VoteDialog> createState() => _VoteDialogState();
}

class _VoteDialogState extends State<VoteDialog> {
  String? _selectedStance;
  bool _isVoting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      title: const Row(
        children: [
          Icon(Icons.how_to_vote, color: AppColors.primaryColor),
          SizedBox(width: 8),
          Text('투표하기'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.issue.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '이 이슈에 대한 당신의 의견은?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // 찬성 옵션
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedStance == 'pro'
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RadioListTile<String>(
              title: const Row(
                children: [
                  Icon(Icons.thumb_up, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('찬성', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              value: 'pro',
              groupValue: _selectedStance,
              activeColor: Colors.blue,
              onChanged: _isVoting ? null : (value) {
                setState(() {
                  _selectedStance = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),

          // 반대 옵션
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedStance == 'con'
                    ? Colors.red
                    : Colors.grey.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: RadioListTile<String>(
              title: const Row(
                children: [
                  Icon(Icons.thumb_down, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('반대', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              value: 'con',
              groupValue: _selectedStance,
              activeColor: Colors.red,
              onChanged: _isVoting ? null : (value) {
                setState(() {
                  _selectedStance = value;
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVoting ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _selectedStance == null || _isVoting
              ? null
              : () async {
            setState(() => _isVoting = true);
            await widget.onVote(_selectedStance!);
            setState(() => _isVoting = false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedStance == 'pro' ? Colors.blue : Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isVoting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text('투표하기'),
        ),
      ],
    );
  }
}