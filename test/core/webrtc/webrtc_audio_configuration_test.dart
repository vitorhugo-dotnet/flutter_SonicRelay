import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Guards the audio profile the receiver factory pushes into flutter_webrtc.
///
/// The viewer is receive-only, so it must run the Android audio session in a
/// *media playback* profile. Left on flutter_webrtc's defaults it would put the
/// whole device into `MODE_IN_COMMUNICATION` / `USAGE_VOICE_COMMUNICATION`,
/// muffling every app's audio into "phone call" quality for the duration of the
/// session (issue #14). This test locks the preset we rely on so a dependency
/// bump that changes its meaning fails loudly here instead of on a real phone.
void main() {
  group('AndroidAudioConfiguration.media (issue #14 audio profile)', () {
    final map = AndroidAudioConfiguration.media.toMap();

    test('uses MODE_NORMAL, not a call/communication mode', () {
      expect(map['androidAudioMode'], AndroidAudioMode.normal.name);
      expect(map['androidAudioMode'], isNot(AndroidAudioMode.inCommunication.name));
      expect(map['androidAudioMode'], isNot(AndroidAudioMode.inCall.name));
    });

    test('routes as media, not voice communication', () {
      expect(
        map['androidAudioAttributesUsageType'],
        AndroidAudioAttributesUsageType.media.name,
      );
      expect(
        map['androidAudioAttributesUsageType'],
        isNot(AndroidAudioAttributesUsageType.voiceCommunication.name),
      );
    });

    test('requests the music stream, not the voice-call stream', () {
      expect(
        map['androidAudioStreamType'],
        AndroidAudioStreamType.music.name,
      );
      expect(
        map['androidAudioStreamType'],
        isNot(AndroidAudioStreamType.voiceCall.name),
      );
    });

    test('manages audio focus so it is cleanly abandoned on teardown', () {
      expect(map['manageAudioFocus'], isTrue);
    });
  });
}
