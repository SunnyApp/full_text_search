import 'matching.dart';
import 'searches.dart';
import 'term_search_result.dart';

/// A scoring algorithm for search results.
abstract class SearchScoring {
  const SearchScoring();

  /// Inspects a matched term [term] and appends a score to [current].  The scores are calculated
  /// after all scorers have run, at which point the _amount_ values are summed up, and then the
  /// percent multipliers are applied
  void scoreTerm(FullTextSearch search, TermSearchResult term, Score current) {}
}

/// Scoring that applies a boost if all search terms are a match
class MatchAllTermsScoring extends SearchScoring {
  @override
  void scoreTerm(FullTextSearch search, TermSearchResult term, Score current) =>
      current += Boost.amount(
          term.matchAll ? (term.matchedTerms.length * 0.5) : 0, "matchAll");

  const MatchAllTermsScoring() : super();
}

/// Applies a linear boost based on the number of search terms that were matched.  See [MatchAllTermsScoring]
class MatchedTermsScoring extends SearchScoring {
  const MatchedTermsScoring() : super();
  @override
  void scoreTerm(FullTextSearch search, TermSearchResult term, Score current) =>
      current += Boost.amount(
        term.matchedTerms.length.toDouble(),
        () => "terms_x${term.matchedTerms.length}",
      );
}

/// Applies a boost for matched tokens, but adjusts the boost based on whether the term is an exact match, a
/// prefix match, or a contains match
class MatchedTokensScoring extends SearchScoring {
  final Boost matchedTokenBoost;
  const MatchedTokensScoring(
      [this.matchedTokenBoost = const Boost.amount(1, "tokenPrefix")])
      : super();
  @override
  void scoreTerm(FullTextSearch search, TermSearchResult term, Score current) {
    for (final t in term.matchedTokens) {
      switch (t.key) {
        case EqualsMatch.matchKey:
          current += (matchedTokenBoost.times(1.3, "tokenEquals"));
          break;
        case StartsWithMatch.matchKey:
          current += matchedTokenBoost;
          break;
        case ContainsMatch.matchKey:
          current += matchedTokenBoost.times(0.85, "tokenContains");
          break;
        default:
          break;
      }
    }
  }
}

/// Boosts certain tokens, like firstName or lastName.  This assumes your tokenizer routine also
/// provided named tokens.
class BoostTokenScoring extends SearchScoring {
  final Map<String, Boost> boosts;

  BoostTokenScoring(this.boosts);

  @override
  void scoreTerm(FullTextSearch search, TermSearchResult term, Score current) {
    for (final t in term.matchedTokens) {
      final _boost = boosts[t.matchedToken.name];
      if (_boost != null) {
        current += _boost;
      }
    }
  }
}

/// Represents an accumulating score for a search term.
///
/// [Boost]s are added to the score.  Once the score has been calculated, you can't append any more boosts.
class Score {
  double? _score;
  final List<Boost> boosts;

  Score.zero()
      : boosts = [],
        _score = null;

  Score operator +(Boost boost) {
    if (_score != null) {
      throw "Score is frozen - new values cannot be adeed";
    }
    boosts.add(boost);
    return this;
  }

  double calculate() {
    return _score ??= _calculateScore(boosts);
  }

  @override
  String toString() {
    return '$_score: boosts: ${boosts.join("")}';
  }
}

double _calculateScore(List<Boost> boosts) {
  double percent = 0;
  double amount = 0;
  int pctCount = 0;
  for (final boost in boosts) {
    if (boost.percent != null) {
      percent += boost.percent!;
      pctCount++;
    } else if (boost.amount != null) {
      amount += boost.amount!;
    }
  }
  return pctCount > 0 ? amount * (percent / pctCount) : amount;
}

/// A single boost - can either be an amount, or a percent
class Boost {
  final double? amount;
  final double? percent;
  final dynamic debugLabel;

  const Boost(this.amount, this.percent, [this.debugLabel]);
  const Boost.amount(this.amount, [this.debugLabel]) : percent = null;
  const Boost.percent(this.percent, [this.debugLabel]) : amount = null;

  Boost times(double num, [dynamic debugLabel]) {
    final amt = amount == null ? null : amount! * num;
    final pct = percent == null ? null : percent! * num;

    return Boost(amt, pct, debugLabel);
  }

  Boost operator *(double num) {
    return times(num, debugLabel);
  }

  @override
  String toString() {
    var str = StringBuffer();
    if (debugLabel != null) {
      if (debugLabel is String) {
        str.write("$debugLabel[");
      } else {
        str.write("${debugLabel()}[");
      }
    }
    if (amount != null) str.write("+$amount");
    if (percent != null) str.write("+$percent%");
    if (debugLabel != null) {
      str.write("]; ");
    }
    return str.toString();
  }
}
