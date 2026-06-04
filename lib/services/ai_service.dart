import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candidate.dart';

abstract class AIService {
  Future<List<Candidate>> analyzeCandidates({
    required String jobDescription,
    required List<Map<String, dynamic>> resumes,
  });

  Future<bool> validateApiKey();
}

class AIFactory {
  static AIService getService(String provider, String apiKey, {
    String customPrompt = '',
    String companyContext = '',
    double weightSkills = 40,
    double weightExperience = 40,
    double weightCulture = 20,
  }) {
    switch (provider.toLowerCase()) {
      case 'claude':
        return ClaudeService(apiKey, customPrompt, companyContext, weightSkills, weightExperience, weightCulture);
      case 'openai':
      default:
        return OpenAIService(apiKey, customPrompt, companyContext, weightSkills, weightExperience, weightCulture);
    }
  }
}

// ============================================================================
// BASE SERVICE WITH SHARED LOGIC
// ============================================================================
abstract class BaseAIService implements AIService {
  final String apiKey;
  final String customPrompt;
  final String companyContext;
  final double weightSkills;
  final double weightExperience;
  final double weightCulture;

  BaseAIService(
    this.apiKey, 
    this.customPrompt, 
    this.companyContext, 
    this.weightSkills, 
    this.weightExperience, 
    this.weightCulture
  );

  static const int _topCandidatesForDeepReview = 5;

  @override
  Future<List<Candidate>> analyzeCandidates({
    required String jobDescription,
    required List<Map<String, dynamic>> resumes,
  }) async {
    if (jobDescription.trim().isEmpty) {
      throw Exception('Please paste a job description first.');
    }
    if (resumes.isEmpty) {
      throw Exception('Please upload or paste at least one resume.');
    }

    final requirements = await extractJobRequirements(jobDescription);

    final prelim = <_ScoredProfile>[];
    for (final resume in resumes) {
      final fileName = resume['name'] ?? 'Candidate';
      final content = resume['content'] ?? '';
      if (content.trim().isEmpty) continue;

      final profile = await extractResumeProfile(fileName, content);
      final score = _localScore(requirements, profile);
      prelim.add(_ScoredProfile(
        fileName: fileName,
        profile: profile,
        score: score,
        path: resume['path'],
        bytes: resume['bytes'],
      ));
    }

    prelim.sort((a, b) => b.score.compareTo(a.score));

    final results = <Candidate>[];
    for (var i = 0; i < prelim.length; i++) {
      final item = prelim[i];
      if (i < _topCandidatesForDeepReview) {
        final candidate = await deepReview(requirements, item.profile, item.score);
        candidate.pdfPath = item.path;
        candidate.pdfBytes = item.bytes;
        results.add(candidate);
      } else {
        final candidate = _candidateFromProfile(item.profile, item.score);
        candidate.pdfPath = item.path;
        candidate.pdfBytes = item.bytes;
        results.add(candidate);
      }
    }

    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return results;
  }

  Future<Map<String, dynamic>> extractJobRequirements(String jobDescription);
  Future<Map<String, dynamic>> extractResumeProfile(String fileName, String resumeText);
  Future<Candidate> deepReview(Map<String, dynamic> requirements, Map<String, dynamic> profile, double preliminaryScore);

