import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candidate.dart';

abstract class AIService {
  Future<List<Candidate>> analyzeCandidates({
    required String jobDescription,
    required List<Map<String, dynamic>> resumes,
  });

  Future<bool> validateApiKey();

  Future<String> optimizeJobDescription(String currentDesc);

  Future<String> generateJobDescription(String rolePrompt);

  Future<String> atsOptimizeResume({required String resumeText, required String jobDescription});
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
      case 'gemini':
        return GeminiService(apiKey, customPrompt, companyContext, weightSkills, weightExperience, weightCulture);
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

    final prelimFutures = resumes.map((resume) async {
      final fileName = resume['name'] ?? 'Candidate';
      final content = resume['content'] ?? '';
      if (content.trim().isEmpty) return null;

      final profile = _extractLocalProfile(fileName, content);
      final score = _localScore(requirements, profile);
      return _ScoredProfile(
        fileName: fileName,
        profile: profile,
        score: score,
        path: resume['path'],
        bytes: resume['bytes'],
        rawText: content,
      );
    });

    final prelimResults = await Future.wait(prelimFutures);
    final prelim = prelimResults.whereType<_ScoredProfile>().toList();

    prelim.sort((a, b) => b.score.compareTo(a.score));

    final results = <Candidate>[];
    for (var i = 0; i < prelim.length; i++) {
      final item = prelim[i];
      if (i < _topCandidatesForDeepReview) {
        // Run sequentially to prevent rate limiting (429 errors)
        final candidate = await deepReview(requirements, item.rawText, item.fileName, item.score);
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
  Future<Candidate> deepReview(Map<String, dynamic> requirements, String resumeText, String fileName, double preliminaryScore);

  Map<String, dynamic> _extractLocalProfile(String fileName, String content) {
    return {
      'name': fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
      'skills': keywords(content).take(20).toList(),
      'yearsExperience': 0, // Fallback locally, LLM will refine in deep review
      'phone': '',
      'email': '',
      'highlights': <String>[],
    };
  }

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
  Future<Candidate> deepReview(Map<String, dynamic> requirements, String resumeText, String fileName, double preliminaryScore) async {
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
Candidate Resume File Name: $fileName
Candidate Resume Text:
${trim(resumeText, 9000)}
''';
    final fallbackProfile = _extractLocalProfile(fileName, resumeText);
    final json = await _chatJson(prompt, 900, _candidateJsonFromProfile(fallbackProfile, preliminaryScore));
    return Candidate.fromJson(normalizeCandidateJson(json, fallbackProfile, preliminaryScore));
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

  @override
  Future<String> optimizeJobDescription(String currentDesc) async {
    if (currentDesc.trim().isEmpty) return '';
    final prompt = '''
You are an expert technical recruiter. Please optimize and improve the following job description to make it professional, engaging, and clear. 
Fix any typos, improve the formatting, and ensure it highlights the requirements well. Only return the improved job description text, nothing else.

Current Job Description:
$currentDesc
''';
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
      }),
    );
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } catch (_) {}
    }
    return currentDesc; // fallback
  }

  @override
  Future<String> generateJobDescription(String rolePrompt) async {
    if (rolePrompt.trim().isEmpty) return '';
    final prompt = '''
You are an expert technical recruiter. Please generate a professional, engaging, and clear job description for the following role: "$rolePrompt".
The job description should be about 6 to 7 lines long and include a brief overview, key responsibilities, and main requirements. 
Return ONLY the job description text, nothing else.
''';
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
      }),
    );
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } catch (_) {}
    }
    throw Exception('Failed to generate job description.');
  }

  @override
  Future<String> atsOptimizeResume({required String resumeText, required String jobDescription}) async {
    if (resumeText.trim().isEmpty) return '';
    final prompt = '''
You are an expert ATS (Applicant Tracking System) optimization assistant. 
Rewrite the following resume so that it passes ATS systems with the highest possible match rate for the provided job description.
Follow these rules strictly:
1. Do not hallucinate or invent non-existent experience.
2. Naturally integrate as many keywords from the job description as possible into the bullet points.
3. Use clean, standard section headings (e.g., "Professional Experience", "Skills", "Education").
4. Rephrase bullet points to be impact-driven (Action Verb + Context + Result) and align with the role's requirements.
5. Return ONLY the rewritten resume content in clear Markdown formatting. Do not include any introductory or concluding conversational text.

Target Job Description:
${trim(jobDescription, 5000)}

Original Resume:
${trim(resumeText, 8000)}
''';
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
      }),
    );
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'].toString().trim();
        if (content.startsWith('```markdown')) {
          content = content.substring(11);
        } else if (content.startsWith('```')) {
          content = content.substring(3);
        }
        if (content.endsWith('```')) {
          content = content.substring(0, content.length - 3);
        }
        return content.trim();
      } catch (_) {}
    }
    throw Exception('Failed to optimize resume with OpenAI.');
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
  Future<Candidate> deepReview(Map<String, dynamic> requirements, String resumeText, String fileName, double preliminaryScore) async {
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
Candidate Resume File Name: $fileName
Candidate Resume Text: ${trim(resumeText, 9000)}
''';
    final fallbackProfile = _extractLocalProfile(fileName, resumeText);
    final json = await _chatJson(prompt, _candidateJsonFromProfile(fallbackProfile, preliminaryScore));
    return Candidate.fromJson(normalizeCandidateJson(json, fallbackProfile, preliminaryScore));
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

  @override
  Future<String> optimizeJobDescription(String currentDesc) async {
    if (currentDesc.trim().isEmpty) return '';
    final prompt = '''
You are an expert technical recruiter. Please optimize and improve the following job description to make it professional, engaging, and clear. 
Fix any typos, improve the formatting, and ensure it highlights the requirements well. Only return the improved job description text, nothing else.

Current Job Description:
$currentDesc
''';
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
        'temperature': 0.7,
        'messages': [
          {'role': 'user', 'content': prompt}
        ]
      }),
    );
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'].toString().trim();
      } catch (_) {}
    }
    return currentDesc; // fallback
  }

  @override
  Future<String> generateJobDescription(String rolePrompt) async {
    if (rolePrompt.trim().isEmpty) return '';
    final prompt = '''
You are an expert technical recruiter. Please generate a professional, engaging, and clear job description for the following role: "$rolePrompt".
The job description should be about 6 to 7 lines long and include a brief overview, key responsibilities, and main requirements. 
Return ONLY the job description text, nothing else.
''';
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
        'temperature': 0.7,
        'messages': [
          {'role': 'user', 'content': prompt}
        ]
      }),
    );
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'].toString().trim();
      } catch (_) {}
    }
    throw Exception('Failed to generate job description.');
  }

  @override
  Future<String> atsOptimizeResume({required String resumeText, required String jobDescription}) async {
    if (resumeText.trim().isEmpty) return '';
    final prompt = '''
You are an expert ATS (Applicant Tracking System) optimization assistant. 
Rewrite the following resume so that it passes ATS systems with the highest possible match rate for the provided job description.
Follow these rules strictly:
1. Do not hallucinate or invent non-existent experience.
2. Naturally integrate as many keywords from the job description as possible into the bullet points.
3. Use clean, standard section headings (e.g., "Professional Experience", "Skills", "Education").
4. Rephrase bullet points to be impact-driven (Action Verb + Context + Result) and align with the role's requirements.
5. Return ONLY the rewritten resume content in clear Markdown formatting. Do not include any introductory or concluding conversational text.

Target Job Description:
${trim(jobDescription, 5000)}

Original Resume:
${trim(resumeText, 8000)}
''';
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 2500,
        'temperature': 0.4,
        'messages': [
          {'role': 'user', 'content': prompt}
        ]
      }),
    );
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'].toString().trim();
      } catch (_) {}
    }
    throw Exception('Failed to optimize resume with Claude.');
  }
}

