import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { plan, workflow, graph, review }

class NavigationState {
  final AppMode currentMode;
  final int selectedIndex;

  const NavigationState({required this.currentMode, required this.selectedIndex});

  NavigationState copyWith({AppMode? currentMode, int? selectedIndex}) {
    return NavigationState(
      currentMode: currentMode ?? this.currentMode,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState(currentMode: AppMode.plan, selectedIndex: 0));

  void setMode(AppMode mode) {
    final index = AppMode.values.indexOf(mode);
    state = state.copyWith(currentMode: mode, selectedIndex: index);
  }

  void setIndex(int index) {
    if (index >= 0 && index < AppMode.values.length) {
      state = state.copyWith(currentMode: AppMode.values[index], selectedIndex: index);
    }
  }
}

final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});
