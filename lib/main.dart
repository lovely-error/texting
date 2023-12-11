import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';

late ui.Image _animeGirls;
Future<void> _loadAnimeGirlsImg() async {
  final img = await ui.ImageDescriptor.encoded(
    await ImmutableBuffer.fromAsset("images/anime2.jpeg"));
  final codec = await img.instantiateCodec();
  final nf = await codec.getNextFrame();
  _animeGirls = nf.image;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sb = ServicesBinding.instance;
  sb.requestPerformanceMode(ui.DartPerformanceMode.balanced);
  await _loadAnimeGirlsImg();
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
        body:  App() // MyAppIntermidiary()
      ),
    );
  }
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<StatefulWidget> createState() {
    return AppState();
  }
}
enum SelectedView {
  intro, folderview
}
class AppState extends State<App> {

  late Directory _dir;
  late String? _dirpath;
  bool hovered = false;
  String msg = "Drop a folder here, or click this button";
  SelectedView _selectedView = SelectedView.intro;

  void _getDir() async {
    _dirpath =  await getDirectoryPath();
  }
  void _openDir() {
    if (_dirpath == null) return;
    _dir = Directory(_dirpath!);
    _dir.exists().then((ok) {
      setState(() {
        if (ok) {
          _selectedView = SelectedView.folderview;
        } else {
          msg = "That wasnt a folder...   ~_~";
        }
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    switch (_selectedView) {
      case SelectedView.intro:
        return _introView;
      case SelectedView.folderview:
        return Stack(
          fit: StackFit.expand,
          children: [
            _bg,
            // _dirItemsView
            FolderStructureView(_dir)
          ]
        );
    }
  }
  Widget get _bg => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
    Colors.blueGrey.shade400,
    Colors.blueGrey.shade700
  ])));

  // Widget _dirItemView(
  //   FileSystemEntity fse
  // ) {
  //   String name = "";
  //   switch (fse) {
  //     case Directory dir:
  //       name = dir.path;
  //     case File file:
  //       name = file.path;
  //     case Link link:
  //       name = link.path;
  //   }
  //   return Row(children: [
  //     Text(name)
  //   ],);
  // }

  // Widget get _dirItemsView  => ListView(
  //   children:
  //   _dirContent.map(_dirItemView).toList(),
  // );

