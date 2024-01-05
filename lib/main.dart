import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as rpc;
import 'package:web_socket_channel/web_socket_channel.dart' as ws;

const lspPort = 13136;

late ui.Image _animeGirls ;
Future<void> _loadAnimeGirls() async {
  final img = await ui.ImageDescriptor.encoded(
    await ImmutableBuffer.fromAsset("images/anime2.jpeg"));
  final codec = await img.instantiateCodec();
  final nf = await codec.getNextFrame();
  _animeGirls = nf.image;
}
late rpc.Peer _lspConn;
late Stream<List<SemanticError>> _diagnosticsStream;
Future<void> _startPyLSP() async {
  await Process.start(
    "pylsp",
    ["--ws", "--port", "$lspPort"],
    mode: ProcessStartMode.detached
  );
  final ws_ = ws.WebSocketChannel.connect(Uri(
    scheme: "ws", host: "localhost", port: lspPort
  ));
  _lspConn = rpc.Peer(ws_.cast());
  final scontr = StreamController<List<SemanticError>>.broadcast();
  _diagnosticsStream = scontr.stream;
  _lspConn.registerMethod("textDocument/publishDiagnostics", (args){
    final args_ = (args as rpc.Parameters).asMap;
    List diags = args_["diagnostics"];
    if (diags.isEmpty) return;
    String filePath = args_["uri"];
    List<SemanticError> diagns = [];
    for (final item in diags) {
      SemanticErrorSeverity severity = SemanticErrorSeverity.warning;
      switch (item["severity"]) {
        case 1:
          severity = SemanticErrorSeverity.error;
          break;
        case 2:
          severity = SemanticErrorSeverity.warning;
          break;
        case 3:
          severity = SemanticErrorSeverity.warning;
          break;
        case 4:
          severity = SemanticErrorSeverity.warning;
          break;
        case int n:
          throw Exception("Unexpected severity number $n");
      }
      int line = item["range"]["start"]["line"];
      String msg = item["message"];
      diagns.add(SemanticError(line, msg, severity, filePath));
    }
    scontr.add(diagns);
  });
  _lspConn.listen();
  _lspConn.sendNotification("initialize", {
    "capabilities" : {
      // "workspace" : {
      //   "workspaceEdit" : {
      //     "documentChanges" : true
      //   },
      //   "didChangeConfiguration" : {
      //     "dynamicRegistration" : true
      //   }
      // },
      "textDocument" : {
        "completion" : {},
        // "colorProvider" : {
        // },
        "syncronization" : {
          "dynamicRegistration" : true
        },
        "diagnostic" : {},
      }
    }
  });
}


void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final sb = ServicesBinding.instance;
  sb.requestPerformanceMode(ui.DartPerformanceMode.balanced);
  await Future.wait([
    _loadAnimeGirls(),
    _startPyLSP()
  ]);
  Uri? folderPath;
  try {
    final path = args.firstOrNull;
    if (path != null) {
      folderPath = Uri.parse(path);
    }
  } catch (err) {
    stderr.write(err.toString());
    return;
  }
  if (folderPath != null) {
    final p = Directory(folderPath.path);
    if (!await p.exists()) {
      stderr.write("cant open $folderPath as folder");
      return;
    }
    runApp(FolderStructureView(p));
  } else {
    runApp(const MyApp());
  }
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
class AppState extends State<App> with TickerProviderStateMixin {

  late Directory _dir;
  late String? _dirpath;
  bool hovered = false;
  String msg = "Drop a folder here, or click this button";
  SelectedView _selectedView = SelectedView.intro;

