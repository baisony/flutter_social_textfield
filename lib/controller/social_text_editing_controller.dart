import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_textfield/flutter_social_textfield.dart';



///An improved [TextEditingController] for using with any widget that accepts [TextEditingController].
///It uses [SocialTextSpanBuilder] for rendering the content.
///[_detectionStream] returns content of the current cursor position. Positions are calculated by the cyrrent location of the word
///Configuration is made by calling setter functions.
///example:
///     _textEditingController = SocialTextEditingController()
///       ..setTextStyle(DetectedType.mention, TextStyle(color: Colors.purple,backgroundColor: Colors.purple.withAlpha(50)))
///      ..setTextStyle(DetectedType.url, TextStyle(color: Colors.blue, decoration: TextDecoration.underline))
///      ..setTextStyle(DetectedType.hashtag, TextStyle(color: Colors.blue, fontWeight: FontWeight.w600))
///      ..setRegexp(DetectedType.mention, Regexp("your_custom_regex_pattern");
///
///There is also a helper function that can replaces range with the given value. In order to change cursor context, cursor moves to next word after replacement.
///

class SocialTextEditingController extends TextEditingController {
  StreamController<SocialContentDetection> _detectionStream = StreamController<SocialContentDetection>.broadcast();
  SocialContentDetection? lastDetection;
  List<SocialContentDetection> previousDetections = [];
  List<SocialContentDetection> allDetections = [];


  final Map<DetectedType, TextStyle> detectionTextStyles = Map();

  final Map<DetectedType, RegExp> _regularExpressions = {
    DetectedType.mention:atSignRegExp,
    DetectedType.hashtag:hashTagRegExp,
    DetectedType.url:urlRegex,
    DetectedType.emoji:emojiRegex,
  };

  StreamSubscription<SocialContentDetection> subscribeToDetection(Function(SocialContentDetection detected) listener) {
    return _detectionStream.stream.listen(listener);
  }

  void setTextStyle(DetectedType type, TextStyle style) {
    detectionTextStyles[type] = style;
  }

  void setRegexp(DetectedType type, RegExp regExp) {
    _regularExpressions[type] = regExp;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    return _buildCustomTextSpan(text, style);
  }

  TextSpan _buildCustomTextSpan(String text, TextStyle? style) {
    List<TextSpan> spans = [];
    int lastIndex = 0;

    allDetections.sort((a, b) => a.range.start.compareTo(b.range.start));

    for (var detection in allDetections) {
      if (detection.range.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, detection.range.start), style: style));
      }
      spans.add(TextSpan(
        text: detection.text,
        style: detectionTextStyles[detection.type] ?? style?.copyWith(color: Colors.blue),
      ));
      lastIndex = detection.range.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    print(lastIndex);
    print(spans);
    print(text);

    return TextSpan(children: spans);
  }

  void replaceRange(String newValue, TextRange range) {
    var newText = text.replaceRange(range.start, range.end, newValue);
    var newRange = TextRange(start: range.start, end: range.start + newValue.length);
    bool isAtTheEndOfText = (newRange.end == newText.length);
    if (isAtTheEndOfText) {
      newText += " ";
    }
    TextSelection newTextSelection = TextSelection(baseOffset: newRange.end + (isAtTheEndOfText ? 1 : 0), extentOffset: newRange.end + (isAtTheEndOfText ? 1 : 0));
    value = value.copyWith(text: newText, selection: newTextSelection);
  }

  @override
  set value(TextEditingValue newValue) {
    _processNewValue(newValue);
    super.value = newValue;
  }

  void _processNewValue(TextEditingValue newValue) {
    allDetections.clear();

    for (var type in _regularExpressions.keys) {
      var matches = _regularExpressions[type]!.allMatches(newValue.text);
      for (var match in matches) {
        var detection = SocialContentDetection(
            type,
            TextRange(start: match.start, end: match.end),
            match.group(0)!
        );
        allDetections.add(detection);
      }
    }

    // カーソル位置の検出も維持
    var currentPosition = newValue.selection.baseOffset;
    if (currentPosition > -1 && currentPosition <= newValue.text.length) {
      var subString = newValue.text.substring(0, currentPosition);
      var lastPart = subString.split(" ").last.split("\n").last;
      var startIndex = currentPosition - lastPart.length;
      var detectionContent = newValue.text.substring(startIndex).split(" ").first.split("\n").first;

      var cursorDetection = SocialContentDetection(
          getType(detectionContent),
          TextRange(start: startIndex, end: startIndex + detectionContent.length),
          detectionContent
      );

      if (cursorDetection.text != lastDetection?.text) {
        lastDetection = cursorDetection;
        _detectionStream.add(lastDetection!);
      }
    }

    notifyListeners();
  }


  DetectedType getType(String word) {
    return _regularExpressions.keys.firstWhere(
            (type) => _regularExpressions[type]!.hasMatch(word),
        orElse: () => DetectedType.plain_text
    );
  }

  @override
  void dispose() {
    _detectionStream.close();
    super.dispose();
  }
}