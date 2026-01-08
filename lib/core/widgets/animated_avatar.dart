import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';

/// Avatar widget that supports GIF animation
/// 
/// Uses ExtendedImage for .gif files to preserve animation
/// Uses CachedNetworkImage for other formats for better performance
class AnimatedAvatar extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AnimatedAvatar({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isGif = imageUrl.toLowerCase().endsWith('.gif') || 
                  imageUrl.toLowerCase().endsWith('.webp');

    print('🖼️ AnimatedAvatar rendering: $imageUrl');
    print('🎨 Is GIF/WebP: $isGif');

    if (isGif) {
      // GIF/WebP için ExtendedImage kullan (Cache ve Performans için en iyisi)
      print('🎬 Using ExtendedImage for GIF animation');
      return ExtendedImage.network(
        imageUrl,
        fit: fit,
        cache: true,
        enableLoadState: true, // Yükleme durumunu göster
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.completed) {
             // Animasyon otomatik oynar
            return null; 
          }
          if (state.extendedImageLoadState == LoadState.loading) {
            return placeholder ?? Container(color: Colors.grey[900]);
          }
           if (state.extendedImageLoadState == LoadState.failed) {
            return errorWidget ?? const Icon(Icons.person, size: 50, color: Colors.white);
          }
          return null;
        },
      );
    } else {
      print('📸 Using CachedNetworkImage for non-GIF');
      // PNG/JPG için CachedNetworkImage kullan (cache için)
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (context, url) => placeholder ?? Container(color: Colors.grey[900]),
        errorWidget: (context, url, error) => errorWidget ?? const Icon(Icons.person, size: 50, color: Colors.white),
      );
    }
  }
}
