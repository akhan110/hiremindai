import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _openAiController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final settings = await FirebaseService.getUserSettings();
      if (settings != null) {
        setState(() {
          _openAiController.text = settings['openai_key'] ?? '';
        });
        return;
      }
    } catch (e) {
      // Ignored
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _openAiController.text = prefs.getString('openai_key') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_key', _openAiController.text.trim());
    await prefs.setString('preferred_provider', 'OpenAI');

    try {
      await FirebaseService.saveUserSettings({
        'openai_key': _openAiController.text.trim(),
        'preferred_provider': 'OpenAI',
      });
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _finishSetup() async {
    final activeKey = _openAiController.text.trim();

    if (activeKey.isEmpty) {
      setState(() => _error = 'Please enter an OpenAI API key.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = OpenAIService(activeKey, '', '', 40, 40, 20);
      final valid = await service.validateApiKey();
      if (!valid) {
        setState(() => _error = 'Invalid OpenAI API key. Please check and try again.');
        return;
      }

      await _saveSettings();

      if (!mounted) return;
      
      final apiKeys = {
        'OpenAI': activeKey,
      };

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            apiKeys: apiKeys,
            provider: 'OpenAI',
            customPrompt: '',
            shortlistCutoff: 75,
            companyName: '',
            companyIndustry: '',
            weightSkills: 40,
            weightExperience: 40,
            weightCulture: 20,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Could not validate key. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

              // Setup Card
              Container(
                width: isMobile ? double.infinity : 500,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Provider',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your OpenAI API key to enable AI features. Your key is stored locally on your device.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'OpenAI API Key',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _openAiController,
                      obscureText: _obscure,
                      style: GoogleFonts.robotoMono(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'sk-...',
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
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Show Key', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
                        Switch(
                          value: !_obscure,
                          onChanged: (v) => setState(() => _obscure = !v),
                          activeTrackColor: const Color(0xFF1A56DB),
                        ),
                      ],
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

                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _finishSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text('Finish Setup', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }
}
