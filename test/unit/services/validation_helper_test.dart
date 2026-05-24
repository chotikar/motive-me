import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Services/validation_helper.dart';

void main() {
  group('ValidationHelper - Boundary Value Analysis (BVA) & Equivalence Partitioning (EP)', () {
    
    // ─── 1. Goal Validation (Range: 1 to 10,000) ─────────────────────────────
    group('Goal Validation [BVA & EP]', () {
      // ── BVA Cases
      test('BVA - Input "0" (Below Lower Boundary) -> Invalid', () {
        expect(ValidationHelper.validateGoal('0'), equals('Must be at least 1'));
      });

      test('BVA - Input "1" (On Lower Boundary) -> Valid', () {
        expect(ValidationHelper.validateGoal('1'), isNull);
      });

      test('BVA - Input "2" (Above Lower Boundary) -> Valid', () {
        expect(ValidationHelper.validateGoal('2'), isNull);
      });

      test('BVA - Input "9999" (Below Upper Boundary) -> Valid', () {
        expect(ValidationHelper.validateGoal('9999'), isNull);
      });

      test('BVA - Input "10000" (On Upper Boundary) -> Valid', () {
        expect(ValidationHelper.validateGoal('10000'), isNull);
      });

      test('BVA - Input "10001" (Above Upper Boundary) -> Invalid', () {
        expect(ValidationHelper.validateGoal('10001'), equals('Max is 10,000'));
      });

      // ── EP Cases
      test('EP [Invalid Partition 1: Negatives & Zero] - Input "-50" -> Invalid', () {
        expect(ValidationHelper.validateGoal('-50'), equals('Must be at least 1'));
      });

      test('EP [Valid Partition: In-Range] - Input "500" -> Valid', () {
        expect(ValidationHelper.validateGoal('500'), isNull);
      });

      test('EP [Invalid Partition 2: Too High] - Input "15000" -> Invalid', () {
        expect(ValidationHelper.validateGoal('15000'), equals('Max is 10,000'));
      });
    });

    // ─── 2. Reward Validation (Min: 0) ───────────────────────────────────────
    group('Reward Validation [BVA & EP]', () {
      // ── BVA Cases
      test('BVA - Input "-1" (Below Boundary) -> Invalid', () {
        expect(ValidationHelper.validateReward('-1'), equals('Must be 0 or more'));
      });

      test('BVA - Input "0" (On Boundary) -> Valid', () {
        expect(ValidationHelper.validateReward('0'), isNull);
      });

      test('BVA - Input "1" (Above Boundary) -> Valid', () {
        expect(ValidationHelper.validateReward('1'), isNull);
      });

      // ── EP Cases
      test('EP [Invalid Partition: Negatives] - Input "-10" -> Invalid', () {
        expect(ValidationHelper.validateReward('-10'), equals('Must be 0 or more'));
      });

      test('EP [Valid Partition: Positive] - Input "100" -> Valid', () {
        expect(ValidationHelper.validateReward('100'), isNull);
      });
    });

    // ─── 3. Password Validation (Min: 6 characters) ──────────────────────────
    group('Password Validation [BVA & EP]', () {
      // ── BVA Cases
      test('BVA - Input 5 chars (Below Boundary) -> Invalid', () {
        expect(ValidationHelper.validatePassword('abcde'), equals('Password must be at least 6 characters'));
      });

      test('BVA - Input 6 chars (On Boundary) -> Valid', () {
        expect(ValidationHelper.validatePassword('abcdef'), isNull);
      });

      test('BVA - Input 7 chars (Above Boundary) -> Valid', () {
        expect(ValidationHelper.validatePassword('abcdefg'), isNull);
      });

      // ── EP Cases
      test('EP [Invalid Partition: Too Short] - Input "abc" (3 chars) -> Invalid', () {
        expect(ValidationHelper.validatePassword('abc'), equals('Password must be at least 6 characters'));
      });

      test('EP [Valid Partition: Long Enough] - Input "mysecurepwd" (11 chars) -> Valid', () {
        expect(ValidationHelper.validatePassword('mysecurepwd'), isNull);
      });
    });

    // ─── 4. Skill Name Validation (Length: 1 to 80 characters, Charset: A-Z a-z 0-9 _ - space) ───
    group('Skill Name Validation [BVA & EP]', () {
      // ── BVA Cases
      test('BVA - Input "" (Below Lower Boundary) -> Invalid', () {
        expect(ValidationHelper.validateSkillName(''), equals('Name is required'));
      });

      test('BVA - Input "A" (On Lower Boundary) -> Valid', () {
        expect(ValidationHelper.validateSkillName('A'), isNull);
      });

      test('BVA - Input 79 chars (Below Upper Boundary) -> Valid', () {
        expect(ValidationHelper.validateSkillName('A' * 79), isNull);
      });

      test('BVA - Input 80 chars (On Upper Boundary) -> Valid', () {
        expect(ValidationHelper.validateSkillName('A' * 80), isNull);
      });

      test('BVA - Input 81 chars (Above Upper Boundary) -> Invalid', () {
        expect(ValidationHelper.validateSkillName('A' * 81), equals('Max is 80 characters'));
      });

      // ── EP Cases
      test('EP [Valid Partition: In-Range] - Input "Push-ups 101" -> Valid', () {
        expect(ValidationHelper.validateSkillName('Push-ups 101'), isNull);
      });

      test('EP [Invalid Partition 1: Too Long] - Input 90 chars -> Invalid', () {
        expect(ValidationHelper.validateSkillName('A' * 90), equals('Max is 80 characters'));
      });

      test('EP [Invalid Partition 2: Disallowed Characters] - Input "Push-ups!" -> Invalid', () {
        expect(ValidationHelper.validateSkillName('Push-ups!'), equals('Only letters, numbers, space, _ and - allowed'));
      });
    });
  });
}
