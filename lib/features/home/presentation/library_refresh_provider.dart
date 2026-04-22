import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markUpdated() {
    state = state + 1;
  }
}

final libraryRefreshProvider = NotifierProvider<LibraryRefreshNotifier, int>(
  () => LibraryRefreshNotifier(),
);
