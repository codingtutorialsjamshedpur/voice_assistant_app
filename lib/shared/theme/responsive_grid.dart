import 'package:flutter/material.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double? tabletSpacing;
  final double? desktopSpacing;
  final double childAspectRatio;
  final double? tabletChildAspectRatio;
  final double? desktopChildAspectRatio;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.tabletSpacing,
    this.desktopSpacing,
    this.childAspectRatio = 0.8,
    this.tabletChildAspectRatio,
    this.desktopChildAspectRatio,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;
    final isTablet = width >= 600 && !isDesktop;

    final crossAxisCount = isDesktop
        ? desktopColumns!
        : (isTablet ? tabletColumns! : mobileColumns!);
    final gap = isDesktop
        ? (desktopSpacing ?? spacing)
        : (isTablet ? (tabletSpacing ?? spacing) : spacing);
    final aspect = isDesktop
        ? (desktopChildAspectRatio ?? childAspectRatio)
        : (isTablet ? (tabletChildAspectRatio ?? childAspectRatio) : childAspectRatio);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
        childAspectRatio: aspect,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
