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
  bool _userRequestedStop = false;
  String _priorText = '';
  double _soundLevel = 0;
  String? _statusText;
  String? _speechError;

  static const _suggestions = [
    'I need to send the updated pitch deck tonight',
    'Idea: stitch scattered voice notes into a weekly review',
    'Remind me to stretch in 45 minutes or else',
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
      _userRequestedStop = true;
      await widget.speechCaptureService.stopListening();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _statusText = 'Review the transcript, then save it.';
      });
      return;
    }

    _userRequestedStop = false;
    _startListeningSession();
  }

  void _startListeningSession() {
    // Capture whatever is already in the box — new speech appends to it.
    _priorText = _textController.text.trimRight();

    setState(() {
      _speechError = null;
      _isListening = true;
      _statusText = 'Listening on device...';
    });

    widget.speechCaptureService.startListening(
      onTranscript: (transcript, isFinal) {
        if (!mounted) return;
        final prefix = _priorText.isEmpty ? '' : '$_priorText ';
        setState(() {
          _textController.text = '$prefix$transcript';
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
        });
        // Don't flip _isListening on isFinal — let onStatus be authoritative
        // so we don't flicker when we auto-restart the session.
      },
      onStatus: (status) {
        if (!mounted) return;
        final normalized = status.toLowerCase();
        if (normalized == 'listening') {
          setState(() {
            _isListening = true;
            _statusText = 'Listening on device...';
          });
        } else if (normalized == 'done' || normalized == 'notlistening') {
          if (!_userRequestedStop) {
            // Session ended naturally (OS timeout/pause limit).
            // Transparently restart so the user never has to think about it.
            _priorText = _textController.text.trimRight();
            _startListeningSession();
          } else {
            if (mounted) setState(() => _isListening = false);
          }
        }
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _speechError = message;
          _statusText = 'Speech hiccup. Tap mic to keep going.';
        });
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level.clamp(0, 50));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capture something genius',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.controller.remoteSummaryEnabled
                ? 'Local speech capture is on. Gemini AI summaries enabled.'
                : 'Local speech capture is on. Add a Gemini key later for magic summaries.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
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
                            ? 'Warming up...'
                            : _isListening
                            ? 'Make it stop!'
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
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _speechError ?? _statusText ?? '',
                  style: theme.textTheme.bodySmall,
                ),
                if (!_speechAvailable && !_isPreparingSpeech) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Manual fallback stays available, so capture still works even if the mic fails.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: 'Type your deep thoughts...',
              filled: true,
              fillColor: theme.cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
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
            child: FilledButton.tonal(
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
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Save this masterpiece',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
