import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const audio = [
    {'index': 1, 'codec_type': 'audio', 'codec_name': 'aac'},
    {
      'index': 7,
      'codec_type': 'audio',
      'codec_name': 'aac',
      'disposition': {'default': 1},
    },
  ];

  test(
    'single-track extraction chooses the flagged default, not stream zero',
    () {
      final arguments = [
        '-i',
        'source Việt "music".mkv',
        '-map',
        '0:a?',
        '-map_metadata',
        '0:g',
        'output.mp3',
      ];
      expect(
        MediaStreamMapping.resolve(
          arguments,
          outputExtension: 'MP3',
          streams: audio,
        ),
        [
          '-i',
          'source Việt "music".mkv',
          '-map',
          '0:7',
          '-map_metadata',
          '0:g',
          'output.mp3',
        ],
      );
      expect(arguments, contains('0:a?'));
    },
  );

  test('a source without a default flag uses its first audio index', () {
    expect(
      MediaStreamMapping.resolve(
        ['-map', '0:a?', 'output.wav'],
        outputExtension: 'wav',
        streams: [
          {'index': 5, 'codec_type': 'audio'},
          {'index': 2, 'codec_type': 'audio'},
        ],
      ),
      ['-map', '0:2', 'output.wav'],
    );
  });

  test('missing probe metadata leaves an optional first-audio map', () {
    expect(
      MediaStreamMapping.resolve(
        ['-map', '0:a?', 'output.aac'],
        outputExtension: 'aac',
        streams: [],
      ),
      ['-map', '0:a:0?', 'output.aac'],
    );
  });

  test('a container supporting multiple audio tracks retains them all', () {
    const arguments = ['-map', '0:a?', 'output.m4a'];
    expect(
      MediaStreamMapping.resolve(
        arguments,
        outputExtension: 'm4a',
        streams: audio,
      ),
      arguments,
    );
  });

  test('an explicit audio choice is not replaced with the default', () {
    const arguments = ['-map', '0:a:0', 'output.mp3'];
    expect(
      MediaStreamMapping.resolve(
        arguments,
        outputExtension: 'mp3',
        streams: audio,
      ),
      arguments,
    );
  });

  test('MP4 converts text tracks and omits bitmap tracks with contiguous codec indexes', () {
    expect(
      MediaStreamMapping.resolve(
        ['-map', '0:V?', '-map', '0:s?', 'output.mp4'],
        outputExtension: 'mp4',
        streams: [
          {
            'index': 3,
            'codec_type': 'subtitle',
            'codec_name': 'hdmv_pgs_subtitle',
          },
          {'index': 4, 'codec_type': 'subtitle', 'codec_name': 'subrip'},
          {'index': 8, 'codec_type': 'subtitle', 'codec_name': 'ass'},
        ],
      ),
      [
        '-map',
        '0:V?',
        '-map',
        '0:4',
        '-c:s:0',
        'mov_text',
        '-map',
        '0:8',
        '-c:s:1',
        'mov_text',
        'output.mp4',
      ],
    );
  });

  test('Matroska copies supported tracks and converts other text tracks separately', () {
    expect(
      MediaStreamMapping.resolve(
        ['-map', '0:s?', 'output.mkv'],
        outputExtension: 'mkv',
        streams: [
          {
            'index': 2,
            'codec_type': 'subtitle',
            'codec_name': 'hdmv_pgs_subtitle',
          },
          {'index': 3, 'codec_type': 'subtitle', 'codec_name': 'mov_text'},
          {'index': 6, 'codec_type': 'subtitle', 'codec_name': 'ass'},
        ],
      ),
      [
        '-map',
        '0:2',
        '-c:s:0',
        'copy',
        '-map',
        '0:3',
        '-c:s:1',
        'subrip',
        '-map',
        '0:6',
        '-c:s:2',
        'copy',
        'output.mkv',
      ],
    );
  });

  test('a container without text subtitle support omits that optional map', () {
    expect(
      MediaStreamMapping.resolve(
        ['-map', '0:V?', '-map', '0:s?', 'output.flv'],
        outputExtension: 'flv',
        streams: [
          {'index': 3, 'codec_type': 'subtitle', 'codec_name': 'subrip'},
        ],
      ),
      ['-map', '0:V?', 'output.flv'],
    );
  });

  test(
    'DVB TS retains DVB subtitles and omits PGS requiring Blu-ray signalling',
    () {
      expect(
        MediaStreamMapping.resolve(
          ['-map', '0:s?', 'output.ts'],
          outputExtension: 'ts',
          streams: [
            {
              'index': 3,
              'codec_type': 'subtitle',
              'codec_name': 'hdmv_pgs_subtitle',
            },
            {
              'index': 4,
              'codec_type': 'subtitle',
              'codec_name': 'dvb_subtitle',
            },
          ],
        ),
        ['-map', '0:4', '-c:s:0', 'copy', 'output.ts'],
      );
    },
  );

  test(
    'explicit subtitle mappings and encoders retain their original meaning',
    () {
      for (final arguments in [
        ['-map', '0:s:0', 'output.mp4'],
        ['-map', '0:s?', '-c:s', 'copy', 'output.mp4'],
        ['-map', '0:s?', '-sn', 'output.mp4'],
        ['-map', '0:s?', '-map', '-0:s:0', 'output.mp4'],
      ]) {
        expect(
          MediaStreamMapping.resolve(
            arguments,
            outputExtension: 'mp4',
            streams: [
              {'index': 3, 'codec_type': 'subtitle', 'codec_name': 'subrip'},
            ],
          ),
          arguments,
        );
      }
    },
  );
}
