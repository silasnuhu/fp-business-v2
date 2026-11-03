import 'package:flutter/material.dart';
import 'package:whoxa/widgets/global.dart';

class CustomCircleImage extends StatelessWidget {
  final String imageUrl;
  final double radius;

  const CustomCircleImage({
    super.key,
    required this.imageUrl,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      maxRadius: radius,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  Icon(Icons.error, size: radius, color: Colors.red),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: commonLoading(),
            );
          },
        ),
      ),
    );
  }
}
