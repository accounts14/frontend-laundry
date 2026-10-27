import 'package:flutter/material.dart';
import 'theme.dart';

/// Menggambar inner shadow: terang di kiri-atas, gelap di kanan-bawah
/// (dibalik saat [inverted] untuk efek cekung / tertekan).
class InnerShadowPainter extends CustomPainter {
  const InnerShadowPainter({
    required this.radius,
    this.inverted = false,
    this.depth = 7,
  });

  final double radius;
  final double depth;
  final bool inverted;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);

    void shade(Offset shift, Color color) {
      final outer = Path()..addRect(rect.inflate(depth * 4));
      final inner = Path()..addRRect(rrect.shift(shift));
      final gap = Path.combine(PathOperation.difference, outer, inner);
      canvas.drawPath(
        gap,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth),
      );
    }

    final light = Colors.white.withAlpha(235);
    final dark = const Color(0xFF8FA3C7).withAlpha(120);

    // Bayangan di sisi kiri-atas muncul ketika rrect digeser ke kanan-bawah.
    shade(Offset(depth, depth), inverted ? dark : light);
    shade(Offset(-depth, -depth), inverted ? light : dark);

    canvas.restore();
  }

  @override
  bool shouldRepaint(InnerShadowPainter old) =>
      old.radius != radius || old.inverted != inverted || old.depth != depth;
}

/// Kartu claymorphism: drop shadow + inner shadow + sudut sangat membulat.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    this.color,
    this.onTap,
    this.inverted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? ClayColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: inverted
            ? const []
            : const [
                BoxShadow(
                  color: ClayColors.shadowDark,
                  offset: Offset(8, 8),
                  blurRadius: 18,
                ),
                BoxShadow(
                  color: ClayColors.shadowLight,
                  offset: Offset(-6, -6),
                  blurRadius: 14,
                ),
              ],
      ),
      child: CustomPaint(
        foregroundPainter: InnerShadowPainter(
          radius: radius,
          inverted: inverted,
          depth: inverted ? 5 : 7,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

/// Tombol claymorphism: "tenggelam" saat ditekan.
class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = ClayColors.primary,
    this.loading = false,
    this.expanded = true,
    this.foreground = Colors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool loading;
  final bool expanded;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: widget.foreground,
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, color: widget.foreground, size: 22),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: ClayCard(
            color: widget.color,
            radius: 24,
            inverted: _pressed,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Input claymorphism (cekung).
class ClayTextField extends StatelessWidget {
  const ClayTextField({
    super.key,
    required this.label,
    this.controller,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      inverted: true,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(
            color: ClayColors.textSoft,
            fontWeight: FontWeight.w700,
          ),
          icon: icon == null ? null : Icon(icon, color: ClayColors.primary),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

/// Lencana status kecil berbentuk pil.
class ClayPill extends StatelessWidget {
  const ClayPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
