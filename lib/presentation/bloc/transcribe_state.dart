part of 'transcribe_bloc.dart';

abstract class TranscribeState extends Equatable {
  const TranscribeState();

  @override
  List<Object> get props => [];
}

class TranscribeInitial extends TranscribeState {}

class TranscribeLoading extends TranscribeState {}

class TranscribeLoaded extends TranscribeState {
  final TranscribeOutput transcribeOutput;

  const TranscribeLoaded(this.transcribeOutput);

  @override
  List<Object> get props => [transcribeOutput];
}

class TranscribeError extends TranscribeState {
  final String message;

  const TranscribeError(this.message);

  @override
  List<Object> get props => [message];
}
