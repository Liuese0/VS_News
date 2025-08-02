// lib/providers/issue_provider.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class IssueProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Issue> _issues = [];
  Map<int, bool> _userVotes = {}; // 이슈별 사용자 투표 여부 저장
  bool _isLoading = false;
  String? _error;

  List<Issue> get issues => _issues;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 사용자가 특정 이슈에 투표했는지 확인
  bool hasUserVoted(int issueId, String userId) {
    return _userVotes[issueId] ?? false;
  }

  Future<void> loadIssues({String sortBy = 'debate_score'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _issues = await _apiService.getIssues(sortBy: sortBy);
      _error = null;

      // 사용자 투표 여부 확인 (실제 구현 시 API 호출 필요)
      // 여기서는 임시로 처리
      await _loadUserVotes();
    } catch (e) {
      _error = e.toString();
      _issues = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 사용자의 투표 여부를 로드하는 메서드
  Future<void> _loadUserVotes() async {
    // 실제 구현에서는 API를 통해 사용자의 투표 정보를 가져와야 합니다
    // 임시로 몇 개의 이슈에 대해 투표한 것으로 설정
    _userVotes.clear();

    // 예시: 첫 번째와 세 번째 이슈에 투표한 것으로 설정
    if (_issues.isNotEmpty) {
      _userVotes[_issues[0].id] = true;
      if (_issues.length > 2) {
        _userVotes[_issues[2].id] = true;
      }
    }
  }

  // 사용자가 투표했을 때 호출
  void markAsVoted(int issueId) {
    _userVotes[issueId] = true;
    notifyListeners();
  }

  Future<void> refreshIssues() async {
    await loadIssues();
  }

  void updateIssue(Issue updatedIssue) {
    final index = _issues.indexWhere((issue) => issue.id == updatedIssue.id);
    if (index != -1) {
      _issues[index] = updatedIssue;
      notifyListeners();
    }
  }
}