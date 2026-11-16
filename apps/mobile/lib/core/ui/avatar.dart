import "dart:typed_data";
import "package:material_ui/material_ui.dart";
import "../app_theme.dart";

/// A circular profile photo with a graceful fallback (icon or initial) while
/// loading or when the image fails, and an optional camera badge that makes
/// it obvious the photo is editable.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    this.imageUrl,
    this.bytes,
    this.name,
    this.radius = 28,
    this.onTap,
    this.showEditBadge = false,
    super.key,
  });

  final String? imageUrl;
  final Uint8List? bytes;

  /// Used for an initial when there is no photo.
  final String? name;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = name?.trim() ?? "";
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: trimmed.isEmpty
          ? Icon(Icons.person, size: radius, color: scheme.onPrimaryContainer)
          : Text(
              trimmed.characters.first.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: radius * 0.8,
                color: scheme.onPrimaryContainer,
              ),
            ),
    );
  }

  Widget _image(BuildContext context) {
    final size = radius * 2;
    if (bytes != null) {
      return Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover);
    }
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback(context);
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _fallback(context),
      loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = ClipOval(child: SizedBox(width: radius * 2, height: radius * 2, child: _image(context)));

    if (showEditBadge) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: EdgeInsets.all(radius * 0.2),
              decoration: BoxDecoration(
                color: AppTheme.coral,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cream, width: 3),
              ),
              child: Icon(Icons.photo_camera, size: radius * 0.4, color: Colors.white),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      child: InkResponse(onTap: onTap, radius: radius + 6, child: avatar),
    );
  }
}
