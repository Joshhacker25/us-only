import 'package:flutter_test/flutter_test.dart';

// NOTE: relative import (not package:only_us/...) so this test runs
// whatever package name Part A gives the app in pubspec.yaml.
import '../../lib/shared/utils/dedup.dart';

/// Minimal stand-in for a chat message, to keep this test independent
/// of the real message model (Part B/C may change it).
class TestMessage {
  final String id; // server-assigned id, may differ per copy
  final String clientId; // stable id assigned at send time
  final String text;

  const TestMessage({
    required this.id,
    required this.clientId,
    required this.text,
  });
}

void main() {
  group('dedupeByClientId', () {
    test('removes the second copy of a message with the same clientId', () {
      const localEcho = TestMessage(
        id: 'local-1',
        clientId: 'c-1',
        text: 'hello',
      );
      const fromServer = TestMessage(
        id: 'srv-9',
        clientId: 'c-1',
        text: 'hello',
      );
      final result = dedupeByClientId<TestMessage>(
        [localEcho, fromServer],
        (m) => m.clientId,
      );
      expect(result, hasLength(1));
      // First occurrence wins — the local echo is kept.
      expect(result.first.id, 'local-1');
    });

    test('keeps order and keeps distinct messages', () {
      final messages = [
        const TestMessage(id: 'a', clientId: 'c-1', text: 'one'),
        const TestMessage(id: 'b', clientId: 'c-2', text: 'two'),
        const TestMessage(id: 'c', clientId: 'c-3', text: 'three'),
      ];
      final result = dedupeByClientId<TestMessage>(
        messages,
        (m) => m.clientId,
      );
      expect(result.map((m) => m.id).toList(), ['a', 'b', 'c']);
    });

    test('drops a duplicate in the middle, keeps the rest in order', () {
      final messages = [
        const TestMessage(id: 'a', clientId: 'c-1', text: 'one'),
        const TestMessage(id: 'b', clientId: 'c-2', text: 'two'),
        const TestMessage(id: 'b2', clientId: 'c-2', text: 'two again'),
        const TestMessage(id: 'c', clientId: 'c-3', text: 'three'),
        const TestMessage(id: 'a2', clientId: 'c-1', text: 'one again'),
      ];
      final result = dedupeByClientId<TestMessage>(
        messages,
        (m) => m.clientId,
      );
      expect(result.map((m) => m.id).toList(), ['a', 'b', 'c']);
    });

    test('empty clientId is never deduplicated', () {
      // Two messages with no clientId are two different messages.
      final messages = [
        const TestMessage(id: 'a', clientId: '', text: 'one'),
        const TestMessage(id: 'b', clientId: '', text: 'two'),
      ];
      final result = dedupeByClientId<TestMessage>(
        messages,
        (m) => m.clientId,
      );
      expect(result, hasLength(2));
    });

    test('empty list stays empty; all-unique list is unchanged', () {
      expect(
        dedupeByClientId<TestMessage>([], (m) => m.clientId),
        isEmpty,
      );
      final messages = [
        const TestMessage(id: 'a', clientId: 'c-1', text: 'one'),
        const TestMessage(id: 'b', clientId: 'c-2', text: 'two'),
      ];
      expect(
        dedupeByClientId<TestMessage>(messages, (m) => m.clientId),
        hasLength(2),
      );
    });

    test('does not mutate the input list', () {
      final messages = [
        const TestMessage(id: 'a', clientId: 'c-1', text: 'one'),
        const TestMessage(id: 'a2', clientId: 'c-1', text: 'one again'),
      ];
      final result = dedupeByClientId<TestMessage>(
        messages,
        (m) => m.clientId,
      );
      expect(messages, hasLength(2));
      expect(result, hasLength(1));
    });
  });

  group('dedupeMessageMaps', () {
    test('dedupes maps by their clientId key', () {
      final messages = [
        {'clientId': 'c-1', 'text': 'hi'},
        {'clientId': 'c-1', 'text': 'hi'},
        {'clientId': 'c-2', 'text': 'hey'},
      ];
      expect(dedupeMessageMaps(messages), hasLength(2));
    });

    test('maps without a clientId key are kept', () {
      final messages = [
        {'text': 'no id 1'},
        {'text': 'no id 2'},
      ];
      expect(dedupeMessageMaps(messages), hasLength(2));
    });
  });
}
