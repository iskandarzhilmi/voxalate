import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:voxalate/domain/entities/transcribe_output.dart';
import 'package:voxalate/domain/use_cases/get_transcribe_output.dart';
import 'package:voxalate/failures.dart';

part 'transcribe_event.dart';
part 'transcribe_state.dart';

class TranscribeBloc extends Bloc<TranscribeEvent, TranscribeState> {
  final GetTranscribeOutput _getTranscribeOutput;

  TranscribeBloc(this._getTranscribeOutput) : super(TranscribeInitial()) {
    on<TranscribeStarted>(_onTranscribeStarted);
  }
  Future<void> _onTranscribeStarted(TranscribeEvent event, Emitter emit) async {
    final path = (event as TranscribeStarted).path;
    emit(TranscribeLoading());
    final result = await _getTranscribeOutput.execute(path);
    result.fold(
      (failure) => emit(TranscribeError(failure.message)),
      (transcribeOutput) => emit(TranscribeLoaded(transcribeOutput)),
    );
  }
}
