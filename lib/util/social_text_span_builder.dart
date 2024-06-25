import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_textfield/model/detected_type_enum.dart';
import 'package:flutter_social_textfield/model/social_content_detection_model.dart';

class SocialTextSpanBuilder {
  final Function(SocialContentDetection detection)? onTapDetection;
  final TextStyle? defaultTextStyle;
  final TextStyle? ignoredTextStyle;
  final Map<DetectedType, TextStyle> detectionTextStyles;
  final Map<DetectedType, RegExp> regularExpressions;
  Map<DetectedType, List<RegExpMatch>?> allMatches = Map();

  SocialTextSpanBuilder({
    required this.regularExpressions,
    required this.defaultTextStyle,
    this.detectionTextStyles = const {},
    this.onTapDetection,
    this.ignoredTextStyle,
  });

  MatchSearchResult getTextStyleForRange(int start, int end,
      {List<String>? ignoreCases, List<String>? includeOnlyCases}) {
    TextStyle? textStyle;
    DetectedType detectedType = DetectedType.plain_text;
    String text = "";
    allMatches.keys.forEach((type) {
      var index =
      allMatches[type]!.indexWhere((match) => match.start == start && match.end == end);

      if (index != -1) {
        text = allMatches[type]![index].input.substring(start, end);
        var isIgnored = false;
        if (includeOnlyCases?.isNotEmpty ?? false) {
          isIgnored = (includeOnlyCases?.indexWhere((t) => t == text.trim()) ?? -1) == -1;
        } else {
          isIgnored = (ignoreCases?.indexWhere((t) => t == text.trim()) ?? -1) >= 0;
        }
        if (isIgnored) {
          textStyle = ignoredTextStyle;
          detectedType = DetectedType.plain_text;
        } else {
          textStyle = detectionTextStyles[type];
          detectedType = type;
        }
        return;
      }
    });
    return MatchSearchResult(textStyle ?? defaultTextStyle ?? TextStyle(), detectedType, text);
  }

  TextSpan build(String text, {List<String>? ignoreCases, List<String>? includeOnlyCases}) {
    regularExpressions.keys.forEach((type) {
      allMatches[type] = regularExpressions[type]!.allMatches(text).toList();
    });
    if (allMatches.isEmpty) {
      return TextSpan(text: text, style: defaultTextStyle);
    }
    var orderedMatches = allMatches.values.expand((element) => element!.toList()).toList()
      ..sort((m1, m2) => m1.start.compareTo(m2.start));
    if (orderedMatches.isEmpty) {
      return TextSpan(text: text, style: defaultTextStyle);
    }
    List<TextSpan> spans = [];
    int cursorPosition = 0;
    for (int i = 0; i < orderedMatches.length; i++) {
      var match = orderedMatches[i];
      print("Match: ${text.substring(match.start, match.end)}");
      print("Match: ${match.input.substring(match.start, match.end)}");

      var firstSearch = getTextStyleForRange(cursorPosition, match.start,
          ignoreCases: ignoreCases, includeOnlyCases: includeOnlyCases);
      spans.add(TextSpan(
        text: text.substring(cursorPosition, match.start),
        style: firstSearch.textStyle,
      ));

      var secondSearch = getTextStyleForRange(match.start, match.end,
          ignoreCases: ignoreCases, includeOnlyCases: includeOnlyCases);
      TapGestureRecognizer? tapRecognizer2;
      if (onTapDetection != null) {
        tapRecognizer2 = TapGestureRecognizer()
          ..onTap = () {
            onTapDetection!(SocialContentDetection(
              secondSearch.type,
              TextRange(start: match.start, end: match.end),
              secondSearch.text,
            ));
          };
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: secondSearch.textStyle,
        recognizer: tapRecognizer2,
      ));
      cursorPosition = match.end;
    }
    if (cursorPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursorPosition),
        style: getTextStyleForRange(cursorPosition, text.length).textStyle,
      ));
    }
    return TextSpan(children: spans);
  }

  TextSpan getTextSpan(TextSpan? root, String text, TextStyle style,
      {TapGestureRecognizer? tapRecognizer}) {
    if (root == null) {
      return TextSpan(text: text, style: style, recognizer: tapRecognizer);
    } else {
      return TextSpan(children: [root, TextSpan(text: text, style: style, recognizer: tapRecognizer)]);
    }
  }
}

class MatchSearchResult {
  final TextStyle textStyle;
  final DetectedType type;
  final String text;
  MatchSearchResult(this.textStyle, this.type, this.text);
}
