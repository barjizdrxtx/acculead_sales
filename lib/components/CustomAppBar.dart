// lib/components/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:acculead_sales/profile/Profile.dart';
import '../utls/colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showProfileIcon;
  final Color backgroundColor;

  const CustomAppBar({
    Key? key,
    this.title = '',
    this.actions,
    this.showBackButton = true,
    this.showProfileIcon = true,
    this.backgroundColor = Colors.white,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // start with any passed-in actions...
    final actionWidgets = <Widget>[
      if (actions != null) ...actions!,
      // then add profile icon if requested
      if (showProfileIcon)
        IconButton(
          icon: const Icon(Icons.person_outline),
          color: Colors.black,
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
          },
        ),
    ];

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.black,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: actionWidgets,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: Colors.red, // or use greyLight from your utls/colors.dart
          height: 1,
        ),
      ),
    );
  }
}
