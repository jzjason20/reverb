import 'package:flutter/material.dart';

import 'app/reverb_app.dart';
import 'bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.initialize();
  runApp(
    ReverbApp(
      controller: bootstrap.controller,
      speechCaptureService: bootstrap.speechCaptureService,
      whisperTranscribeService: bootstrap.whisperTranscribeService,
    ),
  );
}
