import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/candidate.dart';

class OpenAIService {
  final String apiKey;

  OpenAIService(this.apiKey);

  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _extractModel = 'gpt-4o-mini';
  static const String _finalModel = 'gpt-4.1-mini';
  static const String _embeddingModel = 'text-embedding-3-small';
  static const int _topCandidatesForDeepReview = 5;

  /// Cost-efficient pipeline:
  /// 1. Extract compact job requirements once.
  /// 2. Extract each resume into compact JSON one at a time.
  /// 3. Use embeddings + local scoring to rank every candidate cheaply.
  /// 4. Use GPT deep review only for the top candidates.
  Future<List<Candidate>> analyzeCandidates({
    required String jobDescription,
    required List<Map<String, String>> resumes,
  }) async {
    if (jobDescription.trim().isEmpty) {
      throw Exception('Please paste a job description first.');
    }
    if (resumes.isEmpty) {
      throw Exception('Please upload or paste at least one resume.');
    }

    final requirements = await _extractJobRequirements(jobDescription);
    final jdEmbedding = await _createEmbedding(_compactJobText(requirements, jobDescription));

    final prelim = <_ScoredProfile>[];
    for (final resume in resumes) {
      final fileName = resume['name'] ?? 'Candidate';
      final content = resume['content'] ?? '';
      if (content.trim().isEmpty) continue;

      final profile = await _extractResumeProfile(fileName, content);
      final resumeEmbedding = await _createEmbedding(_compactResumeText(profile, content));
      final score = _localScore(requirements, profile, jdEmbedding, resumeEmbedding);
      prelim.add(_ScoredProfile(fileName: fileName, profile: profile, score: score));
    }

    prelim.sort((a, b) => b.score.compareTo(a.score));

    final results = <Candidate>[];
    for (var i = 0; i < prelim.length; i++) {
      final item = prelim[i];
      if (i < _topCandidatesForDeepReview) {
        results.add(await _deepReview(requirements, item.profile, item.score));
      } else {
        results.add(_candidateFromProfile(item.profile, item.score));
      }
    }

    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return results;
  }

  Future<Map<String, dynamic>> _extractJobRequirements(String jobDescription) async {
    final prompt = '''
Extract hiring requirements from this job description. Return JSON only.

Schema:
{
  "roleTitle": "string",
  "requiredSkills": ["string"],
  "niceToHaveSkills": ["string"],
  "responsibilities": ["string"],
  "minimumYearsExperience": number,
  "educationKeywords": ["string"]
}

Job description:
${_trim(jobDescription, 7000)}
''';

    return await _chatJson(
      model: _extractModel,
      prompt: prompt,
      maxTokens: 900,
      fallback: {
        'roleTitle': 'Open Role',
        'requiredSkills': _keywords(jobDescription).take(12).toList(),
        'niceToHaveSkills': <String>[],
        'responsibilities': <String>[],
        'minimumYearsExperience': 0,
        'educationKeywords': <String>[],
      },
    );
  }

  Future<Map<String, dynamic>> _extractResumeProfile(String fileName, String resumeText) async {
    final prompt = '''
Extract this resume into compact candidate JSON. Return JSON only.

Schema:
{
  "name": "string",
  "yearsExperience": number,
  "skills": ["string"],
  "education": ["string"],
  "recentTitles": ["string"],
  "highlights": ["string"],
  "evidence": ["short proof points from resume"]
}

Use the file name if the candidate name is not clear: $fileName
Resume:
${_trim(resumeText, 9000)}
''';

    return await _chatJson(
      model: _extractModel,
      prompt: prompt,
      maxTokens: 1000,
      fallback: {
        'name': fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
        'yearsExperience': 0,
        'skills': _keywords(resumeText).take(15).toList(),
        'education': <String>[],
        'recentTitles': <String>[],
        'highlights': <String>[],
        'evidence': <String>[],
      },
    );
  }

