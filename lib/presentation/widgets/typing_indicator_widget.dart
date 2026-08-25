import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TypingIndicatorWidget extends StatefulWidget {
  final String userName;
  final bool isDark;

  const TypingIndicatorWidget({
    super.key,
    required this.userName,
    required this.isDark,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin: const EdgeInsets.only(left: 16, bottom: 6),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.darkSurface.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.userName} sedang mengetik',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: widget.isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final value = (_controller.value - delay) % 1.0;
                  final opacity = (value < 0.5 ? value * 2 : (1.0 - value) * 2).clamp(0.2, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}
