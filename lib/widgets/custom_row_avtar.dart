import 'package:flutter/material.dart';
import 'package:whoxa/widgets/custom_image.dart';

class UserImagesRow extends StatelessWidget {
  final List<String> imageUrls;
  final double avatarRadius;
  final double overlapOffset;

  const UserImagesRow({
    super.key,
    required this.imageUrls,
    this.avatarRadius = 14,
    this.overlapOffset = 2,
  });

  @override
  Widget build(BuildContext context) {
    int showCount = imageUrls.length > 4 ? 3 : imageUrls.length;
    double widthFactor = 0.5;
    double avatarSize = avatarRadius * 2;

    return Row(
      children: [
        for (int i = 0; i < showCount; i++)
          Align(
            widthFactor: widthFactor,
            alignment: Alignment.center,
            child: Container(
              margin: EdgeInsets.only(left: i.toDouble() * overlapOffset),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white),
              ),
              child: CustomCircleImage(imageUrl: imageUrls[i]),
              // CircleAvatar(
              //   maxRadius: avatarRadius,
              //   backgroundImage: NetworkImage(imageUrls[i]),
              // ),
            ),
          ),

        // The +N Avatar
        if (imageUrls.length > 4)
          Align(
            widthFactor: widthFactor,
            alignment: Alignment.center,
            child: Container(
              margin: EdgeInsets.only(
                left: showCount.toDouble() * overlapOffset,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomCircleImage(imageUrl: imageUrls[3]),
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    '+${imageUrls.length - 3}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
