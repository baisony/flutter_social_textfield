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
class SocialTextEditingController extends TextEditingController{
  StreamController<SocialContentDetection> _detectionStream = StreamController<SocialContentDetection>.broadcast();
  SocialContentDetection? lastDetection; // ここでプロパティとして定義

  @override
  void dispose() {
    _detectionStream.close();
    super.dispose();
  }

  final Map<DetectedType, TextStyle> detectionTextStyles = Map();

  final Map<DetectedType, RegExp> _regularExpressions = {
    DetectedType.mention:atSignRegExp,
    DetectedType.hashtag:hashTagRegExp,
    DetectedType.url:urlRegex,
    DetectedType.emoji:emojiRegex,
  };

  StreamSubscription<SocialContentDetection> subscribeToDetection(Function(SocialContentDetection detected) listener){
    return _detectionStream.stream.listen(listener);
  }

  void setTextStyle(DetectedType type, TextStyle style){
    detectionTextStyles[type] = style;
  }

  void setRegexp(DetectedType type, RegExp regExp){
    _regularExpressions[type] = regExp;
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

  void _processNewValue(TextEditingValue newValue) {
    var currentPosition = newValue.selection.baseOffset;
    if (currentPosition == -1) {
      currentPosition = 0;
    }
    if (currentPosition > newValue.text.length) {
      currentPosition = newValue.text.length;
    }
    var subString = newValue.text.substring(0, currentPosition);

    var lastPart = subString.split(" ").last.split("\n").last;
    var startIndex = currentPosition - lastPart.length;
    var detectionContent = newValue.text.substring(startIndex).split(" ").first.split("\n").first;

    var newDetection = SocialContentDetection(
        getType(detectionContent),
        TextRange(start: startIndex, end: startIndex + detectionContent.length),
        detectionContent
    );

    if (newDetection != lastDetection) {
      lastDetection = newDetection;
      _detectionStream.add(lastDetection!);
    }
  }

  TextSpan _buildCustomTextSpan(String text, TextStyle? style) {
    if (lastDetection == null) {
      return TextSpan(text: text, style: style);
    }

    List<TextSpan> spans = [];
    int lastIndex = 0;

    if (lastDetection!.range.start > 0) {
      spans.add(TextSpan(text: text.substring(0, lastDetection!.range.start), style: style));
    }

    spans.add(TextSpan(
      text: lastDetection?.text,
      style: style?.copyWith(color: Colors.blue), // メンションやハッシュタグのスタイルをここで設定
    ));

    if (lastDetection!.range.end < text.length) {
      spans.add(TextSpan(text: text.substring(lastDetection!.range.end), style: style));
    }

    return TextSpan(children: spans);
  }


  DetectedType getType(String word){
    return _regularExpressions.keys.firstWhere((type) => _regularExpressions[type]!.hasMatch(word),orElse: ()=>DetectedType.plain_text);
  }

  @override
  set value(TextEditingValue newValue) {
    _processNewValue(newValue);
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // カスタムのTextSpanビルダーを使用
    return _buildCustomTextSpan(text, style);
  }
}