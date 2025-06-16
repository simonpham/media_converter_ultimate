import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

class JobMakerConfigCustomizer extends StatelessWidget {
  const JobMakerConfigCustomizer({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<
      JobMakerViewModel,
      (BaseOutputConfiguration?, OutputFormat?)
    >(
      selector: (_, model) => (model.outputConfig, model.outputFormat),
      builder: (context, data, _) {
        final (config, outputFormat) = data;
        if (config == null || outputFormat == null) {
          return const Center(child: Text('No configuration selected.'));
        }

        Widget fields = _buildBaseFields(context, config);

        if (config is CombinedOutputConfiguration) {
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBaseFields(context, config),
              _buildCombinedFields(context, config, outputFormat),
            ],
          );
        } else if (config is AudioOutputConfiguration) {
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBaseFields(context, config),
              _buildAudioFields(context, config, outputFormat),
            ],
          );
        } else if (config is VideoOutputConfiguration) {
          fields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBaseFields(context, config),
              _buildVideoFields(context, config, outputFormat),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: fields,
        );
      },
    );
  }

  void _updateConfig(BuildContext context, BaseOutputConfiguration newConfig) {
    context.read<JobMakerViewModel>().setOutputConfig(newConfig);
  }

  Widget _buildBaseFields(
    BuildContext context,
    BaseOutputConfiguration config,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Overwrite Output'),
          value: config.overwrite,
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(overwrite: Some(val)),
          ),
        ),
        TextFormField(
          initialValue: config.startTime ?? '',
          decoration: const InputDecoration(labelText: 'Start Time'),
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(startTime: Some(val)),
          ),
        ),
        TextFormField(
          initialValue: config.duration ?? '',
          decoration: const InputDecoration(labelText: 'Duration'),
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(duration: Some(val)),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioFields(
    BuildContext context,
    AudioOutputConfiguration config,
    OutputFormat outputFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: config.audioCodec,
          decoration: const InputDecoration(labelText: 'Audio Codec'),
          items: outputFormat.supportedAudioCodecs
              .map(
                (codec) => DropdownMenuItem(value: codec, child: Text(codec)),
              )
              .toList(),
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(audioCodec: Some(val))),
        ),
        DropdownButtonFormField<String>(
          value: config.audioBitrate,
          decoration: const InputDecoration(labelText: 'Audio Bitrate'),
          items: outputFormat.supportedAudioBitrates
              .map((br) => DropdownMenuItem(value: br, child: Text(br)))
              .toList(),
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(audioBitrate: Some(val))),
        ),
        DropdownButtonFormField<int>(
          value: config.audioChannels,
          decoration: const InputDecoration(labelText: 'Audio Channels'),
          items: outputFormat.supportedAudioChannels
              .map((ch) => DropdownMenuItem(value: ch, child: Text('$ch')))
              .toList(),
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(audioChannels: Some(val))),
        ),
        TextFormField(
          initialValue: config.audioSampleRate?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Audio Sample Rate'),
          keyboardType: TextInputType.number,
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(audioSampleRate: Some(int.tryParse(val))),
          ),
        ),
        TextFormField(
          initialValue: config.audioVolume?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Audio Volume'),
          keyboardType: TextInputType.number,
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(audioVolume: Some(double.tryParse(val))),
          ),
        ),
        SwitchListTile(
          title: const Text('Trim Silence'),
          value: config.trimSilence,
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(trimSilence: Some(val))),
        ),
      ],
    );
  }

  Widget _buildVideoFields(
    BuildContext context,
    VideoOutputConfiguration config,
    OutputFormat outputFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: config.videoCodec,
          decoration: const InputDecoration(labelText: 'Video Codec'),
          items: outputFormat.supportedVideoCodecs
              .map(
                (codec) => DropdownMenuItem(value: codec, child: Text(codec)),
              )
              .toList(),
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(videoCodec: Some(val))),
        ),
        DropdownButtonFormField<String>(
          value: config.videoBitrate,
          decoration: const InputDecoration(labelText: 'Video Bitrate'),
          items: outputFormat.supportedVideoBitrates
              .map((br) => DropdownMenuItem(value: br, child: Text(br)))
              .toList(),
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(videoBitrate: Some(val))),
        ),
        DropdownButtonFormField<String>(
          value: config.videoResolution,
          decoration: const InputDecoration(labelText: 'Video Resolution'),
          items: outputFormat.supportedVideoResolutions
              .map((res) => DropdownMenuItem(value: res, child: Text(res)))
              .toList(),
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(videoResolution: Some(val)),
          ),
        ),
        DropdownButtonFormField<double>(
          value: config.videoFrameRate,
          decoration: const InputDecoration(labelText: 'Video Frame Rate'),
          items: outputFormat.supportedVideoFrameRates
              .map((fr) => DropdownMenuItem(value: fr, child: Text('$fr')))
              .toList(),
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(videoFrameRate: Some(val)),
          ),
        ),
        TextFormField(
          initialValue: config.videoPreset ?? '',
          decoration: const InputDecoration(labelText: 'Video Preset'),
          onChanged: (val) =>
              _updateConfig(context, config.copyWith(videoPreset: Some(val))),
        ),
        TextFormField(
          initialValue: config.videoCrf?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Video CRF'),
          keyboardType: TextInputType.number,
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(videoCrf: Some(int.tryParse(val))),
          ),
        ),
        TextFormField(
          initialValue: config.videoAspectRatio ?? '',
          decoration: const InputDecoration(labelText: 'Video Aspect Ratio'),
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(videoAspectRatio: Some(val)),
          ),
        ),
        TextFormField(
          initialValue: config.videoPixelFormat ?? '',
          decoration: const InputDecoration(labelText: 'Video Pixel Format'),
          onChanged: (val) => _updateConfig(
            context,
            config.copyWith(videoPixelFormat: Some(val)),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedFields(
    BuildContext context,
    CombinedOutputConfiguration config,
    OutputFormat outputFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.audioConfig != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Audio Configuration',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _buildAudioFields(context, config.audioConfig!, outputFormat),
        ],
        if (config.videoConfig != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Video Configuration',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          _buildVideoFields(context, config.videoConfig!, outputFormat),
        ],
      ],
    );
  }
}
