class OpenAiCompletionModel {
  final String? id;
  final String? object;
  final int? created;
  final String? model;
  final List<OpenAiCompletionChoice>? choices;
  final OpenAiCompletionUsage? usage;

  OpenAiCompletionModel({
    this.id,
    this.object,
    this.created,
    this.model,
    this.choices,
    this.usage,
  });

  factory OpenAiCompletionModel.fromJson(Map<String, dynamic> json) {
    return OpenAiCompletionModel(
      id: json['id'] as String?,
      object: json['object'] as String?,
      created: json['created'] as int?,
      model: json['model'] as String?,
      choices: json['choices'] != null
          ? (json['choices'] as List<dynamic>)
              .map(
                (e) =>
                    OpenAiCompletionChoice.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : null,
      usage: json['usage'] != null
          ? OpenAiCompletionUsage.fromJson(
              json['usage'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class OpenAiCompletionChoice {
  final String? text;
  final int? index;
  final dynamic logprobs;
  final String? finishReason;

  OpenAiCompletionChoice({
    this.text,
    this.index,
    this.logprobs,
    this.finishReason,
  });

  factory OpenAiCompletionChoice.fromJson(Map<String, dynamic> json) {
    return OpenAiCompletionChoice(
      text: json['text'] as String?,
      index: json['index'] as int?,
      logprobs: json['logprobs'],
      finishReason: json['finish_reason'] as String?,
    );
  }
}

class OpenAiCompletionUsage {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  OpenAiCompletionUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  factory OpenAiCompletionUsage.fromJson(Map<String, dynamic> json) {
    return OpenAiCompletionUsage(
      promptTokens: json['prompt_tokens'] as int?,
      completionTokens: json['completion_tokens'] as int?,
      totalTokens: json['total_tokens'] as int?,
    );
  }
}
