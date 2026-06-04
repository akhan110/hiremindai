import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/candidate.dart';

class ReportsScreen extends StatefulWidget {
  final List<Candidate> candidates;

  const ReportsScreen({super.key, required this.candidates});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTopCardIndex = 0;

  List<_ReportCandidate> get _items {
    if (widget.candidates.isEmpty) return [];
    final mapped = widget.candidates.map(_ReportCandidate.fromCandidate).toList();
    mapped.sort((a, b) => b.score.compareTo(a.score));
    return mapped;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              'No reports available.',
              style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyze candidates first to generate a hiring report.',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final items = _items;
    final topThree = items.take(3).toList();
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                _buildHeader(context, items.length),
                const SizedBox(height: 28),
                _SectionTitle(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Top 3 Recommended Candidates',
                ),
                const SizedBox(height: 16),
                if (isWide)
                  Row(
                    children: topThree
                        .asMap()
                        .entries
                        .map(
                          (entry) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right:
                                    entry.key == topThree.length - 1 ? 0 : 20,
                              ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTopCardIndex = entry.key;
                                });
                              },
                              child: _TopCandidateCard(
                                candidate: entry.value,
                                highlighted: entry.key == _selectedTopCardIndex,
                              ),
                            ),
                            ),
                          ),
                        )
                        .toList(),
                  )
                else
                  Column(
                    children: topThree
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedTopCardIndex = entry.key;
                                });
                              },
                              child: _TopCandidateCard(
                                candidate: entry.value,
                                highlighted: entry.key == _selectedTopCardIndex,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 38),
                _buildTableHeader(),
                const SizedBox(height: 14),
                _AnalysisTable(candidates: items),
                const SizedBox(height: 66),
                _buildFooter(),
              ],
            ),
          ),
        );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final isWide = MediaQuery.of(context).size.width >= 760;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hiring Analysis Report',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Project: Senior .NET Developer #402',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderButton(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Download Detailed PDF',
              filled: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating PDF report...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            _HeaderButton(
              icon: Icons.upload_file_outlined,
              label: 'Export to ATS',
              filled: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exporting data to ATS integration...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Based on ${widget.candidates.length} total applicants',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerLeft, child: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        actions,
      ],
    );
  }

  Widget _buildTableHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Full Analysis Report',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        Text(
          'Filter by Score:',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Text(
                'All Candidates',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down,
                  size: 15, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Text(
          '© 2026 HireMind AI. All rights reserved.',
          style:
              GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        const Spacer(),
        Text(
          'Help Center     Privacy Policy     API Documentation',
          style:
              GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: filled ? const Color(0xFF1A56DB) : Colors.white,
          foregroundColor: filled ? Colors.white : const Color(0xFF111827),
          side: filled
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

class _TopCandidateCard extends StatelessWidget {
  final _ReportCandidate candidate;
  final bool highlighted;

  const _TopCandidateCard({required this.candidate, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              highlighted ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _MatchLabel(candidate: candidate),
                  ],
                ),
              ),
              _ScoreCircle(score: candidate.score, color: candidate.scoreColor),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'WHY THEY MATCH',
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          ...candidate.whyTheyMatch.take(3).map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 13, color: Color(0xFF22C55E)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                'View Profile',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04);
  }
}

class _AnalysisTable extends StatelessWidget {
  final List<_ReportCandidate> candidates;

