import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:colorzen_block_puzzle/domain/engines/game_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_painter.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_grid.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/perf_tier.dart';

enum DragPhase { idle, dragging, settling, canceling }

/// Holds live drag state without rebuilding the whole game tree every frame.
class PieceDragController {
  PieceDragController();

  final ValueNotifier<Offset?> finger = ValueNotifier(null);
  final ValueNotifier<Piece?> piece = ValueNotifier(null);
  final ValueNotifier<GhostState?> ghost = ValueNotifier(null);
  final ValueNotifier<DragPhase> phase = ValueNotifier(DragPhase.idle);

  /// Reused ghost mask — avoids allocating 9×9 every pointer move.
  final List<List<bool>> _maskScratch =
      List.generate(9, (_) => List.filled(9, false));

  int? trayIndex;
  int? activePointer;
  bool get isDragging => piece.value != null;

  /// Bumped when a drag is force-cancelled (app pause / stuck pointer).
  final ValueNotifier<int> interruptGen = ValueNotifier(0);
  int _resumedAtMs = 0;

  Offset? settleTargetTopLeft;
  VoidCallback? _settleDone;
  bool settleIsPlace = true;

  /// Piece floats well above the finger so the board ghost stays visible.
  static const double fingerLift = 118;
  /// Near board-cell size while dragging — large scale hid the drop target.
  static const double pickupScale = 1.08;

  void start({
    required Piece p,
    required int index,
    required Offset global,
    int? pointer,
  }) {
    trayIndex = index;
    activePointer = pointer;
    settleTargetTopLeft = null;
    _settleDone = null;
    finger.value = global;
    piece.value = p;
    phase.value = DragPhase.dragging;
  }

  void update(Offset global) {
    if (phase.value != DragPhase.dragging) return;
    finger.value = global;
  }

  /// Fly the sprite into the snapped cell, then run [onComplete] (place).
  void beginPlaceSettle({
    required Offset targetTopLeft,
    required VoidCallback onComplete,
  }) {
    settleTargetTopLeft = targetTopLeft;
    _settleDone = onComplete;
    settleIsPlace = true;
    phase.value = DragPhase.settling;
  }

  /// Soft scale-out when the drop is invalid.
  void beginCancelSettle({required VoidCallback onComplete}) {
    settleTargetTopLeft = null;
    _settleDone = onComplete;
    settleIsPlace = false;
    phase.value = DragPhase.canceling;
  }

  void completeSettle() {
    final done = _settleDone;
    _settleDone = null;
    done?.call();
  }

  void clear() {
    trayIndex = null;
    activePointer = null;
    piece.value = null;
    finger.value = null;
    ghost.value = null;
    settleTargetTopLeft = null;
    _settleDone = null;
    phase.value = DragPhase.idle;
  }

  /// True for a short window after returning from background / screen-off.
  bool get inResumeGrace {
    if (_resumedAtMs == 0) return false;
    final dt = DateTime.now().millisecondsSinceEpoch - _resumedAtMs;
    return dt >= 0 && dt < 800;
  }

