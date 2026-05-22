class Candidate {
  final String name;
  final int matchScore;
  final String matchLabel; // STRONG MATCH, MODERATE MATCH, POTENTIAL
  final int experience;
  final List<String> skills;
  final String aiSummary;
  final List<String> strengths;
  final List<String> potentialGaps;
  final List<String> interviewQuestions;

  Candidate({
    required this.name,
    required this.matchScore,
    required this.matchLabel,
    required this.experience,
    required this.skills,
    required this.aiSummary,
    required this.strengths,
    required this.potentialGaps,
    required this.interviewQuestions,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    List<String> toStringList(dynamic value) {
      if (value is List) return value.map((e) => e.toString()).toList();
      return <String>[];
    }

    return Candidate(
      name: (json['name'] ?? '').toString(),
      matchScore: toInt(json['matchScore']).clamp(0, 100).toInt(),
      matchLabel: (json['matchLabel'] ?? 'POTENTIAL').toString(),
      experience: toInt(json['experience']),
      skills: toStringList(json['skills']),
      aiSummary: (json['aiSummary'] ?? '').toString(),
      strengths: toStringList(json['strengths']),
      potentialGaps: toStringList(json['potentialGaps']),
      interviewQuestions: toStringList(json['interviewQuestions']),
    );
  }
}
