import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_textfield/flutter_social_textfield.dart';

class SocialTextEditingController extends TextEditingController {
  StreamController<SocialContentDetection> _detectionStream = StreamController<SocialContentDetection>.broadcast();

  @override
  void dispose() {
    _detectionStream.close();
    super.dispose();
  }

  final Map<DetectedType, TextStyle> detectionTextStyles = Map();

  final Map<DetectedType, RegExp> _regularExpressions = {
    DetectedType.mention: atSignRegExp,
    DetectedType.hashtag: hashTagRegExp,
    DetectedType.url: urlRegex,
    DetectedType.emoji: emojiRegex,
  };

  List<SocialContentDetection> allDetections = [];

  StreamSubscription<SocialContentDetection> subscribeToDetection(Function(SocialContentDetection detected) listener) {
    return _detectionStream.stream.listen(listener);
  }

  void setTextStyle(DetectedType type, TextStyle style) {
    detectionTextStyles[type] = style;
  }

  void setRegexp(DetectedType type, RegExp regExp) {
    _regularExpressions[type] = regExp;
  }

  void replaceRange(String newValue, TextRange range) {
    var newText = text.replaceRange(range.start, range.end, newValue);
    var newRange = TextRange(start: range.start, end: range.start + newValue.length);
    bool isAtTheEndOfText = (newRange.end == newText.length);
    if (isAtTheEndOfText) {
      newText += " ";
    }
    TextSelection newTextSelection = TextSelection(
        baseOffset: newRange.end + (isAtTheEndOfText ? 1 : 0),
        extentOffset: newRange.end + (isAtTheEndOfText ? 1 : 0)
    );
    value = value.copyWith(text: newText, selection: newTextSelection);
  }

  void _processNewValue(TextEditingValue newValue) {
    allDetections.clear(); // 既存の検出結果をクリア
    var text = newValue.text;

    for (var type in _regularExpressions.keys) {
      var matches = _regularExpressions[type]!.allMatches(text);
      for (var match in matches) {
        var detection = SocialContentDetection(
            type,
            TextRange(start: match.start, end: match.end),
            match.group(0)!
        );
        allDetections.add(detection);
      }
    }
    _detectionStream.addStream(Stream.fromIterable(allDetections)); // すべての検出結果をストリームに追加
  }

  DetectedType getType(String word) {
    return _regularExpressions.keys.firstWhere(
            (type) => _regularExpressions[type]!.hasMatch(word),
        orElse: () => DetectedType.plain_text
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.selection.baseOffset >= newValue.text.length) {
      newValue = newValue.copyWith(
          text: newValue.text.trimRight() + " ",
          selection: newValue.selection.copyWith(
              baseOffset: newValue.text.length,
              extentOffset: newValue.text.length
          )
      );
    }
    if (newValue.text == " ") {
      newValue = newValue.copyWith(
          text: "",
          selection: newValue.selection.copyWith(baseOffset: 0, extentOffset: 0)
      );
    }
    _processNewValue(newValue);
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    return SocialTextSpanBuilder(
        regularExpressions: _regularExpressions,
        defaultTextStyle: style,
        detectionTextStyles: detectionTextStyles
    ).build(text);
  }
}