class _ScoredProfile {
  final String fileName;
  final Map<String, dynamic> profile;
  final double score;
  final String? path;
  final List<int>? bytes;
  final String rawText;

  _ScoredProfile({
    required this.fileName,
    required this.profile,
    required this.score,
    this.path,
    this.bytes,
    required this.rawText,
  });
}

// ============================================================================
// GEMINI SERVICE
// ============================================================================
class GeminiService extends BaseAIService {
  GeminiService(
    super.apiKey, 
    super.customPrompt, 
    super.companyContext, 
    super.weightSkills, 
    super.weightExperience, 
    super.weightCulture
  );

  static const String _model = 'gemini-2.5-flash';

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
  Future<Candidate> deepReview(Map<String, dynamic> requirements, String resumeText, String fileName, double preliminaryScore) async {
    final prompt = '''
${companyContext.isNotEmpty ? "COMPANY CONTEXT: You are hiring for $companyContext.\\n" : ""}
${customPrompt.isNotEmpty ? "CUSTOM RULES: $customPrompt\\n" : ""}
SCORING WEIGHTS: 
- Technical Skills: $weightSkills%
- Experience & Pedigree: $weightExperience%
- Culture Fit & Soft Skills: $weightCulture%
You are a precise recruiting assistant. Compare the compact candidate profile against the compact job requirements. Return ONE JSON object only.
For "aiSummary", write a comprehensive, detailed paragraph (at least 4 to 5 sentences and 80 words) summarizing the candidate's background, core competencies, and overall fitness for the role.
Required JSON Schema: {"name": "string", "phone": "string", "email": "string", "matchScore": integer, "matchLabel": "STRONG MATCH" | "MODERATE MATCH" | "POTENTIAL", "experience": integer, "skills": ["string"], "aiSummary": "string", "strengths": ["string"], "potentialGaps": ["string"], "interviewQuestions": ["string"], "company": "string", "previousCompany": "string", "primaryExperienceTitle": "string", "secondaryExperienceTitle": "string"}
Calibration local score: ${preliminaryScore.round()}
Job requirements JSON: ${jsonEncode(requirements)}
Candidate Resume File Name: $fileName
Candidate Resume Text: ${trim(resumeText, 9000)}
''';
    final fallbackProfile = _extractLocalProfile(fileName, resumeText);
    final json = await _chatJson(prompt, _candidateJsonFromProfile(fallbackProfile, preliminaryScore));
    return Candidate.fromJson(normalizeCandidateJson(json, fallbackProfile, preliminaryScore));
  }

