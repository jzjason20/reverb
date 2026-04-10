import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class SpeechCaptureService {
  bool get isListening;
  Future<bool> initialize();
  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onTranscript,
    void Function(String status)? onStatus,
    void Function(String message)? onError,
    void Function(double level)? onSoundLevel,
  });
  Future<void> stopListening();
  Future<void> cancelListening();
}

class DeviceSpeechCaptureService implements SpeechCaptureService {
  DeviceSpeechCaptureService({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;
  bool _initialized = false;

  @override
  bool get isListening => _speechToText.isListening;

  @override
  Future<bool> initialize() async {
    if (_initialized) {
      return _speechToText.isAvailable;
    }

    _initialized = await _speechToText.initialize();
    return _initialized;
  }

  @override
  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onTranscript,
    void Function(String status)? onStatus,
    void Function(String message)? onError,
    void Function(double level)? onSoundLevel,
  }) async {
    if (!await initialize()) {
      onError?.call('Device speech recognition is not available here.');
      return;
    }

    await _speechToText.initialize(
      onError: (SpeechRecognitionError error) {
        onError?.call(error.errorMsg);
      },
      onStatus: onStatus,
    );

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onTranscript(result.recognizedWords, result.finalResult);
      },
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        onDevice: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
      ),
    );
  }

  @override
  Future<void> stopListening() => _speechToText.stop();

  @override
  Future<void> cancelListening() => _speechToText.cancel();
}

class DisabledSpeechCaptureService implements SpeechCaptureService {
  @override
  bool get isListening => false;

  @override
  Future<void> cancelListening() async {}

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onTranscript,
    void Function(String status)? onStatus,
    void Function(String message)? onError,
    void Function(double level)? onSoundLevel,
  }) async {
    onError?.call(
      'Device speech recognition is not available in this context.',
    );
  }

  @override
  Future<void> stopListening() async {}
}
