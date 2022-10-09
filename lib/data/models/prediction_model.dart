class PredictionModel {
  final String? id;
  final String? version;
  final String? createdAt;
  final String? completedAt;
  final String? status;
  final PredictionInput? input;
  final PredictionOutput? output;
  final String? error;
  final String? logs;
  final PredictionMetrics? metrics;

  PredictionModel({
    this.id,
    this.version,
    this.createdAt,
    this.completedAt,
    this.status,
    this.input,
    this.output,
    this.error,
    this.logs,
    this.metrics,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      id: json['id'] as String?,
      version: json['version'] as String?,
      createdAt: json['created_at'] as String?,
      completedAt: json['completed_at'] as String?,
      status: json['status'] as String?,
      input: json['input'] != null
          ? PredictionInput.fromJson(json['input'] as Map<String, dynamic>)
          : null,
      output: json['output'] != null
          ? PredictionOutput.fromJson(json['output'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      logs: json['logs'] as String?,
      metrics: json['metrics'] != null
          ? PredictionMetrics.fromJson(
              json['metrics'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class PredictionInput {
  final String? audio;
  final String? model;
  final bool? translate;

  PredictionInput({
    this.audio,
    this.model,
    this.translate,
  });

  factory PredictionInput.fromJson(Map<String, dynamic> json) {
    return PredictionInput(
      audio: json['audio'] as String?,
      model: json['model'] as String?,
      translate: json['translate'] as bool?,
    );
  }
}

class PredictionOutput {
  final String? translation;
  final String? transcription;
  final String? detectedLanguage;

  PredictionOutput({
    this.translation,
    this.transcription,
    this.detectedLanguage,
  });

  factory PredictionOutput.fromJson(Map<String, dynamic> json) {
    return PredictionOutput(
      translation: json['translation'] as String?,
      transcription: json['transcription'] as String?,
      detectedLanguage: json['detected_language'] as String?,
    );
  }
}

class PredictionMetrics {
  final double? predictTime;

  PredictionMetrics({
    this.predictTime,
  });

  factory PredictionMetrics.fromJson(Map<String, dynamic> json) {
    return PredictionMetrics(
      predictTime: json['predict_time'] as double?,
    );
  }
}
