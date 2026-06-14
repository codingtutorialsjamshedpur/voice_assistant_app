import 'package:flutter/material.dart';
import 'responsive.dart';

class RText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? align;
  final int? maxLines;

  const RText(this.text,
      {super.key,
      required this.fontSize,
      this.fontWeight,
      this.color,
      this.align,
      this.maxLines});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: context.r.sp(fontSize),
          fontWeight: fontWeight,
          color: color),
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null);
}

class RSizedBox extends StatelessWidget {
  final double? w, h;
  final Widget? child;

  const RSizedBox({super.key, this.w, this.h, this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: w != null ? context.r.scale(w!) : null,
      height: h != null ? context.r.scale(h!) : null,
      child: child);
}

class RPadding extends StatelessWidget {
  final Widget child;
  final double h, v;

  const RPadding({super.key, required this.child, this.h = 16, this.v = 16});

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.r.scale(h), vertical: context.r.scale(v)),
      child: child);
}

class RContainer extends StatelessWidget {
  final Widget child;
  final double? width, height, pw, ph;
  final EdgeInsetsGeometry? padding, margin;
  final Decoration? decoration;

  const RContainer(
      {super.key,
      required this.child,
      this.width,
      this.height,
      this.pw,
      this.ph,
      this.padding,
      this.margin,
      this.decoration});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: pw != null
          ? r.wp(pw!)
          : (width != null ? r.scale(width!) : null),
      height: ph != null
          ? r.hp(ph!)
          : (height != null ? r.scale(height!) : null),
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}

class SafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  const SafeText(this.text,
      {super.key, this.style, this.maxLines = 2, this.textAlign});

  @override
  Widget build(BuildContext context) => Text(text,
      style: style,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: TextOverflow.ellipsis);
}

class ResponsiveTwoColumn extends StatelessWidget {
  final Widget? left, right, mobile;

  const ResponsiveTwoColumn(
      {super.key, this.left, this.right, this.mobile});

  @override
  Widget build(BuildContext context) {
    if (context.r.isTablet || context.r.isLargeTablet) {
      return Row(children: [
        Expanded(flex: 2, child: left ?? const SizedBox()),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: right ?? const SizedBox()),
      ]);
    }
    return mobile ?? left ?? const SizedBox();
  }
}

class TabletConstrained extends StatelessWidget {
  final Widget child;

  const TabletConstrained({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (context.r.isTablet || context.r.isLargeTablet) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.r.isTablet ? 840 : 1200),
          child: child,
        ),
      );
    }
    return child;
  }
}
