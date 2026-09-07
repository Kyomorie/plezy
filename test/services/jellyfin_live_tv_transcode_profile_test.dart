import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:plezy/services/jellyfin_client.dart';

import '../test_helpers/backend_client_fixtures.dart';

void main() {
  Future<List<String>> containersFor({required bool emby, required bool liveTv}) async {
    String? requestBody;
    Future<http.Response> handler(http.Request request) async {
      requestBody = request.body;
      return http.Response(
        jsonEncode({'MediaSources': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    final JellyfinClient client = emby
        ? testEmbyClient(handler: handler)
        : testJellyfinClient(handler: handler);
    addTearDown(client.close);

    await client.getPlaybackInfo('item-1', autoOpenLiveStream: liveTv ? true : null);

    final body = jsonDecode(requestBody!) as Map<String, dynamic>;
    final profile = body['DeviceProfile'] as Map<String, dynamic>;
    final transcodeProfiles = profile['TranscodingProfiles'] as List<dynamic>;
    return [
      for (final entry in transcodeProfiles.cast<Map<String, dynamic>>())
        if (entry['Type'] == 'Video') entry['Container'] as String,
    ];
  }

  test('Emby Live TV prefers MPEG-TS HLS without changing Jellyfin or VOD ordering', () async {
    expect(await containersFor(emby: true, liveTv: true), ['ts', 'mp4']);
    expect(await containersFor(emby: false, liveTv: true), ['mp4', 'ts']);
    expect(await containersFor(emby: true, liveTv: false), ['mp4', 'ts']);
    expect(await containersFor(emby: false, liveTv: false), ['mp4', 'ts']);
  });
}
