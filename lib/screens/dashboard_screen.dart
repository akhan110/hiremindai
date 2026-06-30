import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/candidate.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../widgets/candidate_card.dart';
import 'candidate_pool_screen.dart';
import 'pipeline_screen.dart';
import 'ats_optimizer_screen.dart';
import 'onboarding_screen.dart';
import '../models/app_user.dart';
import 'splash_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, String> apiKeys;
  final String provider;
  final String customPrompt;
  final int shortlistCutoff;
  final String companyName;
  final String companyIndustry;
  final double weightSkills;
  final double weightExperience;
  final double weightCulture;

  const DashboardScreen({
    super.key,
    required this.apiKeys,
    required this.provider,
    this.customPrompt = '',
    this.shortlistCutoff = 75,
    this.companyName = '',
    this.companyIndustry = '',
    this.weightSkills = 40.0,
    this.weightExperience = 40.0,
    this.weightCulture = 20.0,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _jobDescController = TextEditingController();
  final _rolePromptController = TextEditingController();
  late final AIService _aiService;

  List<Map<String, dynamic>> _resumes = [];
  List<Candidate> _candidates = [];
  AppUser? _currentUser;
  bool _uploading = false;
  bool _analyzing = false;
  bool _optimizingJobDesc = false;
  double _uploadProgress = 0;
  String? _errorMsg;
  String _sortBy = 'Score';
  int _selectedTab = 0;
  final List<String> _activeFilters = [];
  int? _expandedIndex = 0;

  final List<String> _filterOptions = [
    'Software',
    'Remote',
    'Senior',
    'Junior',
    'Full-Stack',
    'Backend'
  ];

  @override
  void initState() {
    super.initState();
    final activeKey = widget.apiKeys[widget.provider] ?? '';
    _aiService = AIFactory.getService(
      widget.provider, 
      activeKey, 
      customPrompt: widget.customPrompt,
      companyContext: '${widget.companyName} (${widget.companyIndustry})',
      weightSkills: widget.weightSkills,
      weightExperience: widget.weightExperience,
      weightCulture: widget.weightCulture,
    );
    _loadCandidatesFromCloud();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await FirebaseService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _loadCandidatesFromCloud() async {
    try {
      final candidates = await FirebaseService.getCandidates();
      if (mounted) {
        setState(() {
          _candidates = candidates;
        });
      }
    } catch (e) {
      // Ignored for now
    }
  }

  Future<void> _pickResumes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _uploading = true;
        _uploadProgress = 0;
        _resumes = [];
      });

      final total = result.files.length;
      for (int i = 0; i < total; i++) {
        final file = result.files[i];
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
          } else if (name.toLowerCase().endsWith('.txt')) {
            content = utf8.decode(file.bytes!, allowMalformed: true);
          } else {
            content = utf8.decode(file.bytes!, allowMalformed: true);
          }
        }

        _resumes.add({
          'name': name,
          'content': content,
          'path': kIsWeb ? name : file.path,
          'bytes': file.bytes,
        });

        setState(() {
          _uploadProgress = (i + 1) / total;
        });

        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() => _uploading = false);
    } catch (e) {
      setState(() {
        _uploading = false;
        _errorMsg = 'Failed to upload files: $e';
      });
    }
  }

  Future<void> _analyze() async {
    if (_jobDescController.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Please paste a job description first.');
      return;
    }
    if (_resumes.isEmpty) {
      setState(() => _errorMsg = 'Please upload at least one resume.');
      return;
    }

    if (_currentUser != null) {
      if (_currentUser!.tokensUsed + _resumes.length > _currentUser!.monthlyQuota) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Quota Exceeded'),
            content: Text('You only have ${_currentUser!.monthlyQuota - _currentUser!.tokensUsed} AI scans remaining, but you uploaded ${_resumes.length} resumes. Please upgrade your plan.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
            ],
          )
        );
        return;
      }
    }

    setState(() {
      _analyzing = true;
      _errorMsg = null;
    });

    try {
      final results = await _aiService.analyzeCandidates(
        jobDescription: _jobDescController.text.trim(),
        resumes: _resumes,
      );
      
      if (_currentUser != null) {
        await FirebaseService.incrementTokenUsage(_resumes.length);
        _loadCurrentUser(); // Refresh local quota
      }

      
      // Auto-shortlist candidates meeting the cutoff threshold
      for (var c in results) {
        if (c.matchScore >= widget.shortlistCutoff) {
          c.isShortlisted = true;
          c.pipelineStatus = 'Not Contacted';
        }

        // Upload PDF if present
        if (c.pdfBytes != null && c.pdfPath != null) {
          try {
             final filename = c.pdfPath!.split('/').last.split('\\').last;
             final url = await FirebaseService.uploadResumePdf(filename, c.pdfBytes!);
             c.pdfPath = url;
             c.pdfBytes = null; // Free memory
          } catch(e) {
             print('Failed to upload PDF: $e');
          }
        }
        
        // Save candidate to Firestore
        try {
           await FirebaseService.saveCandidate(c);
        } catch(e) {
           print('Failed to save to Firestore: $e');
        }
      }
      
      setState(() => _candidates = [...results, ..._candidates]);
      
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _analyzing = false);
    }
  }

  List<Candidate> get _sortedCandidates {
    var list = List<Candidate>.from(_candidates);
    
    // Apply filters
    if (_activeFilters.isNotEmpty) {
      list = list.where((c) {
        return _activeFilters.any((filter) {
          final f = filter.toLowerCase();
          return c.skills.any((s) => s.toLowerCase().contains(f)) ||
                 c.aiSummary.toLowerCase().contains(f) ||
                 c.strengths.any((s) => s.toLowerCase().contains(f));
        });
      }).toList();
    }

    if (_sortBy == 'Score') {
      list.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    } else if (_sortBy == 'Experience') {
      list.sort((a, b) => b.experience.compareTo(a.experience));
    } else if (_sortBy == 'Name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final sortedCandidates = _sortedCandidates;

    Widget body;
    switch (_selectedTab) {
      case 1:
        body = CandidatePoolScreen(
          candidates: sortedCandidates,
          onCandidateUpdated: (c) {
            if (c.id != null) {
              FirebaseService.updateCandidateStatus(c.id!, c.pipelineStatus, c.isShortlisted);
            }
            setState(() {});
          },
        );
        break;
      case 2:
        body = PipelineScreen(
          candidates: sortedCandidates.where((c) => c.isShortlisted).toList(),
          onCandidateUpdated: (c) {
            if (c.id != null) {
              FirebaseService.updateCandidateStatus(c.id!, c.pipelineStatus, c.isShortlisted);
            }
            setState(() {});
          },
        );
        break;
      case 3:
        body = ATSOptimizerScreen(
          apiKeys: widget.apiKeys,
          provider: widget.provider,
        );
        break;
      default:
        body = isWide ? _buildWideLayout() : _buildNarrowLayout();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: Column(
        children: [
          _buildNavBar(),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_outlined,
              color: Color(0xFF1A56DB), size: 24),
          if (isWide) const SizedBox(width: 8),
          if (isWide)
            Text(
              widget.companyName.isNotEmpty ? widget.companyName : 'HireMind AI',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          const SizedBox(width: 32),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Dashboard', 'Candidate Pool', 'Pipeline', 'ATS Optimizer'].asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _NavItem(
                          label: entry.value,
                          active: _selectedTab == entry.key,
                          onTap: () => setState(() => _selectedTab = entry.key),
                        ),
                      ),
                    ).toList(),
              ),
            ),
          ),
          if (isWide)
            InkWell(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF059669), size: 8),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.provider} Connected',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),

                const SizedBox(width: 12),
                
                // User Name
                if (_currentUser != null)
                  Text(
                    FirebaseAuth.instance.currentUser?.displayName ?? _currentUser!.email.split('@').first,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                const SizedBox(width: 12),
                
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/user_avatar.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF6B7280)),
                  tooltip: 'Sign Out',
                  onPressed: () async {
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel
        Container(
          width: 320,
          height: double.infinity,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildLeftPanel(),
          ),
        ),
        // Right panel
        Expanded(
          child: _buildRightPanel(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLeftPanel(),
          const SizedBox(height: 16),
          _buildRightPanel(),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeader(label: 'Job Description', step: 'STEP 1'),
        const SizedBox(height: 10),
        TextField(
          controller: _jobDescController,
          maxLines: 8,
          style: GoogleFonts.inter(fontSize: 13, height: 1.6),
          decoration: InputDecoration(
            hintText: 'Paste the job description here...',
            hintStyle:
                GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD1D5DB)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rolePromptController,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Or type a role to generate...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD1D5DB)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _optimizingJobDesc ? null : () async {
                final rolePrompt = _rolePromptController.text.trim();
                final currentDesc = _jobDescController.text.trim();

                if (rolePrompt.isEmpty && currentDesc.isEmpty) {
                  setState(() => _errorMsg = 'Please enter a role or paste a job description.');
                  return;
                }

                setState(() {
                  _optimizingJobDesc = true;
                  _errorMsg = null;
                });
                try {
                  String result;
                  if (rolePrompt.isNotEmpty) {
                    result = await _aiService.generateJobDescription(rolePrompt);
                  } else {
                    result = await _aiService.optimizeJobDescription(currentDesc);
                  }
                  
                  if (result.isNotEmpty) {
                    _jobDescController.text = result;
                    _rolePromptController.clear();
                  }
                } catch (e) {
                  setState(() => _errorMsg = 'Failed to process: $e');
                } finally {
                  setState(() => _optimizingJobDesc = false);
                }
              },
              icon: _optimizingJobDesc 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome, size: 14),
              label: Text(
                _optimizingJobDesc ? 'Processing...' : 'AI Optimize',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1A56DB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _StepHeader(label: 'Source Candidates', step: 'STEP 2'),
        const SizedBox(height: 10),

        // Drop zone
        GestureDetector(
          onTap: _pickResumes,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFD1D5DB),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF9FAFB),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file_outlined,
                      size: 32, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 8),
                  Text(
                    'Drop resumes here or click to upload',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supports PDF, TXT up to 10MB each',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            onPressed: _pickResumes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Upload Resumes',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),

        if (_uploading) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1A56DB)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Uploading ${_resumes.length} resumes...',
            style:
                GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
          ),
        ],

        if (_resumes.isNotEmpty && !_uploading) ...[
          const SizedBox(height: 8),
          Text(
            '${_resumes.length} resume(s) ready',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF059669),
                fontWeight: FontWeight.w600),
          ),
        ],

        const SizedBox(height: 24),
        if (_errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: (_analyzing || _uploading) ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.psychology_outlined, size: 20),
            label: Text(
              _analyzing ? 'Analyzing...' : 'Analyze Candidates',
              style:
                  GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56DB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI-Ranked Candidates',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        if (_candidates.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A56DB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_candidates.length} Found',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (_candidates.isNotEmpty)
                  Row(
                    children: [
                      Text('Filters: ',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF6B7280))),
                      ..._filterOptions.take(3).map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _FilterChip(
                                label: f,
                                active: _activeFilters.contains(f),
                                onTap: () {
                                  setState(() {
                                    if (_activeFilters.contains(f)) {
                                      _activeFilters.remove(f);
                                    } else {
                                      _activeFilters.add(f);
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                      const SizedBox(width: 12),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: const Color(0xFF374151)),
                          items: ['Score', 'Experience', 'Name']
                              .map((s) => DropdownMenuItem(
                                  value: s, child: Text('Sort by $s')))
                              .toList(),
                          onChanged: (v) => setState(() => _sortBy = v!),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Candidate list or empty state
            if (_candidates.isEmpty && !_analyzing)
              _EmptyState()
            else if (_analyzing)
              _AnalyzingState(provider: widget.provider)
            else
              ..._sortedCandidates
                  .asMap()
                  .entries
                  .map(
                    (e) => CandidateCard(
                      candidate: e.value,
                      index: e.key,
                      isExpanded: _expandedIndex == e.key,
                      onToggle: () {
                        setState(() {
                          _expandedIndex = _expandedIndex == e.key ? null : e.key;
                        });
                      },
                    ).animate(delay: (e.key * 50).ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String label;
  final String step;

  const _StepHeader({required this.label, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
        Text(
          step,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: active
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1A56DB), width: 2),
                ),
              )
            : null,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? const Color(0xFF1A56DB) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  active ? const Color(0xFF1A56DB) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color:
                    active ? const Color(0xFF1A56DB) : const Color(0xFF374151),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 12, color: Color(0xFF1A56DB)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No candidates yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste a job description, upload resumes,\nthen click Analyze Candidates.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFD1D5DB),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingState extends StatelessWidget {
  final String provider;

  const _AnalyzingState({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A56DB)),
            const SizedBox(height: 20),
            Text(
              'Analyzing candidates with $provider...',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scoring resumes, identifying strengths,\nand generating interview questions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}