  void _getDir() async {
    _dirpath =  await getDirectoryPath();
    _openDir();
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
            FolderStructureViewInter(_dir, this)
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
  void paint(ui.Canvas canvas, ui.Size size) async {
    canvas.drawPaint(
      Paint()..shader=ui.Gradient.linear(
        Offset.zero, Offset(0, size.height), [
          Colors.blueGrey.shade300,
          Colors.blueGrey,
        ]));
    final animeGirls = _animeGirls;
    var w = animeGirls.width.toDouble();
    double dx = 0;
    if (w > size.width) {
      dx = (w - size.width) / 2;
      w = size.width;
    }
    var h = animeGirls.height.toDouble();
    double dy = 0;
    if (h > size.height) {
      dy = (h - size.height) / 2;
      h = size.height;
    }
    canvas.drawImageRect(
      animeGirls,
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
class FolderStructureView extends StatefulWidget {
  const FolderStructureView(this._directory, {super.key});
  final Directory _directory;
  @override
  State<StatefulWidget> createState() {
    return FolderStructureViewState();
  }
}
class FolderStructureViewState
extends State<FolderStructureView>
with TickerProviderStateMixin {
  FolderStructureViewState();

  @override
  Widget build(BuildContext context) {
    return FolderStructureViewInter(widget._directory, this);
  }
}
class FolderStructureViewInter extends LeafRenderObjectWidget {
  const FolderStructureViewInter(this._directory, this._tickerProvider, {super.key});
  final Directory _directory;
  final TickerProvider _tickerProvider;
  @override
  RenderObject createRenderObject(BuildContext context) {
    return FolderStructureViewImpl(_directory, _tickerProvider);
  }
}

class FolderStructureViewImpl extends RenderBox {

  FolderStructureViewImpl(
    this._directory,
    this._tickerProvider
  ) {
    final l = _directory.listSync().map((e) => Box<SomeDirStructure>(FSItem(e))).toList();
    _limit = l.length + 1;
    _dirStructure = Box(OpenedFolder(l, _directory));
    _textPainter.text = TextSpan(text: " ", style: TextStyle(fontSize: _textSize));
    _textPainter.layout();
    _lineHeight = _textPainter.height;

    _keyboard.addHandler((e){
      _handleKey(e);
      return false;
    });
  }

  final TickerProvider _tickerProvider;
  final Directory _directory;
  late Box<SomeDirStructure> _dirStructure;
  int _currentLine = 0;
  late int _limit;
  final HardwareKeyboard _keyboard = HardwareKeyboard.instance;
  final TextPainter _textPainter = TextPainter(textDirection: TextDirection.ltr);
  late double _lineHeight;
  final Color _folderColor = Colors.pink;
  final double _textSize = 20;
  late int _linesPerViewPort ;
  double _verticalScrollOffset = 0;
  bool _inFocus = true;


  TextEditorViewImpl? _textEditorViewImpl ;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_inFocus) return;
    switch (event) {
      case PointerScrollEvent pse:
        handlePointerScrollEvent(pse);
    }
    super.handleEvent(event, entry);
  }
  @override
  bool hitTestChildren(BoxHitTestResult result, {required ui.Offset position}) {
    if (_textEditorViewImpl != null) {
      result.add(BoxHitTestEntry(_textEditorViewImpl!, position));
      return true;
    } else {
      return false;
    }
  }
  void closeTextView() {
    if (_textEditorViewImpl != null) {
      dropChild(_textEditorViewImpl!);
    }
    _textEditorViewImpl = null;
    _inFocus = true;
  }
  void handlePointerScrollEvent(PointerScrollEvent pse) {
    final off = pse.scrollDelta;
    if (_limit * _lineHeight > size.height) {
      _verticalScrollOffset += off.dy;
      if (_verticalScrollOffset > 0) {
        _verticalScrollOffset = 0;
      }
      if (_verticalScrollOffset.abs() >= _limit * _lineHeight) {
        _verticalScrollOffset = _verticalScrollOffset - pse.scrollDelta.dy;
      }
    }
    markNeedsPaint();
  }
  void _handleKey(KeyEvent ke) {
    if (!_inFocus) return;
    switch (ke) {
      case KeyDownEvent kde:
        switch (kde.logicalKey) {
          case LogicalKeyboardKey.enter:
            _openUnderCursor(_currentLine, _dirStructure);
            break;
          case LogicalKeyboardKey.arrowDown:
            if (_currentLine + 1 == _limit) return;
            _currentLine += 1;
            final offset = (_verticalScrollOffset.abs() / _lineHeight).floor();
            final ln = (_currentLine - offset) % _linesPerViewPort;
            if (ln == 0) {
              _verticalScrollOffset = _verticalScrollOffset - _lineHeight;
            }
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowUp:
            if (_currentLine == 0) return;
            _currentLine -= 1;
            final offset = (_verticalScrollOffset.abs() / _lineHeight).floor();
            if (offset != 0) {
              final ln = (_currentLine - offset) % _linesPerViewPort;
              if (ln == 0) {
                _verticalScrollOffset = _verticalScrollOffset + _lineHeight;
              }
            }
            markNeedsPaint();
            break;
        }
        break;
      case KeyRepeatEvent kre:
        switch (kre.logicalKey) {
          case LogicalKeyboardKey.arrowDown:
            if (_currentLine + 1 == _limit) return;
            _currentLine += 1;
            final offset = (_verticalScrollOffset.abs() / _lineHeight).floor();
            final ln = (_currentLine - offset) % _linesPerViewPort;
            if (ln == 0) {
              _verticalScrollOffset = _verticalScrollOffset - _lineHeight;
            }
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowUp:
            if (_currentLine == 0) return;
            _currentLine -= 1;
            final offset = (_verticalScrollOffset.abs() / _lineHeight).floor();
            if (offset != 0) {
              final ln = (_currentLine - offset) % _linesPerViewPort;
              if (ln == 0) {
                _verticalScrollOffset = _verticalScrollOffset + _lineHeight;
              }
            }
            markNeedsPaint();
            break;
        }
        markNeedsPaint();
        break;
      default:
        break;
    }
  }
  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_textEditorViewImpl != null) {
      visitor(_textEditorViewImpl!);
    }
  }
  void _openTextFile(
    File file
  ) {
    _inFocus = false;
    _textEditorViewImpl = TextEditorViewImpl(
      _tickerProvider,
      this,
      assocciatedFile: file
    );
    // _textEditorViewImpl!.layout(constraints);
    adoptChild(_textEditorViewImpl!);
    markNeedsPaint();
  }
  int? _openUnderCursor(
    int cursor,
    Box<SomeDirStructure> structure
  ) {
    switch (structure.value) {
      case FSItem item:
        if (cursor != 0) return cursor;
        switch (item.item) {
          case Directory dir:
            final moreItems =
              dir.listSync().map((i) => Box<SomeDirStructure>(FSItem(i))).toList();
            _limit += moreItems.length;
            structure.value = OpenedFolder(moreItems, dir);
            markNeedsPaint();
            return null;
          case File file:
            _openTextFile(file);
            return null;
          case Link _:
          default:
            return cursor;
        }
      case OpenedFolder items:
        var cursor_ = cursor;
        if (cursor_ == 0) {
          structure.value = FSItem(items.directory);
          _limit -= items.items.length;
          markNeedsPaint();
          return null;
        }
        final iter = items.items.iterator;
        while (true) {
          final hasElem = iter.moveNext();
          if (!hasElem) { return cursor_; }
          var item_ = iter.current;
          final out = _openUnderCursor(cursor_ - 1, item_);
          if (out == null) return null;
          cursor_ = out;
        }
    }
  }
  @override
  void performLayout() {
    final cons = constraints.normalize();
    size = Size(cons.maxWidth, cons.maxHeight);
    _linesPerViewPort = (size.height / _lineHeight).floor();
    _textEditorViewImpl?.layout(constraints);
  }
  @override
  void paint(PaintingContext context, ui.Offset offset) {

    if (_textEditorViewImpl != null) {
      context.paintChild(_textEditorViewImpl!, Offset.zero);
      return;
    }

    context.canvas.drawPaint(
      Paint()..shader=ui.Gradient.linear(
        Offset.zero, Offset(0, size.height), [
          Colors.blueGrey.shade300,
          Colors.blueGrey,
        ]));
    final animeGirls = _animeGirls;
    var w = animeGirls.width.toDouble();
    double dx = 0;
    if (w > size.width) {
      dx = (w - size.width) / 2;
      w = size.width;
    }
    var h = animeGirls.height.toDouble();
    double dy = 0;
    if (h > size.height) {
      dy = (h - size.height) / 2;
      h = size.height;
    }
    context.canvas.drawImageRect(
      animeGirls,
      Offset(dx, dy) &
      Size(w, h),
      Offset.zero & size,
      Paint()
      ..imageFilter=ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10)
      ..blendMode=BlendMode.colorBurn
    );

