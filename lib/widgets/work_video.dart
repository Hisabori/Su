import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../config/api_config.dart';

class WorkVideo extends StatefulWidget {
  final String source;
  final void Function(bool)? onFinished;
  const WorkVideo({super.key, required this.source, this.onFinished});
  @override
  State<WorkVideo> createState() => _WorkVideoState();
}

class _WorkVideoState extends State<WorkVideo> with WidgetsBindingObserver {
  VideoPlayerController? video;
  YoutubePlayerController? youtube;
  String? error;
  bool reported = false;
  void report(bool success) {
    if (!reported && mounted) {
      reported = true;
      widget.onFinished?.call(success);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    final uri = Uri.parse(ApiConfig.baseUrl).resolve(widget.source);
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com')) {
      final id = YoutubePlayer.convertUrlToId(uri.toString());
      if (id == null) {
        setState(() => error = '영상 주소를 확인할 수 없습니다.');
        report(false);
        return;
      }
      youtube = YoutubePlayerController(
          initialVideoId: id, flags: const YoutubePlayerFlags(autoPlay: true));
      youtube!.addListener(() {
        if (youtube!.value.hasError) report(false);
      });
      setState(() {});
      return;
    }
    if (uri.scheme != 'https') {
      setState(() => error = '안전한 영상 주소가 필요합니다.');
      report(false);
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    video = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.play();
      controller.addListener(() {
        if (controller.value.hasError) {
          report(false);
        } else if (controller.value.duration > Duration.zero &&
            controller.value.position >= controller.value.duration) {
          report(true);
        }
      });
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => error = '영상을 불러오지 못했습니다.');
      report(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      video?.pause();
      youtube?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    video?.dispose();
    youtube?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(error!));
    }
    if (youtube != null) {
      return YoutubePlayer(controller: youtube!, onEnded: (_) => report(true));
    }
    final controller = video;
    if (controller == null || !controller.value.isInitialized) {
      return const Padding(
          padding: EdgeInsets.all(24), child: CircularProgressIndicator());
    }
    return Column(children: [
      AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller)),
      VideoProgressIndicator(controller, allowScrubbing: true),
      IconButton(
          tooltip: '재생 / 일시정지',
          onPressed: () async {
            if (controller.value.isPlaying) {
              await controller.pause();
            } else {
              await controller.play();
            }
            if (mounted) setState(() {});
          },
          icon:
              Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow))
    ]);
  }
}