  Future<Map<String, dynamic>> _chatJson(String prompt, Map<String, dynamic> fallback) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': 'Return valid JSON only. No markdown.\\n$prompt'}]}
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json'
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini Error ${response.statusCode}: ${response.body}');
    }

    try {
      final data = jsonDecode(response.body);
      final content = data['candidates'][0]['content']['parts'][0]['text'].toString();
      final decoded = jsonDecode(cleanJson(content));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return fallback;
  }

  @override
  Future<bool> validateApiKey() async {
    try {
      final response = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> optimizeJobDescription(String currentDesc) async {
    if (currentDesc.trim().isEmpty) return '';
    final prompt = '''
You are an expert technical recruiter. Please optimize and improve the following job description to make it professional, engaging, and clear. 
Fix any typos, improve the formatting, and ensure it highlights the requirements well. Only return the improved job description text, nothing else.

Current Job Description:
$currentDesc
''';
    return await _generateText(prompt, currentDesc);
  }

  @override
  Future<String> generateJobDescription(String rolePrompt) async {
    if (rolePrompt.trim().isEmpty) return '';
    final prompt = '''
You are an expert technical recruiter. Please generate a professional, engaging, and clear job description for the following role: "$rolePrompt".
The job description should be about 6 to 7 lines long and include a brief overview, key responsibilities, and main requirements. 
Return ONLY the job description text, nothing else.
''';
    final result = await _generateText(prompt, '');
    if (result.isEmpty) throw Exception('Failed to generate job description.');
    return result;
  }

  @override
  Future<String> atsOptimizeResume({required String resumeText, required String jobDescription}) async {
    if (resumeText.trim().isEmpty) return '';
    final prompt = '''
You are an expert ATS (Applicant Tracking System) optimization assistant. 
Rewrite the following resume so that it passes ATS systems with the highest possible match rate for the provided job description.
Follow these rules strictly:
1. Do not hallucinate or invent non-existent experience.
2. Naturally integrate as many keywords from the job description as possible into the bullet points.
3. Use clean, standard section headings (e.g., "Professional Experience", "Skills", "Education").
4. Rephrase bullet points to be impact-driven (Action Verb + Context + Result) and align with the role's requirements.
5. Return ONLY the rewritten resume content in clear Markdown formatting. Do not include any introductory or concluding conversational text.

Target Job Description:
${trim(jobDescription, 5000)}

Original Resume:
${trim(resumeText, 8000)}
''';
    final result = await _generateText(prompt, '');
    if (result.isEmpty) throw Exception('Failed to optimize resume with Gemini.');
    
    String content = result;
    if (content.startsWith('```markdown')) {
      content = content.substring(11);
    } else if (content.startsWith('```')) {
      content = content.substring(3);
    }
    if (content.endsWith('```')) {
      content = content.substring(0, content.length - 3);
    }
    return content.trim();
  }

  Future<String> _generateText(String prompt, String fallback) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {
          'temperature': 0.7,
        }
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Gemini Error ${response.statusCode}: ${response.body}');
    }
    try {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
    } catch (_) {}
    return fallback;
  }
}