    context.canvas.translate(0, _verticalScrollOffset);

    // folder selection
    context.canvas.drawRect(
      Offset(0, (_currentLine) * _lineHeight) &
      Size(size.width, _lineHeight),
      Paint()..color=Colors.blueGrey.shade800);

    // fs items
    var ln = 0;
    const off = 15.0;
    var xoff = 0.0;
    void drawComps(Box<SomeDirStructure> dirStructure) {
      String name;
      var ts = TextStyle(fontSize: _textSize);
      switch (dirStructure.value) {
        case FSItem item:
          if (item.item is Directory) {
            final ps = item.item.uri.pathSegments;
            name = ps[ps.length - 2];
            name = "$name/";
            ts = TextStyle(color: _folderColor, fontSize: _textSize);
          } else {
            name = item.item.uri.pathSegments.last;
          }
          _textPainter.text = TextSpan(text: name, style: ts);
          _textPainter.layout();
          _textPainter.paint(context.canvas, Offset(xoff, ln * _lineHeight));
          ln += 1;
          break;
        case OpenedFolder folder:
          ts = TextStyle(color: _folderColor, fontSize: _textSize);
          final ps = folder.directory.uri.pathSegments;
          name = ps[ps.length - 2];
          name = "$name/";
          _textPainter.text = TextSpan(text: name, style: ts);
          _textPainter.layout();
          _textPainter.paint(context.canvas, Offset(xoff, ln * _lineHeight));
          xoff += off;
          ln += 1;
          for (final item in folder.items) {
            context.canvas.drawLine(
              Offset(xoff - off, ln * _lineHeight),
              Offset(xoff - off, (ln + 1) * _lineHeight),
              Paint()..color=_folderColor);
            drawComps(item);
          }
          xoff -= off;
      }
    }
    drawComps(_dirStructure);

    context.canvas.restore();
  }
}
class HintBox extends RenderBox {
  HintBox(this._parent, this._textPainter, this._selection) {
    _selection.addListener(markNeedsPaint);
  }
  @override
  void dispose() {
    _selection.removeListener(markNeedsPaint);
    super.dispose();
  }

  final TextEditorViewImpl _parent;
  final TextPainter _textPainter;
  final Observed<int> _selection;

  @override
  void performLayout() {
    var width = 0.0;
    var height = 0.0;
    for (final line in _parent._filteredMatches) {
      _textPainter.text = TextSpan(text: line, style: _parent._codeTextStyle);
      _textPainter.layout();
      if (_textPainter.width > width) { width = _textPainter.width; }
      height += _parent._lineHeight;
    }
    size = Size(width, height);
  }
  @override
  void paint(PaintingContext context, ui.Offset offset) {
    final lnh = _parent._lineHeight;
    final relevantItems = _parent._filteredMatches;
    // if (relevantItems.isEmpty) return;
    // bg
    context.canvas.drawRect(
      Offset.zero &
      Size(size.width, size.height),
      Paint()..color=Colors.blueGrey.shade600);
    // selection line
    context.canvas.drawRect(
      Offset(0, lnh * _selection.value) &
      Size(size.width, lnh),
      Paint()..color=Colors.deepPurple);
    final len = _parent._prefix.characters.length;
    var ln = 0;
    for (final line in relevantItems) {
      final left = TextSpan(
        text: line.substring(0, len),
        style: _parent._codeTextStyle.copyWith(color: Colors.grey));
      _textPainter.text = left;
      _textPainter.layout();
      _textPainter.paint(context.canvas, Offset(0, lnh * ln));
      final right = TextSpan(
        text: line.substring(len),
        style: _parent._codeTextStyle);
      _textPainter.text = right;
      _textPainter.layout();
      _textPainter.paint(
        context.canvas,
        Offset(len * _parent._characterWidth, lnh * ln));
      ln += 1;
    }
  }
}
class TextEditInfo {
  TextEditInfo(this.start, this.end, this.newText);
  (int, int) start;
  (int, int) end;
  String newText;
}
enum SemanticErrorSeverity {
  error, warning
}
final class SemanticError {
  SemanticError(this.lineNumber, this.message, this.severity, this.path);

