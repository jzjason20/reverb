import 'package:flutter/material.dart';

import '../controllers/reverb_controller.dart';
import '../services/speech_capture_service.dart';

class CaptureSheet extends StatefulWidget {
  const CaptureSheet({
    super.key,
    required this.controller,
    required this.speechCaptureService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;

  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  late final TextEditingController _textController;
  bool _isPreparingSpeech = true;
  bool _speechAvailable = false;
  bool _isListening = false;
  double _soundLevel = 0;
  String? _statusText;
  String? _speechError;

  static const _suggestions = [
    'i need to send the updated pitch deck tonight',
    'idea: stitch together scattered voice notes into a weekly review',
    'remind me to stretch in 45 minutes',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _prepareSpeech();
  }

  @override
  void dispose() {
    widget.speechCaptureService.cancelListening();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _prepareSpeech() async {
    final available = await widget.speechCaptureService.initialize();
    if (!mounted) {
      return;
    }

    setState(() {
      _isPreparingSpeech = false;
      _speechAvailable = available;
      _statusText = available
          ? 'Tap the mic and speak. Review the transcript, then save it.'
          : 'Device speech recognition is unavailable here. You can still type.';
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await widget.speechCaptureService.stopListening();
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _statusText = 'Review the transcript, then save it.';
      });
      return;
    }

    setState(() {
      _speechError = null;
      _isListening = true;
      _statusText = 'Listening on device...';
    });

    await widget.speechCaptureService.startListening(
      onTranscript: (transcript, isFinal) {
        if (!mounted) {
          return;
        }
        setState(() {
          _textController.text = transcript;
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
          if (isFinal) {
            _isListening = false;
            _statusText = 'Transcript captured. Adjust it if needed.';
          }
        });
      },
      onStatus: (status) {
        if (!mounted) {
          return;
        }

        final normalized = status.toLowerCase();
        setState(() {
          if (normalized == 'listening') {
            _isListening = true;
            _statusText = 'Listening on device...';
          } else if (normalized == 'done' || normalized == 'notlistening') {
            _isListening = false;
          }
        });
      },
      onError: (message) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isListening = false;
          _speechError = message;
          _statusText = 'Speech capture stopped. You can type or try again.';
        });
      },
      onSoundLevel: (level) {
        if (!mounted) {
          return;
        }
        setState(() {
          _soundLevel = level.clamp(0, 50);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capture memory',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.controller.remoteSummaryEnabled
                ? 'Local speech capture is on. OpenAI summaries are also enabled through your env config.'
                : 'Local speech capture is on. Add your OpenAI key in `.env` when you want remote summaries.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isPreparingSpeech ? null : _toggleListening,
                      icon: Icon(
                        _isListening ? Icons.stop_circle_outlined : Icons.mic,
                      ),
                      label: Text(
                        _isPreparingSpeech
                            ? 'Preparing...'
                            : _isListening
                            ? 'Stop listening'
                            : 'Start listening',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                        value: _isListening
                            ? (_soundLevel / 50).clamp(0.05, 1.0)
                            : 0.02,
                        backgroundColor: const Color(0xFFEAE2D7),
                        color: const Color(0xFFCC5C3B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _speechError ?? _statusText ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!_speechAvailable && !_isPreparingSpeech) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Manual fallback stays available, so capture still works even if the device recognizer does not.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Say whatever is on your mind...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  _textController.text = suggestion;
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (_isListening) {
                  await widget.speechCaptureService.stopListening();
                }
                await widget.controller.captureTranscript(_textController.text);
                if (mounted) {
                  navigator.pop();
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save memory'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