  void markResumed() {
    _resumedAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// App was backgrounded / screen locked, or a new touch stole a stuck gesture.
  /// If the player already released (settling), finish the place; otherwise abort.
  void handleLifecycleInterrupt({required bool completePending}) {
    final p = phase.value;
    var changed = false;
    if (p == DragPhase.settling || p == DragPhase.canceling) {
      if (completePending) {
        completeSettle();
      } else {
        _settleDone = null;
        clear();
      }
      changed = true;
    } else if (isDragging) {
      clear();
      changed = true;
    }
    if (changed) {
      interruptGen.value++;
    }
  }

  void setGhost({
    required List<List<bool>>? mask,
    required Color? color,
    required bool valid,
    required int? row,
    required int? col,
    List<int> previewClearRows = const [],
    List<int> previewClearCols = const [],
  }) {
    if (mask == null) {
      if (ghost.value != null) ghost.value = null;
      return;
    }
    final prev = ghost.value;
    // Skip notify when ghost target didn't change (drag jitter).
    if (prev != null &&
        prev.valid == valid &&
        prev.row == (row ?? 0) &&
        prev.col == (col ?? 0) &&
        prev.color == color &&
        listEquals(prev.previewClearRows, previewClearRows) &&
        listEquals(prev.previewClearCols, previewClearCols)) {
      return;
    }
    ghost.value = GhostState(
      mask: mask,
      color: color,
      valid: valid,
      row: row ?? 0,
      col: col ?? 0,
      previewClearRows: previewClearRows,
      previewClearCols: previewClearCols,
    );
  }

  void dispose() {
    finger.dispose();
    piece.dispose();
    ghost.dispose();
    phase.dispose();
    interruptGen.dispose();
  }
}

/// Accurate placement math: floating piece top-left → board cells.
class DragMath {
  static Size piecePixelSize(Piece piece) {
    final stride = BoardSnap.stride;
    final gap = BoardSnap.gap;
    final w = piece.cols * BoardSnap.cell + (piece.cols - 1) * gap;
    final h = piece.rows * BoardSnap.cell + (piece.rows - 1) * gap;
    assert(stride > 0);
    return Size(w, h);
  }

  /// Top-left of the floating piece in global coordinates.
  static Offset pieceTopLeftGlobal(Offset finger, Piece piece) {
    final size = piecePixelSize(piece);
    return Offset(
      finger.dx - size.width / 2,
      finger.dy - PieceDragController.fingerLift - size.height / 2,
    );
  }

  /// Board-space origin of a piece placed at [row],[col], in global coords.
  static bool get boardReady {
    final box =
        BoardSnap.cellsKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.attached && box.hasSize;
  }

  static Offset? pieceTopLeftForAnchor(int row, int col) {
    final box =
        BoardSnap.cellsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final stride = BoardSnap.stride;
    return box.localToGlobal(Offset(col * stride, row * stride));
  }

  static (int row, int col)? rawAnchor({
    required Offset globalFinger,
    required Piece piece,
  }) {
    final box =
        BoardSnap.cellsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;

    final topLeft = pieceTopLeftGlobal(globalFinger, piece);
    final local = box.globalToLocal(topLeft);
    final stride = BoardSnap.stride;

    // Snap using cell centers — more forgiving than pure top-left.
    final half = BoardSnap.cell / 2;
    var col = ((local.dx + half) / stride).floor();
    var row = ((local.dy + half) / stride).floor();

    // Allow slight out-of-range for invalid ghost, but keep usable.
    if (row < -2 || col < -2 || row > 10 || col > 10) return null;
    return (row, col);
  }

  /// Prefer exact guess; if invalid, magnet-snap to nearest valid spot.
  static (int row, int col)? anchorFor({
    required List<List<BlockColor?>> board,
    required Offset globalFinger,
    required Piece piece,
  }) {
    final guessed = rawAnchor(globalFinger: globalFinger, piece: piece);
    if (guessed == null) return null;
    final (gr, gc) = guessed;

    if (GameEngine.canPlace(board, piece, gr, gc)) {
      return guessed;
    }

    // Magnet only when already aiming at the 9×9 — not from the tray.
    if (gr < 0 || gc < 0 || gr >= 9 || gc >= 9) return guessed;

    // Magnetic assist: search nearby valid cells (feels forgiving + fun).
    (int, int)? best;
    var bestDist = 1 << 30;
    for (var dr = -2; dr <= 2; dr++) {
      for (var dc = -2; dc <= 2; dc++) {
        final r = gr + dr;
        final c = gc + dc;
        if (!GameEngine.canPlace(board, piece, r, c)) continue;
        final dist = dr * dr + dc * dc;
        if (dist < bestDist) {
          bestDist = dist;
          best = (r, c);
        }
      }
    }
    // Magnetic assist within ~2.5 cells — forgiving, still predictable.
    return bestDist <= 8 ? best : guessed;
  }

