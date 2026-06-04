import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/candidate.dart';

class AgenticCandidateCard extends StatelessWidget {
  final Candidate candidate;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;

  const AgenticCandidateCard({
    super.key,
    required this.candidate,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
  });

  Color get _matchColor {
    switch (candidate.matchLabel) {
      case 'STRONG MATCH':
        return const Color(0xFF059669);
      case 'MODERATE MATCH':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF6366F1);
    }
  }

  Color get _matchBg {
    switch (candidate.matchLabel) {
      case 'STRONG MATCH':
        return const Color(0xFFD1FAE5);
      case 'MODERATE MATCH':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFEDE9FE);
    }
  }

  Color get _scoreColor {
    final s = candidate.matchScore;
    if (s >= 80) return const Color(0xFF1A56DB);
    if (s >= 60) return const Color(0xFFD97706);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Score circle
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _scoreColor, width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          '${c.matchScore}%',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _scoreColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _matchBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.matchLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _matchColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Experience: ${c.experience} years',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 12),
                // Skill chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: c.skills
                      .map((s) => _SkillChip(label: s))
                      .toList(),
                ),
              ],
            ),
          ),

          // AI Summary
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                border: Border(
                  top: BorderSide(color: const Color(0xFFE5E7EB)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 15, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 6),
                      Text(
                        'AI Summary',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A56DB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${c.aiSummary}"',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF374151),
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SummarySection(
                          title: 'Strengths',
                          color: const Color(0xFF059669),
                          items: c.strengths,
                          bullet: '•',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummarySection(
                          title: 'Potential Gaps',
                          color: const Color(0xFFEF4444),
                          items: c.potentialGaps,
                          bullet: '•',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Expand / Collapse toggle
          InkWell(
              onTap: onToggle,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isExpanded ? 'Hide AI Analysis' : 'View AI Analysis',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A56DB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: const Color(0xFF1A56DB),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.05);
  }
}


class _SkillChip extends StatelessWidget {
  final String label;

  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> items;
  final String bullet;

  const _SummarySection(
      {required this.title,
      required this.color,
      required this.items,
      required this.bullet});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$bullet ',
                    style: TextStyle(color: color, fontSize: 12)),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF374151),
                      height: 1.5,
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
