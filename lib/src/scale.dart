import 'dart:async';

import 'package:flutter/material.dart';

class ScaleMorphingText extends StatefulWidget {
  /// List of [String] which will show the texts
  final List<String> texts;

  /// Gives [TextStyle] to the text
  ///
  /// Default is [DefaultTextStyle]
  final TextStyle? textStyle;

  /// Speed of changing text
  ///
  /// Default is [Duration(milliseconds: 500)]
  final Duration speed;

  /// Duration of pause between the changing text
  ///
  /// Default is [Duration(seconds: 1, milliseconds: 500)]
  final Duration pause;

  /// Animation should keep looping forever
  ///
  /// Default is [false]
  final bool loopForever;

  /// Number of times animation should repeat
  /// after the defined [loopCount] is completed
  /// [onCompleted] is called.
  ///
  /// Default is [1]
  final int loopCount;

  /// Called after [loopCount] is completed
  final VoidCallback? onComplete;

  /// Curve which controls opacity from 0 to 1
  ///
  /// Default is [Curves.easeInExpo]
  final Curve fadeInCurve;

  /// Curve which controls opacity from 1 to 0
  ///
  /// Default is [Curves.easeOut]
  final Curve fadeOutCurve;

  /// Curve which controls movement of text and scale changes
  ///
  /// Default is [Curves.easeIn]
  final Curve progressCurve;

  const ScaleMorphingText({
    Key? key,
    /*required*/ required this.texts,
    this.textStyle,
    this.speed = const Duration(milliseconds: 500),
    this.pause = const Duration(seconds: 1, milliseconds: 500),
    this.loopForever = false,
    this.loopCount = 1,
    this.onComplete,
    this.fadeInCurve = Curves.easeInExpo,
    this.fadeOutCurve = Curves.easeOut,
    this.progressCurve = Curves.easeIn,
  })  : assert(
          loopCount > 0,
          "'loopCount' should have value greater than 0",
        ),
        super(key: key);

  @override
  _ScaleMorphingTextState createState() => _ScaleMorphingTextState();
}

class _ScaleMorphingTextState extends State<ScaleMorphingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn, _fadeOut, _progress;

  late List<String> texts;
  int index = -1;
  late int length, count;

  Timer? _timer;

  @override
  void initState() {
    // Setting up controller and animation
    _controller = AnimationController(
      vsync: this,
      duration: widget.speed,
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: widget.fadeInCurve);
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.fadeOutCurve),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: widget.progressCurve,
    )..addStatusListener(_statusListener);

    // getting data from parent class
    texts = widget.texts;
    length = texts.length;
    count = widget.loopCount;

    super.initState();

    // Calling _nextText to start animation
    _nextText();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: _WTextPainter(
              text: texts[index],
              textStyle:
                  DefaultTextStyle.of(context).style.merge(widget.textStyle),
              fadeInProgress: _fadeIn.value,
              fadeOutProgress: _fadeOut.value,
              progress: _progress.value,
            ),
          ),
        );
      },
    );
  }

  void _statusListener(AnimationStatus status) {
    if (AnimationStatus.completed == status) {
      // Pause before starting an animation and then call _nextText
      _timer = Timer(widget.pause, _nextText);
    }
  }

  Future<void> _nextText() async {
    final bool isLast = index % length == length - 1;

    // loopForever is [false] and  we are a last index
    if (!widget.loopForever && isLast) {
      // decrement the count
      count--;
      // check if the counter is [0]
      if (count == 0) {
        // call [onComplete] and break the recusive calls
        widget.onComplete?.call();
        return;
      }
    }

    // incremented index or set to [0]
    index = isLast ? 0 : index + 1;

    if (mounted) setState(() {});

    // restarting the controller from [0]
    _controller.forward(from: 0);
  }
}

class _WTextPainter extends CustomPainter {
  _WTextPainter({
    required this.text,
    required this.textStyle,
    required this.fadeInProgress,
    required this.fadeOutProgress,
    required this.progress,
  });

  final String text;

  final TextStyle textStyle;
  final double /*!*/ fadeInProgress, fadeOutProgress, progress;

  List<_TextInfo> _textInfo = [];
  List<_TextInfo> _oldTextInfo = [];

  String? _oldText;

