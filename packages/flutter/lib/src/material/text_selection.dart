// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'debug.dart';
import 'flat_button.dart';
import 'icon_button.dart';
import 'icons.dart';
import 'material.dart';
import 'material_localizations.dart';
import 'theme.dart';
import 'colors.dart';

const double _kHandleSize = 22.0;

// Minimal padding from all edges of the selection toolbar to all edges of the
// viewport.
const double _kToolbarScreenPadding = 8.0;
const double _kToolbarHeight = 44.0;
// Padding when positioning toolbar below selection.
const double _kToolbarContentDistanceBelow = 16.0;
const double _kToolbarContentDistance = 8.0;

/// Manages a copy/paste text selection toolbar.
class _TextSelectionToolbar extends StatefulWidget {
  const _TextSelectionToolbar({
    Key key,
    this.handleCut,
    this.handleCopy,
    this.handlePaste,
    this.handleSelectAll,
  }) : super(key: key);

  final VoidCallback handleCut;
  final VoidCallback handleCopy;
  final VoidCallback handlePaste;
  final VoidCallback handleSelectAll;

  // Returns true iff the menu items that this widget renders will produce a
  // different width than that of oldWidget. Width depends on the existence of
  // callbacks for their respective buttons.
  bool menuWidthChanged(_TextSelectionToolbar oldWidget) {
    return (handleCut == null) != (oldWidget.handleCut == null)
      || (handleCopy == null) != (oldWidget.handleCopy == null)
      || (handlePaste == null) != (oldWidget.handlePaste == null)
      || (handleSelectAll == null) != (oldWidget.handleSelectAll == null);
  }

  @override
  _TextSelectionToolbarState createState() => _TextSelectionToolbarState();
}

class _TextSelectionToolbarState extends State<_TextSelectionToolbar> {
  final GlobalKey _containerKey = GlobalKey();
  final GlobalKey _moreButtonKey = GlobalKey();
  double _menuContentWidth;

  // Keys for all items in the menu.
  final List<GlobalKey> _itemKeys = <GlobalKey>[];
  // The index of the item that overflows the selection menu, or -1 if
  // everything fits.
  int _indexWhereOverflows;

  // Whether or not the overflow menu is open.
  bool _overflowOpen = false;

  // Whether the overflow menu exists.
  bool get _shouldShowMoreButton {
    final int itemsInFirstMenu = _indexWhereOverflows == -1 ? _itemKeys.length : _indexWhereOverflows;
    if (_itemKeys.isEmpty || itemsInFirstMenu == null) {
      return false;
    }
    return itemsInFirstMenu < _itemKeys.length;
  }

  @override
  void initState() {
    //_measureItemsNextFrame();
    super.initState();
  }

  @override
  void didUpdateWidget(_TextSelectionToolbar oldWidget) {
    // If the widget has been updated, then the content in the menu could have
    // changed, so it will be necessary to render another frame offscreen and
    // re-measure.
    if (widget.menuWidthChanged(oldWidget)) {
      _menuContentWidth = null;
      //_measureItemsNextFrame();
    }
    super.didUpdateWidget(oldWidget);
  }

