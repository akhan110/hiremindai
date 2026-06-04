class Candidate {
  final String name;
  final String phone;
  final String email;
  final int matchScore;
  final String matchLabel;
  final int experience;
  final List<String> skills;
  final String aiSummary;
  final List<String> strengths;
  final List<String> potentialGaps;
  final List<String> interviewQuestions;
  final String company;
  final String previousCompany;
  final String primaryExperienceTitle;
  final String secondaryExperienceTitle;
  final String linkedin;
  final String github;
  final String portfolio;

  // Pipeline Fields
  bool isShortlisted;
  String pipelineStatus;
  String? pdfPath;
  List<int>? pdfBytes; // Note: Uint8List causes issues with json decoding without importing dart:typed_data, using List<int> instead

  Candidate({
    required this.name,
    required this.phone,
    required this.email,
    required this.matchScore,
    required this.matchLabel,
    required this.experience,
    required this.skills,
    required this.aiSummary,
    required this.strengths,
    required this.potentialGaps,
    required this.interviewQuestions,
    required this.company,
    required this.previousCompany,
    required this.primaryExperienceTitle,
    required this.secondaryExperienceTitle,
    required this.linkedin,
    required this.github,
    required this.portfolio,
    this.isShortlisted = false,
    this.pipelineStatus = 'Not Contacted',
    this.pdfPath,
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
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      matchScore: toInt(json['matchScore']).clamp(0, 100).toInt(),
      matchLabel: (json['matchLabel'] ?? 'POTENTIAL').toString(),
      experience: toInt(json['experience']),
      skills: toStringList(json['skills']),
      aiSummary: (json['aiSummary'] ?? '').toString(),
      strengths: toStringList(json['strengths']),
      potentialGaps: toStringList(json['potentialGaps']),
      interviewQuestions: toStringList(json['interviewQuestions']),
      company: (json['company'] ?? '').toString(),
      previousCompany: (json['previousCompany'] ?? '').toString(),
      primaryExperienceTitle: (json['primaryExperienceTitle'] ?? '').toString(),
      secondaryExperienceTitle: (json['secondaryExperienceTitle'] ?? '').toString(),
      linkedin: (json['linkedin'] ?? '').toString(),
      github: (json['github'] ?? '').toString(),
      portfolio: (json['portfolio'] ?? '').toString(),
      isShortlisted: json['isShortlisted'] == true,
      pipelineStatus: (json['pipelineStatus'] ?? 'Not Contacted').toString(),
      pdfPath: json['pdfPath']?.toString(),
    );
  }
}
