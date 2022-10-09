import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:voxalate/data/data_sources/remote_data_source.dart';
import 'package:voxalate/data/repositories/repository_implementation.dart';
import 'package:voxalate/domain/repositories/repository.dart';
import 'package:voxalate/domain/use_cases/get_transcribe_output.dart';
import 'package:voxalate/presentation/bloc/transcribe_bloc.dart';

final locator = GetIt.instance;

void initialiseLocator() {
  // Blocs
  locator.registerFactory(() => TranscribeBloc(locator()));

  // Use cases
  locator.registerLazySingleton(() => GetTranscribeOutput(locator()));

  // Repositories
  locator.registerLazySingleton<Repository>(
    () => RepositoryImplementation(remoteDataSource: locator()),
  );

  // Data sources
  locator.registerLazySingleton<RemoteDataSource>(
    () => RemoteDataSourceImplementation(
      client: locator(),
    ),
  );

  // External
  locator.registerLazySingleton(() => http.Client());
}