  // Measure how many items fit inside the container in order to decide which
  // to put in the overflow menu.
  void _measureItemsNextFrame() {
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      // If the menu is empty, no need to measure it.
      if (_itemKeys.isEmpty) {
        return;
      }

      assert(_containerKey.currentContext != null);
      final RenderBox renderBoxContainer = _containerKey.currentContext.findRenderObject() as RenderBox;
      double remainingContainerWidth = renderBoxContainer.size.width;

      _indexWhereOverflows = _itemKeys.indexWhere((GlobalKey key) {
        assert(key.currentContext != null);
        final RenderBox renderBox = key.currentContext.findRenderObject() as RenderBox;

        if (renderBox.size.width > remainingContainerWidth) {
          return true;
        }

        remainingContainerWidth -= renderBox.size.width;
        return false;
      });

      final RenderBox renderBoxMoreButton = _moreButtonKey.currentContext.findRenderObject() as RenderBox;
      final double moreButtonWidth = renderBoxMoreButton.size.width;
      final double itemsWidth = renderBoxContainer.size.width - remainingContainerWidth;

      setState(() {
        _menuContentWidth = _shouldShowMoreButton
          ? itemsWidth + moreButtonWidth
          : itemsWidth;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);

    final List<Widget> items = <Widget>[];
    _itemKeys.removeRange(0, _itemKeys.length);
    if (widget.handleCut != null) {
      _itemKeys.add(GlobalKey());
      items.add(FlatButton(
        key: _itemKeys[_itemKeys.length - 1],
        child: Text(localizations.cutButtonLabel),
        onPressed: () {
          setState(() {
            _overflowOpen = false;
          });
          widget.handleCut();
        },
      ));
    }
    if (widget.handleCopy != null) {
      _itemKeys.add(GlobalKey());
      items.add(FlatButton(
        key: _itemKeys[_itemKeys.length - 1],
        child: Text(localizations.copyButtonLabel),
        onPressed: () {
          setState(() {
            _overflowOpen = false;
          });
          widget.handleCopy();
        },
      ));
    }
    if (widget.handlePaste != null) {
      _itemKeys.add(GlobalKey());
      items.add(FlatButton(
        key: _itemKeys[_itemKeys.length - 1],
        child: Text(localizations.pasteButtonLabel),
        onPressed: () {
          setState(() {
            _overflowOpen = false;
          });
          widget.handlePaste();
        },
      ));
    }
    if (widget.handleSelectAll != null) {
      _itemKeys.add(GlobalKey());
      items.add(FlatButton(
        key: _itemKeys[_itemKeys.length - 1],
        child: Text('Select absolutely everything'),//localizations.selectAllButtonLabel),
        onPressed: () {
          setState(() {
            _overflowOpen = false;
          });
          widget.handleSelectAll();
        },
      ));
    }

    // If there is no option available, build an empty widget.
    if (items.isEmpty) {
      return Container(width: 0.0, height: 0.0);
    }

    // If _itemsInFirstMenu hasn't been calculated yet, render offstage for one
    // frame for measurement.
    if (_menuContentWidth == null && false) {
      return Offstage(
        child: _TextSelectionToolbarContainer(
          key: _containerKey,
          child: _TextSelectionToolbarContent(
            items: items,
            showMoreButton: true,
            moreButtonKey: _moreButtonKey,
          ),
        ),
      );
    }

    final int itemsInFirstMenu = _indexWhereOverflows == -1
      ? _itemKeys.length
      : _indexWhereOverflows;

    if (_overflowOpen || true) {
      return _TextSelectionToolbarContainer(
        key: _containerKey,
        width: 300,//_menuContentWidth,
        child: _TextSelectionToolbarContentOverflow(
          items: items.sublist(0, items.length),//itemsInFirstMenu, items.length),
          onBackPressed: () {
            setState(() {
              _overflowOpen = false;
            });
          },
        ),
      );
    }

    return _TextSelectionToolbarContainer(
      key: _containerKey,
      width: _menuContentWidth,
      child: _TextSelectionToolbarContent(
        items: items.sublist(0, itemsInFirstMenu),
        showMoreButton: itemsInFirstMenu < items.length,
        moreButtonKey: _moreButtonKey,
        onMorePressed: () {
          setState(() {
            _overflowOpen = true;
          });
        },
      ),
    );
  }
}

class _TextSelectionToolbarContainer extends StatefulWidget {
  const _TextSelectionToolbarContainer({
    Key key,
    this.width,
    this.child,
  }) : super(key: key);

  final Widget child;
  final double width;

