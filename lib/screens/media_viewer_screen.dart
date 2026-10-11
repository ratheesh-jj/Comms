import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/file_service.dart';
import '../models/chat_message.dart';

class MediaViewerScreen extends StatefulWidget {
  final String url;
  final String fileName;
  final MessageType type;

  const MediaViewerScreen({
    super.key,
    required this.url,
    required this.fileName,
    required this.type,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == MessageType.video) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
          _videoController?.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _downloadMedia() async {
    setState(() => _isDownloading = true);
    
    final fileService = Provider.of<FileService>(context, listen: false);
    final result = await fileService.saveToPublicStorage(widget.url, widget.fileName);
    
    if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?.contains('/') == true ? 'Downloaded to: $result' : result ?? 'Download failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (_isDownloading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadMedia,
            ),
        ],
      ),
      body: Center(
        child: widget.type == MessageType.image
            ? PhotoView(
                imageProvider: CachedNetworkImageProvider(widget.url),
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                ),
              )
            : _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_videoController!),
                        _VideoControls(controller: _videoController!),
                        VideoProgressIndicator(
                          _videoController!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.red,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.black26,
                          ),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Container(
        color: Colors.transparent,
        child: _showControls
            ? Center(
                child: FloatingActionButton(
                  backgroundColor: Colors.black54,
                  onPressed: () {
                    setState(() {
                      widget.controller.value.isPlaying
                          ? widget.controller.pause()
                          : widget.controller.play();
                    });
                  },
                  child: Icon(
                    widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
