import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockRepo extends Mock implements UserProfileRepository {}

/// The profile load started in build() fails in tests with the
/// uninitialized-provider error tracked in #51; it is ignored here, as in
/// user_profile_notifier_test.dart.
Future<void> _ignoringProfileLoadError(Future<void> Function() body) {
  final done = Completer<void>();
  runZonedGuarded(
    () => body().then(done.complete, onError: done.completeError),
    (error, stack) {
      if (error is! StateError) done.completeError(error, stack);
    },
  );
  return done.future;
}

void main() {
  group('UserProfileNotifier.updateAccount photo (Ziki #12421)', () {
    late _MockRepo repository;
    late ProviderContainer container;

    setUpAll(() => registerFallbackValue(ProfileAccount.empty()));

    setUp(() {
      repository = _MockRepo();
      when(
        () => repository.updateAccount(any()),
      ).thenAnswer((_) async => Success(ProfileAccount.empty()));
      when(
        () => repository.uploadAvatar(any()),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => repository.removeAvatar(),
      ).thenAnswer((_) async => const Success<void>(null));
      when(() => repository.getAccount()).thenAnswer(
        (_) async => Success(
          ProfileAccount.empty().copyWith(
            avatarUrl: 'https://cdn.zedu.chat/me.png',
          ),
        ),
      );
      container = ProviderContainer(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });

    test('a photo-only change uploads it without an empty PATCH of fields '
        'and shows the new photo', () {
      return _ignoringProfileLoadError(() async {
        final notifier = container.read(userProfileNotifierProvider.notifier);

        await notifier.updateAccount(
          ProfileAccount.empty(),
          photo: const ProfilePhotoEdit.upload('C:/photos/me.png'),
        );

        verifyNever(() => repository.updateAccount(any()));
        verify(() => repository.uploadAvatar('C:/photos/me.png')).called(1);
        final state = container.read(userProfileNotifierProvider);
        expect(state.successMessage, 'Account information saved successfully.');
        expect(state.account?.avatarUrl, 'https://cdn.zedu.chat/me.png');
      });
    });

    test('field edits and a new photo are both saved', () {
      return _ignoringProfileLoadError(() async {
        final notifier = container.read(userProfileNotifierProvider.notifier);

        await notifier.updateAccount(
          ProfileAccount.empty().copyWith(title: 'QA Tester'),
          photo: const ProfilePhotoEdit.upload('C:/photos/me.png'),
        );

        verify(() => repository.updateAccount(any())).called(1);
        verify(() => repository.uploadAvatar('C:/photos/me.png')).called(1);
        expect(
          container.read(userProfileNotifierProvider).account?.title,
          'QA Tester',
        );
      });
    });

    test('removing the photo clears it', () {
      return _ignoringProfileLoadError(() async {
        when(
          () => repository.getAccount(),
        ).thenAnswer((_) async => Success(ProfileAccount.empty()));
        final notifier = container.read(userProfileNotifierProvider.notifier);

        await notifier.updateAccount(
          ProfileAccount.empty(),
          photo: ProfilePhotoEdit.removed,
        );

        verify(() => repository.removeAvatar()).called(1);
        expect(
          container.read(userProfileNotifierProvider).account?.avatarUrl,
          isNull,
        );
      });
    });

    test('a failed upload is reported instead of a false "saved"', () {
      return _ignoringProfileLoadError(() async {
        when(() => repository.uploadAvatar(any())).thenAnswer(
          (_) async => const Failure<void>(ApiFailure(message: 'too large')),
        );
        final notifier = container.read(userProfileNotifierProvider.notifier);

        await notifier.updateAccount(
          ProfileAccount.empty(),
          photo: const ProfilePhotoEdit.upload('C:/photos/me.png'),
        );

        final state = container.read(userProfileNotifierProvider);
        expect(state.error, contains('photo could not be uploaded'));
        expect(state.successMessage, isNull);
        expect(state.isSaving, isFalse);
      });
    });
  });
}
