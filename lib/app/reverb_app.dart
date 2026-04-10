import 'package:flutter/material.dart';

import '../controllers/reverb_controller.dart';
import '../screens/reverb_home_screen.dart';
import '../services/speech_capture_service.dart';
import '../theme/app_theme.dart';

class ReverbApp extends StatelessWidget {
  const ReverbApp({
    super.key,
    required this.controller,
    required this.speechCaptureService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reverb',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: ReverbHomeScreen(
        controller: controller,
        speechCaptureService: speechCaptureService,
      ),
    );
  }
}