  const _AnalysisTable({required this.candidates});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 56),
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                dividerThickness: 1,
                horizontalMargin: 22,
                columnSpacing: 38,
                headingTextStyle: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: const Color(0xFF64748B),
                ),
                dataTextStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
                columns: const [
                  DataColumn(label: Text('CANDIDATE NAME')),
                  DataColumn(label: Text('EXPERIENCE')),
                  DataColumn(label: Text('MATCH SCORE')),
                  DataColumn(label: Text('KEY STRENGTHS')),
                  DataColumn(label: Text('POTENTIAL GAPS')),
                ],
                rows: candidates
                    .take(5)
                    .map(
                      (candidate) => DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidate.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  candidate.role,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(candidate.experience)),
                          DataCell(_ScorePill(
                              score: candidate.score,
                              color: candidate.scoreColor)),
                          DataCell(SizedBox(width: 200, child: Text(candidate.keyStrengths, maxLines: 2, overflow: TextOverflow.ellipsis))),
                          DataCell(SizedBox(width: 200, child: Text(candidate.potentialGap, maxLines: 2, overflow: TextOverflow.ellipsis))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Text(
                  'Showing 5 of ${candidates.length} total analyzed candidates',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const Spacer(),
                _PagerButton(label: 'Previous'),
                const SizedBox(width: 8),
                _PagerButton(label: 'Next'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchLabel extends StatelessWidget {
  final _ReportCandidate candidate;

  const _MatchLabel({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Text(
      candidate.badge,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: candidate.scoreColor,
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreCircle({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.45), width: 2),
      ),
      child: Center(
        child: Text(
          '$score%',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int score;
  final Color color;

  const _ScorePill({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  final String label;

  const _PagerButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          label,
          style:
              GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

class _ReportCandidate {
  final String name;
  final String role;
  final String experience;
  final int score;
  final String badge;
  final Color scoreColor;
  final List<String> whyTheyMatch;
  final String keyStrengths;
  final String potentialGap;

  const _ReportCandidate({
    required this.name,
    required this.role,
    required this.experience,
    required this.score,
    required this.badge,
    required this.scoreColor,
    required this.whyTheyMatch,
    required this.keyStrengths,
    required this.potentialGap,
  });

  factory _ReportCandidate.fromCandidate(Candidate candidate) {
    final score = candidate.matchScore;
    final strengths = candidate.strengths.isEmpty
        ? candidate.skills.take(3).toList()
        : candidate.strengths.take(3).toList();
    final gaps = candidate.potentialGaps.isEmpty
        ? 'Review manually for role-specific gaps'
        : candidate.potentialGaps.first;
    final role = _roleFromSkills(candidate.skills);

    return _ReportCandidate(
      name: candidate.name.isEmpty ? 'Candidate' : candidate.name,
      role: role,
      experience: '${candidate.experience} Years',
      score: score,
      badge: score >= 90
          ? 'EXCEPTIONAL MATCH'
          : score >= 80
              ? 'STRONG CANDIDATE'
              : score >= 60
                  ? 'MODERATE MATCH'
                  : 'POTENTIAL',
      scoreColor: _scoreColor(score),
      whyTheyMatch: strengths.isEmpty
          ? [
              'Relevant skills detected',
              'Good semantic match',
              'Resume aligns with JD'
            ]
          : strengths,
      keyStrengths: candidate.skills.take(3).join(', '),
      potentialGap: gaps,
    );
  }
}

String _roleFromSkills(List<String> skills) {
  final joined = skills.join(' ').toLowerCase();
  if (joined.contains('.net') ||
      joined.contains('c#') ||
      joined.contains('asp.net')) {
    return '.NET Developer';
  }
  if (joined.contains('react')) return 'Full Stack Engineer';
  if (joined.contains('azure')) return 'Software Engineer';
  if (joined.contains('python') || joined.contains('django'))
    return 'Backend Developer';
  return 'Software Engineer';
}

Color _scoreColor(int score) {
  if (score >= 80) return const Color(0xFF22C55E);
  if (score >= 60) return const Color(0xFFEAB308);
  return const Color(0xFFEF4444);
}

const List<_ReportCandidate> _demoReportCandidates = [
  _ReportCandidate(
    name: 'Muhammad Hussain',
    role: 'Senior Developer',
    experience: '6 Years',
    score: 94,
    badge: 'EXCEPTIONAL MATCH',
    scoreColor: Color(0xFF1A56DB),
    whyTheyMatch: [
      '6+ years expert .NET Core & SQL experience',
      'Strong microservices architecture background',
      'Previous experience leading remote teams',
    ],
    keyStrengths: '.NET Core, SQL, Architecture',
    potentialGap: 'Minimal React knowledge',
  ),
  _ReportCandidate(
    name: 'Syed Hassaan',
    role: 'Software Engineer',
    experience: '5 Years',
    score: 88,
    badge: 'STRONG CANDIDATE',
    scoreColor: Color(0xFF22C55E),
    whyTheyMatch: [
      'Masters in Computer Science',
      'Expertise in Azure Cloud services',
      'Clean code advocate (SOLID, TDD)',
    ],
    keyStrengths: 'Azure, DevOps, C#',
    potentialGap: 'Lacks Docker experience',
  ),
  _ReportCandidate(
    name: 'Fatima Zahra',
    role: 'Full Stack Engineer',
    experience: '4.5 Years',
    score: 85,
    badge: 'STRONG CANDIDATE',
    scoreColor: Color(0xFF22C55E),
    whyTheyMatch: [
      'Strong frontend (React) & backend skills',
      'Docker & Kubernetes proficiency',
      'Excellent communication score',
    ],
    keyStrengths: 'React, .NET, Kubernetes',
    potentialGap: 'Limited enterprise SQL',
  ),
  _ReportCandidate(
    name: 'Muhammad Khan',
    role: 'Backend Developer',
    experience: '5 Years',
    score: 78,
    badge: 'MODERATE MATCH',
    scoreColor: Color(0xFFEAB308),
    whyTheyMatch: [
      'Strong backend programming background',
      'Database and API delivery experience',
      'Good problem-solving record',
    ],
    keyStrengths: 'Django, SQL, Python',
    potentialGap: 'No .NET experience',
  ),
  _ReportCandidate(
    name: 'Ayesha Siddiqua',
    role: 'Junior .NET dev',
    experience: '2 Years',
    score: 42,
    badge: 'POTENTIAL',
    scoreColor: Color(0xFFEF4444),
    whyTheyMatch: [
      'Basic C# and .NET exposure',
      'Motivated junior profile',
      'Some SQL Server familiarity',
    ],
    keyStrengths: 'C#, .NET Basic',
    potentialGap: 'Under-qualified for Senior role',
  ),
];
