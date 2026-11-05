import 'package:zedu/core/core.dart';

class UserMenuState {
  final bool isAway;
  final bool notificationsPaused;

  UserMenuState({this.isAway = false, this.notificationsPaused = false});

  UserMenuState copyWith({bool? isAway, bool? notificationsPaused}) {
    return UserMenuState(
      isAway: isAway ?? this.isAway,
      notificationsPaused: notificationsPaused ?? this.notificationsPaused,
    );
  }
}

final userMenuStateProvider = NotifierProvider<UserMenuNotifier, UserMenuState>(
  UserMenuNotifier.new,
);

class UserMenuNotifier extends Notifier<UserMenuState> {
  @override
  UserMenuState build() {
    return UserMenuState();
  }

  void toggleAwayStatus() {
    state = state.copyWith(isAway: !state.isAway);
  }

  /// Syncs the rail dot and profile panel with the confirmed auth presence.
  void setAway(bool away) {
    if (state.isAway != away) {
      state = state.copyWith(isAway: away);
    }
  }

  void toggleNotifications() {
    state = state.copyWith(notificationsPaused: !state.notificationsPaused);
  }

  void reset() {
    state = UserMenuState();
  }
}
