// lib/components/custom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:acculead_sales/profile/Main_Profile.dart';
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
    final canGoBack = Navigator.of(context).canPop();

    final actionWidgets = <Widget>[
      if (actions != null) ...actions!,
      if (showProfileIcon)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MainProfilePage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2), // width of the gradient ring
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFFAB47BC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: const AssetImage('assets/avatar.jpg'),
              ),
            ),
          ),
        ),
    ];

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: showBackButton && canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.black,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      centerTitle: false,
      titleSpacing: 16,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: actionWidgets,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(2),
        child: ColoredBox(
          color: Colors.red, // or greyLight
          child: SizedBox(height: 1),
        ),
      ),
    );
  }
}
