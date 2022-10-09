import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:voxalate/data/data_sources/remote_data_source.dart';
import 'package:voxalate/domain/entities/transcribe_output.dart';
import 'package:voxalate/domain/repositories/repository.dart';
import 'package:voxalate/exception.dart';
import 'package:voxalate/failures.dart';

class RepositoryImplementation implements Repository {
  final RemoteDataSource remoteDataSource;

  RepositoryImplementation({required this.remoteDataSource});

  @override
  Future<Either<Failure, TranscribeOutput>> getTranscribeOutput(
    String path,
  ) async {
    try {
      await remoteDataSource.uploadFile(path);
      final initialPrediction = await remoteDataSource.startPrediction();
      final predictionStream = remoteDataSource.getPredictionStream(
        initialPrediction.id!,
      );
      final prediction = await predictionStream.first;
      String englishText = prediction.output!.transcription!;

      // If the translation is not null, use it instead of the transcription because it means the transcription was in a language other than English
      if (prediction.output!.translation != null) {
        englishText = prediction.output!.translation!;
      }

      final summary = await remoteDataSource.getSummary(englishText);

      return Right(
        TranscribeOutput(
          transcription: prediction.output!.transcription!,
          translation: prediction.output!.translation,
          summary: summary.choices!.first.text,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.toString()));
    } on SocketException catch (e) {
      return Left(ConnectionFailure(e.toString()));
    } on Exception catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
