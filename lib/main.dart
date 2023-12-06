import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' as r;
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sb = ServicesBinding.instance;
  sb.requestPerformanceMode(ui.DartPerformanceMode.balanced);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: MyAppIntermidiary(),
      ),
    );
  }
}
class MyAppIntermidiary extends StatefulWidget {
  const MyAppIntermidiary({super.key});
  @override
  State<StatefulWidget> createState() {
    return MyAppIntermidiaryState();
  }
}
class MyAppIntermidiaryState
  extends State<MyAppIntermidiary>
  with TickerProviderStateMixin
{

  @override
  Widget build(BuildContext context) {
    return TextEditorView(this);
  }
}

enum CarretMoveDirection {
  up, down, left, right
}
enum WordJumpDirection {
  left, right
}
enum LineEditHint {
  characterAdded, characterErased
}
class TextEditorView extends LeafRenderObjectWidget {
  const TextEditorView(this.vsyncer, {super.key});
  final TickerProvider vsyncer;
  @override
  RenderObject createRenderObject(BuildContext context) {
    var pointerEventListener = r.RenderPointerListener(
      behavior: HitTestBehavior.opaque,
    );
    var child = TextEditorViewImpl(pointerEventListener, vsyncer);
    pointerEventListener.child = child;
    return pointerEventListener;
  }
}
final class TextEditorViewImpl extends RenderBox  {
  TextEditorViewImpl(
    this._pointerListener,
    this._vsyncer,
    {
      bool carretShouldBlink = false
    }
  ) :
    _keyboard = HardwareKeyboard.instance,
    _carretShouldBlink = carretShouldBlink
  {
    _pointerListener.onPointerDown = (ev) {
      if (!ev.down) return;
      pointerDownForCarretMove(
        Offset(ev.position.dx, ev.position.dy - _scrollOffset.dy));
    };
    _pointerListener.onPointerSignal = handlePointerEvent;

    _keyboard.addHandler((event) {
      handleKey(event);
      return false;
    });
    _textPainter.text = TextSpan(text: " ", style: dts);
    _textPainter.layout();
    _lineHeight = _textPainter.height;
    _characterWidth = _textPainter.width;

    _animationController = AnimationController(
      vsync: _vsyncer,
      duration: const Duration(milliseconds: 300),
    );

    _animationController.addListener(() {
      _carretOpacity = _animationController.value;
      markNeedsPaint();
    });
    if (_carretShouldBlink) {
      activateCarretBlinking();
    }
    final rec = ui.PictureRecorder();
    final _ = Canvas(rec);
    _cachedTextLayer = rec.endRecording().toImageSync(1, 1);
    // doesnt work 0_o
    // _shortcutManager = ShortcutManager(shortcuts: {
    //   LogicalKeySet(
    //     LogicalKeyboardKey.control,
    //     LogicalKeyboardKey.keyC,
    //     LogicalKeyboardKey.keyB)
    //   :
    //   VoidCallbackIntent(() {
    //     print("this");
    //   }),
    //   const SingleActivator(LogicalKeyboardKey.keyY, control: true)
    //   :
    //   VoidCallbackIntent(() {
    //     print("that");
    //   })
    // });
  }