  Widget get _introView => DropTarget(
    onDragDone: (details) {
      if (details.files.length != 1) {
        setState(() {
          msg = "That wasnt a folder...   ~_~";
        });
        return;
      }
      _dirpath = details.files.first.path;
      _openDir();
    },
    child: Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        CustomPaint(painter: BGPaint(),),
        Center(child: MouseRegion(
          onEnter: (event) {
            setState(() {
              hovered = true;
            });
          },
          onExit: (event) {
            setState(() {
              hovered = false;
            });
          },
          child: GestureDetector(
            onTap: _getDir,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: hovered ? [
                    Colors.blueGrey.shade600,
                    Colors.blueGrey.shade900
                  ] : [
                    Colors.blueGrey.shade400,
                    Colors.blueGrey.shade700
                  ]
                ),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                boxShadow: const [
                  BoxShadow(spreadRadius: 20, blurRadius: 30, color: Colors.blueGrey)
                ],
                border: Border.all(color: Colors.blueGrey.shade900)
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.snippet_folder),
                    Text(
                      msg,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ))
      ],),
  );
}
class BGPaint extends CustomPainter {
  BGPaint() ;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawPaint(
      Paint()..shader=ui.Gradient.linear(
        Offset.zero, Offset(0, size.height), [
          Colors.blueGrey.shade300,
          Colors.blueGrey,
        ]));
    var w = _animeGirls.width.toDouble();
    double dx = 0;
    if (w > size.width) {
      dx = (w - size.width) / 2;
      w = size.width;
    }
    var h = _animeGirls.height.toDouble();
    double dy = 0;
    if (h > size.height) {
      dy = (h - size.height) / 2;
      h = size.height;
    }
    canvas.drawImageRect(
      _animeGirls,
      Offset(dx, dy) &
      Size(w, h),
      Offset.zero & size,
      Paint()
      // ..imageFilter=ui.ImageFilter.dilate(radiusX: 1,radiusY: 1)
      // ui.ImageFilter.compose(
      //   outer: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      //   inner: ui.ImageFilter.dilate(radiusX: 5,radiusY: 5)
      // )
      ..blendMode=BlendMode.colorDodge
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
class Box<T> {
  Box(this.value);
  T value;
}
sealed class SomeDirStructure {}
class FSItem extends SomeDirStructure {
  FSItem(this.item);
  FileSystemEntity item;
}
class OpenedFolder extends SomeDirStructure {
  OpenedFolder(this.items, this.directory);
  Directory directory;
  List<Box<SomeDirStructure>> items;
}
class FolderStructureView extends LeafRenderObjectWidget {
  const FolderStructureView(this._directory, {super.key});
  final Directory _directory;
  @override
  RenderObject createRenderObject(BuildContext context) {
    return FolderStructureViewImpl(_directory);
  }
}
class FolderStructureViewImpl extends RenderBox {
  FolderStructureViewImpl(this._directory) {
    final l = _directory.listSync().map((e) => Box(FSItem(e))).toList();
    _limit = l.length + 1;
    _dirStructure = Box(OpenedFolder(l, _directory));
    _textPainter.text = const TextSpan(text: " ");
    _textPainter.layout();
    _lineHeight = _textPainter.height;

    _keyboard.addHandler((e){
      _handleKey(e);
      return false;
    });
  }

  final Directory _directory;
  late Box<SomeDirStructure> _dirStructure;
  int _currentLine = 0;
  late int _limit;
  final HardwareKeyboard _keyboard = HardwareKeyboard.instance;
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr);
  late double _lineHeight;

  void _handleKey(KeyEvent ke) {
    switch (ke) {
      case KeyDownEvent kde:
        switch (kde.logicalKey) {
          case LogicalKeyboardKey.enter:
            _openUnderCursor(_currentLine, _dirStructure);
            break;
          case LogicalKeyboardKey.arrowDown:
            if (_currentLine + 1 == _limit) return;
            _currentLine += 1;
            break;
          case LogicalKeyboardKey.arrowUp:
            if (_currentLine == 0) return;
            _currentLine -= 1;
            break;
        }
        markNeedsPaint();
        break;
      case KeyRepeatEvent kre:
        switch (kre.logicalKey) {
          case LogicalKeyboardKey.arrowDown:
            if (_currentLine + 1 == _limit) return;
            _currentLine += 1;
            break;
          case LogicalKeyboardKey.arrowUp:
            if (_currentLine == 0) return;
            _currentLine -= 1;
            break;
        }
        markNeedsPaint();
        break;
      default:
        break;
    }
  }
  int? _openUnderCursor(
    int cursor,
    Box<SomeDirStructure> structure
  ) {
    switch (structure.value) {
      case FSItem item:
        switch (item.item) {
          case Directory dir:
            if (cursor != 0) return cursor;
            List<Box<SomeDirStructure>> moreItems =
              dir.listSync().map((i) => Box<SomeDirStructure>(FSItem(i))).toList();
            _limit += moreItems.length;
            structure.value = OpenedFolder(moreItems, dir);
            markNeedsPaint();
            return null;
          case File _:
          case Link _:
          default:
            return cursor;
        }
      case OpenedFolder items:
        var cursor_ = cursor;
        final iter = items.items.iterator;
        while (true) {
          if (cursor_ == 0) return null;
          final hasElem = iter.moveNext();
          if (!hasElem) { return cursor_; }
          var item_ = iter.current;
          final out = _openUnderCursor(cursor_ - 1, item_);
          if (out == null) return null;
          cursor_ = out;
        }
      default:
        return null;
    }
  }
  @override
  void performLayout() {
    final cons = constraints.normalize();
    size = Size(cons.maxWidth, cons.maxHeight);
  }
  @override
  void paint(PaintingContext context, ui.Offset offset) {

    context.canvas.drawRect(
      Offset(0, (_currentLine) * _lineHeight) &
      Size(size.width, _lineHeight),
      Paint()..color=Colors.blueGrey.shade900);

    var ln = 0;
    const off = 10.0;
    var xoff = 0.0;
    void drawComps(Box<SomeDirStructure> dirStructure) {
      switch (dirStructure.value) {
        case FSItem item:
          String name;
          if (item.item is Directory) {
            final ps = item.item.uri.pathSegments;
            name = ps[ps.length - 2];
            name = "$name/";
          } else {
            name = item.item.uri.pathSegments.last;
          }
          _textPainter.text = TextSpan(text: name);
          _textPainter.layout();
          _textPainter.paint(context.canvas, Offset(xoff, ln * _lineHeight));
          ln += 1;
          break;
        case OpenedFolder folder:
          _textPainter.text = TextSpan(text: folder.directory.path);
          _textPainter.layout();
          _textPainter.paint(context.canvas, Offset.zero);
          xoff += off;
          ln += 1;
          for (final item in folder.items) {
            drawComps(item);
          }
          xoff -= off;
      }
    }
    drawComps(_dirStructure);
  }
}

class MyAppIntermidiary extends StatefulWidget {
  const MyAppIntermidiary({super.key});
  @override
  State<StatefulWidget> createState() {
    return MyAppIntermidiaryState();
  }
}
class MyAppIntermidiaryState extends State<MyAppIntermidiary>
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
enum TextEditorViewItem {
  overtab
}
class TextEditorView
// extends SlottedMultiChildRenderObjectWidget<TextEditorViewItem, RenderBox>
extends LeafRenderObjectWidget
{
  const TextEditorView(this.vsyncer, {super.key});
  final TickerProvider vsyncer;

  final Widget k = const ColoredBox(color: Colors.black);

  @override
  // SlottedContainerRenderObjectMixin<TextEditorViewItem, RenderBox>
  RenderObject
  createRenderObject(BuildContext context) {
    return TextEditorViewImpl(vsyncer);
  }

  // @override
  // Widget? childForSlot(TextEditorViewItem slot) {
  //   switch (slot) {
  //     case TextEditorViewItem.overtab:
  //       return k;
  //   }
  // }

  // @override
  // Iterable<TextEditorViewItem> get slots => TextEditorViewItem.values;
}

final class SemanticError {
  SemanticError(this.lineNumber, this.message);

