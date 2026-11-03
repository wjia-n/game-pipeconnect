import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipeconnect/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'pipeconnectstar'});
    expect(StoreService.starId, 'pipeconnectstar');
  });
  test('Android maps to coffee + chocolate only', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'pipeconnectcoffee', 'pipeconnectchocolate'});
    expect(StoreService.productIdsFor(TargetPlatform.android),
        isNot(contains('pipeconnectstar')));
  });
}
