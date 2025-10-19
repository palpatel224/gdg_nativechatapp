import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String? url;
  final double radius;
  const Avatar({super.key, this.url, this.radius = 32});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty)
      return CircleAvatar(radius: radius, child: const Icon(Icons.person));
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url!));
  }
}