  double _localScore(Map<String, dynamic> requirements, Map<String, dynamic> profile) {
    final requiredSkills = _stringList(requirements['requiredSkills']);
    final niceSkills = _stringList(requirements['niceToHaveSkills']);
    final candidateSkills = _stringList(profile['skills']);

    final requiredSkillScore = _coverage(requiredSkills, candidateSkills);
    final niceSkillScore = _coverage(niceSkills, candidateSkills);

    final minYears = _numValue(requirements['minimumYearsExperience']);
    final years = _numValue(profile['yearsExperience']);
    final experienceScore = minYears <= 0 ? 0.75 : (years / minYears).clamp(0.0, 1.0);

    // Without embeddings, weight keyword overlap more heavily
    final score = (requiredSkillScore * 65) + (experienceScore * 25) + (niceSkillScore * 10);
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

  Candidate _candidateFromProfile(Map<String, dynamic> profile, double score) {
    return Candidate.fromJson(_candidateJsonFromProfile(profile, score));
  }

  Map<String, dynamic> _candidateJsonFromProfile(Map<String, dynamic> profile, double score) {
    final skills = _stringList(profile['skills']).take(6).toList();
    final highlights = _stringList(profile['highlights']);
    return {
      'name': (profile['name'] ?? 'Candidate').toString(),
      'phone': profile['phone'] ?? '',
      'email': profile['email'] ?? '',
      'matchScore': score.round().clamp(0, 100),
      'matchLabel': _label(score),
      'experience': _numValue(profile['yearsExperience']).round(),
      'skills': skills,
      'aiSummary': highlights.isEmpty
          ? 'Ranked using structured extraction and local scoring.'
          : highlights.take(2).join(' '),
      'strengths': highlights.take(3).toList(),
      'potentialGaps': ['Not deep-reviewed to save cost. Review manually if they are near the cutoff.'],
      'interviewQuestions': [
        'Which project best demonstrates your fit for this role?',
        'Which required skill from the job description have you used most recently?'
      ],
    };
  }

  Map<String, dynamic> normalizeCandidateJson(Map<String, dynamic> json, Map<String, dynamic> profile, double fallbackScore) {
    json['matchScore'] ??= fallbackScore.round();
    json['matchLabel'] ??= _label(_numValue(json['matchScore']));
    json['experience'] ??= json['yearsExperience'] ?? profile['yearsExperience'] ?? 0;
    json['skills'] ??= <String>[];
    json['strengths'] ??= <String>[];
    json['potentialGaps'] ??= <String>[];
    json['interviewQuestions'] ??= <String>[];
    json['name'] ??= profile['name'];
    json['phone'] ??= profile['phone'];
    json['linkedin'] ??= profile['linkedin'];
    json['github'] ??= profile['github'];
    json['portfolio'] ??= profile['portfolio'];
    return json;
  }

  String _label(num score) {
    if (score >= 80) return 'STRONG MATCH';
    if (score >= 60) return 'MODERATE MATCH';
    return 'POTENTIAL';
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

  String trim(String value, int maxChars) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    return clean.substring(0, maxChars);
  }

  String cleanJson(String content) {
    return content.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  List<String> keywords(String text) {
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

  final Set<String> _stopWords = {
    'the', 'and', 'for', 'with', 'from', 'this', 'that', 'you', 'your', 'are', 'was', 'were', 'have', 'has',
    'will', 'can', 'our', 'their', 'they', 'them', 'job', 'role', 'resume', 'experience', 'work', 'team',
  };
}

// ============================================================================
// OPENAI SERVICE
// ============================================================================
class OpenAIService extends BaseAIService {
  OpenAIService(
    super.apiKey, 
    super.customPrompt, 
    super.companyContext, 
    super.weightSkills, 
    super.weightExperience, 
    super.weightCulture
  );

  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini';

  @override
  Future<Map<String, dynamic>> extractJobRequirements(String jobDescription) async {
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
${trim(jobDescription, 7000)}
''';
    return await _chatJson(prompt, 900, {
      'roleTitle': 'Open Role',
      'requiredSkills': keywords(jobDescription).take(12).toList(),
      'niceToHaveSkills': <String>[],
      'responsibilities': <String>[],
      'minimumYearsExperience': 0,
      'educationKeywords': <String>[],
    });
  }

  @override
  Future<Map<String, dynamic>> extractResumeProfile(String fileName, String resumeText) async {
    final prompt = '''
${customPrompt.isNotEmpty ? "CUSTOM RULES: $customPrompt\n" : ""}
Extract this resume into compact candidate JSON. Return JSON only.
Schema:
{
  "name": "string",
  "phone": "string",
  "email": "string",
  "linkedin": "string",
  "github": "string",
  "portfolio": "string",
  "yearsExperience": number,
  "skills": ["string"],
  "education": ["string"],
  "recentTitles": ["string"],
  "highlights": ["string"],
  "evidence": ["short proof points from resume"]
}
Use the file name if the candidate name is not clear: $fileName
Resume:
${trim(resumeText, 9000)}
''';
    return await _chatJson(prompt, 1000, {
      'name': fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      'phone': '',
      'linkedin': '',
      'github': '',
      'portfolio': '',
      'yearsExperience': 0,
      'skills': keywords(resumeText).take(15).toList(),
      'education': <String>[],
      'recentTitles': <String>[],
      'highlights': <String>[],
      'evidence': <String>[],
    });
  }

  @override
  Future<Candidate> deepReview(Map<String, dynamic> requirements, Map<String, dynamic> profile, double preliminaryScore) async {
    final prompt = '''
${companyContext.isNotEmpty ? "COMPANY CONTEXT: You are hiring for $companyContext.\n" : ""}
${customPrompt.isNotEmpty ? "CUSTOM RULES: $customPrompt\n" : ""}
SCORING WEIGHTS: 
- Technical Skills: $weightSkills%
- Experience & Pedigree: $weightExperience%
- Culture Fit & Soft Skills: $weightCulture%
You are a precise recruiting assistant. Compare the compact candidate profile against the compact job requirements.
Return ONE JSON object only.
Required JSON:
{
  "name": "string",
  "phone": "string",
  "email": "string",
  "matchScore": integer 0-100,
  "matchLabel": "STRONG MATCH" | "MODERATE MATCH" | "POTENTIAL",
  "experience": integer,
  "skills": ["top 4-6 relevant skills"],
  "aiSummary": "A detailed paragraph of at least 4-5 sentences and 80 words summarizing fitness for role",
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
    final json = await _chatJson(prompt, 900, _candidateJsonFromProfile(profile, preliminaryScore));
    return Candidate.fromJson(normalizeCandidateJson(json, profile, preliminaryScore));
  }

  Future<Map<String, dynamic>> _chatJson(String prompt, int maxTokens, Map<String, dynamic> fallback) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': _model,
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
      throw Exception('OpenAI Error: ${response.statusCode}');
    }

    try {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'].toString();
      final decoded = jsonDecode(cleanJson(content));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return fallback;
  }

  @override
  Future<bool> validateApiKey() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/models'), headers: {'Authorization': 'Bearer $apiKey'});
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// CLAUDE SERVICE
// ============================================================================
class ClaudeService extends BaseAIService {
  ClaudeService(
    super.apiKey, 
    super.customPrompt, 
    super.companyContext, 
    super.weightSkills, 
    super.weightExperience, 
    super.weightCulture
  );

  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-3-haiku-20240307';

  @override
  Future<Map<String, dynamic>> extractJobRequirements(String jobDescription) async {
    final prompt = '''
Extract hiring requirements from this job description. Return JSON only.
Schema: {"roleTitle": "string", "requiredSkills": ["string"], "niceToHaveSkills": ["string"], "responsibilities": ["string"], "minimumYearsExperience": number, "educationKeywords": ["string"]}
Job description: ${trim(jobDescription, 7000)}
''';
    return await _chatJson(prompt, {
      'roleTitle': 'Open Role',
      'requiredSkills': keywords(jobDescription).take(12).toList(),
      'niceToHaveSkills': <String>[],
      'responsibilities': <String>[],
      'minimumYearsExperience': 0,
      'educationKeywords': <String>[],
    });
  }

  @override
  Future<Map<String, dynamic>> extractResumeProfile(String fileName, String resumeText) async {
    final prompt = '''
${customPrompt.isNotEmpty ? "CUSTOM RULES: $customPrompt\n" : ""}
Extract this resume into compact candidate JSON. Return JSON only.
Schema: {"name": "string", "phone": "string", "email": "string", "linkedin": "string", "github": "string", "portfolio": "string", "yearsExperience": number, "skills": ["string"], "education": ["string"], "recentTitles": ["string"], "highlights": ["string"], "evidence": ["string"]}
File name: $fileName
Resume: ${trim(resumeText, 9000)}
''';
    return await _chatJson(prompt, {
      'name': fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      'phone': '',
      'email': '',
      'linkedin': '',
      'github': '',
      'portfolio': '',
      'yearsExperience': 0,
      'skills': keywords(resumeText).take(15).toList(),
      'education': <String>[],
      'recentTitles': <String>[],
      'highlights': <String>[],
      'evidence': <String>[],
    });
  }

  @override
  Future<Candidate> deepReview(Map<String, dynamic> requirements, Map<String, dynamic> profile, double preliminaryScore) async {
    final prompt = '''
${companyContext.isNotEmpty ? "COMPANY CONTEXT: You are hiring for $companyContext.\n" : ""}
${customPrompt.isNotEmpty ? "CUSTOM RULES: $customPrompt\n" : ""}
SCORING WEIGHTS: 
- Technical Skills: $weightSkills%
- Experience & Pedigree: $weightExperience%
- Culture Fit & Soft Skills: $weightCulture%
You are a precise recruiting assistant. Compare the compact candidate profile against the compact job requirements. Return ONE JSON object only.
For "aiSummary", write a comprehensive, detailed paragraph (at least 4 to 5 sentences and 80 words) summarizing the candidate's background, core competencies, and overall fitness for the role.
Required JSON Schema: {"name": "string", "phone": "string", "email": "string", "matchScore": integer, "matchLabel": "STRONG MATCH" | "MODERATE MATCH" | "POTENTIAL", "experience": integer, "skills": ["string"], "aiSummary": "string", "strengths": ["string"], "potentialGaps": ["string"], "interviewQuestions": ["string"], "company": "string", "previousCompany": "string", "primaryExperienceTitle": "string", "secondaryExperienceTitle": "string"}
Calibration local score: ${preliminaryScore.round()}
Job requirements JSON: ${jsonEncode(requirements)}
Candidate profile JSON: ${jsonEncode(profile)}
''';
    final json = await _chatJson(prompt, _candidateJsonFromProfile(profile, preliminaryScore));
    return Candidate.fromJson(normalizeCandidateJson(json, profile, preliminaryScore));
  }

  Future<Map<String, dynamic>> _chatJson(String prompt, Map<String, dynamic> fallback) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1000,
        'temperature': 0.2,
        'messages': [
          {'role': 'user', 'content': 'Return valid JSON only. No markdown.\n$prompt'}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude Error: ${response.statusCode}');
    }

    try {
      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'].toString();
      final decoded = jsonDecode(cleanJson(content));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return fallback;
  }

  @override
  Future<bool> validateApiKey() async {
    try {
      // Just test with a tiny request
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ]
        }),
      );
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
  final String? path;
  final List<int>? bytes;

  _ScoredProfile({
    required this.fileName,
    required this.profile,
    required this.score,
    this.path,
    this.bytes,
  });
}