  Future<Candidate> _deepReview(
    Map<String, dynamic> requirements,
    Map<String, dynamic> profile,
    double preliminaryScore,
  ) async {
    final prompt = '''
You are a precise recruiting assistant. Compare the compact candidate profile against the compact job requirements.
Return ONE JSON object only.

Required JSON:
{
  "name": "string",
  "matchScore": integer 0-100,
  "matchLabel": "STRONG MATCH" | "MODERATE MATCH" | "POTENTIAL",
  "experience": integer,
  "skills": ["top 4-6 relevant skills"],
  "aiSummary": "2 concise sentences",
  "strengths": ["3 strengths"],
  "potentialGaps": ["2-3 gaps"],
  "interviewQuestions": ["2 tailored questions"]
}

Use this preliminary local score as a calibration signal: ${preliminaryScore.round()}

Job requirements JSON:
${jsonEncode(requirements)}

Candidate profile JSON:
${jsonEncode(profile)}
''';

    final json = await _chatJson(
      model: _finalModel,
      prompt: prompt,
      maxTokens: 900,
      fallback: _candidateJsonFromProfile(profile, preliminaryScore),
    );

    return Candidate.fromJson(_normalizeCandidateJson(json, preliminaryScore));
  }

  Future<Map<String, dynamic>> _chatJson({
    required String model,
    required String prompt,
    required int maxTokens,
    required Map<String, dynamic> fallback,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: _headers,
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': 'Return valid JSON only. No markdown.'},
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.2,
        'max_tokens': maxTokens,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      final message = _apiErrorMessage(response.body, response.statusCode);
      throw Exception(message);
    }

    try {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'].toString();
      final decoded = jsonDecode(_cleanJson(content));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  Future<List<double>> _createEmbedding(String input) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/embeddings'),
      headers: _headers,
      body: jsonEncode({
        'model': _embeddingModel,
        'input': _trim(input, 8000),
      }),
    );

    if (response.statusCode != 200) {
      final message = _apiErrorMessage(response.body, response.statusCode);
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    return (data['data'][0]['embedding'] as List).map((e) => (e as num).toDouble()).toList();
  }

  double _localScore(
    Map<String, dynamic> requirements,
    Map<String, dynamic> profile,
    List<double> jdEmbedding,
    List<double> resumeEmbedding,
  ) {
    final requiredSkills = _stringList(requirements['requiredSkills']);
    final niceSkills = _stringList(requirements['niceToHaveSkills']);
    final candidateSkills = _stringList(profile['skills']);

    final requiredSkillScore = _coverage(requiredSkills, candidateSkills);
    final niceSkillScore = _coverage(niceSkills, candidateSkills);
    final semanticScore = ((_cosine(jdEmbedding, resumeEmbedding) + 1) / 2).clamp(0.0, 1.0);

    final minYears = _numValue(requirements['minimumYearsExperience']);
    final years = _numValue(profile['yearsExperience']);
    final experienceScore = minYears <= 0 ? 0.75 : (years / minYears).clamp(0.0, 1.0);

    final score =
        (requiredSkillScore * 45) + (semanticScore * 30) + (experienceScore * 15) + (niceSkillScore * 10);
    return score.clamp(0, 100).toDouble();
  }

  double _coverage(List<String> required, List<String> actual) {
    if (required.isEmpty) return 0.7;
    final actualNorm = actual.map(_norm).where((e) => e.isNotEmpty).toList();
    var hits = 0;
    for (final skill in required) {
      final s = _norm(skill);
      if (s.isEmpty) continue;
      if (actualNorm.any((a) => a.contains(s) || s.contains(a))) hits++;
    }
    return (hits / required.length).clamp(0.0, 1.0).toDouble();
  }

  double _cosine(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    if (n == 0) return 0;
    var dot = 0.0;
    var magA = 0.0;
    var magB = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    if (magA == 0 || magB == 0) return 0;
    return dot / (sqrt(magA) * sqrt(magB));
  }

  Candidate _candidateFromProfile(Map<String, dynamic> profile, double score) {
    return Candidate.fromJson(_candidateJsonFromProfile(profile, score));
  }

  Map<String, dynamic> _candidateJsonFromProfile(Map<String, dynamic> profile, double score) {
    final skills = _stringList(profile['skills']).take(6).toList();
    final highlights = _stringList(profile['highlights']);
    return {
      'name': (profile['name'] ?? 'Candidate').toString(),
      'matchScore': score.round().clamp(0, 100),
      'matchLabel': _label(score),
      'experience': _numValue(profile['yearsExperience']).round(),
      'skills': skills,
      'aiSummary': highlights.isEmpty
          ? 'This candidate was ranked using low-cost structured extraction, embeddings, and local scoring.'
          : highlights.take(2).join(' '),
      'strengths': highlights.take(3).toList(),
      'potentialGaps': ['Not deep-reviewed to save cost. Review manually if they are near the cutoff.'],
      'interviewQuestions': [
        'Which project best demonstrates your fit for this role?',
        'Which required skill from the job description have you used most recently?'
      ],
    };
  }

  Map<String, dynamic> _normalizeCandidateJson(Map<String, dynamic> json, double fallbackScore) {
    json['matchScore'] ??= fallbackScore.round();
    json['matchLabel'] ??= _label(_numValue(json['matchScore']));
    json['experience'] ??= json['yearsExperience'] ?? 0;
    json['skills'] ??= <String>[];
    json['strengths'] ??= <String>[];
    json['potentialGaps'] ??= <String>[];
    json['interviewQuestions'] ??= <String>[];
    return json;
  }

  String _label(num score) {
    if (score >= 80) return 'STRONG MATCH';
    if (score >= 60) return 'MODERATE MATCH';
    return 'POTENTIAL';
  }

  String _compactJobText(Map<String, dynamic> reqs, String fallback) {
    return '${reqs['roleTitle']} ${_stringList(reqs['requiredSkills']).join(' ')} '
        '${_stringList(reqs['niceToHaveSkills']).join(' ')} '
        '${_stringList(reqs['responsibilities']).join(' ')} ${_trim(fallback, 2500)}';
  }

  String _compactResumeText(Map<String, dynamic> profile, String fallback) {
    return '${profile['name']} ${_stringList(profile['skills']).join(' ')} '
        '${_stringList(profile['recentTitles']).join(' ')} '
        '${_stringList(profile['highlights']).join(' ')} ${_trim(fallback, 2500)}';
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    return <String>[];
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _norm(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+#. ]'), '').trim();

  String _trim(String value, int maxChars) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    return clean.substring(0, maxChars);
  }

  String _cleanJson(String content) {
    return content.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  List<String> _keywords(String text) {
    final words = RegExp(r'[A-Za-z][A-Za-z0-9+#.]{2,}').allMatches(text).map((m) => m.group(0)!).toList();
    final counts = <String, int>{};
    for (final word in words) {
      final key = word.toLowerCase();
      if (_stopWords.contains(key)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(30).map((e) => e.key).toList();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  String _apiErrorMessage(String body, int statusCode) {
    try {
      final error = jsonDecode(body);
      return error['error']?['message']?.toString() ?? 'OpenAI API error: $statusCode';
    } catch (_) {
      return 'OpenAI API error: $statusCode';
    }
  }

  Future<bool> validateApiKey() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/models'), headers: _headers);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class _ScoredProfile {
  final String fileName;
  final Map<String, dynamic> profile;
  final double score;

  _ScoredProfile({required this.fileName, required this.profile, required this.score});
}

const Set<String> _stopWords = {
  'the', 'and', 'for', 'with', 'from', 'this', 'that', 'you', 'your', 'are', 'was', 'were', 'have', 'has',
  'will', 'can', 'our', 'their', 'they', 'them', 'job', 'role', 'resume', 'experience', 'work', 'team',
};
