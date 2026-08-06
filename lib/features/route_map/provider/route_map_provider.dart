// ============================================================================
// features/today_route/route_map/provider/route_map_provider.dart
//
// UI-state layer for the Route Map screen. Holds ONLY view concerns
// (selected stop, sheet open/closed). The route data itself comes from the
// real `todayRouteProvider`, so the map always reflects live API data.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../today_route/model/route_model.dart';
import '../../today_route/provider/today_route_provider.dart';


/// View-only state: which stop is selected and whether the sheet is expanded.
class RouteMapUiState {
  const RouteMapUiState({
    this.selectedIndex = 0,
    this.sheetExpanded = true,
  });

  final int selectedIndex;
  final bool sheetExpanded;

  RouteMapUiState copyWith({int? selectedIndex, bool? sheetExpanded}) {
    return RouteMapUiState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      sheetExpanded: sheetExpanded ?? this.sheetExpanded,
    );
  }
}

class RouteMapUiNotifier extends StateNotifier<RouteMapUiState> {
  RouteMapUiNotifier(this._ref) : super(const RouteMapUiState()) {
    // Default selection: the in-progress stop, else the first.
    final stops = _ref.read(todayRouteProvider).route?.stops ?? const [];
    final idx = stops.indexWhere((s) => s.status == StopStatus.inProgress);
    if (idx >= 0) state = state.copyWith(selectedIndex: idx);
  }

  final Ref _ref;

  List<RouteStop> get _stops =>
      _ref.read(todayRouteProvider).route?.stops ?? const [];

  void selectStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    state = state.copyWith(selectedIndex: index, sheetExpanded: true);
  }

  void nextStop() => selectStop(state.selectedIndex + 1);
  void prevStop() => selectStop(state.selectedIndex - 1);

  void toggleSheet() =>
      state = state.copyWith(sheetExpanded: !state.sheetExpanded);

  void setSheetExpanded(bool v) => state = state.copyWith(sheetExpanded: v);

  /// After a pickup/drop completes, move selection to the next in-progress stop.
  void syncSelectionToProgress() {
    final stops = _stops;
    final idx = stops.indexWhere((s) => s.status == StopStatus.inProgress);
    if (idx >= 0) {
      state = state.copyWith(selectedIndex: idx);
    }
  }
}

final routeMapUiProvider =
StateNotifierProvider.autoDispose<RouteMapUiNotifier, RouteMapUiState>(
      (ref) => RouteMapUiNotifier(ref),
);