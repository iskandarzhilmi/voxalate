part of 'transcribe_bloc.dart';

abstract class TranscribeEvent extends Equatable {
  const TranscribeEvent();

  @override
  List<Object> get props => [];
}

class TranscribeStarted extends TranscribeEvent {
  final String path;

  const TranscribeStarted(this.path);

  @override
  List<Object> get props => [path];
}