  int lineNumber;
  String message;
  bool fresh = true;
}

class TextEditorViewImpl extends RenderBox
// with SlottedContainerRenderObjectMixin<TextEditorViewItem, r.RenderPointerListener>
{
  TextEditorViewImpl(
    this._vsyncer,
    {
      bool carretShouldBlink = false
    }
  ) :
    _keyboard = HardwareKeyboard.instance,
    _carretShouldBlink = carretShouldBlink
  {

    _keyboard.addHandler((event) {
      handleKey(event);
      return false;
    });
    _textPainter.text = TextSpan(text: " ", style: _codeTextStyle);
    _textPainter.layout();
    _lineHeight = _textPainter.height;
    _characterWidth = _textPainter.width;

    _carretBlinkingAnimationController = AnimationController(
      vsync: _vsyncer,
      duration: const Duration(milliseconds: 200),
    );

    if (_carretShouldBlink) {
      activateCarretBlinking();
    }

    final rec = ui.PictureRecorder();
    final _ = Canvas(rec);
    _cachedTextLayer = rec.endRecording().toImageSync(1, 1);

    _errorSlideAnimationController = AnimationController(
      vsync: _vsyncer,
      duration: const Duration(milliseconds: 500));
    _errorSlideAnimation = CurvedAnimation(
      parent: _errorSlideAnimationController,
      curve: Curves.easeInOut);

    _paintErrSign();
  }


  late final Animation _errorSlideAnimation;
  final bool _carretShouldBlink;
  final double _textSize = 13.5;
  Offset _scrollOffset = Offset.zero;
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
  late final _codeTextStyle = TextStyle(
    color: Colors.black.withOpacity(0.7),
    fontSize: _textSize,
    fontFamily: fontFam
  );
  late final _invisiblesStyle = TextStyle(
    color: Colors.black26,
    fontSize: _textSize,
    fontFamily: fontFam
  );
  late final _errTextStyle = TextStyle(
    color: Colors.black87,
    fontSize: _textSize,
    fontFamily: fontFam,
    fontStyle: FontStyle.italic
  );
  final TickerProvider _vsyncer;
  late AnimationController _carretBlinkingAnimationController;
  late AnimationController _errorSlideAnimationController;
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
    ("\u000A", "\u2B92"),
    ("\u000B", "\u21A0")
  ];
  final String _jumpStoppers = " (){}.;=:_";
  late final Color _selectionBoxColor = _carretColor.withOpacity(0.1);
  final Radius _selectionBoxBorderRadius = const Radius.circular(3);
  late int _linesPerViewport;
  double _errShowProgress = 0;
  final List<SemanticError> _errors = [
    SemanticError(0, "Your code sucks!"),
    // SemanticError(2, "HUUUGE DICK!")
  ];
  final List<SemanticError> _visibleErrors = [];
  late final ui.Image _errSign;

