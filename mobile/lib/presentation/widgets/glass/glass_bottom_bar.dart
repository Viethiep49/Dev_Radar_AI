import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../icons/github_logo.dart';

class GlassBottomBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badgeText;
  final String? avatarUrl;

  const GlassBottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeText,
    this.avatarUrl,
  });
}

class GlassBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassBottomBarItem> items;
  final GlassBottomBarItem? actionItem;
  final int actionIndex;

  const GlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.actionItem,
    this.actionIndex = 4,
  });

  @override
  State<GlassBottomBar> createState() => _GlassBottomBarState();
}

class _GlassBottomBarState extends State<GlassBottomBar> with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  double? _dragX;
  bool _isDragging = false;
  int? _lastHapticIndex;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _bounceAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.value = 1.0;
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _triggerBounce() {
    _bounceController.forward(from: 0.0);
    HapticFeedback.selectionClick();
  }

  void _onPanStart(DragDownDetails details, double itemWidth, double paddingH) {
    setState(() {
      _isDragging = true;
      _dragX = details.localPosition.dx;
    });
    _checkIndexChange(itemWidth, paddingH);
  }

  void _onPanUpdate(DragUpdateDetails details, double itemWidth, double paddingH) {
    setState(() {
      _dragX = details.localPosition.dx;
    });
    _checkIndexChange(itemWidth, paddingH);
  }

  void _onPanEnd(double itemWidth, double paddingH) {
    if (_dragX != null) {
      final relativeX = _dragX! - paddingH;
      final index = (relativeX / itemWidth).floor().clamp(0, widget.items.length - 1);
      if (index != widget.currentIndex) {
        widget.onTap(index);
        _triggerBounce();
      }
    }
    setState(() {
      _isDragging = false;
      _dragX = null;
      _lastHapticIndex = null;
    });
  }

  void _checkIndexChange(double itemWidth, double paddingH) {
    if (_dragX == null) return;
    final relativeX = _dragX! - paddingH;
    final index = (relativeX / itemWidth).floor().clamp(0, widget.items.length - 1);
    if (index != _lastHapticIndex && index != widget.currentIndex) {
      _lastHapticIndex = index;
      widget.onTap(index);
      _triggerBounce();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Authentic Apple translucent liquid glass
    final barBgColor = isDark
        ? const Color(0xFF131720).withAlpha(173) // ~68% opacity
        : const Color(0xFF1B202A).withAlpha(184); // ~72% opacity

    final barBorderColor = Colors.white.withAlpha(31); // ~12% opacity
    final isActionActive = widget.currentIndex == widget.actionIndex;
    const double barHeight = 70.0; // Tăng viền ngoài to ra 1 tí theo yêu cầu
    const double marginH = 12.0;
    const double outerRadius = 35.0;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(marginH, 0, marginH, 10),
        height: barHeight,
        child: Row(
          children: [
            // 1. THANH VIÊN NANG CHÍNH (4 tabs)
            Expanded(
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(outerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(89),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(outerRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        color: barBgColor,
                        borderRadius: BorderRadius.circular(outerRadius),
                        border: Border.all(
                          color: barBorderColor,
                          width: 1.0,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Viền trong to ra ôm sát icon, bo đều đồng tâm: R_in = 35 - 5 = 30.0
                          const double pad = 5.0;
                          const double innerRadius = outerRadius - pad; // 30.0
                          const double pillHeight = barHeight - (pad * 2); // 60.0: Cao hơn ôm trọn icon và text

                          final contentWidth = constraints.maxWidth - (pad * 2);
                          final itemCount = widget.items.length;
                          final itemWidth = contentWidth / (itemCount > 0 ? itemCount : 1);
                          final pillWidth = itemWidth;

                          final hasSelectedTabInMain =
                              widget.currentIndex >= 0 && widget.currentIndex < widget.items.length;

                          final targetLeft = _isDragging && _dragX != null
                              ? (_dragX! - pillWidth / 2).clamp(pad, constraints.maxWidth - pad - pillWidth)
                              : (hasSelectedTabInMain
                                  ? pad + (widget.currentIndex * itemWidth)
                                  : pad);

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanDown: (details) => _onPanStart(details, itemWidth, pad),
                            onPanUpdate: (details) => _onPanUpdate(details, itemWidth, pad),
                            onPanEnd: (_) => _onPanEnd(itemWidth, pad),
                            onPanCancel: () {
                              setState(() {
                                _isDragging = false;
                                _dragX = null;
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                // SLIDING LIQUID GLASS PILL (Bo đều đồng tâm chuẩn xác với viền ngoài)
                                AnimatedPositioned(
                                  duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  left: targetLeft,
                                  top: pad,
                                  width: pillWidth,
                                  height: pillHeight,
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 200),
                                      opacity: hasSelectedTabInMain ? 1.0 : 0.0,
                                      child: AnimatedScale(
                                        scale: _isDragging ? 1.03 : 1.0,
                                        duration: const Duration(milliseconds: 150),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(28),
                                            borderRadius: BorderRadius.circular(innerRadius), // 26.0px: BO ĐỀU TUYỆT ĐỐI
                                            border: Border.all(
                                              color: Colors.white.withAlpha(46),
                                              width: 1.0,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white.withAlpha(36),
                                                Colors.white.withAlpha(10),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.4, 1.0],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(45),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // TAB ITEMS
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: pad),
                                  child: Row(
                                    children: List.generate(widget.items.length, (index) {
                                      final item = widget.items[index];
                                      final isSelected = widget.currentIndex == index;

                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            if (widget.currentIndex != index) {
                                              widget.onTap(index);
                                              _triggerBounce();
                                            }
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: SizedBox(
                                            height: barHeight,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                // Icon Area (28px)
                                                SizedBox(
                                                  height: 28,
                                                  child: Center(
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      alignment: Alignment.center,
                                                      children: [
                                                        if (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                                                          // Avatar Tab (Cài đặt)
                                                          Container(
                                                            width: isSelected ? 28 : 24,
                                                            height: isSelected ? 28 : 24,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              border: Border.all(
                                                                color: isSelected
                                                                    ? const Color(0xFF2188FF)
                                                                    : Colors.white.withAlpha(102),
                                                                width: isSelected ? 2.0 : 1.0,
                                                              ),
                                                              boxShadow: isSelected
                                                                  ? [
                                                                      BoxShadow(
                                                                        color: const Color(0xFF2188FF).withAlpha(115),
                                                                        blurRadius: 8,
                                                                      ),
                                                                    ]
                                                                  : null,
                                                            ),
                                                            child: ClipOval(
                                                              child: Image.network(
                                                                item.avatarUrl!,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (context, error, stackTrace) =>
                                                                    const Center(child: GithubLogo(size: 15, color: Colors.white)),
                                                              ),
                                                            ),
                                                          )
                                                        else
                                                          // Normal Icon Tab: Khi Active có nút tròn xanh biển
                                                          AnimatedBuilder(
                                                            animation: _bounceAnimation,
                                                            builder: (context, child) => Transform.scale(
                                                              scale: isSelected ? _bounceAnimation.value : 1.0,
                                                              child: child,
                                                            ),
                                                            child: isSelected
                                                                ? Container(
                                                                    width: 28,
                                                                    height: 28,
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(0xFF2188FF),
                                                                      shape: BoxShape.circle,
                                                                      boxShadow: [
                                                                        BoxShadow(
                                                                          color: const Color(0xFF2188FF).withAlpha(115),
                                                                          blurRadius: 8,
                                                                          offset: const Offset(0, 2),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    child: Center(
                                                                      child: Icon(
                                                                        item.activeIcon,
                                                                        size: 16,
                                                                        color: Colors.white,
                                                                      ),
                                                                    ),
                                                                  )
                                                                : Icon(
                                                                    item.icon,
                                                                    size: 21,
                                                                    color: Colors.white.withAlpha(217),
                                                                  ),
                                                          ),

                                                        // Red Notification Badge (Ảnh mẫu)
                                                        if (item.badgeText != null)
                                                          Positioned(
                                                            top: -5,
                                                            right: -10,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFF3B30),
                                                                borderRadius: BorderRadius.circular(9),
                                                                border: Border.all(
                                                                  color: const Color(0xFF131720),
                                                                  width: 1.2,
                                                                ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: const Color(0xFFFF3B30).withAlpha(102),
                                                                    blurRadius: 4,
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Text(
                                                                item.badgeText!,
                                                                style: const TextStyle(
                                                                  fontSize: 8.5,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
                                                                  height: 1.0,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(height: 2),

                                                // Text Label
                                                Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                    color: isSelected
                                                        ? const Color(0xFF2188FF)
                                                        : Colors.white.withAlpha(184),
                                                    letterSpacing: -0.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. NÚT TRÒN RIÊNG BIỆT BÊN PHẢI (Tìm kiếm - Chuẩn ảnh mẫu của bạn)
            if (widget.actionItem != null) ...[
              const SizedBox(width: 9),
              GestureDetector(
                onTap: () {
                  if (!isActionActive) {
                    widget.onTap(widget.actionIndex);
                    _triggerBounce();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedScale(
                  scale: isActionActive ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 60,
                    height: barHeight,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isActionActive
                              ? const Color(0xFF2188FF).withAlpha(120)
                              : Colors.black.withAlpha(89),
                          blurRadius: isActionActive ? 16 : 20,
                          offset: const Offset(0, 6),
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActionActive
                                ? const Color(0xFF2188FF)
                                : barBgColor,
                            border: Border.all(
                              color: isActionActive
                                  ? Colors.white.withAlpha(70)
                                  : barBorderColor,
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              isActionActive ? widget.actionItem!.activeIcon : widget.actionItem!.icon,
                              size: 24,
                              color: isActionActive
                                  ? Colors.white
                                  : Colors.white.withAlpha(220),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