  int lineNumber;
  String message;
  bool fresh = true;
  SemanticErrorSeverity severity;
  String path;
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
class Observed<T> extends ChangeNotifier {
  Observed(this.value_);
  T value_;
  set value(T newVal) {
    value_ = newVal;
    notifyListeners();
  }
  T get value => value_;
  void withValueInspection(T? Function(T) action) {
    final val = action(value_);
    if (val != null) {
      value = val;
      notifyListeners();
    }
  }
}
class Line {
  Line(this.text);
  String text;
  Box<SemanticError?> error = Box(null);
}
class Memoised<T> {
  Memoised(this.computation);
  T Function() computation;
  T? _cachedValue;
  T get value => _cachedValue ??= computation();
  void invalidate() { _cachedValue = null; }
}
class TextEditorViewImpl extends RenderBox {
  TextEditorViewImpl(
    this._vsyncer,
    this._parent,
    {
      required File assocciatedFile,

      bool carretShouldBlink = false,
    }
  ) :
    _keyboard = HardwareKeyboard.instance,
    _carretShouldBlink = carretShouldBlink,
    _actualFile = assocciatedFile
  {

    _keyboard.addHandler((event) {
      _respondToKeyPress(event);
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
      _activateCarretBlinking();
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
    _errorSlideAnimation.addListener(markNeedsPaint);

    _prepareErrSign();

    // final lines = assocciatedFile.openRead()
    // .transform(utf8.decoder)
    // .transform(const LineSplitter());
    assocciatedFile.readAsLines().then((lines) async {
      if (lines.isEmpty) {
        return;
      }
      _lines = lines.map((e) => Line(e)).toList();
      _lspConn.sendNotification("textDocument/didOpen", {
        "textDocument" : {
          "uri" : assocciatedFile.path,
          "languageId" : "python",
          "version" : _salt,
          "text" : lines.join(Platform.lineTerminator) // :(
        }
      });
      markNeedsPaint();
    }).then((_) {
      var salt = _salt;
      _periodicSyncer = Timer.periodic(Duration(seconds: _syncPeriodSecs), ((_) {
        final currentSalt = _salt;
        if (currentSalt == salt || _completions != null) return;
        salt = currentSalt;
        _syncChanges();
      }));
    });
    _diagnosticsStream.listen((batch) async {
      for (final oldErrBox in _errors) {
        oldErrBox.value = null;
      }
      _errors.clear();
      for (final newErr in batch) {
        final box = _lines[newErr.lineNumber].error;
        box.value = newErr;
        _errors.add(box);
      }
      _visibleLines.invalidate();
      await _displayErrs();
    });
  }

  final List<Box<SemanticError?>> _errors = [];
  final Color _errBoxColor = Colors.red.shade300;
  final Color _warnBoxColor = Colors.amber;
  int _salt = 0;
  late final Timer _periodicSyncer;
  final int _syncPeriodSecs = 3;
  final File _actualFile;
  FileSystemException? _exception;
  final FolderStructureViewImpl _parent;
  late final Animation _errorSlideAnimation;
  final bool _carretShouldBlink;
  final double _textSize = 14;
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
  List<Line> _lines = [Line("")];
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
  final String _newLineCharSubst = "⮧";
  final List<(String, String)> _invisibles = [
    ("\u0020", "•"),
    ("\u000A", "\u2B92"),
    ("\u000B", "\u21A0")
  ];
  final String _jumpStoppers = " (){}.;=:_";
  late final Color _selectionBoxColor = _carretColor.withOpacity(0.1);
  final Radius _selectionBoxBorderRadius = const Radius.circular(3);
  late int _linesPerViewport;
  late final Memoised<(List<Line>, int)> _visibleLines =
    Memoised(_getLinesInViewport);
  late final ui.Image _errSign;
  List<String>? _completions;
  final Observed<int> _compSelection = Observed(0);
  HintBox? _hintBox;
  late int _completionsAnchorCharPoint;
  final List<Line> _updates = [];


  String get _textOnCurrentLine => _lines[_carretLineIndex].text;
  int get _currentLineCharLimit =>
    _lines[_carretLineIndex].text.characters.length;
  String get _prefix => _textOnCurrentLine.laxSubstring(
    _completionsAnchorCharPoint,
    _carretCharIndex);
  List<String> get _filteredMatches =>
    _completions!.filterIn((p0) => _prefix.matchAsPrefix(p0) != null);


  void _syncSpanUpdate(int startLine, int span) {

  }
  void _syncEraseUpdate(int startLine, int span) {

  }
  void _markCurrentLineAsStale() {
    final currentLine = _lines[_carretLineIndex];
    final alreadyThere = _updates.any((e) => e.text == currentLine.text);
    if (alreadyThere) return;
    _updates.add(currentLine);
  }
  void _dismissErrOnThisLine() {
    _lines[_carretLineIndex].error.value = null;
  }
  (List<Line>, int) _getLinesInViewport() {
    final (lo, hi) = _viewLinePortRange();
    final lines = _lines.sublist(lo, hi);
    return (lines, lo);
  }
  Future<void> _displayErrs() async {
    final lines = _visibleLines.value.$1;
    final runErrSlideAnim = lines.any((e) => e.error.value?.fresh ?? false);
    if (runErrSlideAnim) {
      _errorSlideAnimationController.reset();
      await _errorSlideAnimationController.forward();
      for (final lines in lines) {
        lines.error.value?.fresh = false;
      }
    }
  }
  void _syncChanges() async {
    _lspConn.sendNotification("textDocument/didChange", {
      "textDocument" : {
        "version" : _salt,
        "uri" : _actualFile.path
      },
      "contentChanges" : [
        { "text" : _lines.map((e) => e.text).join(Platform.lineTerminator) }
      ]
    });
  }
  void _changeSalt() {
    _salt += 1;
  }
  String _reedAllText() {
    return _lines.map((e) => e.text).join(Platform.lineTerminator);
  }
  void _closeSelf() async {
    final text = _reedAllText();
    await _actualFile.writeAsString(text);
    _lspConn.sendNotification("textDocument/didClose", {
      "textDocument" : {
        "uri" : _actualFile.uri.path
      }
    });
    _parent.closeTextView();
  }
  void _prepareErrSign() {
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
    return (lineOff, math.min(lineOff + _linesPerViewport, lineOff + _lines.length));
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
        _pointerDownForCarretMove(
          Offset(pde.localPosition.dx, pde.localPosition.dy - _scrollOffset.dy));
        break;
      case PointerScrollEvent pse:
        _handlePointerScrollEvent(pse);
        break;
      default:
        return;
    }
  }
  void _activateCarretBlinking() {
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
  @override
  void visitChildren(RenderObjectVisitor visitor) {
    if (_hintBox != null) {
      visitor(_hintBox!);
    }
  }
  void _insertCompletion() {
    final line = _lines[_carretLineIndex];
    final str = line.text;
    final left = str.laxSubstring(0, _completionsAnchorCharPoint);
    final (_,r) = _textOnCurrentLine.findWordBoundryForIndex(
      _carretCharIndex, _jumpStoppers);
    final right = str.laxSubstring(r);
    final comp = _filteredMatches[_compSelection.value];
    line.text = left + comp + right;
    _carretCharIndex = _completionsAnchorCharPoint + comp.characters.length;
    _closeCompletionsBox();
    _dismissErrOnThisLine();
  }
  @override
  void dispose() {
    _carretBlinkCycleTrigger?.cancel();
    _periodicSyncer.cancel();

    super.dispose();
  }
  void _handlePointerScrollEvent(PointerSignalEvent pse) {
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
  void _pointerDownForCarretMove(
    Offset position
  ) {
    _closeCompletionsBox();
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
  void _cancelSelectionMode() {
    _selectionModeData = null;
  }
  void _respondToKeyPress(KeyEvent ke) async {
    switch (ke) {
      case KeyRepeatEvent kre:
        switch (kre.logicalKey) {
          case LogicalKeyboardKey.arrowLeft:
            _closeCompletionsBox();
            _moveCarret(CarretMoveDirection.left);
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowRight:
            _closeCompletionsBox();
            _moveCarret(CarretMoveDirection.right);
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowUp:
            if (_completions != null) {
              _compSelection.withValueInspection((p0) {
                if (p0 == 0) return null;
                return p0 - 1;
              });
            } else {
              _closeCompletionsBox();
              _moveCarret(CarretMoveDirection.up);
            }
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.arrowDown:
            if (_completions != null) {
              _compSelection.withValueInspection((p0) {
                if (p0 + 1 == _filteredMatches.length) return null;
                return p0 + 1;
              });
            } else {
              _closeCompletionsBox();
              _moveCarret(CarretMoveDirection.down);
            }
            markNeedsPaint();
            break;
          case LogicalKeyboardKey.backspace:
            if (_selectionModeData != null) {
              _eraseSelection();
              _visibleLines.invalidate();
            } else {
              _eraseChar();
              _dismissErrOnThisLine();
              if (_completions != null) {
                if (_completionsAnchorCharPoint > _carretCharIndex) {
                  _compSelection.value_ = 0;
                  _closeCompletionsBox();
                }
              }
            }
            markNeedsPaint();
            break;
          default:
            break;
        }
        return;
      case KeyDownEvent kde:
        switch (kde.logicalKey) {
          case LogicalKeyboardKey.escape:
            _closeCompletionsBox();
            _closeSelf();
            return;
          case LogicalKeyboardKey.arrowLeft:
            _completions = null;
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
              if (_controlKeyboardKeyActive) {
                final next = _findClosestStopIndex(WordJumpDirection.left);
                _carretCharIndex = next;
                markNeedsPaint();
              } else {
                _moveCarret(CarretMoveDirection.left);
                markNeedsPaint();
              }
            } else if (_controlKeyboardKeyActive) {
              _cancelSelectionMode();
              final next = _findClosestStopIndex(WordJumpDirection.left);
              _carretCharIndex = next;
              markNeedsPaint();
            } else {
              _cancelSelectionMode();
              _moveCarret(CarretMoveDirection.left);
              markNeedsPaint();
            }
            return;
          case LogicalKeyboardKey.arrowRight:
            _closeCompletionsBox();
            if (_shiftKeyboardKeyActive) {
              if (_controlKeyboardKeyActive) {
                final next = _findClosestStopIndex(WordJumpDirection.right);
                _selectionModeData ??= (_carretCharIndex,_carretLineIndex);
                _carretCharIndex = next;
                markNeedsPaint();
              } else {
                _moveCarret(CarretMoveDirection.right);
                markNeedsPaint();
              }
            } else if (_controlKeyboardKeyActive) {
              _cancelSelectionMode();
              final next = _findClosestStopIndex(WordJumpDirection.right);
              _carretCharIndex = next;
              markNeedsPaint();
            } else {
              _cancelSelectionMode();
              _moveCarret(CarretMoveDirection.right);
              markNeedsPaint();
            }
            return;
          case LogicalKeyboardKey.arrowUp:
            if (_completions != null) {
              _compSelection.withValueInspection((p0) {
                if (p0 == 0) return null;
                return p0 - 1;
              });
            } else {
              _closeCompletionsBox();
              if (_shiftKeyboardKeyActive) {
                _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
              } else {
                _cancelSelectionMode();
              }
              _moveCarret(CarretMoveDirection.up);
            }
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.arrowDown:
            if (_completions != null) {
              _compSelection.withValueInspection((p0) {
                if (p0 + 1 == _filteredMatches.length) return null;
                return p0 + 1;
              });
            } else {
              _closeCompletionsBox();
              if (_shiftKeyboardKeyActive) {
                _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
              } else {
                _cancelSelectionMode();
              }
              _moveCarret(CarretMoveDirection.down);
            }
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.home:
            _closeCompletionsBox();
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
            } else {
              _cancelSelectionMode();
            }
            _carretCharIndex = 0;
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.end:
            _closeCompletionsBox();
            if (_shiftKeyboardKeyActive) {
              _selectionModeData ??= (_carretCharIndex, _carretLineIndex);
            } else {
              _cancelSelectionMode();
            }
            _carretCharIndex = _currentLineCharLimit;
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.controlLeft:
            _controlKeyboardKeyActive = true;
            return;
          case LogicalKeyboardKey.enter:
            if (_completions != null) {
              _insertCompletion();
            } else {
              _closeCompletionsBox();
              _dismissErrOnThisLine();
              _moveToNextLine();
              _visibleLines.invalidate();
            }
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.shiftLeft:
            _shiftKeyboardKeyActive = true;
            return;
          case LogicalKeyboardKey.space:
            if (_controlKeyboardKeyActive) {
              if (_completions != null) {
                _closeCompletionsBox();
                _dismissErrOnThisLine();
              } else {
                _askCompletions();
              }
            } else {
              _closeCompletionsBox();
              _dismissErrOnThisLine();
              if (_selectionModeData != null) {
                _eraseSelection();
              }
              _carretCharIndex += 1;
              _insertChar(" ");
              // _updateTextCache(delSpan.$1, 1, delSpan.$2);
              _visibleLines.invalidate();
              markNeedsPaint();
            }
            return;
          case LogicalKeyboardKey.backspace:
            if (_selectionModeData != null) {
              _eraseSelection();
              // _updateTextCache(delSpan.$1, 1, delSpan.$2);
              _visibleLines.invalidate();
            } else if (_controlKeyboardKeyActive) {
              _closeCompletionsBox();
              _markCurrentLineAsStale();
              _dismissErrOnThisLine();
              _cancelSelectionMode();
              _eraseToLeftMostWord();
            } else {
              _eraseChar();
              if (_completions != null) {
                if (_completionsAnchorCharPoint > _carretCharIndex) {
                  _compSelection.value_ = 0;
                  _closeCompletionsBox();
                }
              } else {
                _dismissErrOnThisLine();
              }
            }
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.keyA when _controlKeyboardKeyActive:
            _closeCompletionsBox();
            _selectAllText();
            markNeedsPaint();
            return;
          case LogicalKeyboardKey.keyC
          when _controlKeyboardKeyActive && _selectionModeData != null:
            _closeCompletionsBox();
            final sel = _getSelectedText();
            Clipboard.setData(ClipboardData(text: sel));
            return;
          case LogicalKeyboardKey.keyV
          when _controlKeyboardKeyActive && !_pasteProceeding:
            _closeCompletionsBox();
            _pasteProceeding = true;
            final str = await _getMostRecentDataFromPasteboard();
            if (str != null) {
              if (_selectionModeData != null) {
                _eraseSelection();
              }
              _insertText(str);
              _visibleLines.invalidate();
              markNeedsPaint();
            }
            _pasteProceeding = false;
            return;
          default:
            final v = kde.character;
            if (v == null) return;
            if (_selectionModeData != null) {
              _eraseSelection();
            }
            _markCurrentLineAsStale();
            _dismissErrOnThisLine();
            _carretCharIndex += 1;
            _insertChar(v);
            _compSelection.value_ = 0;
            _hintBox?.layout(const BoxConstraints());
            // _updateTextCache(delSpan.$1, 1, delSpan.$2);
            _visibleLines.invalidate();
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
  void _askCompletions() async {
    final resp = await _lspConn.sendRequest("textDocument/completion", {
      "textDocument" : {
        "uri" : _actualFile.path
      },
      "position" : {
        "line" : _carretLineIndex,
        "character" : _carretCharIndex
      },
    });
    List<String> items =
      (resp["items"] as List).map((e) => e["insertText"] as String).toList();
    if (items.isEmpty) return;
    var ci = _carretCharIndex;
    _completions = items;
    final (l, _) = _textOnCurrentLine.findWordBoundryForIndex(ci, _jumpStoppers);
    _completionsAnchorCharPoint = l;
    _hintBox = HintBox(this, _textPainter, _compSelection);
    _hintBox!.layout(const BoxConstraints());
    adoptChild(_hintBox!);
    markNeedsPaint();
  }
  void _closeCompletionsBox() {
    if (_hintBox != null) {
      _completions = null;
      dropChild(_hintBox!);
      _hintBox = null;
      _compSelection.value_ = 0;
    }
  }
  void _selectAllText() {
    _selectionModeData = (0,0);
    _carretLineIndex = _lines.length.cappedSub(1);
    _carretCharIndex = _currentLineCharLimit;
  }
  void _moveToNextLine() {
    final str = _lines[_carretLineIndex];
    final retained = str.text.substring(0, _carretCharIndex);
    _lines[_carretLineIndex] = Line(retained);
    final slided = str.text.substring(_carretCharIndex);
    _lines.insert(_carretLineIndex + 1, Line(slided));
    _visibleLines.invalidate();
    // _updateTextCache(_carretLineIndex, 2, 0);
    markNeedsPaint();
  }
  String _getSelectedText() {
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
      final cs = str.text.substring(b,e);
      return cs;
    } else {
      final first = _lines[lo.$2].text.substring(lo.$1);
      final last = _lines[hi.$2].text.substring(0, hi.$1);
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
  (int, int) _insertText(String text) {
    assert(_selectionModeData == null);
    _changeSalt();
    var lines = text.split("\n");
    final str = _lines[_carretLineIndex];
    final left = str.text.substring(0, _carretCharIndex);
    final right = str.text.substring(_carretCharIndex);
    final split = lines.trisplit();
    if (split == null) {
      final res = left + text + right;
      _lines[_carretLineIndex] = Line(res);
    } else {
      final (f, m, l) = split;
      _lines[_carretLineIndex] = Line(left + f);
      _lines.insert(_carretLineIndex + 1, Line(l + right));
      for (final line in m.reversed) {
        _lines.insert(_carretLineIndex + 1, Line(line));
      }
    }
    _visibleLines.invalidate();
    final span = lines.length;
    _syncSpanUpdate(_carretLineIndex, span);
    return (_carretLineIndex, span);
  }
  // void _updateTextCache(
  //   int startLine,
  //   int updateSpan,
  //   int deleteSpan
  // ) {
  //   assert(updateSpan > 0);
  //   final rec = ui.PictureRecorder();
  //   final canvas = Canvas(rec);
  //   final oldTextLayerWidth = _cachedTextLayer.width.toDouble();
  //   final firstPatch =
  //     const Offset(0,0) &
  //     Size(oldTextLayerWidth, startLine * _lineHeight);
  //   canvas.drawImageRect(
  //     _cachedTextLayer,
  //     firstPatch,
  //     firstPatch,
  //     Paint()
  //   );
  //   final spread = startLine + updateSpan;
  //   final newLines = _lines.sublist(startLine, spread);
  //   var lineNum = startLine;
  //   var widestLine = .0;
  //   for (final line in newLines) {
  //     final chars = line.text.characters;
  //     final currentLineWidth = (chars.length + 1) * _characterWidth;
  //     if (currentLineWidth > widestLine) {
  //       widestLine = currentLineWidth;
  //     }
  //     var dxOffset = .0;
  //     for (final char in chars) {
  //       var matched = false;
  //       for (final (invch, subst) in _invisibles) {
  //         if (invch == char) {
  //           _textPainter.text = TextSpan(text: subst, style: _invisiblesStyle);
  //           matched = true;
  //           break;
  //         }
  //       }
  //       if (!matched) {
  //         _textPainter.text = TextSpan(text: char, style: _codeTextStyle);
  //       }
  //       _textPainter.layout();
  //       _textPainter.paint(canvas, Offset(dxOffset, lineNum * _lineHeight));
  //       dxOffset += _characterWidth;
  //     }
  //     if (lineNum != _lines.length - 1) {
  //       _textPainter.text = TextSpan(text: "$_newLineCharSubst\n", style: _invisiblesStyle);
  //       _textPainter.layout();
  //       _textPainter.paint(canvas, Offset(dxOffset, lineNum * _lineHeight));
  //     }
  //     lineNum += 1;
  //   }
  //   final sph = _cachedTextLayer.height - startLine * _lineHeight;
  //   canvas.drawImageRect(
  //     _cachedTextLayer,
  //     Offset(0, (startLine + 1 + deleteSpan) * _lineHeight) &
  //     Size(oldTextLayerWidth, sph),
  //     Offset(0, lineNum * _lineHeight) &
  //     Size(oldTextLayerWidth, sph),
  //     Paint()
  //   );
  //   var w = oldTextLayerWidth;
  //   if (widestLine > w) {
  //     w = widestLine;
  //   }
  //   var h = _cachedTextLayer.height + spread * _lineHeight;
  //   _cachedTextLayer.dispose();
  //   _cachedTextLayer = rec.endRecording().toImageSync(w.toInt(), h.toInt());
  // }
  Future<String?> _getMostRecentDataFromPasteboard() async {
    final insert = await Clipboard.getData(Clipboard.kTextPlain);
    if (insert == null) return null;
    return insert.text;
  }
  int _findClosestStopIndex(
    WordJumpDirection direction
  ) {
     final chars = _lines[_carretLineIndex].text.characters;
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
  void _moveCarret(CarretMoveDirection cmd) {
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
          _visibleLines.invalidate();
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
          _visibleLines.invalidate();
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
  void _insertChar(String inp) {
    _changeSalt();
    _lines[_carretLineIndex].error.value = null;
    final str = _lines[_carretLineIndex];
    final left = str.text.substring(0, _carretCharIndex - 1);
    final right = str.text.substring(_carretCharIndex - 1);
    final res = left + inp + right;
    _lines[_carretLineIndex] = Line(res);
    _visibleLines.invalidate();
  }
  void _eraseChar() {
    _changeSalt();
    _lines[_carretLineIndex].error.value = null;
    final str = _lines[_carretLineIndex];
    final carretAtStart = _carretCharIndex == 0;
    if (carretAtStart) {
      if (_carretLineIndex == 0) return;
      _lines.removeAt(_carretLineIndex);
      _carretLineIndex -= 1;
      _lines[_carretLineIndex].text += str.text;
      _carretCharIndex = _currentLineCharLimit;
      // _updateTextCache(_carretLineIndex, 1, 1);
    } else {
      final left = str.text.substring(0, _carretCharIndex - 1);
      var right = str.text.substring(_carretCharIndex);
      final res = left + right;
      _lines[_carretLineIndex] = Line(res);
      _carretCharIndex -= 1;
      // _updateTextCache(_carretLineIndex, 1, 0);
    }
    _visibleLines.invalidate();
  }
  void _eraseToLeftMostWord() {
    if (_carretCharIndex == 0) return;
    _lines[_carretLineIndex].error.value = null;
    final str = _lines[_carretLineIndex];
    final ls = _carretCharIndex;
    final re = _findClosestStopIndex(WordJumpDirection.left);
    final left = str.text.substring(0, re);
    final right = str.text.substring(ls);
    final res = left + right;
    _lines[_carretLineIndex] = Line(res);
    _carretCharIndex = re;
    // _updateTextCache(_carretLineIndex, 1, 0);
    _visibleLines.invalidate();
  }
  (int, int) _eraseSelection() {
    _changeSalt();
    final (lo, hi) = getNormalisedSelectionLocs();
    final (int, int) ret;
    if (lo.$2 == hi.$2) {
      _lines[lo.$2].error.value = null;
      final int start ;
      final int end;
      if (lo.$1 > hi.$1) {
        start = hi.$1; end = lo.$1;
      } else {
        start = lo.$1; end = hi.$1;
      }
      final str = _lines[lo.$2];
      final left = str.text.substring(0, start);
      final right = str.text.substring(end);
      final res = left + right;
      _lines[_carretLineIndex] = Line(res);
      _carretCharIndex = start;
      _carretLineIndex = lo.$2;
      ret = (lo.$2, 1);
    } else {
      final left = _lines[lo.$2].text.substring(0, lo.$1);
      final right = _lines[hi.$2].text.substring(hi.$1);
      final span = hi.$2 - lo.$2;
      var spani = span ;
      while (true) {
        if (spani == 0) break;
        _lines.removeAt(lo.$2 + spani);
        spani -= 1;
      }
      final text = left + right;
      _lines[lo.$2] = Line(text);
      _carretCharIndex = lo.$1;
      _carretLineIndex = lo.$2;
      ret = (lo.$2, span);

      final screenTopLn = (_scrollOffset.dy.abs() / _lineHeight).floor();
      if (lo.$2 < screenTopLn) {
        _scrollOffset = Offset(_scrollOffset.dx, -(lo.$2 * _lineHeight));
      }
    }
    _selectionModeData = null;
    _visibleLines.invalidate();
    _syncEraseUpdate(ret.$1, ret.$2);
    return ret;
  }
  // @override
  // void performLayout() {
  //   final normed = constraints.normalize();
  //   assert(normed.maxWidth.isFinite && normed.maxHeight.isFinite);
  //   final lpv = normed.maxHeight / _lineHeight;
  //   _linesPerViewport = lpv.floor();
  //   size = Size(normed.maxWidth, normed.maxHeight);
  // }
  @override
  bool get sizedByParent => true;
  @override
  ui.Size computeDryLayout(BoxConstraints constraints) {
    final normed = constraints.normalize();
    assert(normed.maxWidth.isFinite && normed.maxHeight.isFinite);
    final lpv = normed.maxHeight / _lineHeight;
    _linesPerViewport = lpv.floor();
    return Size(normed.maxWidth, normed.maxHeight);
  }
  @override
  void paint(PaintingContext context, Offset offset) {

    final canvas = context.canvas;

    if (_exception != null) {
      _textPainter.text = TextSpan(
        text: _exception!.message,
        style: const TextStyle(color: Colors.red)
      );
      _textPainter.layout();
      final xoff = math.max(0,_textPainter.width - size.width) / 2;
      final yoff = math.max(0, _textPainter.height - size.width) / 2;
      _textPainter.paint(canvas, Offset(xoff, yoff));
      return;
    }

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

    // canvas.drawImage(
    //   _cachedTextLayer,
    //   Offset.zero,
    //   Paint());

    // lines
    final vis = _visibleLines.value;
    var lineNum = vis.$2;
    for (final line in vis.$1) {
      final chars = line.text.characters;
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
        _textPainter.text = TextSpan(text: "$_newLineCharSubst\n", style: _invisiblesStyle);
        _textPainter.layout();
        _textPainter.paint(canvas, Offset(dxOffset, lineNum * _lineHeight));
      }
      if (line.error.value != null) {
        final err = line.error.value!;
        Color boxColor = _errBoxColor;
        double prog = 1;
        if (err.fresh) { prog = _errorSlideAnimation.value; }
        switch (err.severity) {
          case SemanticErrorSeverity.error:
            boxColor = _errBoxColor;
            break;
          case SemanticErrorSeverity.warning:
            boxColor = _warnBoxColor;
        }
        _textPainter.text = TextSpan(
          text: err.message,
          style: _errTextStyle.copyWith(color: _errTextStyle.color!.withOpacity(prog))
        );
        const errBoxTrailingPad = 20;
        final errSignWH = _lineHeight;
        const trailingErrSignPadding = 0.0;
        const leadingErrSignPadding = 5.0;
        final textOnLineLen =
          (line.text.characters.length + 1) * _characterWidth;
        final decorWidth =
          leadingErrSignPadding + errSignWH + trailingErrSignPadding + errBoxTrailingPad;
        final maxSpaceOnLineForErrMsg =
          size.width - textOnLineLen - decorWidth;
        _textPainter.layout(maxWidth: maxSpaceOnLineForErrMsg);
        final errBoxWidth =
          _textPainter.width + decorWidth;
        final errMsgBoxXOff = (size.width - errBoxWidth) + (errBoxWidth * (1 - prog));

        const corn = Radius.circular(5);
        final errLine = lineNum;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Offset(errMsgBoxXOff, errLine * _lineHeight) &
            Size(errBoxWidth, _lineHeight),
            topLeft: corn,
            bottomLeft: corn
          ),
          Paint()..color=boxColor.withOpacity(prog)
        );
        canvas.drawImageRect(
          _errSign,
          Offset.zero &
          Size(_errSign.width.toDouble(), _errSign.height.toDouble()),
          Offset(
            errMsgBoxXOff + leadingErrSignPadding,
            (errLine * _lineHeight) + 3) &
          Size(errSignWH, errSignWH),
          Paint());
        final textXOff =
          errMsgBoxXOff + leadingErrSignPadding + errSignWH + trailingErrSignPadding;
        _textPainter.paint(
          canvas,
          Offset(
            textXOff,
            errLine * _lineHeight)
        );
      }
      lineNum += 1;
    }

    // selection boxes
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
          (_lines[lowLine.$2].text.characters.length - lowLine.$1) * _characterWidth;
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
            _lines[lowLine.$2 + span].text.characters.length * _characterWidth;
          canvas.drawRect(
            Offset(0, (lowLine.$2 + span) * _lineHeight) &
            Size(width, _lineHeight),
            selectionBoxPaint);
          span -= 1;
        }
      }
    }
    // end of text line
    canvas.drawRect(
      Offset(0, (_lines.length) * _lineHeight) &
      Size(size.width, 1),
      Paint()..color=Colors.blueGrey.shade900);
      
    // completions box
    if (_completions != null) {
      final xoff = _completionsAnchorCharPoint * _characterWidth;
      final yoff = (_carretLineIndex + 1) * _lineHeight;
      canvas.save();
      canvas.translate(xoff, yoff);
      context.paintChild(_hintBox!, Offset.zero); // offset doesnt work?? lmao owo!
      canvas.restore();
    }

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
    int index, String stopChars
  ) {
    final chars = characters;
    var leftBound = index;
    if (leftBound == chars.length) leftBound -= 1;
    while (true) {
      if (leftBound == 0) break;
      final char = chars.elementAt(leftBound);
      if (stopChars.contains(char)) {
        if (index != leftBound) {
          leftBound += 1;
        }
        break;
      }
      leftBound -= 1;
    }
    final limit = chars.length;
    var rightBound = index;
    while (true) {
      if (rightBound == limit) break;
      final char = chars.elementAt(rightBound);
      if (stopChars.contains(char)) {
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

extension<T> on List<T> {
  List<T> filterIn(bool Function(T) passthrough) {
    List<T> res = [];
    for (final item in this) {
      if (passthrough(item)) {
        res.add(item);
      }
    }
    return res;
  }
}

extension on String {
  String laxSubstring(int begin, [int? end]) {
    if (end == null || end > characters.length) {
      return substring(begin);
    }
    return substring(begin, end);
  }
}