  @override
  _TextSelectionToolbarContainerState createState() => _TextSelectionToolbarContainerState();
}

class _TextSelectionToolbarContainerState extends State<_TextSelectionToolbarContainer> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: _kToolbarHeight,
      color: Colors.red,
      //child: widget.child,
      /*
      child: Align(
        alignment: Alignment.bottomRight,
        heightFactor: 1.0,
        widthFactor: 1.0,
        child: Material(
          elevation: 1.0,
          child: AnimatedSize(
            vsync: this,
            // This duration was eyeballed on a Pixel 2 emulator running Android
            // API 28.
            duration: const Duration(milliseconds: 140),
            child: widget.child,
          ),
        ),
      //),
        */
    );
  }
}

// The content of the text selection menu when the overflow menu is closed,
// including when the more button is not shown at all.
class _TextSelectionToolbarContent extends StatelessWidget {
  const _TextSelectionToolbarContent({
    Key key,
    @required this.items,
    this.onMorePressed,
    this.showMoreButton = false,
    this.moreButtonKey,
  }) : assert(items != null),
       super(key: key);

  final List<Widget> items;
  final VoidCallback onMorePressed;
  final bool showMoreButton;
  final GlobalKey moreButtonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kToolbarHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...items,
          if (showMoreButton) IconButton(
            key: moreButtonKey,
            icon: Icon(Icons.more_vert),
            tooltip: 'More',
            onPressed: onMorePressed,
          ),
        ],
      ),
    );
  }
}

// The content of the text selection menu when the overflow menu is open.
class _TextSelectionToolbarContentOverflow extends StatelessWidget {
  const _TextSelectionToolbarContentOverflow({
    Key key,
    @required this.items,
    @required this.onBackPressed,
  }) : assert(items != null),
       assert(onBackPressed != null),
       super(key: key);

  final List<Widget> items;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final IconButton moreButton = IconButton(
      icon: Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: onBackPressed,
    );
    final List<Widget> children = <Widget>[...items];
    if ((materialTextSelectionControls as _MaterialTextSelectionControls).fitsAbove) {
      children.insert(children.length, moreButton);
    } else {
      children.insert(0, moreButton);
    }

    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Centers the toolbar around the given position, ensuring that it remains on
/// screen.
class _TextSelectionToolbarLayout extends SingleChildLayoutDelegate {
  _TextSelectionToolbarLayout(this.screenSize, this.globalEditableRegion, this.position);

  /// The size of the screen at the time that the toolbar was last laid out.
  final Size screenSize;

  /// Size and position of the editing region at the time the toolbar was last
  /// laid out, in global coordinates.
  final Rect globalEditableRegion;

  /// Anchor position of the toolbar, relative to the top left of the
  /// [globalEditableRegion].
  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final Offset globalPosition = globalEditableRegion.topLeft + position;

    double x = globalPosition.dx - childSize.width / 2.0;
    double y = globalPosition.dy - childSize.height;

    if (x < _kToolbarScreenPadding)
      x = _kToolbarScreenPadding;
    else if (x + childSize.width > screenSize.width - _kToolbarScreenPadding)
      x = screenSize.width - childSize.width - _kToolbarScreenPadding;

    if (y < _kToolbarScreenPadding)
      y = _kToolbarScreenPadding;
    else if (y + childSize.height > screenSize.height - _kToolbarScreenPadding)
      y = screenSize.height - childSize.height - _kToolbarScreenPadding;

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_TextSelectionToolbarLayout oldDelegate) {
    return position != oldDelegate.position;
  }
}

/// Draws a single text selection handle which points up and to the left.
class _TextSelectionHandlePainter extends CustomPainter {
  _TextSelectionHandlePainter({ this.color });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double radius = size.width/2.0;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    canvas.drawRect(Rect.fromLTWH(0.0, 0.0, radius, radius), paint);
  }

  @override
  bool shouldRepaint(_TextSelectionHandlePainter oldPainter) {
    return color != oldPainter.color;
  }
}

class _MaterialTextSelectionControls extends TextSelectionControls {
  final GlobalKey _key = GlobalKey();

  /// Indicates that the controls fit above the text on the screen.
  ///
  /// If null, then buildToolbar has not yet been called.
  bool fitsAbove;

