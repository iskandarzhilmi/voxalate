import 'package:equatable/equatable.dart';

class TranscribeOutput extends Equatable {
  final String detectedLanguage;
  final String transcription;
  final String? translation;
  final String? summary;

  const TranscribeOutput({
    required this.detectedLanguage,
    required this.transcription,
    required this.translation,
    this.summary,
  });

  @override
  List<Object?> get props => [
        detectedLanguage,
        transcription,
        translation,
        summary,
      ];
}
