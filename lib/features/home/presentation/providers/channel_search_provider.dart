import 'package:zedu/core/core.dart';

/// The channel whose message search is open beside it, or null when no
/// search is open (Ziki #2849). Switching to another channel shows no search,
/// because the panel only opens for the channel id stored here.
class ChannelSearchNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String channelId) => state = channelId;

  void close() => state = null;
}

final channelSearchProvider = NotifierProvider<ChannelSearchNotifier, String?>(
  ChannelSearchNotifier.new,
);
