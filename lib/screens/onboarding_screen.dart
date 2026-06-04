import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  
  // Step 1: Company Profile
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  String _teamSize = '1-10';
  final List<String> _teamSizes = ['1-10', '11-50', '51-200', '201-500', '500+'];

  // Step 2: Evaluation Rules
  final _customPromptController = TextEditingController();
  
  // Step 3: Scoring Weights
  double _skillsWeight = 40;
  double _experienceWeight = 40;
  double _cultureWeight = 20;

  // Step 4: Automation Settings
  double _cutoffScore = 75.0;
  
  // Step 5: AI Providers
  final _openAiController = TextEditingController();
  final _claudeController = TextEditingController();
  String _selectedProvider = 'OpenAI';
  final List<String> _providers = ['OpenAI', 'Claude'];
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyNameController.text = prefs.getString('company_name') ?? '';
      _industryController.text = prefs.getString('company_industry') ?? '';
      _teamSize = prefs.getString('team_size') ?? '1-10';
      if (!_teamSizes.contains(_teamSize)) _teamSize = '1-10';

      _customPromptController.text = prefs.getString('custom_ai_prompt') ?? '';
      
      _skillsWeight = prefs.getDouble('weight_skills') ?? 40.0;
      _experienceWeight = prefs.getDouble('weight_experience') ?? 40.0;
      _cultureWeight = prefs.getDouble('weight_culture') ?? 20.0;

      _cutoffScore = (prefs.getInt('shortlist_cutoff') ?? 75).toDouble();
      
      _openAiController.text = prefs.getString('openai_key') ?? '';
      _claudeController.text = prefs.getString('claude_key') ?? '';
      _selectedProvider = prefs.getString('preferred_provider') ?? 'OpenAI';
      if (!_providers.contains(_selectedProvider)) {
        _selectedProvider = 'OpenAI';
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', _companyNameController.text.trim());
    await prefs.setString('company_industry', _industryController.text.trim());
    await prefs.setString('team_size', _teamSize);
    
    await prefs.setString('custom_ai_prompt', _customPromptController.text.trim());
    
    await prefs.setDouble('weight_skills', _skillsWeight);
    await prefs.setDouble('weight_experience', _experienceWeight);
    await prefs.setDouble('weight_culture', _cultureWeight);

    await prefs.setInt('shortlist_cutoff', _cutoffScore.toInt());
    
    await prefs.setString('openai_key', _openAiController.text.trim());
    await prefs.setString('claude_key', _claudeController.text.trim());
    await prefs.setString('preferred_provider', _selectedProvider);
  }

  String _getKeyForProvider(String provider) {
    if (provider == 'OpenAI') return _openAiController.text.trim();
    if (provider == 'Claude') return _claudeController.text.trim();
    return '';
  }

  Future<void> _finishSetup() async {
    final activeKey = _getKeyForProvider(_selectedProvider);

    if (activeKey.isEmpty) {
      setState(() => _error = 'Please enter an API key for $_selectedProvider.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = AIFactory.getService(_selectedProvider, activeKey);
      final valid = await service.validateApiKey();
      if (!valid) {
        setState(() => _error = 'Invalid API key for $_selectedProvider. Please check and try again.');
        return;
      }

      await _saveSettings();

      if (!mounted) return;
      
      final apiKeys = {
        'OpenAI': _openAiController.text.trim(),
        'Claude': _claudeController.text.trim(),
      };

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            apiKeys: apiKeys,
            provider: _selectedProvider,
            customPrompt: _customPromptController.text.trim(),
            shortlistCutoff: _cutoffScore.toInt(),
            companyName: _companyNameController.text.trim(),
            companyIndustry: _industryController.text.trim(),
            weightSkills: _skillsWeight,
            weightExperience: _experienceWeight,
            weightCulture: _cultureWeight,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Could not validate key. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTextInput(String label, String hint, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFFD1D5DB),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
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
              borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildKeyInput(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: _obscure,
          style: GoogleFonts.robotoMono(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.robotoMono(
              color: const Color(0xFFD1D5DB),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
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
              borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildSlider(String title, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
            ),
            Text(
              '${value.toInt()}%',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF1A56DB),
            inactiveTrackColor: const Color(0xFFE5E7EB),
            thumbColor: const Color(0xFF1A56DB),
            overlayColor: const Color(0xFF1A56DB).withOpacity(0.1),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + Brand
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isMobile ? 36 : 44,
                    height: isMobile ? 36 : 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A56DB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.psychology_outlined, color: Colors.white, size: isMobile ? 22 : 26),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'HireMind Setup',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
              const SizedBox(height: 32),

              // Stepper Card
              Container(
                width: isMobile ? double.infinity : 650,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Theme(
                  data: ThemeData(
                    colorScheme: ColorScheme.light(primary: const Color(0xFF1A56DB)),
                  ),
                  child: Stepper(
                    type: isMobile ? StepperType.vertical : StepperType.vertical,
                    physics: const ClampingScrollPhysics(),
                    currentStep: _currentStep,
                    onStepContinue: () {
                      if (_currentStep < 4) {
                        setState(() => _currentStep++);
                      } else {
                        _finishSetup();
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep--);
                      }
                    },
                    onStepTapped: (step) {
                      setState(() => _currentStep = step);
                    },
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: isMobile ? 1 : 0,
                              child: ElevatedButton(
                                onPressed: _loading ? null : details.onStepContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A56DB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: _loading && _currentStep == 4
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(_currentStep == 4 ? 'Finish Setup' : 'Continue', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              ),
                            ),
                            if (_currentStep > 0) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: isMobile ? 1 : 0,
                                child: TextButton(
                                  onPressed: _loading ? null : details.onStepCancel,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF6B7280),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: Text('Back', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    steps: [
                      // Step 1: Company Profile
                      Step(
                        title: Text('Company Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Context helps AI understand culture fit.', style: GoogleFonts.inter(fontSize: 12)),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildTextInput('Company Name', 'e.g. Acme Corp', _companyNameController),
                            _buildTextInput('Industry', 'e.g. Software, Finance, Healthcare', _industryController),
                            Text(
                              'Team Size',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _teamSize,
                                  isExpanded: true,
                                  items: _teamSizes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  onChanged: (v) => setState(() => _teamSize = v!),
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Step 2: Evaluation Rules
                      Step(
                        title: Text('Evaluation Rules', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Define the AI\'s persona and custom rules.', style: GoogleFonts.inter(fontSize: 12)),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildTextInput(
                              'Custom AI Persona & Rules (Optional)', 
                              'e.g. Always prioritize candidates with Flutter experience. Penalize gaps in employment...', 
                              _customPromptController,
                              maxLines: 4
                            ),
                          ],
                        ),
                      ),
                      // Step 3: Scoring Weights
                      Step(
                        title: Text('Scoring Weights', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Define what matters most for scoring.', style: GoogleFonts.inter(fontSize: 12)),
                        isActive: _currentStep >= 2,
                        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Adjust the weights below to tailor how the AI calculates the final match score.',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 24),
                            _buildSlider('Technical Skills', _skillsWeight, (v) => setState(() => _skillsWeight = v)),
                            _buildSlider('Experience & Pedigree', _experienceWeight, (v) => setState(() => _experienceWeight = v)),
                            _buildSlider('Culture Fit & Soft Skills', _cultureWeight, (v) => setState(() => _cultureWeight = v)),
                          ],
                        ),
                      ),
                      // Step 4: Automation Settings
                      Step(
                        title: Text('Automation Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Set thresholds for automatic pipeline actions.', style: GoogleFonts.inter(fontSize: 12)),
                        isActive: _currentStep >= 3,
                        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Candidates scoring at or above this percentage will be automatically moved to the Shortlisted pipeline.',
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
                            ),
                            const SizedBox(height: 24),
                            _buildSlider('Auto-Shortlist Cutoff', _cutoffScore, (v) => setState(() => _cutoffScore = v)),
                          ],
                        ),
                      ),
                      // Step 5: AI Providers
                      Step(
                        title: Text('AI Providers', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text('Configure API keys for resume extraction.', style: GoogleFonts.inter(fontSize: 12)),
                        isActive: _currentStep >= 4,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildKeyInput('OpenAI API Key (Optional)', 'sk-...', _openAiController),
                            _buildKeyInput('Claude API Key (Optional)', 'sk-ant-...', _claudeController),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Show Keys', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
                                Switch(
                                  value: !_obscure,
                                  onChanged: (v) => setState(() => _obscure = !v),
                                  activeColor: const Color(0xFF1A56DB),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Preferred AI Provider',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedProvider,
                                  isExpanded: true,
                                  items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  onChanged: (v) => setState(() => _selectedProvider = v!),
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFEF4444)))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }
}
