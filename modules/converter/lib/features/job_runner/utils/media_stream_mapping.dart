/// Resolves the builder's optional stream maps against the output container.
/// Explicit track selections and subtitle encoders retain their original meaning.
class MediaStreamMapping {
  static const _singleAudioFormats = {
    'mp3',
    'aac',
    'flac',
    'wav',
    'aiff',
    'amr',
    'ac3',
    'eac3',
    'caf',
    'flv',
  };

  static const _textSubtitles = {
    'subrip',
    'srt',
    'ass',
    'ssa',
    'mov_text',
    'webvtt',
    'text',
    'microdvd',
    'jacosub',
    'mpl2',
    'realtext',
    'sami',
    'stl',
    'subviewer',
    'subviewer1',
    'vplayer',
    'pjs',
  };

  static const _matroskaSubtitles = {
    'subrip',
    'ass',
    'ssa',
    'webvtt',
    'dvb_subtitle',
    'dvd_subtitle',
    'hdmv_pgs_subtitle',
  };

  static bool supportsMultipleAudio(String extension) =>
      !_singleAudioFormats.contains(extension.toLowerCase());

  static List<String> resolve(
    List<String> arguments, {
    required String outputExtension,
    required Iterable<Map<dynamic, dynamic>> streams,
  }) {
    final tracks = [
      for (final stream in streams)
        if (stream['index'] case final int index when index >= 0)
          _Track(
            index,
            '${stream['codec_type']}',
            '${stream['codec_name']}',
            stream['disposition'] is Map &&
                (stream['disposition'] as Map)['default'] == 1,
          ),
    ];
    final audio = tracks.where((track) => track.type == 'audio').toList()
      ..sort((first, second) => first.index.compareTo(second.index));
    final preferred =
        audio.where((track) => track.isDefault).firstOrNull ??
        audio.firstOrNull;
    final subtitles = tracks
        .where((track) => track.type == 'subtitle')
        .toList();
    final customSubtitles =
        arguments.any(
          (argument) =>
              argument == '-sn' ||
              argument == '-c' ||
              argument == '-codec' ||
              argument.startsWith('-c:s') ||
              argument.startsWith('-codec:s'),
        ) ||
        _hasExplicitSubtitleMap(arguments, subtitles);
    final resolved = <String>[];
    var subtitleIndex = 0;
    for (var index = 0; index < arguments.length; index++) {
      if (arguments[index] != '-map' || index + 1 >= arguments.length) {
        resolved.add(arguments[index]);
        continue;
      }
      final mapping = arguments[++index];
      if (mapping == '0:a?' && !supportsMultipleAudio(outputExtension)) {
        resolved.addAll([
          '-map',
          preferred == null ? '0:a:0?' : '0:${preferred.index}',
        ]);
      } else if (mapping == '0:s?' && !customSubtitles) {
        for (final subtitle in subtitles) {
          final encoder = _subtitleEncoder(outputExtension, subtitle.codec);
          if (encoder == null) continue;
          resolved.addAll([
            '-map',
            '0:${subtitle.index}',
            '-c:s:$subtitleIndex',
            encoder,
          ]);
          subtitleIndex++;
        }
      } else {
        resolved.addAll(['-map', mapping]);
      }
    }
    return resolved;
  }

  static bool _hasExplicitSubtitleMap(
    List<String> arguments,
    List<_Track> subtitles,
  ) {
    for (var index = 0; index + 1 < arguments.length; index++) {
      if (arguments[index] != '-map') continue;
      final mapping = arguments[index + 1];
      if (mapping == '0:s?') continue;
      if (mapping == '0' ||
          mapping.startsWith('-') ||
          RegExp(r'^\d+:s(?::|\?|$)').hasMatch(mapping) ||
          subtitles.any(
            (track) =>
                mapping == '0:${track.index}' || mapping == '0:${track.index}?',
          )) {
        return true;
      }
    }
    return false;
  }

  static String? _subtitleEncoder(
    String extension,
    String codec,
  ) => switch (extension.toLowerCase()) {
    'mp4' ||
    'mov' ||
    '3gp' => _textSubtitles.contains(codec) ? 'mov_text' : null,
    'mkv' || 'mka' =>
      _matroskaSubtitles.contains(codec)
          ? 'copy'
          : _textSubtitles.contains(codec)
          ? 'subrip'
          : null,
    'webm' => _textSubtitles.contains(codec) ? 'webvtt' : null,
    // The default TS muxer uses DVB signalling, not Blu-ray M2TS signalling.
    'ts' => codec == 'dvb_subtitle' ? 'copy' : null,
    'avi' => codec == 'xsub' ? 'copy' : null,
    _ => null,
  };
}

class const _Track(
  final int index,
  final String type,
  final String codec,
  final bool isDefault,
);
