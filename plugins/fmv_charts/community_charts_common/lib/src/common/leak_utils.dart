// useful constants copied from flutter/foundation `constants.dart`
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool kProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool kDebugMode = !kReleaseMode && !kProfileMode;

// useful constants copied from flutter/foundation `memory_allocations.dart`
const bool _kMemoryAllocations = bool.fromEnvironment('flutter.memory_allocations');
const bool kFlutterMemoryAllocationsEnabled = _kMemoryAllocations || kDebugMode;