  // late final ShortcutManager _shortcutManager;
  final bool _carretShouldBlink;
  final double _textSize = 13.5;
  Offset _scrollOffset = Offset.zero;
  final r.RenderPointerListener _pointerListener;
  final HardwareKeyboard _keyboard;
  late double _lineHeight;
  final double _carretWidth = 2;
  late double _characterWidth  ;
  int _carretLineIndex = 0;
  int _carretCharIndex = 0;
  late ui.Image _cachedTextLayer ;
  bool _controlKeyboardKeyActive = false;
  bool _shiftKeyboardKeyActive = false;
  final List<String> _lines = [""];
  final Color _backgroundColor = Colors.blueGrey.shade800;
  final Color _carretColor = Colors.deepOrange;
  double _carretOpacity = 1;
  Timer? _carretBlinkCycleTrigger;
  final fontFam = "Cascadia Code";
  late final dts = TextStyle(
    color: Colors.black.withOpacity(0.7),
    fontSize: _textSize,
    fontFamily: fontFam
  );
  late final ichts = TextStyle(
    color: Colors.black26,
    fontSize: _textSize,
    fontFamily: fontFam
  );
  final TickerProvider _vsyncer;
  late AnimationController _animationController;
  (int charAnchor, int lineAnchor)? _selectionModeData;
  bool _pasteProceeding = false;
  final Color _lineUnderColor =
    Colors.deepOrange.shade100.withOpacity(0.1);
  late final TextPainter _textPainter = TextPainter(
    strutStyle: StrutStyle(fontFamily: fontFam, fontSize: _textSize,),
    textDirection: TextDirection.ltr,
  );
  final String _newLineChar = "⮧";
  final List<(String, String)> _invisibles = [
    ("\u0020", "•"),
    ("\u000A", "\u2B92")
  ];
  final String _jumpStoppers = " (){}.;=:_";
  late final Color _selectionBoxColor = _carretColor.withOpacity(0.1);
  final Radius _selectionBoxBorderRadius = const Radius.circular(3);
  late int _linesPerViewport;

  int get _currentLineCharLimit =>
    _lines[_carretLineIndex].characters.length;

