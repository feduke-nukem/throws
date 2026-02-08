class InheritedThrowsInfo {
  final bool hasAnnotatedSuper;
  final bool allowAny;
  final Set<String> expectedErrors;

  const InheritedThrowsInfo({
    required this.hasAnnotatedSuper,
    required this.allowAny,
    required this.expectedErrors,
  });
}