  static void applyGhost({
    required PieceDragController drag,
    required List<List<BlockColor?>> board,
    required Piece piece,
    required ColorPalette palette,
    required Offset globalFinger,
  }) {
    final anchor = anchorFor(
      board: board,
      globalFinger: globalFinger,
      piece: piece,
    );
    if (anchor == null) {
      drag.setGhost(
        mask: null,
        color: null,
        valid: false,
        row: null,
        col: null,
      );
      return;
    }

    final (row, col) = anchor;
    final valid = GameEngine.canPlace(board, piece, row, col);
    final mask = drag._maskScratch;
    for (var r = 0; r < 9; r++) {
      mask[r].fillRange(0, 9, false);
    }
    var anyOnBoard = false;

    for (final (dr, dc) in piece.occupiedCells) {
      final r = row + dr;
      final c = col + dc;
      if (r >= 0 && c >= 0 && r < 9 && c < 9) {
        mask[r][c] = true;
        anyOnBoard = true;
      }
    }

    if (!anyOnBoard) {
      drag.setGhost(
        mask: null,
        color: null,
        valid: false,
        row: null,
        col: null,
      );
      return;
    }

    var previewRows = const <int>[];
    var previewCols = const <int>[];
    if (valid) {
      final clears =
          LineClearEngine.wouldClearAfterPlace(board, piece, row, col);
      previewRows = clears.$1;
      previewCols = clears.$2;
    }

    drag.setGhost(
      mask: mask,
      color: palette.blockColor(piece.color),
      valid: valid,
      row: row,
      col: col,
      previewClearRows: previewRows,
      previewClearCols: previewCols,
    );
  }
}

class DragOverlayHost extends StatefulWidget {
  const DragOverlayHost({
    super.key,
    required this.controller,
    required this.palette,
    required this.child,
  });

  final PieceDragController controller;
  final ColorPalette palette;
  final Widget child;

  @override
  State<DragOverlayHost> createState() => _DragOverlayHostState();
}

class _DragOverlayHostState extends State<DragOverlayHost>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  OverlayEntry? _entry;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  Timer? _settleWatchdog;

  final _visual = _DragVisual();
  ui.Picture? _picture;
  int? _bakedPieceId;
  double _bakedCell = 0;

  Offset _displayFinger = Offset.zero;
  Offset _settleFrom = Offset.zero;
  double _scale = 1;
  double _opacity = 1;
  double _pickupT = 1;
  double _settleT = 0;
  double _squash = 0;

