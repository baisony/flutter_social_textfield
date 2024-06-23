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
    var oldText = text;
    var newText = oldText.replaceRange(range.start, range.end, newValue);
    var newRange = TextRange(start: range.start, end: range.start + newValue.characters.length);

    bool isAtTheEndOfText = (newRange.end == newText.characters.length);
    if (isAtTheEndOfText) {
      newText += " ";
    }

    int newCursorPosition = newRange.end + (isAtTheEndOfText ? 1 : 0);
    TextSelection newTextSelection = TextSelection(
        baseOffset: newCursorPosition,
        extentOffset: newCursorPosition
    );

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

    // 検出されたコンテンツが変更された場合のみ通知
    if (detectionContent != lastDetection?.content) {
      _detectionStream.add(SocialContentDetection(
          getType(detectionContent),
          TextRange(start: startIndex, end: startIndex + detectionContent.length),
          detectionContent
      ));
    }
  }
  
  DetectedType getType(String word){
    return _regularExpressions.keys.firstWhere((type) => _regularExpressions[type]!.hasMatch(word),orElse: ()=>DetectedType.plain_text);
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      // テキストが変更された場合のみ処理を行う
      _processNewValue(newValue);
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    return SocialTextSpanBuilder(regularExpressions: _regularExpressions,defaultTextStyle: style,detectionTextStyles: detectionTextStyles).build(text);
  }
}