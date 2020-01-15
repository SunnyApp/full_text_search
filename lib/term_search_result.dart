import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:sunny_dart_util/typedefs.dart';

import 'matching.dart';
import 'scoring.dart';

class TermSearchResults<T> extends DelegatingList<TermSearchResult<T>>
    implements Equatable {
  List<TermSearchResult<T>> get results => this;

  TermSearchResults(List<TermSearchResult<T>> results) : super(results);

  @override
  List<Object> get props {
    return [results];
  }
}

class TermSearchResult<T>
    with EquatableMixin
    implements Comparable<TermSearchResult<T>> {
  final Score score;

  final T result;

  final Set<String> matchedTerms;

  final Set<TermMatch> matchedTokens;

  final bool matchAll;

  double _scoreValue;

  double get scoreValue {
    return _scoreValue ??= score.calculate();
  }

  TermSearchResult(
      this.result, this.matchedTerms, this.matchedTokens, this.matchAll)
      : score = Score.zero();

  @override
  int compareTo(lhs) {
    if (lhs is TermSearchResult) {
      final rhs = this;
      if (lhs == rhs) return 0;
      return lhs.scoreValue?.compareTo(rhs?.scoreValue ?? 0) ?? -1;
    } else {
      return -1;
    }
  }

  @override
  List<Object> get props => [result, matchedTerms, matchedTokens, matchAll];

  @override
  String toString() {
    return 'TermSearchResult{score: $score, matchedTerms: ${matchedTerms.length}, matchedTokens: ${matchedTokens.length}, matchAll: $matchAll}';
  }
}

class TokenCheck extends Equatable {
  final String searchTerm;
  final Token tokenToCheck;
  final TokenCheckResult result;

  TokenCheck.check(this.searchTerm, this.tokenToCheck) : result = null;
  TokenCheck.result(this.searchTerm, this.tokenToCheck, this.result);

  @override
  List<Object> get props => [searchTerm, tokenToCheck, result];

  TokenCheck withResult(TokenCheckResult result) =>
      TokenCheck.result(searchTerm, tokenToCheck, result);

  bool operator >(final other) {
    if (other == null) return true;
    TokenCheckResult type;
    if (other is TokenCheck) {
      type = other.result;
    } else if (other is TokenCheckResult) {
      type = other;
    }
    if (type == null) throw "Can't compare to ${other?.runtimeType}";
    return type > this.result;
  }
}

enum TokenCheckResult { equals, startsWith, contains, none }

extension TokenCheckResultExt on TokenCheckResult {
  bool operator >(TokenCheckResult other) {
    if (this == null) return false;
    if (this == other) return false;
    switch (this) {
      case TokenCheckResult.equals:
        return true;
      case TokenCheckResult.startsWith:
        return other != TokenCheckResult.equals;
      case TokenCheckResult.contains:
        return other == TokenCheckResult.none;
      case TokenCheckResult.none:
        return false;
      default:
        return false;
    }
  }
}

class Token extends Equatable {
  final String token;
  final String name;

  Token(String token, {String name})
      : token = token?.toLowerCase(),
        name = name ?? token;

  bool equals(String term) => token == term;
  bool startsWith(String term) => token?.startsWith(term) == true;
  bool contains(String term) => token?.contains(term) == true;

  @override
  List<Object> get props {
    return [token, name];
  }

  @override
  String toString() {
    if (name.toLowerCase() != token.toLowerCase()) {
      return "$name: $token";
    } else {
      return "$token";
    }
  }
}

extension TokenList on List<Token> {
  void addToken(String token, [String name]) {
    add(Token(token, name: name));
  }

  void addNamed(String name, Iterable<String> tokens) {
    for (final t in tokens) {
      if (t?.isNotEmpty == true) {
        add(Token(t, name: name));
      }
    }
  }
}

class TokenizedItem<T> extends Equatable {
  final Set<Token> tokens;

  final T result;

  TokenizedItem(this.tokens, this.result);

  @override
  List<Object> get props => [tokens, result];
}

int _compareBool(bool a, bool b) {
  if (a == b) return 0;
  if (a == null && b == null) return 0;
  if (a != null && b == null) return 1;
  if (a == null && b != null) return -1;
  return a ? 1 : -1;
}

T _findResult<T>({List<Factory<T>> checks, T exclude}) {
  for (var check in checks) {
    if (check == null) continue;
    final result = check();
    if (result != null && (exclude != null && result != exclude)) {
      return result;
    }
  }
  return null;
}