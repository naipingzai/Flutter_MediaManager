import 'package:flutter_media_view/function/model/availability.dart';
import 'package:flutter/foundation.dart';
import 'package:test/fake.dart';

class FakeAvesAvailability extends Fake implements FmvAvailability {
  @override
  Future<bool> get canLocatePlaces => SynchronousFuture(false);
}
