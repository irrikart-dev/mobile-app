import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav tab `EntryPoint` shows. Lives outside the widget so a
/// screen nested inside one tab (e.g. Cart's empty-state "Start Shopping")
/// can jump to another (Home) without `EntryPoint` handing every tab a
/// callback of its own.
final entryTabIndexProvider = StateProvider<int>((ref) => 0);