  @override
  void initState() {
    super.initState();
    PerfTier.instance.ensureHooked();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    widget.controller.piece.addListener(_syncOverlay);
    widget.controller.phase.addListener(_onPhase);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _interruptForLifecycle();
        break;
      case AppLifecycleState.resumed:
        _recoverFromLifecycle();
        break;
      case AppLifecycleState.inactive:
        if (widget.controller.phase.value != DragPhase.idle) {
          _interruptForLifecycle();
        }
        break;
    }
  }

  void _interruptForLifecycle() {
    _settleWatchdog?.cancel();
    widget.controller.handleLifecycleInterrupt(completePending: true);
    _ticker?.stop();
    _lastElapsed = Duration.zero;
    _dropOverlay();
  }

  void _recoverFromLifecycle() {
    _settleWatchdog?.cancel();
    widget.controller.markResumed();
    widget.controller.handleLifecycleInterrupt(completePending: true);
    _lastElapsed = Duration.zero;
    _dropOverlay();
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  void didUpdateWidget(covariant DragOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.piece.removeListener(_syncOverlay);
      oldWidget.controller.phase.removeListener(_onPhase);
      widget.controller.piece.addListener(_syncOverlay);
      widget.controller.phase.addListener(_onPhase);
    }
  }

  void _onPhase() {
    final phase = widget.controller.phase.value;
    _settleWatchdog?.cancel();
    if (phase == DragPhase.settling || phase == DragPhase.canceling) {
      final piece = widget.controller.piece.value;
      if (piece != null) {
        _settleFrom = DragMath.pieceTopLeftGlobal(_displayFinger, piece);
      }
      _settleT = 0;
      _ensureTicker();
      // Tickers mute while the app is backgrounded — don't leave a drop hanging.
      _settleWatchdog = Timer(const Duration(milliseconds: 220), () {
        final p = widget.controller.phase.value;
        if (p == DragPhase.settling || p == DragPhase.canceling) {
          widget.controller.completeSettle();
        }
      });
    }
  }

  void _ensureTicker() {
    if (_ticker != null && !_ticker!.isActive) {
      _lastElapsed = Duration.zero;
      _ticker!.start();
    }
  }

  void _dropOverlay() {
    _settleWatchdog?.cancel();
    _ticker?.stop();
    _picture?.dispose();
    _picture = null;
    _bakedPieceId = null;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
    _visual
      ..picture = null
      ..bump();
  }

  void _insertOverlay() {
    final entry = _entry;
    if (!mounted || entry == null || entry.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _insertOverlay();
      });
      return;
    }
    overlay.insert(entry);
  }

  void _syncOverlay() {
    final dragging = widget.controller.piece.value != null;
    if (dragging) {
      if (_entry != null && !_entry!.mounted) {
        _entry = null;
      }
      if (_entry == null) {
        final finger = widget.controller.finger.value;
        if (finger != null) _displayFinger = finger;
        _scale = 0.86;
        _opacity = 1;
        _pickupT = 0;
        _squash = 0;
        _bakePicture();
        _entry = OverlayEntry(
          builder: (ctx) => Positioned.fill(
            child: _FloatingPieceLayer(
              visual: _visual,
            ),
          ),
        );
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _insertOverlay();
        });
      }
      _ensureTicker();
    } else if (_entry != null) {
      _dropOverlay();
    }
  }

  void _bakePicture() {
    final piece = widget.controller.piece.value;
    final cell = math.max(12.0, BoardSnap.cell);
    if (piece == null) return;
    if (_picture != null &&
        _bakedPieceId == piece.id &&
        (_bakedCell - cell).abs() < 0.25) {
      return;
    }
    _picture?.dispose();
    _picture = BlockPainter.recordPiece(
      piece: piece,
      palette: widget.palette,
      cell: cell,
      gap: BoardSnap.gap,
      elevated: true,
    );
    _bakedPieceId = piece.id;
    _bakedCell = cell;
    _visual.picture = _picture;
    _visual.pieceSize = DragMath.piecePixelSize(piece);
  }

  static Offset _expLerp(Offset a, Offset b, double dt, double hz) {
    final t = 1 - math.exp(-dt * hz);
    return Offset.lerp(a, b, t.clamp(0.0, 1.0))!;
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    // Frame-time independent; clamp spikes so a hitch doesn't teleport.
    dt = dt.clamp(0.0, 0.032);

    final controller = widget.controller;
    final piece = controller.piece.value;
    final phase = controller.phase.value;

    if (piece == null || phase == DragPhase.idle) {
      _ticker?.stop();
      return;
    }

    _bakePicture();

    if (phase == DragPhase.settling) {
      _settleT += dt / 0.11;
      final u = Curves.easeOutCubic.transform(_settleT.clamp(0.0, 1.0));
      final target = controller.settleTargetTopLeft ?? _settleFrom;
      final topLeft = Offset.lerp(_settleFrom, target, u)!;
      _scale = ui.lerpDouble(PieceDragController.pickupScale, 1.0, u)!;
      // Impact squash — Unity-style land, then settle.
      _squash = math.sin(u * math.pi) * 0.07;
      _opacity = 1;
      _visual
        ..topLeft = topLeft
        ..scale = _scale
        ..scaleY = _scale - _squash
        ..opacity = _opacity
        ..bump();
      if (_settleT >= 1) {
        _ticker?.stop();
        _settleWatchdog?.cancel();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final p = controller.phase.value;
          if (p == DragPhase.settling || p == DragPhase.canceling) {
            controller.completeSettle();
          }
        });
      }
      return;
    }

    if (phase == DragPhase.canceling) {
      _settleT += dt / 0.13;
      final u = Curves.easeIn.transform(_settleT.clamp(0.0, 1.0));
      _scale = ui.lerpDouble(PieceDragController.pickupScale, 0.72, u)!;
      _opacity = 1 - u;
      final topLeft = DragMath.pieceTopLeftGlobal(_displayFinger, piece);
      _visual
        ..topLeft = topLeft
        ..scale = _scale
        ..scaleY = _scale
        ..opacity = _opacity
        ..bump();
      if (_settleT >= 1) {
        _ticker?.stop();
        _settleWatchdog?.cancel();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final p = controller.phase.value;
          if (p == DragPhase.settling || p == DragPhase.canceling) {
            controller.completeSettle();
          }
        });
      }
      return;
    }

    final target = controller.finger.value;
    if (target == null) return;

    // ~40 Hz exponential follow — glued to the finger, interpolated to vsync.
    _displayFinger = _expLerp(_displayFinger, target, dt, 40);

    if (_pickupT < 1) {
      _pickupT += dt / 0.09;
      final u = Curves.easeOutBack.transform(_pickupT.clamp(0.0, 1.0));
      _scale = ui.lerpDouble(0.84, PieceDragController.pickupScale, u)!;
    } else {
      _scale = PieceDragController.pickupScale;
    }
    _squash = 0;
    _opacity = 1;

    _visual
      ..topLeft = DragMath.pieceTopLeftGlobal(_displayFinger, piece)
      ..scale = _scale
      ..scaleY = _scale
      ..opacity = _opacity
      ..bump();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.piece.removeListener(_syncOverlay);
    widget.controller.phase.removeListener(_onPhase);
    _settleWatchdog?.cancel();
    _ticker?.dispose();
    _picture?.dispose();
    if (_entry != null && _entry!.mounted) {
      _entry!.remove();
    }
    _entry = null;
    _visual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DragVisual extends ChangeNotifier {
  ui.Picture? picture;
  Offset topLeft = Offset.zero;
  Size pieceSize = Size.zero;
  double scale = 1;
  double scaleY = 1;
  double opacity = 1;

  void bump() => notifyListeners();
}

class _FloatingPieceLayer extends StatelessWidget {
  const _FloatingPieceLayer({required this.visual});

  final _DragVisual visual;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _FloatPainter(visual: visual),
        isComplex: true,
        willChange: true,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FloatPainter extends CustomPainter {
  _FloatPainter({required this.visual}) : super(repaint: visual);

  final _DragVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final picture = visual.picture;
    if (picture == null || visual.opacity <= 0.01) return;

    final w = visual.pieceSize.width;
    final h = visual.pieceSize.height;
    if (w <= 0 || h <= 0) return;

    canvas.save();
    canvas.translate(visual.topLeft.dx, visual.topLeft.dy);
    // Scale from bottom-center so growth goes up — board under the finger stays clear.
    canvas.translate(w / 2, h);
    canvas.scale(visual.scale, visual.scaleY);
    canvas.translate(-w / 2, -h);
    if (visual.opacity < 0.999) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = Color.fromRGBO(255, 255, 255, visual.opacity),
      );
      canvas.drawPicture(picture);
      canvas.restore();
    } else {
      canvas.drawPicture(picture);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FloatPainter old) => old.visual != visual;
}
