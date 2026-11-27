import 'dart:async';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MagicLinkNotifier extends AsyncNotifier<void> {
  late final AuthRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(authRepositoryProvider);
  }

  /// Sends a magic link to [email]. With [rememberMe] false the session the
  /// link opens lasts until the app closes.
  Future<bool> send(String email, {bool rememberMe = true}) async {
    state = const AsyncLoading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final result = await _repository.sendMagicLink(email: email);
      switch (result) {
        case Success<void>():
          await ref
              .read(authNotifierProvider.notifier)
              .rememberMagicLinkChoice(rememberMe);
          success = true;
        case Failure<void>():
          throw result.error;
      }
    });
    return success;
  }
}

final magicLinkNotifierProvider =
    AsyncNotifierProvider<MagicLinkNotifier, void>(MagicLinkNotifier.new);
