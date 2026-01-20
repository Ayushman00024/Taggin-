import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// EditProfileAvatar
/// - Priority: imageProvider > appPhotoUrl > googlePhotoUrl > monogram > person icon
/// - Auto cache-busting so new photos always show instantly
/// - Entire avatar clickable if [onTapPick] is provided
class EditProfileAvatar extends StatelessWidget {
  final ImageProvider<Object>? imageProvider;
  final String? appPhotoUrl;
  final String? googlePhotoUrl;
  final String? displayName;

  final double size;
  final bool isPicking;
  final VoidCallback? onTapPick;

  const EditProfileAvatar({
    Key? key,
    this.imageProvider,
    this.appPhotoUrl,
    this.googlePhotoUrl,
    this.displayName,
    this.size = 144,
    this.isPicking = false,
    this.onTapPick,
  }) : super(key: key);

  /// Add a query param to bust cache on each build
  String _cacheBustedUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "$url&cb=$ts";
  }

  @override
  Widget build(BuildContext context) {
    final chosen = imageProvider ?? _chooseProvider();

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white10,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: chosen != null
          ? Image(
        image: chosen,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _monogramOrIcon(),
      )
          : _monogramOrIcon(),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Semantics(
          label: 'Profile photo',
          child: onTapPick != null
              ? Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: isPicking ? null : onTapPick,
              customBorder: const CircleBorder(),
              child: avatar,
            ),
          )
              : avatar,
        ),

        if (isPicking)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(size / 2),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        if (onTapPick != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: _CircleIconButton(
              icon: Icons.edit,
              tooltip: 'Change photo',
              onTap: isPicking ? null : onTapPick,
            ),
          ),
      ],
    );
  }

  /// Decide which provider to use
  ImageProvider<Object>? _chooseProvider() {
    if (appPhotoUrl != null && appPhotoUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(_cacheBustedUrl(appPhotoUrl));
    }
    if (googlePhotoUrl != null && googlePhotoUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(
        _normalizeGooglePhotoUrl(googlePhotoUrl!, size.round()),
      );
    }
    return null;
  }

  Widget _monogramOrIcon() {
    final letter = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim().characters.first.toUpperCase()
        : null;

    if (letter != null) {
      return Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
      );
    }
    return const Icon(Icons.person, size: 72, color: Colors.white38);
  }

  String _normalizeGooglePhotoUrl(String url, int size) {
    String out = url.replaceAll(RegExp(r'=s\d+-c'), '=s${size}-c');
    try {
      final uri = Uri.parse(out);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['sz'] = '$size';
      out = uri.replace(queryParameters: qp).toString();
    } catch (_) {}
    return _cacheBustedUrl(out); // bust cache for Google photos too
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  const _CircleIconButton({
    Key? key,
    required this.icon,
    this.tooltip,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.white, size: 20),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: tooltip == null ? btn : Tooltip(message: tooltip!, child: btn),
      ),
    );
  }
}
