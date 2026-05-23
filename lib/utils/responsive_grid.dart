import 'package:flutter/material.dart';

/// 相册列表网格：根据可用宽度自动调整列数
SliverGridDelegate albumGridDelegate(double width) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: _albumMaxExtent(width),
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
    childAspectRatio: 1,
  );
}

/// 表情详情网格
SliverGridDelegate emojiGridDelegate(double width) {
  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: _emojiMaxExtent(width),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1,
  );
}

/// 专辑封面格子的逻辑边长（用于缩略图解码）
double albumCellSide(double width) => _albumMaxExtent(width);

/// 表情格子的逻辑边长（用于缩略图解码）
double emojiCellSide(double width) => _emojiMaxExtent(width);

double _albumMaxExtent(double width) {
  if (width >= 1400) return 220;
  if (width >= 1000) return 200;
  if (width >= 700) return 180;
  if (width >= 500) return 160;
  return 140;
}

double _emojiMaxExtent(double width) {
  if (width >= 1400) return 160;
  if (width >= 1000) return 140;
  if (width >= 700) return 120;
  if (width >= 500) return 110;
  return 96;
}
