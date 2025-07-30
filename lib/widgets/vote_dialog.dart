import 'package:flutter/material.dart';
import '../models/models.dart';

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('투표하기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.issue.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          RadioListTile<String>(
            title: const Text('찬성'),
            value: 'pro',
            groupValue: _selectedStance,
            onChanged: (value) {
              setState(() {
                _selectedStance = value;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('반대'),
            value: 'con',
            groupValue: _selectedStance,
            onChanged: (value) {
              setState(() {
                _selectedStance = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _selectedStance == null
              ? null
              : () => widget.onVote(_selectedStance!),
          child: const Text('투표'),
        ),
      ],
    );
  }
}

