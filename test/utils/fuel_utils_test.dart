import "package:flutter_test/flutter_test.dart";

import "package:smartroad/utils/fuel_utils.dart";

void main() {
  group("FuelUtils.formatRelativeTime", () {
    test("returns just now for recent timestamps", () {
      final ts = DateTime.now().subtract(const Duration(seconds: 20));
      expect(FuelUtils.formatRelativeTime(ts), "just now");
    });

    test("returns minute format", () {
      final ts = DateTime.now().subtract(const Duration(minutes: 5));
      expect(FuelUtils.formatRelativeTime(ts), "5m ago");
    });

    test("returns hour format", () {
      final ts = DateTime.now().subtract(const Duration(hours: 3));
      expect(FuelUtils.formatRelativeTime(ts), "3h ago");
    });
  });

  group("FuelUtils.isPriceStale", () {
    test("returns false for recent prices", () {
      final ts = DateTime.now().subtract(const Duration(hours: 12));
      expect(FuelUtils.isPriceStale(ts), isFalse);
    });

    test("returns true for stale prices", () {
      final ts = DateTime.now().subtract(const Duration(hours: 25));
      expect(FuelUtils.isPriceStale(ts), isTrue);
    });
  });

  group("FuelUtils.validateDistance", () {
    test("allows <= 50m without photo", () {
      final result = FuelUtils.validateDistance(49.5);
      expect(result.allowed, isTrue);
      expect(result.requiresPhoto, isFalse);
      expect(result.message, isNull);
    });

    test("requires photo for 50m to 200m", () {
      final result = FuelUtils.validateDistance(120);
      expect(result.allowed, isTrue);
      expect(result.requiresPhoto, isTrue);
    });

    test(">200m is rejected", () {
      final result = FuelUtils.validateDistance(250);
      expect(result.allowed, isFalse);
      expect(result.requiresPhoto, isFalse);
      expect(result.message, isNotNull);
    });
  });
}
