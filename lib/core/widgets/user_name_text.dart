import 'package:flutter/material.dart';
import 'package:yeniapex/core/widgets/animated_gradient_text.dart';

/// 🎭 User Name Text Widget
/// Admin kullanıcılar için animasyonlu gradient, normal kullanıcılar için standart text
class UserNameText extends StatelessWidget {
  final String displayName;
  final bool isAdmin;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const UserNameText({
    Key? key,
    required this.displayName,
    this.isAdmin = false,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔍 DEBUG: Admin status rendering
    if (isAdmin) {
       print('🌈 Rendering Admin Gradient for: $displayName');
    }

    if (isAdmin) {
      // 🌈 Admin için animasyonlu gradient text + Badge
      double badgeSize = (style?.fontSize ?? 14.0) + 4.0; // Font boyutuna göre adaptif boyut (min 18)
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
           Flexible(
             child: AnimatedGradientText(
                text: displayName,
                style: style,
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: overflow,
              ),
           ),
           SizedBox(width: badgeSize / 4), // Orantılı boşluk
           Image.asset(
             "assets/images/icon_dealer_verify.webp",
             width: badgeSize,
             height: badgeSize,
           ),
        ],
      );
    } else {
      // 👤 Normal kullanıcı için standart text
      return Text(
        displayName,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
  }
}
