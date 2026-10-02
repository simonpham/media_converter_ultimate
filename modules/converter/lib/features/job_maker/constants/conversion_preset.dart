enum ConversionPreset(
  final String formatName,
  final Map<String, String> selectedValues,
) {
  compatibleVideo('mp4', {
    'configs.mp4.video_encoder': '-c:v libx264',
    'configs.mp4.video_preset.x264': 'fast',
    'configs.mp4.pixel_format.x264': '-pix_fmt yuv420p',
    'configs.mp4.crf.x264': '23',
    'configs.mp4.audio_encoder': 'aac',
    'configs.common.video.recommended_args':
        '["-map_metadata 0:g","-map 0:v","-map \'0:a?\'"]',
  }),
  smallerVideo('mp4', {
    'configs.mp4.video_encoder': '-c:v libx264',
    'configs.mp4.video_preset.x264': 'medium',
    'configs.mp4.pixel_format.x264': '-pix_fmt yuv420p',
    'configs.mp4.crf.x264': '28',
    'configs.mp4.audio_encoder': 'aac',
    'configs.common.video.recommended_args':
        '["-map_metadata 0:g","-map 0:v","-map \'0:a?\'"]',
  }),
  highQualityVideo('mp4', {
    'configs.mp4.video_encoder': '-c:v libx264',
    'configs.mp4.video_preset.x264': 'medium',
    'configs.mp4.crf.x264': '18',
    'configs.mp4.audio_encoder': 'aac',
    'configs.common.video.recommended_args':
        '["-map_metadata 0:g","-map 0:v","-map \'0:a?\'"]',
  }),
  musicMp3('mp3', {
    'configs.mp3.audio_encoder': 'libmp3lame',
    'configs.mp3.bitrate_type': 'configs.mp3.bitrate_type.cbr.value',
    'configs.mp3.bitrate': '320k',
    'configs.common.trim_silence': '[]',
  }),
  compactAudio('m4a', {
    'configs.m4a.audio_encoder': 'configs.m4a.audio_encoder.value.aac',
    'configs.m4a.bitrate': '128k',
    'configs.common.trim_silence': '[]',
  }),
  losslessAudio('m4a', {
    'configs.m4a.audio_encoder': 'configs.m4a.audio_encoder.value.alac',
    'configs.common.trim_silence': '[]',
  });

  static List<ConversionPreset> forFormats(Iterable<String> formatNames) {
    final supported = formatNames.toSet();
    return values
        .where((preset) => supported.contains(preset.formatName))
        .toList();
  }
}