  int get _currentLineCharLimit =>
    _lines[_carretLineIndex].characters.length;

  void _paintErrSign() {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    final p = Path();
    const w = 10.0;
    const h = 10.0 * 4;
    p.moveTo(0, 0); // tl
    p.lineTo(w, 0); // tr
    p.lineTo(w, h); // bl
    p.lineTo(0, h); // br
    p.lineTo(0, 0); // close
    const dist = 8;
    const smallH = 10.0;
    const h2 = h + dist;
    p.moveTo(0, h2); // tl
    p.lineTo(w, h2); // tr
    p.lineTo(w, h2 + smallH); // bl
    p.lineTo(0, h2 + smallH); // br
    p.lineTo(0, h2); // close

    const circleSize = ((h2 + smallH) / 2) + 10;
    canvas.drawCircle(
      const Offset(circleSize, circleSize),
      circleSize,
      Paint()..shader=ui.Gradient.linear(Offset.zero, const Offset(0, circleSize), [
        Colors.red.shade200, Colors.red.shade800
      ]));

    Paint paint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.0
    ..style = PaintingStyle.fill
    ..strokeJoin = StrokeJoin.round ;
    const dx = circleSize - w / 2;
    const dy = circleSize - (h2 + smallH) / 2;
    canvas.drawPath(p.shift(const Offset(dx, dy)), paint);

    final img = rec.endRecording().toImageSync(128, 128);
    _errSign = img;
  }
  (int, int) _viewLinePortRange() {
    final lineOff = (_scrollOffset.dy.abs() / _lineHeight).floor();
    return (lineOff, lineOff + _linesPerViewport);
  }
  @override
  bool hitTestSelf(ui.Offset position) {
    return true;
  }
  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry<HitTestTarget> entry) {
    assert(debugHandleEvent(event, entry));
    switch (event) {
      case PointerDownEvent pde:
        pointerDownForCarretMove(
          Offset(pde.localPosition.dx, pde.localPosition.dy - _scrollOffset.dy));
        break;
      case PointerScrollEvent pse:
        handlePointerScrollEvent(pse);
        break;
      default:
        return;
    }
  }
  void activateCarretBlinking() {
    final anim = CurvedAnimation(
      parent: _carretBlinkingAnimationController,
      curve: Curves.bounceInOut);
    anim.addListener(() {
      _carretOpacity = anim.value;
      markNeedsPaint();
    });
    _carretBlinkCycleTrigger ??= Timer.periodic(
      const Duration(seconds: 1, milliseconds: 500),
      (_) async {
        _carretBlinkingAnimationController.reset();
        await _carretBlinkingAnimationController.forward();
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
            _textPainter.text = TextSpan(text: subst, style: _invisiblesStyle);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _textPainter.text = TextSpan(text: char, style: _codeTextStyle);
        }
        _textPainter.layout();
        _textPainter.paint(canvasForText, Offset(dxOffset, lineNum * _lineHeight));
        dxOffset += _characterWidth;
      }
      if (lineNum != _lines.length - 1) {
        _textPainter.text = TextSpan(text: "$_newLineChar\n", style: _invisiblesStyle);
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
  void handlePointerScrollEvent(PointerSignalEvent pse) {
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
            _textPainter.text = TextSpan(text: subst, style: _invisiblesStyle);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _textPainter.text = TextSpan(text: char, style: _codeTextStyle);
        }
        _textPainter.layout();
        _textPainter.paint(canvas, Offset(dxOffset, lineNum * _lineHeight));
        dxOffset += _characterWidth;
      }
      if (lineNum != _lines.length - 1) {
        _textPainter.text = TextSpan(text: "$_newLineChar\n", style: _invisiblesStyle);
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
  void _errSlideValBumper() {
    _errShowProgress = _errorSlideAnimation.value;
    markNeedsPaint();
  }
  void _handleErrorDisplay() async {
    _visibleErrors.clear();
    final (lo, hi) = _viewLinePortRange();
    var runAnim = false;
    for (final err in _errors) {
      final ln = err.lineNumber;
      if (ln >= lo && ln <= hi) {
        _visibleErrors.add(err);
        runAnim |= err.fresh;
      }
    }
    _errShowProgress = 0;
    if (runAnim) {
      _errorSlideAnimation.addListener(_errSlideValBumper);
      _errorSlideAnimationController.reset();
      await _errorSlideAnimationController.forward();
      _errorSlideAnimation.removeListener(_errSlideValBumper);
      for (final ve in _visibleErrors) {
        ve.fresh = false;
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
        _handleErrorDisplay();
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
        _handleErrorDisplay();
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
    // background
    canvas.drawColor(
      _backgroundColor,
      BlendMode.src);
    // line hint box
    canvas.drawRect(
      Offset(0, _carretLineIndex * _lineHeight) &
      Size(size.width, _lineHeight),
      Paint()..color=_lineUnderColor);
    // text
    canvas.drawImage(
      _cachedTextLayer,
      Offset.zero,
      Paint());
    // selected text
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
    // err inline msg
    if (_visibleErrors.isNotEmpty) {
      for (final err in _visibleErrors) {
        double prog ;
        if (err.fresh) { prog = _errShowProgress; } else { prog = 1; }

        _textPainter.text = TextSpan(
          text: err.message,
          style: _errTextStyle.copyWith(color: _errTextStyle.color!.withOpacity(prog))
        );
        const errBoxTrailingPad = 20;
        final errSignWH = _lineHeight;
        const trailingErrSignPadding = 0.0;
        const leadingErrSignPadding = 5.0;
        final textOnLineLen =
          (_lines[err.lineNumber].characters.length + 1) * _characterWidth;
        final decorWidth =
          leadingErrSignPadding + errSignWH + trailingErrSignPadding + errBoxTrailingPad;
        final maxSpaceOnLineForErrMsg =
          size.width - textOnLineLen - decorWidth;
        _textPainter.layout(maxWidth: maxSpaceOnLineForErrMsg);
        final errBoxWidth =
          _textPainter.width + decorWidth;
        final errMsgBoxXOff = (size.width - errBoxWidth) + (errBoxWidth * (1 - prog));

        const corn = Radius.circular(5);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Offset(errMsgBoxXOff, err.lineNumber * _lineHeight) &
            Size(errBoxWidth, _lineHeight),
            topLeft: corn,
            bottomLeft: corn
          ),
          Paint()..color=Colors.red.shade300.withOpacity(prog)
        );
        canvas.drawImageRect(
          _errSign,
          Offset.zero &
          Size(_errSign.width.toDouble(), _errSign.height.toDouble()),
          Offset(
            errMsgBoxXOff + leadingErrSignPadding,
            (err.lineNumber * _lineHeight) + 3) &
          Size(errSignWH, errSignWH),
          Paint());
        final textXOff =
          errMsgBoxXOff + leadingErrSignPadding + errSignWH + trailingErrSignPadding;
        _textPainter.paint(
          canvas,
          Offset(
            textXOff,
            err.lineNumber * _lineHeight)
        );
      }
    }
    // end of text field
    canvas.drawRect(
      Offset(0, (_lines.length) * _lineHeight) &
      Size(size.width, 1),
      Paint()..color=Colors.blueGrey.shade900);
    // carret
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

extension Spliting on String {

}