import 'package:dartz/dartz.dart';
import 'package:voxalate/domain/entities/transcribe_output.dart';
import 'package:voxalate/domain/repositories/repository.dart';
import 'package:voxalate/failures.dart';

class GetTranscribeOutput {
  final Repository repository;

  GetTranscribeOutput(this.repository);

  Future<Either<Failure, TranscribeOutput>> execute(String path) async {
    return repository.getTranscribeOutput(path);
  }
}
