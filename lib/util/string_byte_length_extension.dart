extension StringByteLength on String {
  int byteLength() {
    return this.runes.fold(0, (prev, elem) {
      if (elem <= 0x7F) {
        return prev + 1;
      } else if (elem <= 0x7FF) {
        return prev + 2;
      } else if (elem <= 0xFFFF) {
        return prev + 3;
      } else {
        return prev + 4;
      }
    });
  }

  int getByteIndexFromCharIndex(int charIndex) {
    int byteIndex = 0;
    for (int i = 0; i < charIndex; i++) {
      byteIndex += this[i].runes.fold(0, (prev, elem) {
        if (elem <= 0x7F) {
          return prev + 1;
        } else if (elem <= 0x7FF) {
          return prev + 2;
        } else if (elem <= 0xFFFF) {
          return prev + 3;
        } else {
          return prev + 4;
        }
      });
    }
    return byteIndex;
  }
}