  /// Returns the size of the Material handle.
  @override
  Size getHandleSize(double textLineHeight) => const Size(_kHandleSize, _kHandleSize);

  /// Builder for material-style copy/paste text selection toolbar.
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset position,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
  ) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasMaterialLocalizations(context));

    final double toolbarHeight = 

    // The toolbar should appear below the TextField
    // when there is not enough space above the TextField to show it.
    final TextSelectionPoint startTextSelectionPoint = endpoints[0];
    final double toolbarHeightNeeded = MediaQuery.of(context).padding.top
      + _kToolbarScreenPadding
      + _kToolbarHeight
      + _kToolbarContentDistance;
    final double availableHeight = globalEditableRegion.top + endpoints.first.point.dy - textLineHeight;
    fitsAbove = toolbarHeightNeeded <= availableHeight;
    final double y = fitsAbove
        ? startTextSelectionPoint.point.dy - _kToolbarContentDistance - textLineHeight
        // TODO(justinmc): The main problem is that the toolbar is being layed
        // out assuming it is always height _kToolbarHeight. I need to come up
        // with a way that works with any height that is as close as possible to
        // the original implementation, if possible. Notice that fitsAbove can
        // also be wrong because of this.
        : startTextSelectionPoint.point.dy + _kToolbarHeight + _kToolbarContentDistanceBelow;
    final Offset preciseMidpoint = Offset(position.dx, y);

    return ConstrainedBox(
      key: _key,
      constraints: BoxConstraints.tight(globalEditableRegion.size),
      child: CustomSingleChildLayout(
        delegate: _TextSelectionToolbarLayout(
          MediaQuery.of(context).size,
          globalEditableRegion,
          preciseMidpoint,
        ),
        child: _TextSelectionToolbar(
          handleCut: canCut(delegate) ? () => handleCut(delegate) : null,
          handleCopy: canCopy(delegate) ? () => handleCopy(delegate) : null,
          handlePaste: canPaste(delegate) ? () => handlePaste(delegate) : null,
          handleSelectAll: canSelectAll(delegate) ? () => handleSelectAll(delegate) : null,
        ),
      ),
    );
  }

  /// Builder for material-style text selection handles.
  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textHeight) {
    final Widget handle = SizedBox(
      width: _kHandleSize,
      height: _kHandleSize,
      child: CustomPaint(
        painter: _TextSelectionHandlePainter(
          color: Theme.of(context).textSelectionHandleColor
        ),
      ),
    );

    // [handle] is a circle, with a rectangle in the top left quadrant of that
    // circle (an onion pointing to 10:30). We rotate [handle] to point
    // straight up or up-right depending on the handle type.
    switch (type) {
      case TextSelectionHandleType.left: // points up-right
        return Transform.rotate(
          angle: math.pi / 2.0,
          child: handle,
        );
      case TextSelectionHandleType.right: // points up-left
        return handle;
      case TextSelectionHandleType.collapsed: // points up
        return Transform.rotate(
          angle: math.pi / 4.0,
          child: handle,
        );
    }
    assert(type != null);
    return null;
  }

  /// Gets anchor for material-style text selection handles.
  ///
  /// See [TextSelectionControls.getHandleAnchor].
  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    switch (type) {
      case TextSelectionHandleType.left:
        return const Offset(_kHandleSize, 0);
      case TextSelectionHandleType.right:
        return Offset.zero;
      default:
        return const Offset(_kHandleSize / 2, -4);
    }
  }

  @override
  bool canSelectAll(TextSelectionDelegate delegate) {
    // Android allows SelectAll when selection is not collapsed, unless
    // everything has already been selected.
    final TextEditingValue value = delegate.textEditingValue;
    return delegate.selectAllEnabled &&
           value.text.isNotEmpty &&
           !(value.selection.start == 0 && value.selection.end == value.text.length);
  }
}

/// Text selection controls that follow the Material Design specification.
final TextSelectionControls materialTextSelectionControls = _MaterialTextSelectionControls();
