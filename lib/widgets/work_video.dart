import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../config/api_config.dart';

class WorkVideo extends StatefulWidget {
  final String source;
  final void Function(bool)? onFinished;
  final VoidCallback? onRetry;
  final bool paused;
  const WorkVideo(
      {super.key,
      required this.source,
      this.onFinished,
      this.onRetry,
      this.paused = false});
  @override
  State<WorkVideo> createState() => _WorkVideoState();
}

class _WorkVideoState extends State<WorkVideo> with WidgetsBindingObserver {
  VideoPlayerController? video;
  YoutubePlayerController? youtube;
  StreamSubscription<YoutubePlayerValue>? youtubeEvents;
  String? error;
  bool reported = false, foreground = true, retrying = false;
  int generation = 0;
  void report(bool success) {
    if (!reported && mounted) {
      reported = true;
      final request = generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && request == generation) widget.onFinished?.call(success);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  @override
  void didUpdateWidget(covariant WorkVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && !oldWidget.paused) {
      unawaited(pauseVideo());
      unawaited(pauseYoutube());
    }
  }

  Future<void> retry() async {
    if (!mounted || retrying) return;
    generation++;
    setState(() => retrying = true);
    final prior = video, priorYoutube = youtube;
    final priorEvents = youtubeEvents;
    video = null;
    youtube = null;
    youtubeEvents = null;
    try {
      await prior?.dispose();
      await priorEvents?.cancel();
      await priorYoutube?.close();
      if (!mounted) return;
      setState(() {
        error = null;
        reported = false;
      });
      widget.onRetry?.call();
      await initialize();
    } finally {
      if (mounted) setState(() => retrying = false);
    }
  }

  Future<void> initialize() async {
    final source = Uri.tryParse(widget.source);
    if (source == null) {
      setState(() => error = '영상 주소를 확인할 수 없습니다.');
      report(false);
      return;
    }
    final uri = Uri.parse(ApiConfig.baseUrl).resolveUri(source);
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com')) {
      final id = YoutubePlayerController.convertUrlToId(uri.toString());
      if (id == null) {
        setState(() => error = '영상 주소를 확인할 수 없습니다.');
        report(false);
        return;
      }
      youtube = YoutubePlayerController.fromVideoId(
          videoId: id,
          autoPlay: false,
          params: const YoutubePlayerParams(
              showControls: true, showFullscreenButton: true));
      youtubeEvents = youtube!.listen((value) {
        if (value.hasError) {
          if (mounted && error == null) {
            setState(() => error = '영상을 재생하지 못했습니다.');
          }
          report(false);
        }
        if (value.playerState == PlayerState.ended) report(true);
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
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || video != controller) return;
      controller.addListener(() {
        if (!mounted || video != controller) return;
        if (controller.value.hasError) {
          if (error == null) setState(() => error = '영상을 재생하지 못했습니다.');
          report(false);
        } else if (controller.value.duration > Duration.zero &&
            controller.value.position >= controller.value.duration) {
          report(true);
        }
      });
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted || video != controller) return;
      setState(() => error = '영상을 불러오지 못했습니다.');
      report(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      unawaited(pauseVideo());
      unawaited(pauseYoutube());
    }
  }

  Future<void> pauseYoutube() async {
    try {
      await youtube?.pauseVideo();
    } catch (_) {}
  }

  Future<void> pauseVideo() async {
    try {
      await video?.pause();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    video?.dispose();
    youtubeEvents?.cancel();
    youtube?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: retrying ? null : retry,
                icon: const Icon(Icons.refresh),
                label: const Text('영상 다시 불러오기')),
          ]));
    }
    if (youtube != null) {
      return AbsorbPointer(
          absorbing: widget.paused, child: YoutubePlayer(controller: youtube!));
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
          onPressed: widget.paused
              ? null
              : () async {
                  try {
                    if (controller.value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('재생을 시작하지 못했습니다. 다시 눌러 주세요.')));
                    }
                  }
                  if (mounted) setState(() {});
                },
          icon:
              Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow))
    ]);
  }
}
