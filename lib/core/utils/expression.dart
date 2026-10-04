/// Tiny arithmetic expression evaluator for the in-app calculator.
///
/// Supports `+ - * /`, parentheses, decimals and unary minus.
/// Returns `null` when the expression is incomplete or invalid
/// (bad syntax, division by zero, empty input).
///
/// Pure Dart, no dependencies — implemented as a small recursive-descent
/// parser: expr := term (('+' | '-') term)*, term := factor (('*' | '/')
/// factor)*, factor := number | '(' expr ')' | '-' factor.
double? evaluateExpression(String input) {
  final tokens = _tokenize(input);
  if (tokens == null || tokens.isEmpty) return null;
  final parser = _Parser(tokens);
  final value = parser._parseExpr();
  if (value == null || !parser._atEnd) return null;
  if (value.isNaN || value.isInfinite) return null;
  return value;
}

sealed class _Token {
  const _Token();
}

class _Num extends _Token {
  const _Num(this.value);
  final double value;
}

class _Op extends _Token {
  const _Op(this.op);
  final String op; // '+', '-', '*', '/'
}

class _LParen extends _Token {
  const _LParen();
}

class _RParen extends _Token {
  const _RParen();
}

List<_Token>? _tokenize(String input) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < input.length) {
    final c = input[i];
    if (c == ' ') {
      i++;
      continue;
    }
    if (c == '(') {
      tokens.add(const _LParen());
      i++;
    } else if (c == ')') {
      tokens.add(const _RParen());
      i++;
    } else if (c == '+' || c == '-' || c == '*' || c == '/') {
      tokens.add(_Op(c));
      i++;
    } else if (_isDigit(c) || c == '.') {
      var j = i;
      var dots = 0;
      while (j < input.length && (_isDigit(input[j]) || input[j] == '.')) {
        if (input[j] == '.') dots++;
        j++;
      }
      if (dots > 1) return null;
      final value = double.tryParse(input.substring(i, j));
      if (value == null) return null;
      tokens.add(_Num(value));
      i = j;
    } else {
      return null; // unknown character
    }
  }
  return tokens;
}

bool _isDigit(String c) =>
    c.length == 1 && c.compareTo('0') >= 0 && c.compareTo('9') <= 0;

class _Parser {
  _Parser(this.tokens);
  final List<_Token> tokens;
  var _pos = 0;

  bool get _atEnd => _pos >= tokens.length;
  _Token get _peek => tokens[_pos];

  double? _parseExpr() {
    var v = _parseTerm();
    if (v == null) return null;
    while (!_atEnd && _peek is _Op) {
      final op = (_peek as _Op).op;
      if (op != '+' && op != '-') break;
      _pos++;
      final rhs = _parseTerm();
      if (rhs == null) return null;
      v = op == '+' ? v! + rhs : v! - rhs;
    }
    return v;
  }

  double? _parseTerm() {
    var v = _parseFactor();
    if (v == null) return null;
    while (!_atEnd && _peek is _Op) {
      final op = (_peek as _Op).op;
      if (op != '*' && op != '/') break;
      _pos++;
      final rhs = _parseFactor();
      if (rhs == null) return null;
      if (op == '*') {
        v = v! * rhs;
      } else {
        if (rhs == 0) return null;
        v = v! / rhs;
      }
    }
    return v;
  }

  double? _parseFactor() {
    if (_atEnd) return null;
    final t = _peek;
    if (t is _Op && t.op == '-') {
      _pos++;
      final v = _parseFactor();
      return v == null ? null : -v;
    }
    if (t is _Num) {
      _pos++;
      return t.value;
    }
    if (t is _LParen) {
      _pos++;
      final v = _parseExpr();
      if (v == null || _atEnd || _peek is! _RParen) return null;
      _pos++;
      return v;
    }
    return null;
  }
}
