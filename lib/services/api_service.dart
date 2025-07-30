import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  // 이슈 목록 가져오기
  Future<List<Issue>> getIssues({String sortBy = 'debate_score'}) async {
    try {
      final response = await _dio.get('/issues', queryParameters: {
        'sort': sortBy,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Issue.fromJson(json)).toList();
      }
      throw Exception('Failed to load issues');
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 이슈 상세 정보 가져오기
  Future<Issue> getIssueDetail(int issueId) async {
    try {
      final response = await _dio.get('/issues/$issueId');

      if (response.statusCode == 200) {
        return Issue.fromJson(response.data['data']);
      }
      throw Exception('Failed to load issue detail');
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 이슈 관련 뉴스 가져오기
  Future<List<News>> getIssueNews(int issueId) async {
    try {
      final response = await _dio.get('/issues/$issueId/news');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => News.fromJson(json)).toList();
      }
      throw Exception('Failed to load news');
    } catch (e) {
      throw Exception('네트워크 오류: $e');
    }
  }

  // 투표하기
  Future<bool> vote(int issueId, String userId, String vote) async {
    try {
      final response = await _dio.post('/votes', data: {
        'issue_id': issueId,
        'user_id': userId,
        'vote': vote,
      });

      return response.statusCode == 201;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        throw Exception('이미 투표하셨습니다.');
      }
      throw Exception('투표 실패: $e');
    }
  }

  // 사용자 투표 확인
  Future<Vote?> getUserVote(int issueId, String userId) async {
    try {
      final response = await _dio.get('/votes/check', queryParameters: {
        'issue_id': issueId,
        'user_id': userId,
      });

      if (response.statusCode == 200 && response.data['data'] != null) {
        return Vote.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 댓글 가져오기
  Future<List<Comment>> getComments(int issueId, {String sort = 'recent'}) async {
    try {
      final response = await _dio.get('/issues/$issueId/comments', queryParameters: {
        'sort': sort,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Comment.fromJson(json)).toList();
      }
      throw Exception('Failed to load comments');
    } catch (e) {
      throw Exception('댓글 로딩 실패: $e');
    }
  }

  // 댓글 작성
  Future<bool> postComment(Comment comment) async {
    try {
      final response = await _dio.post('/comments', data: comment.toJson());
      return response.statusCode == 201;
    } catch (e) {
      throw Exception('댓글 작성 실패: $e');
    }
  }

  // 뉴스 검색 (News API 활용)
  Future<List<Map<String, dynamic>>> searchNews(String keyword) async {
    try {
      final response = await _dio.get('https://newsapi.org/v2/everything',
          queryParameters: {
            'q': keyword,
            'language': 'ko',
            'sortBy': 'relevancy',
            'apiKey': ApiConstants.newsApiKey,
          }
      );

      if (response.statusCode == 200) {
        final List<dynamic> articles = response.data['articles'];
        return articles.cast<Map<String, dynamic>>();
      }
      throw Exception('뉴스 검색 실패');
    } catch (e) {
      throw Exception('뉴스 API 오류: $e');
    }
  }
}