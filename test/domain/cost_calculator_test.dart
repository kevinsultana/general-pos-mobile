import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/domain/services/cost_calculator.dart';

void main() {
  group('CostCalculator — Weighted Average Cost Tests', () {
    test('PRD Example 1: 10 units @ Rp5.000 + 20 units @ Rp6.000 -> Rp5.667', () {
      final newCost = CostCalculator.calculateWeightedAverageCost(
        existingQty: 10,
        existingCost: 5000,
        addedQty: 20,
        addedCost: 6000,
      );
      // (50.000 + 120.000) / 30 = 5666.666... -> 5667
      expect(newCost, equals(5667));
    });

    test('Zero initial stock should take added unit cost as new HPP', () {
      final newCost = CostCalculator.calculateWeightedAverageCost(
        existingQty: 0,
        existingCost: 0,
        addedQty: 15,
        addedCost: 7500,
      );
      expect(newCost, equals(7500));
    });

    test('Negative initial stock should reset HPP to added unit cost', () {
      final newCost = CostCalculator.calculateWeightedAverageCost(
        existingQty: -3,
        existingCost: 4000,
        addedQty: 10,
        addedCost: 5500,
      );
      expect(newCost, equals(5500));
    });

    test('Added quantity <= 0 should retain existing unit cost', () {
      final newCost = CostCalculator.calculateWeightedAverageCost(
        existingQty: 10,
        existingCost: 8000,
        addedQty: 0,
        addedCost: 9000,
      );
      expect(newCost, equals(8000));
    });
  });
}
