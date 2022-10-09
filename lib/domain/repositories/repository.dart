import 'package:dartz/dartz.dart';
import 'package:voxalate/domain/entities/transcribe_output.dart';
import 'package:voxalate/failures.dart';

abstract class Repository {
  Future<Either<Failure, TranscribeOutput>> getTranscribeOutput(String path);
}
