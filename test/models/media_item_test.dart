import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant/models/media_item.dart';

void main() {
  group('ProviderMapping', () {
    test('fromJson with all fields', () {
      final json = {
        'item_id': 'test123',
        'provider_domain': 'spotify',
        'provider_instance': 'spotify_1',
        'available': true,
        'audio_format': {'content_type': 'audio/flac'},
      };

      final mapping = ProviderMapping.fromJson(json);

      expect(mapping.itemId, 'test123');
      expect(mapping.providerDomain, 'spotify');
      expect(mapping.providerInstance, 'spotify_1');
      expect(mapping.available, true);
      expect(mapping.audioFormat, isNotNull);
    });

    test('fromJson with null fields uses defaults', () {
      final json = <String, dynamic>{};

      final mapping = ProviderMapping.fromJson(json);

      expect(mapping.itemId, '');
      expect(mapping.providerDomain, '');
      expect(mapping.providerInstance, '');
      expect(mapping.available, true);
      expect(mapping.audioFormat, isNull);
    });

    test('fromJson with partially null fields', () {
      final json = {
        'item_id': 'abc',
        'available': false,
      };

      final mapping = ProviderMapping.fromJson(json);

      expect(mapping.itemId, 'abc');
      expect(mapping.providerDomain, '');
      expect(mapping.providerInstance, '');
      expect(mapping.available, false);
    });
  });

  group('MediaItem', () {
    test('fromJson creates track with all fields', () {
      final json = {
        'item_id': 'track_123',
        'provider': 'spotify',
        'name': 'Test Track',
        'media_type': 'track',
        'sort_name': 'test track',
        'uri': 'spotify:track:123',
        'favorite': true,
        'position': 1,
        'duration': 180,
        'provider_mappings': [
          {
            'item_id': 'map1',
            'provider_domain': 'spotify',
            'provider_instance': 'instance1',
          }
        ],
        'metadata': {'key': 'value'},
      };

      final item = MediaItem.fromJson(json);

      expect(item.itemId, 'track_123');
      expect(item.provider, 'spotify');
      expect(item.name, 'Test Track');
      expect(item.mediaType, MediaType.track);
      expect(item.sortName, 'test track');
      expect(item.uri, 'spotify:track:123');
      expect(item.favorite, true);
      expect(item.position, 1);
      expect(item.duration?.inSeconds, 180);
      expect(item.providerMappings, hasLength(1));
      expect(item.metadata, isNotNull);
    });

    test('fromJson handles missing item_id with id fallback', () {
      final json = {
        'id': 'fallback_id',
        'provider': 'test',
        'name': 'Test',
        'media_type': 'track',
      };

      final item = MediaItem.fromJson(json);

      expect(item.itemId, 'fallback_id');
    });

    test('fromJson handles null item_id and id with empty string', () {
      final json = {
        'provider': 'test',
        'name': 'Test',
        'media_type': 'track',
      };

      final item = MediaItem.fromJson(json);

      expect(item.itemId, '');
    });

    test('fromJson handles null name with empty string', () {
      final json = {
        'item_id': '123',
        'provider': 'test',
        'media_type': 'track',
      };

      final item = MediaItem.fromJson(json);

      expect(item.name, '');
    });

    test('fromJson handles null provider with unknown', () {
      final json = {
        'item_id': '123',
        'name': 'Test',
        'media_type': 'track',
      };

      final item = MediaItem.fromJson(json);

      expect(item.provider, 'unknown');
    });

    test('fromJson handles invalid media_type gracefully', () {
      final json = {
        'item_id': '123',
        'provider': 'test',
        'name': 'Test',
        'media_type': 'invalid_type',
      };

      final item = MediaItem.fromJson(json);

      expect(item.mediaType, MediaType.track); // Default fallback
    });

    test('toJson creates correct map', () {
      final item = MediaItem(
        itemId: 'test_123',
        provider: 'spotify',
        name: 'Test Item',
        mediaType: MediaType.track,
        favorite: true,
      );

      final json = item.toJson();

      expect(json['item_id'], 'test_123');
      expect(json['provider'], 'spotify');
      expect(json['name'], 'Test Item');
      expect(json['media_type'], 'track');
      expect(json['favorite'], true);
    });
  });

  group('Track', () {
    test('fromJson creates track with artists and album', () {
      final json = {
        'item_id': 'track_1',
        'provider': 'spotify',
        'name': 'Wonderful Tonight',
        'media_type': 'track',
        'artists': [
          {
            'item_id': 'artist_1',
            'provider': 'spotify',
            'name': 'Eric Clapton',
            'media_type': 'artist',
          }
        ],
        'album': {
          'item_id': 'album_1',
          'provider': 'spotify',
          'name': 'Slowhand',
          'media_type': 'album',
        },
        'disc_number': 1,
        'track_number': 3,
      };

      final track = Track.fromJson(json);

      expect(track.name, 'Wonderful Tonight');
      expect(track.artists, hasLength(1));
      expect(track.artists!.first.name, 'Eric Clapton');
      expect(track.album, isNotNull);
      expect(track.album!.name, 'Slowhand');
      expect(track.discNumber, 1);
      expect(track.trackNumber, 3);
    });

    test('fromJson handles null artists and album', () {
      final json = {
        'item_id': 'track_1',
        'provider': 'spotify',
        'name': 'Unknown Track',
        'media_type': 'track',
      };

      final track = Track.fromJson(json);

      expect(track.artists, isNull);
      expect(track.album, isNull);
    });

    test('fromJson handles empty artists array', () {
      final json = {
        'item_id': 'track_1',
        'provider': 'spotify',
        'name': 'Test Track',
        'media_type': 'track',
        'artists': [],
      };

      final track = Track.fromJson(json);

      expect(track.artists, isEmpty);
    });
  });

  group('Album', () {
    test('fromJson creates album with artists', () {
      final json = {
        'item_id': 'album_1',
        'provider': 'spotify',
        'name': 'Abbey Road',
        'media_type': 'album',
        'artists': [
          {
            'item_id': 'artist_1',
            'provider': 'spotify',
            'name': 'The Beatles',
            'media_type': 'artist',
          }
        ],
        'year': 1969,
        'version': 'Remastered',
      };

      final album = Album.fromJson(json);

      expect(album.name, 'Abbey Road');
      expect(album.artists, hasLength(1));
      expect(album.artists!.first.name, 'The Beatles');
      expect(album.year, 1969);
      expect(album.version, 'Remastered');
    });
  });

  group('Artist', () {
    test('fromJson creates artist', () {
      final json = {
        'item_id': 'artist_1',
        'provider': 'spotify',
        'name': 'Pink Floyd',
        'media_type': 'artist',
      };

      final artist = Artist.fromJson(json);

      expect(artist.name, 'Pink Floyd');
      expect(artist.mediaType, MediaType.artist);
    });
  });

  group('Playlist', () {
    test('fromJson creates playlist with owner', () {
      final json = {
        'item_id': 'playlist_1',
        'provider': 'spotify',
        'name': 'My Favorites',
        'media_type': 'playlist',
        'owner': 'user123',
        'is_editable': true,
      };

      final playlist = Playlist.fromJson(json);

      expect(playlist.name, 'My Favorites');
      expect(playlist.owner, 'user123');
      expect(playlist.isEditable, true);
    });

    test('fromJson handles null owner and is_editable', () {
      final json = {
        'item_id': 'playlist_1',
        'provider': 'spotify',
        'name': 'Test Playlist',
        'media_type': 'playlist',
      };

      final playlist = Playlist.fromJson(json);

      expect(playlist.owner, isNull);
      expect(playlist.isEditable, isNull);
    });
  });

  group('Radio', () {
    test('fromJson creates radio station', () {
      final json = {
        'item_id': 'radio_1',
        'provider': 'tunein',
        'name': 'BBC Radio 1',
        'media_type': 'radio',
      };

      final radio = Radio.fromJson(json);

      expect(radio.name, 'BBC Radio 1');
      expect(radio.mediaType, MediaType.radio);
    });
  });
}
