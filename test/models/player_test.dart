import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant/models/player.dart';
import 'package:music_assistant/models/media_item.dart';

void main() {
  group('Player', () {
    test('fromJson creates player with all fields', () {
      final json = {
        'player_id': 'player_1',
        'name': 'Living Room',
        'available': true,
        'powered': true,
        'state': 'playing',
        'current_item_id': 'item_123',
        'volume_level': 75,
        'volume_muted': false,
      };

      final player = Player.fromJson(json);

      expect(player.playerId, 'player_1');
      expect(player.name, 'Living Room');
      expect(player.available, true);
      expect(player.powered, true);
      expect(player.state, 'playing');
      expect(player.currentItemId, 'item_123');
      expect(player.volumeLevel, 75);
      expect(player.volumeMuted, false);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'player_id': 'player_1',
        'name': 'Kitchen',
      };

      final player = Player.fromJson(json);

      expect(player.playerId, 'player_1');
      expect(player.name, 'Kitchen');
      expect(player.available, false); // default
      expect(player.powered, false); // default
      expect(player.state, 'idle'); // default
      expect(player.currentItemId, isNull);
      expect(player.volumeLevel, isNull);
      expect(player.volumeMuted, isNull);
    });

    test('derived properties work correctly', () {
      final playingPlayer = Player.fromJson({
        'player_id': '1',
        'name': 'Test',
        'state': 'playing',
        'volume_level': 50,
        'volume_muted': true,
      });

      expect(playingPlayer.isPlaying, true);
      expect(playingPlayer.volume, 50);
      expect(playingPlayer.isMuted, true);

      final idlePlayer = Player.fromJson({
        'player_id': '2',
        'name': 'Test 2',
        'state': 'idle',
      });

      expect(idlePlayer.isPlaying, false);
      expect(idlePlayer.volume, 0); // default when null
      expect(idlePlayer.isMuted, false); // default when null
    });

    test('toJson creates correct map', () {
      final player = Player(
        playerId: 'player_1',
        name: 'Bedroom',
        available: true,
        powered: true,
        state: 'paused',
        currentItemId: 'item_456',
        volumeLevel: 60,
        volumeMuted: false,
      );

      final json = player.toJson();

      expect(json['player_id'], 'player_1');
      expect(json['name'], 'Bedroom');
      expect(json['available'], true);
      expect(json['powered'], true);
      expect(json['state'], 'paused');
      expect(json['current_item_id'], 'item_456');
      expect(json['volume_level'], 60);
      expect(json['volume_muted'], false);
    });

    test('toJson omits null optional fields', () {
      final player = Player(
        playerId: 'player_1',
        name: 'Test',
        available: true,
        powered: false,
        state: 'idle',
      );

      final json = player.toJson();

      expect(json.containsKey('current_item_id'), false);
      expect(json.containsKey('volume_level'), false);
      expect(json.containsKey('volume_muted'), false);
    });
  });

  group('StreamDetails', () {
    test('fromJson creates stream details', () {
      final json = {
        'stream_id': 'stream_123',
        'sample_rate': 96000,
        'bit_depth': 24,
        'content_type': 'audio/flac',
      };

      final stream = StreamDetails.fromJson(json);

      expect(stream.streamId, 'stream_123');
      expect(stream.sampleRate, 96000);
      expect(stream.bitDepth, 24);
      expect(stream.contentType, 'audio/flac');
    });

    test('fromJson uses defaults for missing fields', () {
      final json = {
        'stream_id': 'stream_456',
      };

      final stream = StreamDetails.fromJson(json);

      expect(stream.streamId, 'stream_456');
      expect(stream.sampleRate, 44100); // default
      expect(stream.bitDepth, 16); // default
      expect(stream.contentType, 'audio/flac'); // default
    });
  });

  group('QueueItem', () {
    test('fromJson with queue_item_id', () {
      final json = {
        'queue_item_id': 'queue_1',
        'media_item': {
          'item_id': 'track_1',
          'provider': 'spotify',
          'name': 'Test Track',
          'media_type': 'track',
        },
      };

      final item = QueueItem.fromJson(json);

      expect(item.queueItemId, 'queue_1');
      expect(item.track.name, 'Test Track');
      expect(item.streamdetails, isNull);
    });

    test('fromJson falls back to item_id when queue_item_id missing', () {
      final json = {
        'item_id': 'fallback_id',
        'media_item': {
          'item_id': 'track_1',
          'provider': 'spotify',
          'name': 'Test Track',
          'media_type': 'track',
        },
      };

      final item = QueueItem.fromJson(json);

      expect(item.queueItemId, 'fallback_id');
    });

    test('fromJson handles missing queue_item_id and item_id', () {
      final json = {
        'media_item': {
          'item_id': 'track_1',
          'provider': 'spotify',
          'name': 'Test Track',
          'media_type': 'track',
        },
      };

      final item = QueueItem.fromJson(json);

      expect(item.queueItemId, '');
    });

    test('fromJson extracts track from nested media_item', () {
      final json = {
        'queue_item_id': 'queue_1',
        'media_item': {
          'item_id': 'track_1',
          'provider': 'spotify',
          'name': 'Nested Track',
          'media_type': 'track',
          'artists': [
            {
              'item_id': 'artist_1',
              'provider': 'spotify',
              'name': 'Artist Name',
              'media_type': 'artist',
            }
          ],
        },
        'streamdetails': {
          'stream_id': 'stream_1',
          'sample_rate': 48000,
          'bit_depth': 16,
          'content_type': 'audio/mp3',
        },
      };

      final item = QueueItem.fromJson(json);

      expect(item.track.name, 'Nested Track');
      expect(item.track.artists, hasLength(1));
      expect(item.track.artists!.first.name, 'Artist Name');
      expect(item.streamdetails, isNotNull);
      expect(item.streamdetails!.sampleRate, 48000);
    });

    test('fromJson handles null media_item by using root json', () {
      final json = {
        'queue_item_id': 'queue_1',
        'item_id': 'track_1',
        'provider': 'spotify',
        'name': 'Root Level Track',
        'media_type': 'track',
      };

      final item = QueueItem.fromJson(json);

      expect(item.queueItemId, 'queue_1');
      expect(item.track.name, 'Root Level Track');
    });

    test('fromJson handles missing media_item key', () {
      final json = {
        'queue_item_id': 'queue_1',
        'item_id': 'track_1',
        'provider': 'spotify',
        'name': 'Direct Track',
        'media_type': 'track',
      };

      final item = QueueItem.fromJson(json);

      expect(item.track.name, 'Direct Track');
    });
  });

  group('PlayerQueue', () {
    test('fromJson creates queue with items', () {
      final json = {
        'player_id': 'player_1',
        'items': [
          {
            'queue_item_id': 'q1',
            'media_item': {
              'item_id': 't1',
              'provider': 'spotify',
              'name': 'Track 1',
              'media_type': 'track',
            },
          },
          {
            'queue_item_id': 'q2',
            'media_item': {
              'item_id': 't2',
              'provider': 'spotify',
              'name': 'Track 2',
              'media_type': 'track',
            },
          },
        ],
        'current_index': 0,
        'shuffle_enabled': true,
        'repeat_mode': 'all',
      };

      final queue = PlayerQueue.fromJson(json);

      expect(queue.playerId, 'player_1');
      expect(queue.items, hasLength(2));
      expect(queue.items[0].track.name, 'Track 1');
      expect(queue.items[1].track.name, 'Track 2');
      expect(queue.currentIndex, 0);
      expect(queue.shuffleEnabled, true);
      expect(queue.repeatMode, 'all');
    });

    test('fromJson handles empty items', () {
      final json = {
        'player_id': 'player_1',
        'items': [],
      };

      final queue = PlayerQueue.fromJson(json);

      expect(queue.items, isEmpty);
      expect(queue.currentIndex, isNull);
    });

    test('fromJson handles null items', () {
      final json = {
        'player_id': 'player_1',
      };

      final queue = PlayerQueue.fromJson(json);

      expect(queue.items, isEmpty);
    });

    test('shuffle getter returns correct value', () {
      final shuffleOn = PlayerQueue.fromJson({
        'player_id': '1',
        'shuffle_enabled': true,
      });
      expect(shuffleOn.shuffle, true);

      final shuffleOff = PlayerQueue.fromJson({
        'player_id': '1',
        'shuffle_enabled': false,
      });
      expect(shuffleOff.shuffle, false);

      final shuffleNull = PlayerQueue.fromJson({
        'player_id': '1',
      });
      expect(shuffleNull.shuffle, false); // default
    });

    test('repeat getters work correctly', () {
      final repeatAll = PlayerQueue.fromJson({
        'player_id': '1',
        'repeat_mode': 'all',
      });
      expect(repeatAll.repeatAll, true);
      expect(repeatAll.repeatOne, false);
      expect(repeatAll.repeatOff, false);

      final repeatOne = PlayerQueue.fromJson({
        'player_id': '1',
        'repeat_mode': 'one',
      });
      expect(repeatOne.repeatAll, false);
      expect(repeatOne.repeatOne, true);
      expect(repeatOne.repeatOff, false);

      final repeatOff = PlayerQueue.fromJson({
        'player_id': '1',
        'repeat_mode': 'off',
      });
      expect(repeatOff.repeatAll, false);
      expect(repeatOff.repeatOne, false);
      expect(repeatOff.repeatOff, true);

      final repeatNull = PlayerQueue.fromJson({
        'player_id': '1',
      });
      expect(repeatNull.repeatAll, false);
      expect(repeatNull.repeatOne, false);
      expect(repeatNull.repeatOff, true); // default
    });

    test('currentItem returns correct item', () {
      final queue = PlayerQueue.fromJson({
        'player_id': 'player_1',
        'items': [
          {
            'queue_item_id': 'q1',
            'media_item': {
              'item_id': 't1',
              'provider': 'spotify',
              'name': 'First',
              'media_type': 'track',
            },
          },
          {
            'queue_item_id': 'q2',
            'media_item': {
              'item_id': 't2',
              'provider': 'spotify',
              'name': 'Second',
              'media_type': 'track',
            },
          },
        ],
        'current_index': 1,
      });

      final currentItem = queue.currentItem;
      expect(currentItem, isNotNull);
      expect(currentItem!.track.name, 'Second');
    });

    test('currentItem returns null when index is null', () {
      final queue = PlayerQueue.fromJson({
        'player_id': 'player_1',
        'items': [
          {
            'queue_item_id': 'q1',
            'media_item': {
              'item_id': 't1',
              'provider': 'spotify',
              'name': 'Track',
              'media_type': 'track',
            },
          },
        ],
      });

      expect(queue.currentItem, isNull);
    });

    test('currentItem returns null when items is empty', () {
      final queue = PlayerQueue.fromJson({
        'player_id': 'player_1',
        'current_index': 0,
      });

      expect(queue.currentItem, isNull);
    });

    test('currentItem returns null when index out of bounds', () {
      final queue = PlayerQueue.fromJson({
        'player_id': 'player_1',
        'items': [
          {
            'queue_item_id': 'q1',
            'media_item': {
              'item_id': 't1',
              'provider': 'spotify',
              'name': 'Track',
              'media_type': 'track',
            },
          },
        ],
        'current_index': 5, // out of bounds
      });

      expect(queue.currentItem, isNull);
    });
  });
}
