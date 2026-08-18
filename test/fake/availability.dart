import 'package:flutter_media_view/function/model/function_availability.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeAvesAvailability extends Fake implements AvesAvailability {
  @override
  Future<bool> get canLocatePlaces => SynchronousFuture(false);
}
