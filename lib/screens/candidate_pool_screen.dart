import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/candidate.dart';

class CandidatePoolScreen extends StatefulWidget {
  final List<Candidate> candidates;
  final ValueChanged<Candidate> onCandidateUpdated;

  const CandidatePoolScreen({super.key, required this.candidates, required this.onCandidateUpdated});

  @override
  State<CandidatePoolScreen> createState() => _CandidatePoolScreenState();
}

class _CandidatePoolScreenState extends State<CandidatePoolScreen> {
  int _selectedIndex = 0;
  String _query = '';

  List<_PoolCandidate> get _items {
    final source = widget.candidates.isEmpty
        ? <_PoolCandidate>[]
        : widget.candidates.map(_PoolCandidate.fromCandidate).toList();

    if (_query.trim().isEmpty) return source;
    final q = _query.toLowerCase().trim();
    return source
        .where(
          (candidate) =>
              candidate.name.toLowerCase().contains(q) ||
              candidate.role.toLowerCase().contains(q) ||
              candidate.skills.any((skill) => skill.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  void didUpdateWidget(covariant CandidatePoolScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= _items.length) _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;
    final candidates = _items;
    final selectedIndex = candidates.isEmpty
        ? 0
        : _selectedIndex.clamp(0, candidates.length - 1).toInt();
    if (widget.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(
              'No candidates analyzed yet.',
              style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to the Dashboard and analyze resumes to see them here.',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final selected = candidates[selectedIndex];

    return Stack(
      children: [
        Container(
          color: const Color(0xFFFCF8FF),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 56),
            child: Column(
              children: [
                    _buildToolbar(),
                    const SizedBox(height: 26),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 410,
                            child: _buildCandidateList(candidates),
                          ),
                          const SizedBox(width: 34),
                          Expanded(child: _buildDetailsCard(selected)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildCandidateList(candidates),
                          const SizedBox(height: 18),
                          _buildDetailsCard(selected),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB9C6DA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: (value) => setState(() {
                  _query = value;
                  _selectedIndex = 0;
                }),
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF4B5F7D),
                    size: 20,
                  ),
                  hintText: 'Search by name, skills, or role...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF7C8AA5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFB9C6DA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFB9C6DA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF075BC7)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const _FilterPill(label: 'Status: All'),
          const SizedBox(width: 10),
          const _FilterPill(label: 'Score: High to Low'),
        ],
      ),
    );
  }



  Widget _buildCandidateList(List<_PoolCandidate> candidates) {
    if (candidates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(26),
        decoration: _panelDecoration(),
        child: Text(
          'No candidates match your search.',
          style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
        ),
      );
    }

    return Column(
      children: candidates.asMap().entries.map((entry) {
        final index = entry.key;
        final candidate = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _PoolCandidateCard(
            candidate: candidate,
            selected: _selectedIndex == index,
            onTap: () => setState(() => _selectedIndex = index),
          ).animate(delay: (index * 50).ms).fadeIn(duration: 300.ms).slideX(begin: -0.1),
        );
      }).toList(),
    );
  }

  Widget _buildDetailsCard(_PoolCandidate candidate) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarBox(candidate: candidate),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${candidate.role} • ${candidate.experienceLabel}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF075BC7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _MetaText(
                            icon: Icons.location_on_outlined,
                            label: candidate.location,
                          ),
                          _MetaText(
                            icon: Icons.email_outlined,
                            label: candidate.email,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    SizedBox(
                      width: 150,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          candidate.original.isShortlisted = !candidate.original.isShortlisted;
                          widget.onCandidateUpdated(candidate.original);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: candidate.original.isShortlisted ? Colors.white : const Color(0xFF075BC7),
                          foregroundColor: candidate.original.isShortlisted ? const Color(0xFF075BC7) : Colors.white,
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFF075BC7), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: Text(
                          candidate.original.isShortlisted ? 'Shortlisted' : 'Shortlist',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFB9C6DA)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('PROFESSIONAL LINKS'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ProfessionalLink(
                        icon: Icons.link,
                        label: 'LinkedIn',
                        url: candidate.original.linkedin,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _ProfessionalLink(
                        icon: Icons.code,
                        label: 'GitHub',
                        url: candidate.original.github,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _ProfessionalLink(
                        icon: Icons.language,
                        label: 'Portfolio',
                        url: candidate.original.portfolio,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionLabel('AI EXECUTIVE SUMMARY'),
                const SizedBox(height: 14),
                Text(
                  candidate.summary,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('CORE SKILLS'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: candidate.skills.map((skill) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      skill,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D4ED8),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 24),
                _buildAnalysisPanel(candidate),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.03);
  }

  Widget _buildAnalysisPanel(_PoolCandidate candidate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC6BCEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF075BC7), size: 20),
              const SizedBox(width: 8),
              Text(
                'HireMind AI Analysis',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF075BC7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AnalysisColumn(
                  title: 'STRENGTHS',
                  color: const Color(0xFF059669),
                  icon: Icons.check_circle_outline,
                  items: candidate.strengths,
                ),
              ),
              const SizedBox(width: 34),
              Expanded(
                child: _AnalysisColumn(
                  title: 'AREAS TO PROBE',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.info_outline,
                  items: candidate.gaps,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFB9C6DA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECOMMENDED INTERVIEW QUESTIONS',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                ...candidate.questions.take(2).map(
                      (question) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '"$question"',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.55,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFFB9C6DA)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _PoolCandidateCard extends StatelessWidget {
  final _PoolCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  const _PoolCandidateCard({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F1FF) : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? const Color(0xFF075BC7) : const Color(0xFFB9C6DA),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    candidate.name,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: candidate.score == 0
                        ? const Color(0xFFEF4444) // Red for 0%
                        : candidate.score >= 70
                            ? const Color(0xFF10B981) // Green for >= 70%
                            : selected
                                ? const Color(0xFF075BC7)
                                : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${candidate.score.toString().padLeft(2, '0')}% MATCH',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: (candidate.score == 0 || candidate.score >= 70 || selected)
                          ? Colors.white
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusBadge(
                    label: candidate.status, color: candidate.statusColor),
                Text(
                  candidate.role,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              candidate.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;

  const _FilterPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB9C6DA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.keyboard_arrow_down,
              size: 16, color: Color(0xFF4B5563)),
        ],
      ),
    );
  }
}

class _AvatarBox extends StatelessWidget {
  final _PoolCandidate candidate;

  const _AvatarBox({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB9C6DA)),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF075BC7),
          child: Text(
            candidate.initials,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaText({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF4B5563)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _ProfessionalLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _ProfessionalLink({required this.icon, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final bool hasUrl = url.trim().isNotEmpty;
    return Tooltip(
      message: hasUrl ? 'Copy $label Link: $url' : '$label link not available',
      child: InkWell(
        onTap: hasUrl
            ? () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label link copied to clipboard!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: hasUrl ? Colors.white : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFB9C6DA)),
          ),
          child: Row(
            children: [
              Icon(icon, color: hasUrl ? const Color(0xFF075BC7) : const Color(0xFF9CA3AF), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: hasUrl ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        color: const Color(0xFF075BC7),
      ),
    );
  }
}

class _AnalysisColumn extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<String> items;

  const _AnalysisColumn({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        ...items.take(3).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF374151),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _PoolCandidate {
  final String name;
  final String role;
  final int score;
  final String status;
  final Color statusColor;
  final String summary;
  final String location;
  final String email;
  final String experienceLabel;
  final String company;
  final String previousCompany;
  final String primaryExperienceTitle;
  final String secondaryExperienceTitle;
  final String primaryExperienceDescription;
  final String secondaryExperienceDescription;
  final List<String> skills;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> questions;
  final Candidate original;

  const _PoolCandidate({
    required this.name,
    required this.role,
    required this.score,
    required this.status,
    required this.statusColor,
    required this.summary,
    required this.location,
    required this.email,
    required this.experienceLabel,
    required this.company,
    required this.previousCompany,
    required this.primaryExperienceTitle,
    required this.secondaryExperienceTitle,
    required this.primaryExperienceDescription,
    required this.secondaryExperienceDescription,
    required this.skills,
    required this.strengths,
    required this.gaps,
    required this.questions,
    required this.original,
  });

  factory _PoolCandidate.fromCandidate(Candidate candidate) {
    final fallbackRole = _roleFromSkills(candidate.skills);
    final role = candidate.primaryExperienceTitle.isNotEmpty 
        ? candidate.primaryExperienceTitle 
        : fallbackRole;
    final status = candidate.isShortlisted ? 'SHORTLISTED' : 'NEW';
    final statusColor = candidate.isShortlisted
        ? const Color(0xFF075BC7)
        : const Color(0xFF059669);
    return _PoolCandidate(
      name: candidate.name.isEmpty ? 'Candidate' : candidate.name,
      role: role,
      score: candidate.matchScore,
      status: status,
      statusColor: statusColor,
      summary: candidate.aiSummary.isEmpty
          ? 'Candidate profile generated from uploaded resume analysis.'
          : candidate.aiSummary,
      location: 'Remote / Hybrid',
      email: candidate.email.isNotEmpty ? candidate.email :
          '${candidate.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '.').replaceAll(RegExp(r'^\.|\.$'), '')}@example.com',
      experienceLabel: '${candidate.experience}+ Years Experience',
      company: candidate.company,
      previousCompany: candidate.previousCompany,
      primaryExperienceTitle: candidate.primaryExperienceTitle.isNotEmpty ? candidate.primaryExperienceTitle : role,
      secondaryExperienceTitle: candidate.secondaryExperienceTitle.isNotEmpty ? candidate.secondaryExperienceTitle : 'Professional',
      primaryExperienceDescription: candidate.strengths.isEmpty
          ? 'Built and maintained production applications while collaborating with product and engineering teams.'
          : candidate.strengths.take(2).join(' '),
      secondaryExperienceDescription: candidate.aiSummary.isEmpty
          ? 'Contributed to product delivery, code quality, documentation, and cross-functional delivery rituals.'
          : candidate.aiSummary,
      skills: candidate.skills,
      strengths: candidate.strengths.isEmpty
          ? [
              'Strong alignment with the target role.',
              'Good evidence of production delivery.'
            ]
          : candidate.strengths,
      gaps: candidate.potentialGaps.isEmpty
          ? [
              'Validate depth of hands-on experience.',
              'Probe ownership and communication style.'
            ]
          : candidate.potentialGaps,
      questions: candidate.interviewQuestions.isEmpty
          ? [
              'Can you walk through a recent project that best proves your fit for this role?',
              'Which technical tradeoff did you make recently and why?',
            ]
          : candidate.interviewQuestions,
      original: candidate,
    );
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

String _roleFromSkills(List<String> skills) {
  final joined = skills.join(' ').toLowerCase();
  if (joined.contains('.net') ||
      joined.contains('c#') ||
      joined.contains('asp.net')) {
    return '.NET Developer';
  }
  if (joined.contains('react') ||
      joined.contains('frontend') ||
      joined.contains('ui')) {
    return 'Senior Frontend Engineer';
  }
  if (joined.contains('node') ||
      joined.contains('backend') ||
      joined.contains('api')) {
    return 'Full Stack Developer';
  }
  if (joined.contains('python') || joined.contains('django')) {
    return 'Backend Specialist';
  }
  return 'Professional';
}


