import 'dart:ui';
import 'package:converter/converter.dart';

enum OutputFormatType {
  audio,
  video,
}

enum OutputFormat {
 // Audio formats.
 mp3(value: 'mp3', fileExtension: 'mp3', type: OutputFormatType.audio),
 wav(value: 'wav', fileExtension: 'wav', type: OutputFormatType.audio),
 aac(value: 'adts', fileExtension: 'aac', type: OutputFormatType.audio),
 flac(value: 'flac', fileExtension: 'flac', type: OutputFormatType.audio),
 ogg(value: 'ogg', fileExtension: 'ogg', type: OutputFormatType.audio),

 // Video formats.
 mp4(value: 'mp4', fileExtension: 'mp4', type: OutputFormatType.video),
 mov(value: 'mov', fileExtension: 'mov', type: OutputFormatType.video),
 mkv(value: 'matroska', fileExtension: 'mkv', type: OutputFormatType.video),
 webm(value: 'webm', fileExtension: 'webm', type: OutputFormatType.video),
 avi(value: 'avi', fileExtension: 'avi', type: OutputFormatType.video);

 final String value;
 final String fileExtension;
 final OutputFormatType type;

 const OutputFormat({
   required this.value,
   required this.fileExtension,
   required this.type,
 });

 static List<OutputFormat> audioFormats() =>
     OutputFormat.values.where((f) => f.type == OutputFormatType.audio).toList();

 static List<OutputFormat> videoFormats() =>
     OutputFormat.values.where((f) => f.type == OutputFormatType.video).toList();
}

extension OutputFormatGradient on OutputFormat {
  List<Color> getGradient() {
    switch (this) {
      case OutputFormat.mp3:
        return Gradients.flare;
      case OutputFormat.wav:
        return Gradients.purpleWhite;
      case OutputFormat.aac:
        return Gradients.influenza;
      case OutputFormat.flac:
        return Gradients.greenAndBlue;
      case OutputFormat.ogg:
        return Gradients.pinkFlavor;
      case OutputFormat.mp4:
        return Gradients.betweenNightAndDay;
      case OutputFormat.mov:
        return Gradients.decent;
      case OutputFormat.mkv:
        return Gradients.flare;
      case OutputFormat.webm:
        return Gradients.influenza;
      case OutputFormat.avi:
        return Gradients.miamiDolphins;
    }
  }
}

extension OutputFormatCommand on OutputFormat {
  /// Returns the full FFmpeg format parameter for the selected output format.
  String getCommand() => '-f $value';
}

extension OutputFormatDefaultConfig on OutputFormat {
  /// Returns a default output configuration for this format.
  BaseOutputConfiguration getDefaultOutputConfig() {
    switch (this) {
      case OutputFormat.mp3:
      case OutputFormat.wav:
      case OutputFormat.aac:
      case OutputFormat.flac:
      case OutputFormat.ogg:
        return const AudioOutputConfiguration();
      case OutputFormat.mp4:
      case OutputFormat.mov:
      case OutputFormat.mkv:
      case OutputFormat.webm:
      case OutputFormat.avi:
        return const VideoOutputConfiguration();
    }
  }
}

/// Supported configuration options for each OutputFormat.
extension OutputFormatSupportedConfigs on OutputFormat {
  List<String> get supportedAudioCodecs {
    switch (this) {
      case OutputFormat.mp3:
        return ['libmp3lame', 'mp3'];
      case OutputFormat.aac:
        return ['aac', 'libfdk_aac'];
      case OutputFormat.flac:
        return ['flac'];
      case OutputFormat.ogg:
        return ['libvorbis', 'opus'];
      case OutputFormat.wav:
        return ['pcm_s16le', 'pcm_s24le'];
      default:
        return [];
    }
  }

  List<String> get supportedAudioBitrates {
    switch (this) {
      case OutputFormat.mp3:
      case OutputFormat.aac:
      case OutputFormat.ogg:
        return ['96k', '128k', '192k', '256k', '320k'];
      case OutputFormat.flac:
      case OutputFormat.wav:
        return [];
      default:
        return [];
    }
  }

  List<int> get supportedAudioChannels {
    switch (this) {
      case OutputFormat.mp3:
      case OutputFormat.aac:
      case OutputFormat.ogg:
      case OutputFormat.flac:
      case OutputFormat.wav:
        return [1, 2];
      default:
        return [];
    }
  }

  List<String> get supportedVideoCodecs {
    switch (this) {
      case OutputFormat.mp4:
        return ['libx264', 'libx265', 'mpeg4'];
      case OutputFormat.mov:
        return ['prores', 'mpeg4', 'libx264'];
      case OutputFormat.mkv:
        return ['libx264', 'libx265', 'vp9'];
      case OutputFormat.webm:
        return ['vp8', 'vp9', 'libvpx'];
      case OutputFormat.avi:
        return ['mpeg4', 'libx264'];
      default:
        return [];
    }
  }

  List<String> get supportedVideoBitrates {
    switch (this) {
      case OutputFormat.mp4:
      case OutputFormat.mov:
      case OutputFormat.mkv:
      case OutputFormat.webm:
      case OutputFormat.avi:
        return ['500k', '1000k', '2000k', '4000k', '8000k'];
      default:
        return [];
    }
  }

  List<String> get supportedVideoResolutions {
    switch (this) {
      case OutputFormat.mp4:
      case OutputFormat.mov:
      case OutputFormat.mkv:
      case OutputFormat.webm:
      case OutputFormat.avi:
        return ['640x360', '1280x720', '1920x1080', '3840x2160'];
      default:
        return [];
    }
  }

  List<double> get supportedVideoFrameRates {
    switch (this) {
      case OutputFormat.mp4:
      case OutputFormat.mov:
      case OutputFormat.mkv:
      case OutputFormat.webm:
      case OutputFormat.avi:
        return [23.976, 24, 25, 29.97, 30, 50, 59.94, 60];
      default:
        return [];
    }
  }
}
