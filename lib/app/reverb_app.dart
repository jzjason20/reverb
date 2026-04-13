import 'package:flutter/material.dart';

import '../controllers/reverb_controller.dart';
import '../screens/reverb_home_screen.dart';
import '../services/speech_capture_service.dart';
import '../services/whisper_transcribe_service.dart';
import '../theme/app_theme.dart';

class ReverbApp extends StatelessWidget {
  const ReverbApp({
    super.key,
    required this.controller,
    required this.speechCaptureService,
    this.whisperTranscribeService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;
  final WhisperTranscribeService? whisperTranscribeService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reverb',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTemplate,
      darkTheme: AppTheme.darkTemplate,
      home: ReverbHomeScreen(
        controller: controller,
        speechCaptureService: speechCaptureService,
        whisperTranscribeService: whisperTranscribeService,
      ),
    );
  }
}
