import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps probed cover indexes without including the movie video', () {
    final arguments = [
      '-i',
      'movie.mkv',
      '-map',
      '0:a?',
      '-map',
      '0:v:disp:attached_pic?',
      '-c:v',
      'copy',
      'audio.mp3',
    ];
    expect(
      AudioArtworkMapping.resolve(arguments, attachedPictureIndexes: [2, 4, 2]),
      [
        '-i',
        'movie.mkv',
        '-map',
        '0:a?',
        '-map',
        '0:2',
        '-map',
        '0:4',
        '-c:v',
        'copy',
        'audio.mp3',
      ],
    );
    expect(arguments, contains('0:v:disp:attached_pic?'));
  });

  test('missing pictures remove only the optional artwork map', () {
    expect(
      AudioArtworkMapping.resolve([
        '-i',
        'song.wav',
        '-map',
        '0:a?',
        '-map',
        '0:v:disp:attached_pic?',
        '-c:v',
        'copy',
        'audio.mp3',
      ], attachedPictureIndexes: []),
      [
        '-i',
        'song.wav',
        '-map',
        '0:a?',
        '-c:v',
        'copy',
        'audio.mp3',
      ],
    );
  });

  test('explicit mappings and literal filenames are preserved', () {
    final arguments = [
      '-i',
      '0:v:disp:attached_pic?',
      '-map',
      '0:v',
      'audio.mp3',
    ];
    expect(
      AudioArtworkMapping.resolve(arguments, attachedPictureIndexes: [1]),
      arguments,
    );
  });
}
