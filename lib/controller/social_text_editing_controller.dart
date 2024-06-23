import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_textfield/flutter_social_textfield.dart';
import 'package:flutter_social_textfield/util/string_byte_length_extension.dart';  // 追加

class SocialTextEditingController extends TextEditingController {
  StreamController<SocialContentDetection> _detectionStream =
  StreamController<SocialContentDetection>.broadcast();

  @override
  void dispose() {
    _detectionStream.close();
    super.dispose();
  }

  final Map<DetectedType, TextStyle> detectionTextStyles = {};
  final Map<DetectedType, RegExp> _regularExpressions = {
    DetectedType.mention: atSignRegExp,
    DetectedType.hashtag: hashTagRegExp,
    DetectedType.url: urlRegex,
    DetectedType.emoji: emojiRegex,
  };

  StreamSubscription<SocialContentDetection> subscribeToDetection(
      Function(SocialContentDetection detected) listener) {
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
    var newRange =
    TextRange(start: range.start, end: range.start + newValue.length);
    bool isAtTheEndOfText = (newRange.end == newText.length);
    if (isAtTheEndOfText) {
      newText += " ";
    }
    TextSelection newTextSelection = TextSelection(
        baseOffset: newRange.end + (isAtTheEndOfText ? 1 : 0),
        extentOffset: newRange.end + (isAtTheEndOfText ? 1 : 0));
    value = value.copyWith(
        text: newText, selection: newTextSelection);
  }

  void _processNewValue(TextEditingValue newValue) {
    var currentPosition = newValue.selection.baseOffset;
    if (currentPosition == -1) {
      currentPosition = 0;
    }
    if (currentPosition > newValue.text.length) {
      currentPosition = newValue.text.length - 1;
    }
    var subString = newValue.text.substring(0, currentPosition);

    var lastPart = subString.split(" ").last.split("\n").last;
    var startIndex = subString.byteLengthUntil(subString.length - lastPart.length);
    var detectionContent = newValue.text.substring(startIndex).split(" ").first.split("\n").first;
    _detectionStream.add(SocialContentDetection(getType(detectionContent),
        TextRange(start: startIndex, end: startIndex + detectionContent.length),
        detectionContent));
  }

  DetectedType getType(String word) {
    return _regularExpressions.keys.firstWhere(
            (type) => _regularExpressions[type]!.hasMatch(word),
        orElse: () => DetectedType.plain_text);
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.selection.baseOffset >= newValue.text.length) {
      newValue = newValue.copyWith(
          text: newValue.text.trimRight() + " ",
          selection: newValue.selection.copyWith(
              baseOffset: newValue.text.length, extentOffset: newValue.text.length));
    }
    if (newValue.text == " ") {
      newValue = newValue.copyWith(
          text: "",
          selection: newValue.selection.copyWith(baseOffset: 0, extentOffset: 0));
    }
    _processNewValue(newValue);
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context, TextStyle? style, required bool withComposing}) {
    return SocialTextSpanBuilder(
        regularExpressions: _regularExpressions,
        defaultTextStyle: style,
        detectionTextStyles: detectionTextStyles)
        .build(text);
  }
}
