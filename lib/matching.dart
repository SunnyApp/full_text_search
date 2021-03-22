import 'package:equatable/equatable.dart';

import 'searches.dart';
import 'term_search_result.dart';

const defaultMatcherPriority = 1000;

/// This file contains term matchers - A matcher examines a search term and available tokens and determines
/// if there are any matches.  This can include partial matches, contains, startsWith, etc.  Each of these
/// types of matches is represented by a single [TermMatcher] to make it easy to add/remove them when you're
/// searching.  For example, you might want to restrict the search to not include "contains" matches.
abstract class TermMatcher implements Comparable<TermMatcher> {
  /// The name of this matcher
  String get key;

  /// What order this matcher should run.  This is important because the first matcher that finds a result "wins".
  int get priority;

  /// Applies this matcher and returns one or more match results
  List<TermMatch> apply<T>(FullTextSearch<T> search, TokenizedItem<T> item,
      String term, FTSToken token);
}

/// Provides the [Comparable] implementation for subclasses
mixin TermMatcherMixin implements TermMatcher {
  @override
  int compareTo(TermMatcher other) {
    return priority.compareTo(other.priority);
  }

  @override
  int get priority => defaultMatcherPriority;
}

class StartsWithMatch with TermMatcherMixin {
  @override
  List<TermMatch> apply<T>(FullTextSearch<T> search, TokenizedItem<T> item,
      String term, FTSToken token) {
    term = term.toLowerCase();
    return [
      if (token.startsWith(term)) TermMatch.startsWith(term, token),
    ];
  }

  @override
  String get key => matchKey;
  static const matchKey = "startsWith";

  @override
  int get priority => defaultMatcherPriority - 100;
}

class ContainsMatch with TermMatcherMixin {
  @override
  List<TermMatch> apply<T>(FullTextSearch<T> search, TokenizedItem<T> item,
      String term, FTSToken token) {
    term = term.toLowerCase();
    return [
      if (term.length > 1 && token.contains(term))
        TermMatch.contains(term, token),
    ];
  }

  @override
  int get priority => defaultMatcherPriority + 100;

  @override
  String get key => matchKey;
  static const matchKey = "contains";
}

class EqualsMatch with TermMatcherMixin {
  @override
  List<TermMatch> apply<T>(FullTextSearch<T> search, TokenizedItem<T> item,
      String term, FTSToken token) {
    term = term.toLowerCase();
    return [
      if (token.equals(term)) TermMatch.equals(term, token),
    ];
  }

  @override
  String get key => matchKey;
  static const matchKey = "equals";

  @override
  int get priority => defaultMatcherPriority - 200;

  EqualsMatch();
}

/// The result of a [TermMatcher] operation; essentially represents a positive match of a search term against a token.
abstract class TermMatch {
  /// Key of the matcher that produced this match.  eg 'contains', 'equals'
  String get key;

  /// The search term or partial search term that was matched
  String get term;

  /// The token that matched
  FTSToken get matchedToken;

  factory TermMatch.equals(String term, FTSToken matchedToken) =>
      _TermMatch(EqualsMatch.matchKey, term, matchedToken);
  factory TermMatch.contains(String term, FTSToken matchedToken) =>
      _TermMatch(ContainsMatch.matchKey, term, matchedToken);
  factory TermMatch.startsWith(String term, FTSToken matchedToken) =>
      _TermMatch(StartsWithMatch.matchKey, term, matchedToken);
  factory TermMatch.of(String key, String term, FTSToken matchedToken) =>
      _TermMatch(key, term, matchedToken);
}

class _TermMatch extends Equatable implements TermMatch {
  /// Key of the matcher that produced this match.
  @override
  final String key;

  /// The search term or partial search term that was matched
  @override
  final String term;

  /// The token that matched
  @override
  final FTSToken matchedToken;

  const _TermMatch(this.key, this.term, this.matchedToken);

  @override
  List<Object> get props => [key, term, matchedToken];

  @override
  String toString() {
    return 'TermMatch($key) {term: $term, matchedToken: $matchedToken}';
  }
}
