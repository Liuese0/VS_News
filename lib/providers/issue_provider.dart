// lib/providers/issue_provider.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class IssueProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Issue> _issues = [];
  bool _isLoading = false;
  String? _error;

  List<Issue> get issues => _issues;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadIssues({String sortBy = 'debate_score'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _issues = await _apiService.getIssues(sortBy: sortBy);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _issues = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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