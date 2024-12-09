class DevTools {
  static bool get isDevMode => !const bool.fromEnvironment('dart.vm.product');

  static Widget getTestScreen() {
    if (isDevMode) {
      return const TestScreen();
    }
    return const SizedBox.shrink(); // Return empty widget for production
  }
}
