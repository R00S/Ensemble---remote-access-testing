import 'package:flutter/material.dart';

/// A page route that uses a fade + slight slide transition on forward navigation,
/// but NO page transition on back (letting hero animations shine).
///
/// On forward navigation: fade in + slight slide from right
/// On back navigation: no page transition, just hero animations
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  FadeSlidePageRoute({
    required this.child,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300), // Match hero animation duration
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // On back navigation (reverse), don't apply any page transition
            // Just return the child and let hero animations do their thing
            if (animation.status == AnimationStatus.reverse) {
              return child;
            }

            // Forward navigation: fade in + slight slide from right
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );

            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );
          },
        );
}