  void activateCarretBlinking() {
    _carretBlinkCycleTrigger ??= Timer.periodic(
      const Duration(seconds: 1, milliseconds: 500),
      (_) async {
        _animationController.reset();
        await _animationController.forward();
      }
    );
  }
  ((int, int), (int, int)) getNormalisedSelectionLocs() {
    final (int, int) lowLine ;
    final (int, int) highLine ;
    if (_selectionModeData!.$2 > _carretLineIndex) {
      lowLine = (_carretCharIndex, _carretLineIndex);
      highLine = _selectionModeData!;
    } else {
      lowLine =  _selectionModeData!;
      highLine = (_carretCharIndex, _carretLineIndex);
    }
    return (lowLine, highLine);
  }
  void rebuildTextLayer() {
    _cachedTextLayer.dispose();

    final rec = ui.PictureRecorder();
    final canvasForText = Canvas(rec);

    var widestLine = .0;
    var lineNum = 0;

    for (final line in _lines) {
      final chars = line.characters;
      final currentLineWidth = (chars.length + 1) * _characterWidth;
      if (currentLineWidth > widestLine) {
        widestLine = currentLineWidth;
      }
      var dxOffset = .0;
      for (final char in chars) {
        var matched = false;
        for (final (invch, subst) in _invisibles) {
          if (invch == char) {
            _textPainter.text = TextSpan(text: subst, style: ichts);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _textPainter.text = TextSpan(text: char, style: dts);
        }
        _textPainter.layout();
        _textPainter.paint(canvasForText, Offset(dxOffset, lineNum * _lineHeight));
        dxOffset += _characterWidth;
      }
      if (lineNum != _lines.length - 1) {
        _textPainter.text = TextSpan(text: "$_newLineChar\n", style: ichts);
        _textPainter.layout();
        _textPainter.paint(canvasForText, Offset(dxOffset, lineNum * _lineHeight));
      }
      lineNum += 1;
    }

    final width = widestLine + _characterWidth + _carretWidth;
    final height = _lines.length * _lineHeight;

    _cachedTextLayer = rec.endRecording().toImageSync(
      width.ceil(), height.ceil());
  }
  @override
  void dispose() {
    _carretBlinkCycleTrigger?.cancel();
    // _shortcutManager.dispose();
    super.dispose();
  }
  void handlePointerEvent(PointerSignalEvent pse) {
    switch (pse) {
      case PointerScrollEvent pse:
        final off = pse.scrollDelta;
        if (_cachedTextLayer.height > size.height) {
          _scrollOffset += off;
          if (_scrollOffset.dy > 0) {
            _scrollOffset = Offset(_scrollOffset.dx, 0);
          }
          if (_scrollOffset.dy.abs() >= _cachedTextLayer.height) {
            _scrollOffset = Offset(
              _scrollOffset.dx, _scrollOffset.dy - pse.scrollDelta.dy);
          }
        }
        markNeedsPaint();
        return;
      default:
        return;
    }
  }
  void pointerDownForCarretMove(
    Offset position
  ) {
    final lineIndex = (position.dy / _lineHeight).floor();
    if (lineIndex >= _lines.length) return;
    _carretLineIndex = lineIndex;
    final charLim = _currentLineCharLimit;
    final charIndex = (position.dx / _characterWidth).floor();
    if (charIndex >= charLim) {
      _carretCharIndex = charLim;
    } else {
      _carretCharIndex = charIndex;
    }
    markNeedsPaint();
  }
  void cancelSelectionMode() {
    _selectionModeData = null;
  }
  void handleKey(KeyEvent ke) async {
    switch (ke) {
      case KeyRepeatEvent kre:
        switch (kre.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
            moveCarret(CarretMoveDirection.left);
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowRight:
            moveCarret(CarretMoveDirection.right);
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowUp:
            moveCarret(CarretMoveDirection.up);
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowDown:
            moveCarret(CarretMoveDirection.down);
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.backspace:
            eraseChar();
            break;
          default:
            break;
        }
        return;
      case KeyDownEvent kde:
        switch (kde.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex,_carretLineIndex);
              if (_controlKeyboardKeyActive) {
                final next = findClosestStopIndex(WordJumpDirection.left);
                _carretCharIndex = next;
                markNeedsPaint();
              } else {
                moveCarret(CarretMoveDirection.left);
                markNeedsPaint();
              }
            } else if (_controlKeyboardKeyActive) {
              cancelSelectionMode();
              final next = findClosestStopIndex(WordJumpDirection.left);
              _carretCharIndex = next;
              markNeedsPaint();
            } else {
              cancelSelectionMode();
              moveCarret(CarretMoveDirection.left);
              markNeedsPaint();
            }
            return;
          case LogicalKeyboardKey.arrowRight:
            if (_shiftKeyboardKeyActive) {
              if (_controlKeyboardKeyActive) {
                final next = findClosestStopIndex(WordJumpDirection.right);
                _selectionModeData ??= (_carretCharIndex,_carretLineIndex);
                _carretCharIndex = next;
                markNeedsPaint();
              } else {
                moveCarret(CarretMoveDirection.right);
                markNeedsPaint();
              }
            } else if (_controlKeyboardKeyActive) {
              cancelSelectionMode();
              final next = findClosestStopIndex(WordJumpDirection.right);
              _carretCharIndex = next;
              markNeedsPaint();
            } else {
              cancelSelectionMode();
              moveCarret(CarretMoveDirection.right);
              markNeedsPaint();
            }
            return;
          case LogicalKeyboardKey.arrowUp:
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
            } else {
              cancelSelectionMode();
            }
            moveCarret(CarretMoveDirection.up);
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.arrowDown:
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
            } else {
              cancelSelectionMode();
            }
            moveCarret(CarretMoveDirection.down);
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.home:
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
            } else {
              cancelSelectionMode();
            }
            _carretCharIndex = 0;
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.end:
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
            } else {
              cancelSelectionMode();
            }
            _carretCharIndex = _currentLineCharLimit;
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.controlLeft:
            _controlKeyboardKeyActive = true;
            return;
          case LogicalKeyboardKey.enter:
            moveToNextLine();
            return;
          case LogicalKeyboardKey.shiftLeft:
            _shiftKeyboardKeyActive = true;
            return;
          case LogicalKeyboardKey.space:
            var delSpan = (_carretLineIndex, 0);
            if (_selectionModeData != null) {
              delSpan = eraseSelection();
            }
            _carretCharIndex += 1;
            insertChar(" ");
            _updateTextCache(delSpan.$1, 1, delSpan.$2);
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.backspace:
            if (_selectionModeData != null) {
              final delSpan = eraseSelection();
              _updateTextCache(delSpan.$1, 1, delSpan.$2);
              markNeedsPaint();
            } else if (_controlKeyboardKeyActive) {
              cancelSelectionMode();
              eraseToLeftMostWord();
            } else {
              eraseChar();
            }
            return;
          case LogicalKeyboardKey.keyA when _controlKeyboardKeyActive:
            selectAllText();
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.keyC
          when _controlKeyboardKeyActive && _selectionModeData != null:
            final sel = getSelectedText();
            Clipboard.setData(ClipboardData(text: sel));
            return;
          case LogicalKeyboardKey.keyV
          when _controlKeyboardKeyActive && !_pasteProceeding:
            // this may discard most recent data, but alas!
            _pasteProceeding = true;
            final str = await getMostRecentDataFromPasteboard();
            if (str != null) {
              var delSpan = (_carretLineIndex, 0);
              if (_selectionModeData != null) {
                delSpan = eraseSelection();
              }
              final (ln, span) = insertText(str);
              _updateTextCache(ln, span, delSpan.$2);
              // markNeedsPaint();
              markNeedsPaint();
            }
            _pasteProceeding = false;
            return;
          default:
            final v = kde.character;
            if (v == null) return;
            var delSpan = (_carretLineIndex, 0);
            if (_selectionModeData != null) {
              delSpan = eraseSelection();
            }
            _carretCharIndex += 1;
            insertChar(v);
            _updateTextCache(delSpan.$1, 1, delSpan.$2);
            markNeedsPaint();
            return;
        }
      case KeyUpEvent kue:
        switch (kue.logicalKey) {
          case LogicalKeyboardKey.shiftLeft:
            _shiftKeyboardKeyActive = false;
          case LogicalKeyboardKey.controlLeft:
            _controlKeyboardKeyActive = false;
            return;
          default:
            return;
        }
    }
  }
  void selectAllText() {
    _selectionModeData = (0,0);
    _carretLineIndex = _lines.length.cappedSub(1);
    _carretCharIndex = _currentLineCharLimit;
  }
  void moveToNextLine() {
    final str = _lines[_carretLineIndex];
    final remainder = str.substring(0, _carretCharIndex);
    _lines[_carretLineIndex] = remainder;
    final slided = str.substring(_carretCharIndex);
    _lines.insert(_carretLineIndex + 1, slided);
    _updateTextCache(_carretLineIndex, 2, 0);
    markNeedsPaint();
  }
  String getSelectedText() {
    assert(_selectionModeData != null);
    final str = _lines[_carretLineIndex];
    final (lo, hi) = getNormalisedSelectionLocs();
    if (lo.$2 == hi.$2) {
      final int b;
      final int e;
      if (lo.$1 > hi.$1) {
        e = lo.$1; b = hi.$1;
      } else {
        e = hi.$1; b = lo.$1;
      }
      final cs = str.substring(b,e);
      return cs;
    } else {
      final first = _lines[lo.$2].substring(lo.$1);
      final last = _lines[hi.$2].substring(0, hi.$1);
      var span = hi.$2 - lo.$2 - 1;
      var pcs = [];
      while (true) {
        if (span == 0) break;
        final str = _lines[lo.$2 + span];
        pcs.add(str);
        span -= 1;
      }
      var mid = "";
      var rest = false;
      for (final item in pcs.reversed) {
        if (rest) { mid += "\n"; }
        else { rest = true; }
        mid += item;
      }
      final res = "$first\n$mid\n$last";
      return res;
    }
  }
  (int, int) insertText(String text) {
    assert(_selectionModeData == null);
    var lines = text.split("\n");
    final str = _lines[_carretLineIndex];
    final left = str.substring(0, _carretCharIndex);
    final right = str.substring(_carretCharIndex);
    final split = lines.trisplit();
    if (split == null) {
      final res = left + text + right;
      _lines[_carretLineIndex] = res;
    } else {
      final (f, m, l) = split;
      _lines[_carretLineIndex] = left + f;
      _lines.insert(_carretLineIndex + 1, l + right);
      for (final line in m.reversed) {
        _lines.insert(_carretLineIndex + 1, line);
      }
    }
    final span = lines.length;
    return (_carretLineIndex, span);
  }
  void _updateTextCache(
    int startLine,
    int updateSpan,
    int deleteSpan
  ) {
    assert(updateSpan > 0);

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    final oldTextLayerWidth = _cachedTextLayer.width.toDouble();
    final firstPatch =
      const Offset(0,0) &
      Size(oldTextLayerWidth, startLine * _lineHeight);
    canvas.drawImageRect(
      _cachedTextLayer,
      firstPatch,
      firstPatch,
      Paint()
    );
    final spread = startLine + updateSpan;
    final newLines = _lines.sublist(startLine, spread);
    var lineNum = startLine;
    var widestLine = .0;
    for (final line in newLines) {
      final chars = line.characters;
      final currentLineWidth = (chars.length + 1) * _characterWidth;
      if (currentLineWidth > widestLine) {
        widestLine = currentLineWidth;
      }
      var dxOffset = .0;
      for (final char in chars) {
        var matched = false;
        for (final (invch, subst) in _invisibles) {
          if (invch == char) {
            _textPainter.text = TextSpan(text: subst, style: ichts);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _textPainter.text = TextSpan(text: char, style: dts);
        }
        _textPainter.layout();
        _textPainter.paint(canvas, Offset(dxOffset, lineNum * _lineHeight));
        dxOffset += _characterWidth;
      }
      if (lineNum != _lines.length - 1) {
        _textPainter.text = TextSpan(text: "$_newLineChar\n", style: ichts);
        _textPainter.layout();
        _textPainter.paint(canvas, Offset(dxOffset, lineNum * _lineHeight));
      }
      lineNum += 1;
    }

    final sph = _cachedTextLayer.height - startLine * _lineHeight;
    canvas.drawImageRect(
      _cachedTextLayer,
      Offset(0, (startLine + 1 + deleteSpan) * _lineHeight) &
      Size(oldTextLayerWidth, sph),
      Offset(0, lineNum * _lineHeight) &
      Size(oldTextLayerWidth, sph),
      Paint()
    );
    var w = oldTextLayerWidth;
    if (widestLine > w) {
      w = widestLine;
    }
    var h = _cachedTextLayer.height + spread * _lineHeight;
    _cachedTextLayer.dispose();
    _cachedTextLayer = rec.endRecording().toImageSync(w.toInt(), h.toInt());
  }
  Future<String?> getMostRecentDataFromPasteboard() async {
    final insert = await Clipboard.getData(Clipboard.kTextPlain);
    if (insert == null) return null;
    return insert.text;
  }
  int findClosestStopIndex(
    WordJumpDirection direction
  ) {
    final chars = _lines[_carretLineIndex].characters;
    var index = _carretCharIndex;
    switch (direction) {
      case WordJumpDirection.left:
        if (index == _currentLineCharLimit) { index -= 1; }
        while (true) {
          if (index == 0) return index;
          final char = chars.elementAt(index);
          if (_jumpStoppers.contains(char) && index != _carretCharIndex) {
            return index;
          }
          index -= 1;
        }
      case WordJumpDirection.right:
        while (true) {
          if (index == _currentLineCharLimit) return index;
          final char = chars.elementAt(index);
          if (_jumpStoppers.contains(char) && index != _carretCharIndex) {
            return index;
          }
          index += 1;
        }
    }
  }
  void moveCarret(CarretMoveDirection cmd) {
    switch (cmd) {
      case CarretMoveDirection.up:
        if (_carretLineIndex == 0) return ;
        _carretLineIndex -= 1;
        if (_carretCharIndex > _currentLineCharLimit) {
          _carretCharIndex = _currentLineCharLimit;
        }
        final offset = (_scrollOffset.dy.abs() / _lineHeight).floor();
        if (offset == 0) return;
        final ln = (_carretLineIndex - offset) % _linesPerViewport;
        if (ln == 0) {
          final off = _scrollOffset.dy + _lineHeight;
          _scrollOffset = Offset(_scrollOffset.dx, off);
        }
        return ;
      case CarretMoveDirection.down:
        if (_carretLineIndex + 1 == _lines.length) {
          return ;
        }
        _carretLineIndex += 1;
        if (_carretCharIndex > _currentLineCharLimit) {
          _carretCharIndex = _currentLineCharLimit;
        }
        final offset = (_scrollOffset.dy.abs() / _lineHeight).floor();
        final ln = (_carretLineIndex - offset) % _linesPerViewport;
        if (ln == 0) {
          final off = _scrollOffset.dy - _lineHeight;
          _scrollOffset = Offset(_scrollOffset.dx, off);
        }
        return ;
      case CarretMoveDirection.left:
        if (_carretCharIndex == 0) {
          return ; //wrap arround?
        }
        _carretCharIndex -= 1;
        return ;
      case CarretMoveDirection.right:
        if (_carretCharIndex == _currentLineCharLimit) {
          return ;
        }
        _carretCharIndex += 1;
        return ;
    }
  }
  void insertChar(String inp) {
    final str = _lines[_carretLineIndex];
    final left = str.substring(0, _carretCharIndex - 1);
    final right = str.substring(_carretCharIndex - 1);
    final res = left + inp + right;
    _lines[_carretLineIndex] = res;
  }
  void eraseChar() {
    final str = _lines[_carretLineIndex];
    final carretAtStart = _carretCharIndex == 0;
    if (carretAtStart) {
      if (_carretLineIndex == 0) return;
      _lines.removeAt(_carretLineIndex);
      _carretLineIndex -= 1;
      _lines[_carretLineIndex] += str;
      _carretCharIndex = _currentLineCharLimit;
      _updateTextCache(_carretLineIndex, 1, 1);
    } else {
      final left = str.substring(0, _carretCharIndex - 1);
      var right = str.substring(_carretCharIndex);
      final res = left + right;
      _lines[_carretLineIndex] = res;
      _carretCharIndex -= 1;
      _updateTextCache(_carretLineIndex, 1, 0);
    }
    markNeedsPaint();
  }
  void eraseToLeftMostWord() {
    if (_carretCharIndex == 0) return;
    final str = _lines[_carretLineIndex];
    final ls = _carretCharIndex;
    final re = findClosestStopIndex(WordJumpDirection.left);
    final left = str.substring(0, re);
    final right = str.substring(ls);
    final res = left + right;
    _lines[_carretLineIndex] = res;
    _carretCharIndex = re;
    _updateTextCache(_carretLineIndex, 1, 0);
    markNeedsPaint();
  }
  (int, int) eraseSelection() {
    final (lo, hi) = getNormalisedSelectionLocs();
    final (int, int) ret;
    if (lo.$2 == hi.$2) {
      final int start ;
      final int end;
      if (lo.$1 > hi.$1) {
        start = hi.$1; end = lo.$1;
      } else {
        start = lo.$1; end = hi.$1;
      }
      final str = _lines[lo.$2];
      final left = str.substring(0, start);
      final right = str.substring(end);
      final res = left + right;
      _lines[_carretLineIndex] = res;
      _carretCharIndex = start;
      _carretLineIndex = lo.$2;
      ret = (lo.$2, 0);
    } else {
      final left = _lines[lo.$2].substring(0, lo.$1);
      final right = _lines[hi.$2].substring(hi.$1);
      final span = hi.$2 - lo.$2;
      var spani = span ;
      while (true) {
        if (spani == 0) break;
        _lines.removeAt(lo.$2 + spani);
        spani -= 1;
      }
      _lines[lo.$2] = left + right;
      _carretCharIndex = lo.$1;
      _carretLineIndex = lo.$2;
      ret = (lo.$2,span);

      final screenTopLn = (_scrollOffset.dy.abs() / _lineHeight).floor();
      if (lo.$2 < screenTopLn) {
        _scrollOffset = Offset(_scrollOffset.dx, -(lo.$2 * _lineHeight));
      }
    }
    _selectionModeData = null;
    return ret;
  }
  @override
  void performLayout() {
    final normed = constraints.normalize();
    assert(normed.maxWidth.isFinite && normed.maxHeight.isFinite);
    final lpv = normed.maxHeight / _lineHeight;
    _linesPerViewport = lpv.floor();
    size = Size(normed.maxWidth, normed.maxHeight);
  }
  @override
  void paint(PaintingContext context, Offset offset) {

    final canvas = context.canvas;
    canvas.save();
    canvas.translate(_scrollOffset.dx, _scrollOffset.dy);
    canvas.drawColor(
      _backgroundColor,
      BlendMode.src);
    canvas.drawRect(
      Offset(0, _carretLineIndex * _lineHeight) &
      Size(size.width, _lineHeight),
      Paint()..color=_lineUnderColor);
    canvas.drawImage(
      _cachedTextLayer,
      Offset.zero,
      Paint());


    if (_selectionModeData != null) {
      final selectionBoxPaint = Paint()..color=_selectionBoxColor;
      if (_selectionModeData!.$2 == _carretLineIndex) {
        final selectionBoxWidth =
          _characterWidth * (_selectionModeData!.$1 - _carretCharIndex).abs();
        final selectionBoxXOrigin =
          _characterWidth * math.min(_selectionModeData!.$1, _carretCharIndex);
        final selectionBoxYOrigin = _lineHeight * _carretLineIndex;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Offset(selectionBoxXOrigin, selectionBoxYOrigin) &
            Size(selectionBoxWidth, _lineHeight),
          _selectionBoxBorderRadius),
          selectionBoxPaint);
      } else {
        final (int, int) lowLine ;
        final (int, int) highLine ;
        if (_selectionModeData!.$2 > _carretLineIndex) {
          lowLine = (_carretCharIndex, _carretLineIndex);
          highLine = _selectionModeData!;
        } else {
          lowLine =  _selectionModeData!;
          highLine = (_carretCharIndex, _carretLineIndex);
        }
        final firstBoxWidth =
          (_lines[lowLine.$2].characters.length - lowLine.$1) * _characterWidth;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Offset(lowLine.$1 * _characterWidth, lowLine.$2 * _lineHeight) &
            Size(firstBoxWidth, _lineHeight),
            topLeft: _selectionBoxBorderRadius,
            bottomLeft: _selectionBoxBorderRadius
          ),
          selectionBoxPaint);
        final lastBoxWidth = highLine.$1 * _characterWidth;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Offset(0, highLine.$2 * _lineHeight) &
            Size(lastBoxWidth, _lineHeight),
            topRight: _selectionBoxBorderRadius,
            bottomRight: _selectionBoxBorderRadius
          ),
          selectionBoxPaint);
        var span = highLine.$2 - lowLine.$2 - 1;
        while (true) {
          if (span == 0) break;
          final width =
            _lines[lowLine.$2 + span].characters.length * _characterWidth;
          canvas.drawRect(
            Offset(0, (lowLine.$2 + span) * _lineHeight) &
            Size(width, _lineHeight),
            selectionBoxPaint);
          span -= 1;
        }
      }
    }

    canvas.drawRect(
      Offset(0, (_lines.length) * _lineHeight) &
      Size(size.width, 1),
      Paint()..color=Colors.blueGrey.shade900);

    final carretPaintStyle = Paint()
    ..color=(_carretColor.withOpacity(_carretOpacity));
    final carretOffset = Offset(
      _carretCharIndex * _characterWidth,
      _carretLineIndex * _lineHeight);
    canvas.drawRect(
      carretOffset & Size(_carretWidth, _lineHeight),
      carretPaintStyle);

    canvas.restore();

  }
}

