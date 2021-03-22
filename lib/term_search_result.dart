import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

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

  @override
  bool get stringify => true;
}

// ignore: must_be_immutable
class TermSearchResult<T> extends Equatable
    implements Comparable<TermSearchResult<T>> {
  final Score score;

  final T result;

  /// The search terms that were successfully matched.  For "fuzzy" matches, you may only match one out of 3 terms, eg.
  /// user types: George Harrison ate pizza
  /// we matched: George Jones ate chips
  /// [matchedTerms] = George, ate
  final Set<String> matchedTerms;

  /// The tokens that were successfully matched.
  /// user types: George Harrison ate pizza
  /// we tokenized: My mate George Jones threw poker chips in Georgetown with his wife Atena.
  /// [matchedTerms] = George, ate
  /// [matchedTokens] = Georgetown, Atena, George, mate
  final Set<TermMatch> matchedTokens;

  final bool matchAll;

  double? _scoreValue;

  double get scoreValue {
    return _scoreValue ??= score.calculate();
  }

  TermSearchResult(
      this.result, this.matchedTerms, this.matchedTokens, this.matchAll)
      : score = Score.zero();

  @override
  int compareTo(lhs) {
    if (lhs is TermSearchResult<T>) {
      final rhs = this;
      if (lhs == rhs) return 0;
      var scoreA = rhs.scoreValue;
      var scoreB = lhs.scoreValue;
      if (scoreA == 0 && scoreB == 0) return 1;
      return scoreB.compareTo(scoreA);
    } else {
      return -1;
    }
  }

  @override
  List<Object?> get props => [result, matchedTerms, matchedTokens, matchAll];

  @override
  String toString() {
    return 'TermSearchResult{score: $score, matchedTerms: ${matchedTerms.length}, matchedTokens: ${matchedTokens.length}, matchAll: $matchAll}';
  }
}

class TokenCheck extends Equatable {
  final String searchTerm;
  final FTSToken tokenToCheck;
  final TokenCheckResult? result;

  const TokenCheck.check(this.searchTerm, this.tokenToCheck) : result = null;

  const TokenCheck.result(this.searchTerm, this.tokenToCheck, this.result);

  @override
  List<Object?> get props => [searchTerm, tokenToCheck, result];

  TokenCheck withResult(TokenCheckResult result) =>
      TokenCheck.result(searchTerm, tokenToCheck, result);

  bool operator >(final other) {
    if (other == null) return true;
    TokenCheckResult? type;
    if (other is TokenCheck) {
      type = other.result;
    } else if (other is TokenCheckResult) {
      type = other;
    }
    if (type == null) throw "Can't compare to ${other?.runtimeType}";
    return type > result;
  }
}

enum TokenCheckResult { equals, startsWith, contains, none }

extension TokenCheckResultExt on TokenCheckResult {
  bool operator >(TokenCheckResult? other) {
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

class FTSToken extends Equatable {
  final String token;
  final String name;

  FTSToken(String token, {String? name})
      : token = token.toLowerCase(),
        name = name ?? token;

  bool equals(String term) => token == term;

  bool startsWith(String term) => token.startsWith(term) == true;

  bool contains(String term) => token.contains(term) == true;

  @override
  List<Object> get props {
    return [token, name];
  }

  @override
  String toString() {
    if (name.toLowerCase() != token.toLowerCase()) {
      return '$name: $token';
    } else {
      return '$token';
    }
  }
}

extension TokenList on List<FTSToken> {
  void addToken(String token, [String? name]) {
    add(FTSToken(token, name: name));
  }

  void addNamed(String name, Iterable<String?> tokens) {
    for (final t in tokens) {
      if (t?.isNotEmpty == true) {
        add(FTSToken(t!, name: name));
      }
    }
  }
}

class TokenizedItem<T> extends Equatable {
  final Set<FTSToken> tokens;

  final T result;

  const TokenizedItem(this.tokens, this.result);

  @override
  List<Object?> get props => [tokens, result];
}
