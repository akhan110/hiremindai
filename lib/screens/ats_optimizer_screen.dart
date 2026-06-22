import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_service.dart';

class ATSOptimizerScreen extends StatefulWidget {
  final Map<String, String> apiKeys;
  final String provider;

  const ATSOptimizerScreen({
    super.key,
    required this.apiKeys,
    required this.provider,
  });

  @override
  State<ATSOptimizerScreen> createState() => _ATSOptimizerScreenState();
}

class _ATSOptimizerScreenState extends State<ATSOptimizerScreen> {
  final _jobDescController = TextEditingController();
  late final AIService _aiService;

  String? _resumeName;
  String? _resumeContent;
  String? _optimizedResume;
  bool _uploading = false;
  bool _optimizing = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final activeKey = widget.apiKeys[widget.provider] ?? '';
    _aiService = AIFactory.getService(widget.provider, activeKey);
  }

  Future<void> _pickResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _uploading = true;
        _errorMsg = null;
        _optimizedResume = null;
      });

      final file = result.files.first;
      final name = file.name;
      String content = '';

      if (file.bytes != null) {
        if (name.toLowerCase().endsWith('.pdf')) {
          try {
            final document = PdfDocument(inputBytes: file.bytes!);
            content = PdfTextExtractor(document).extractText();
            document.dispose();
          } catch (e) {
            content = 'Could not parse PDF';
          }
        } else {
          content = utf8.decode(file.bytes!, allowMalformed: true);
        }
      }

      setState(() {
        _resumeName = name;
        _resumeContent = content;
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _errorMsg = 'Failed to upload file: \$e';
      });
    }
  }

  Future<void> _optimize() async {
    if (_resumeContent == null || _resumeContent!.isEmpty) {
      setState(() => _errorMsg = 'Please upload a resume first.');
      return;
    }
    if (_jobDescController.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Please provide a target job description.');
      return;
    }

    setState(() {
      _optimizing = true;
      _errorMsg = null;
      _optimizedResume = null;
    });

    try {
      final result = await _aiService.atsOptimizeResume(
        resumeText: _resumeContent!,
        jobDescription: _jobDescController.text.trim(),
      );
      
      String cleanResult = result.trim();
      if (cleanResult.startsWith('```markdown')) {
        cleanResult = cleanResult.substring(11).trim();
      } else if (cleanResult.startsWith('```')) {
        cleanResult = cleanResult.substring(3).trim();
      }
      if (cleanResult.endsWith('```')) {
        cleanResult = cleanResult.substring(0, cleanResult.length - 3).trim();
      }

      setState(() => _optimizedResume = cleanResult);
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _optimizing = false);
    }
  }

  void _copyToClipboard() {
    if (_optimizedResume != null) {
      Clipboard.setData(ClipboardData(text: _optimizedResume!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied to clipboard!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return isWide ? _buildWideLayout() : _buildNarrowLayout();
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 350,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildInputPanel(),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF5F7FF),
            padding: const EdgeInsets.all(24),
            child: _buildOutputPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: _buildInputPanel(),
          ),
          const SizedBox(height: 16),
          _buildOutputPanel(),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATS Optimizer',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload a resume and paste the target job description to generate a highly optimized, ATS-friendly resume.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Step 1: Upload
        Text(
          'STEP 1: Original Resume',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickResume,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _resumeName != null
                    ? const Color(0xFF10B981)
                    : const Color(0xFFD1D5DB),
                width: _resumeName != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
              color: _resumeName != null
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF9FAFB),
            ),
            child: _uploading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _resumeName != null
                            ? Icons.check_circle
                            : Icons.upload_file_outlined,
                        size: 32,
                        color: _resumeName != null
                            ? const Color(0xFF10B981)
                            : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _resumeName ?? 'Click to upload resume (PDF/TXT)',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: _resumeName != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _resumeName != null
                                ? const Color(0xFF065F46)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Step 2: Job Desc
        Text(
          'STEP 2: Target Job Description',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _jobDescController,
          maxLines: 10,
          style: GoogleFonts.inter(fontSize: 13, height: 1.6),
          decoration: InputDecoration(
            hintText: 'Paste the exact job description here...',
            hintStyle:
                GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD1D5DB)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF1A56DB), width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 24),

        if (_errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA))),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_errorMsg!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFFEF4444)))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Optimize Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (_optimizing || _uploading) ? null : _optimize,
            icon: _optimizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 20),
            label: Text(
              _optimizing ? 'Optimizing Resume...' : 'Bypass ATS System',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputPanel() {
    if (_optimizing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A56DB)),
            const SizedBox(height: 24),
            Text(
              'Analyzing keywords and rewriting resume...',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'This usually takes 10-20 seconds depending on the model.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF9CA3AF)),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    if (_optimizedResume == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined,
                size: 64,
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Optimized Resume Will Appear Here',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ).animate().fadeIn(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ATS-Optimized Resume',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, size: 16),
              label: Text('Copy Text',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF374151),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: MarkdownBody(
                  data: _optimizedResume!,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: const Color(0xFF374151)),
                    h1: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827)),
                    h2: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937)),
                    h3: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151)),
                    listBullet: GoogleFonts.inter(
                        fontSize: 14, color: const Color(0xFF374151)),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.05),
        ),
      ],
    );
  }
}