extension WordBoundryFinding on String {
  // abcd_
  // ^   ^
  (int,int) findWordBoundryForIndex(
    int index,
  ) {
    assert(index != 0);
    final chars = characters;
    assert(characters.elementAt(index) != " ");
    var leftBound = index;
    while (true) {
      if (leftBound == 0) break;
      final char = chars.elementAt(leftBound);
      if (char == " ") {
        leftBound += 1;
        break;
      }
      leftBound -= 1;
    }
    final limit = chars.length;
    var rightBound = index;
    while (true) {
      if (rightBound == limit) break;
      final char = chars.elementAt(rightBound);
      if (char == " ") {
        break;
      }
      rightBound += 1;
    }
    return (leftBound, rightBound);
  }
}
extension ItemDropping on String {
  String dropLastN(int count) {
    final chars = characters;
    final len = chars.length;
    if (count >= len) return "";
    final newLen = len - count;
    final res = chars.take(newLen).string;
    return res;
  }
}

extension CappedSubing on int {
  int cappedSub(int n) {
    if (n > this) return 0;
    return this - n;
  }
}


extension Trisplitting<T> on List<T> {
  (T, List<T>, T)? trisplit() {
    if (length < 2) return null;
    final first_ = first;
    if (length == 2) return (first_, [], last);
    final mid = sublist(1, length - 1);
    final tail = elementAt(length - 1);
    return (first, mid, tail);
  }
}