  @override
  void paint(Canvas canvas, Size size) {
    double percent = progress;
    double fadeIn = fadeInProgress;
    // calculate text info for 1st time
    if (_textInfo.length == 0) {
      calculateTextInfo(text, _textInfo);
    }

    canvas.save();

    if (_oldTextInfo.length > 0) {
      for (_TextInfo _oldTextLayoutInfo in _oldTextInfo) {
        if (_oldTextLayoutInfo.isMoving) {
          final changeInX =
              (_oldTextLayoutInfo.offsetX - _oldTextLayoutInfo.toX) * percent;
          drawText(
            canvas,
            _oldTextLayoutInfo.text,
            1,
            1,
            Offset(
              _oldTextLayoutInfo.offsetX - changeInX,
              _oldTextLayoutInfo.offsetY,
            ),
            _oldTextLayoutInfo,
          );
        } else {
          drawText(
            canvas,
            _oldTextLayoutInfo.text,
            1 - percent,
            fadeOutProgress,
            Offset(_oldTextLayoutInfo.offsetX, _oldTextLayoutInfo.offsetY),
            _oldTextLayoutInfo,
          );
        }
      }
    } else {
      //no oldText
      percent = 1;
      fadeIn = 1;
    }
    for (_TextInfo _textLayoutInfo in _textInfo) {
      if (!_textLayoutInfo.isMoving) {
        drawText(
          canvas,
          _textLayoutInfo.text,
          percent,
          fadeIn,
          Offset(_textLayoutInfo.offsetX, _textLayoutInfo.offsetY),
          _textLayoutInfo,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WTextPainter oldDelegate) {
    String oldFrameText = oldDelegate.text;
    if (oldFrameText == text) {
      this._oldText = oldDelegate._oldText;
      this._oldTextInfo = oldDelegate._oldTextInfo;
      this._textInfo = oldDelegate._textInfo;
      // shouldn't repaint if there is not change in progress
      if (this.progress == oldDelegate.progress) {
        return false;
      }
    } else {
      this._oldText = oldDelegate.text;
      // calculate text info for prev and current text
      calculateTextInfo(text, _textInfo);
      calculateTextInfo(_oldText!, _oldTextInfo);
      // calculate which text will move to which position
      calculateMove();
    }
    return true;
  }

  void drawText(
    Canvas canvas,
    String text,
    double textScaleFactor,
    double alphaFactor,
    Offset offset,
    _TextInfo textInfo,
  ) {
    final textPaint = Paint();
    if (alphaFactor == 1) {
      textPaint.color = textStyle.color!;
    } else {
      textPaint.color = textStyle.color!.withAlpha(
        (textStyle.color!.alpha * alphaFactor).floor(),
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(
          text: text,
          style: textStyle.merge(
            TextStyle(
              color: textPaint.color,
            ),
          )),
    )
      ..textDirection = TextDirection.ltr
      ..textAlign = TextAlign.center
      ..textScaleFactor = textScaleFactor
      ..textDirection = TextDirection.ltr
      ..layout();

    textPainter.paint(
      canvas,
      Offset(offset.dx, offset.dy + (textInfo.height - textPainter.height) / 2),
    );
  }

  void calculateTextInfo(String text, List<_TextInfo> list) {
    list.clear();

    TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textAlign: TextAlign.center,
    )..layout();

    // spliting the text and storing thier infomation for each
    for (int i = 0; i < text.length; i++) {
      var forCaret =
          textPainter.getOffsetForCaret(TextPosition(offset: i), Rect.zero);

      var textLayoutInfo = _TextInfo(
        text: text[i],
        offsetX: forCaret.dx - textPainter.width / 2,
        offsetY: forCaret.dy,
        width: 0,
        height: textPainter.height,
      );

      list.add(textLayoutInfo);
    }
  }

  void calculateMove() {
    if (_oldTextInfo.length == 0) {
      return;
    }
    if (_textInfo.length == 0) {
      return;
    }

    for (_TextInfo oldText in _oldTextInfo) {
      for (_TextInfo text in _textInfo) {
        if (!text.isMoving && !oldText.isMoving && text.text == oldText.text) {
          oldText.toX = text.offsetX;
          text.isMoving = true;
          oldText.isMoving = true;
        }
      }
    }
  }
}

class _TextInfo {
  String text;
  double offsetX;
  double offsetY;
  double width;
  double height;
  double toX = 0;
  bool isMoving = false;

  _TextInfo({
    required this.text,
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });
}
