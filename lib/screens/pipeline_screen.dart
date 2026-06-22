import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../models/candidate.dart';

class PipelineScreen extends StatefulWidget {
  final List<Candidate> candidates;
  final ValueChanged<Candidate> onCandidateUpdated;

  const PipelineScreen({super.key, required this.candidates, required this.onCandidateUpdated});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  final Set<Candidate> _selectedCandidates = {};

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No candidates in pipeline',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Candidate Pool to shortlist candidates.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildTopActionBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: widget.candidates.length,
            itemBuilder: (context, index) {
              final candidate = widget.candidates[index];
              return _buildPipelineCard(candidate);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionBar() {
    final hasSelection = _selectedCandidates.isNotEmpty;
    final count = hasSelection ? _selectedCandidates.length : widget.candidates.length;
    final label = hasSelection ? '$count Selected' : 'All Candidates ($count)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _exportToCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFB9C6DA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final target = hasSelection ? _selectedCandidates : widget.candidates;
                  if (target.isEmpty) return;
                  final emails = target.map((c) {
                    return c.email.isNotEmpty ? c.email : '${c.name.replaceAll(' ', '.').toLowerCase()}@example.com';
                  }).join(',');
                  final url = Uri.parse('mailto:?bcc=$emails&subject=Interview Invitation');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch Email app.')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.email, size: 18),
                label: const Text('Bulk Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075BC7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCsv() async {
    final target = _selectedCandidates.isNotEmpty ? _selectedCandidates.toList() : widget.candidates;
    if (target.isEmpty) return;

    final buffer = StringBuffer();
    // Headers
    buffer.writeln('Name,Role,Match Score,Phone,LinkedIn,GitHub,Portfolio,Skills');

    String escape(String text) {
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    for (final c in target) {
      final skills = escape(c.skills.join('; '));
      buffer.writeln(
        '${escape(c.name)},${escape(c.primaryExperienceTitle)},${c.matchScore},'
        '${escape(c.phone)},${escape(c.linkedin)},${escape(c.github)},${escape(c.portfolio)},$skills'
      );
    }

    final csvString = buffer.toString();

    if (kIsWeb) {
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'pipeline_export.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: 'pipeline_export.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (path != null) {
        await File(path).writeAsString(csvString);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $path')),
          );
        }
      }
    }
  }

  Widget _buildPipelineCard(Candidate candidate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: _selectedCandidates.contains(candidate),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedCandidates.add(candidate);
                } else {
                  _selectedCandidates.remove(candidate);
                }
              });
            },
            activeColor: const Color(0xFF075BC7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          _AvatarBox(name: candidate.name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  candidate.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Applied for: ${candidate.primaryExperienceTitle.isNotEmpty ? candidate.primaryExperienceTitle : 'Professional'}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            children: [
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (kIsWeb) {
                      if (candidate.pdfBytes != null) {
                        final blob = html.Blob([Uint8List.fromList(candidate.pdfBytes!)], 'application/pdf');
                        final url = html.Url.createObjectUrlFromBlob(blob);
                        html.AnchorElement(href: url)
                          ..setAttribute('download', '${candidate.name}_CV.pdf')
                          ..click();
                        html.Url.revokeObjectUrl(url);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CV bytes not found.')),
                        );
                      }
                    } else {
                      if (candidate.pdfPath != null) {
                        OpenFilex.open(candidate.pdfPath!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CV file path not found.')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  label: const Text('Download CV', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4B5563),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'WhatsApp',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () async {
                    if (candidate.phone.isEmpty) return;
                    final url = Uri.parse('https://wa.me/${candidate.phone.replaceAll(RegExp(r'[^0-9]'), '')}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('mailto:?subject=Interview with ${candidate.name}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.email_outlined, size: 14),
                  label: const Text('Send Email', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075BC7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  setState(() {
                    candidate.isShortlisted = false;
                  });
                  widget.onCandidateUpdated(candidate);
                },
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'Remove from Pipeline',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarBox extends StatelessWidget {
  final String name;
  const _AvatarBox({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D4ED8),
          ),
        ),
      ),
    );
  }
}
