// ignore_for_file: omit_local_variable_types
import 'dart:core';

import 'package:logging/logging.dart';
import 'package:sunny_dart/sunny_dart.dart' hide Token;

import 'matching.dart';
import 'scoring.dart';
import 'term_search_result.dart';

typedef Tokenizer<T> = List<dynamic> Function(T input);

final searchTermTokenizer = RegExp('[\\s\-\.]');

/// Matches items in an array with user-provided search string.  The input is split into multiple terms, and there is an option
/// to ensure that each term is matched within the tokens.
/// [term] The search term.  Will be tokenized internally
/// [items] The list of items to search against
/// [isMatchAll] Whether or not we should enforce that all terms in [term] are matched.  eg. term="Eric Martineau" should match on "Eric" AND "Martineau"
/// [isStartsWith] Whether the search will require the search term to match the beginning of the value token or not
/// [ignoreCase] Whether to ignore case when searching
/// [limit] The number of results to return
/// [tokenize] Determines how each item in [items] should produce searchable tokens
class FullTextSearch<T> {
  final String term;
  final Stream<T> items;
  final bool isMatchAll;
  final bool isStartsWith;
  final bool ignoreCase;
  final int? limit;
  final Tokenizer<T> tokenize;
  final List<SearchScoring> scorers;
  final List<TermMatcher> matchers;

  /// This constructor applies default scoring, but also allows you to add additional scoring rules
  /// Matches items in an array with user-provided search string.  The input is split into multiple terms, and there is an option
  /// to ensure that each term is matched within the tokens.
  /// [term] The search term.  Will be tokenized internally
  /// [items] The list of items to search against
  /// [isMatchAll] Whether or not we should enforce that all terms in [term] are matched.  eg. term="Eric Martineau" should match on "Eric" AND "Martineau"
  /// [isStartsWith] Whether the search will require the search term to match the beginning of the value token or not
  /// [ignoreCase] Whether to ignore case when searching
  /// [limit] The number of results to return
  /// [tokenize] Determines how each item in [items] should produce searchable tokens
  /// [additionalScorers] Other scorers to use in addition to the defaults
  FullTextSearch({
    required String term,
    required Iterable<T> items,
    bool isMatchAll = false,
    bool isStartsWith = true,
    bool ignoreCase = true,
    int? limit,
    required Tokenizer<T> tokenize,
    List<SearchScoring>? additionalScorers,
    List<TermMatcher>? additionalMatchers,
  }) : this._(
            term,
            Stream.fromIterable(items),
            isMatchAll,
            isStartsWith,
            ignoreCase,
            limit,
            tokenize,
            [..._defaultScoring, ...?additionalScorers],
            [..._defaultMatchers, ...?additionalMatchers]);

  FullTextSearch.ofStream({
    required String term,
    required Stream<T>? items,
    bool isMatchAll = false,
    bool isStartsWith = true,
    bool ignoreCase = true,
    int? limit,
    required Tokenizer<T> tokenize,
    List<SearchScoring>? additionalScorers,
    List<TermMatcher>? additionalMatchers,
  }) : this._(
            term,
            items ?? Stream<T>.empty(),
            isMatchAll,
            isStartsWith,
            ignoreCase,
            limit,
            tokenize,
            [..._defaultScoring, ...?additionalScorers],
            [..._defaultMatchers, ...?additionalMatchers]);

  /// Matches items in an array with user-provided search string.  The input is split into multiple terms, and there is an option
  /// to ensure that each term is matched within the tokens.
  /// [term] The search term.  Will be tokenized internally
  /// [items] The list of items to search against
  /// [isMatchAll] Whether or not we should enforce that all terms in [term] are matched.  eg. term="Eric Martineau" should match on "Eric" AND "Martineau"
  /// [isStartsWith] Whether the search will require the search term to match the beginning of the value token or not
  /// [ignoreCase] Whether to ignore case when searching
  /// [limit] The number of results to return
  /// [tokenize] Determines how each item in [items] should produce searchable tokens
  /// [scorers] Scorers
  FullTextSearch.scoring(
      {required String term,
      required Stream<T> items,
      bool isMatchAll = false,
      bool isStartsWith = true,
      bool ignoreCase = true,
      int? limit,
      required Tokenizer<T> tokenize,
      List<SearchScoring>? scorers,
      List<TermMatcher>? matchers})
      : this._(
          term,
          items,
          isMatchAll,
          isStartsWith,
          ignoreCase,
          limit,
          tokenize,
          [...?scorers],
          [...?matchers],
        );

  FullTextSearch._(this.term, this.items, this.isMatchAll, this.isStartsWith,
      this.ignoreCase, this.limit, this.tokenize, this.scorers, this.matchers)
      : assert(scorers.isNotEmpty, 'Must have at least one scorer') {
    matchers.sort();
  }

  final log = Logger('termSearch');

  /// Executes a search and finds the results.  See also [execute]
  Future<List<T>> findResults() async {
    List<T> result;
    final executed = await execute();
    if (limit != null) {
      result = executed.take(limit!).map((item) => item.result).toList();
    } else {
      result = executed.map((item) => item.result).toList();
    }
    return result;
  }

  /// Executes a search and applies [isMatchAll], or sorting rules, depending on the configuration of this [FullTextSearch]
  /// instance
  Future<List<TermSearchResult<T>>> execute() async {
    if (term.isNullOrBlank) return [];

    final Stream<TermSearchResult<T>> _results = this.results();
    final FullTextSearch<T> search = this;
    List<TermSearchResult<T>> results;
    if (search.isMatchAll) {
      results = await _results.whereMatchedAll().toList();
    } else {
      results = await _results.toList();
    }
    final sorted = [...results];
    sorted.sort((a, b) => a.compareTo(b));
    results = sorted;
    return limit != null ? [...results.take(limit!)] : [...results];
  }

  /// Executes a search and returns a stream of individual term results, unsorted and unfiltered.
  Stream<TermSearchResult<T>> results() {
    final FullTextSearch<T> search = this;
    final Set<String> terms = search.term
        .toString()
        .split(searchTermTokenizer)
        .where((_) => _ != '')
        .toSet();

    Stream<TokenizedItem<T>> tokens = (search.items).map((item) {
      final tokens = search.tokenize(item).map((t) {
        if (t == null) return null;
        if (t is FTSToken) {
          return t;
        } else {
          return FTSToken('$t');
        }
      }).notNullSet();
      return TokenizedItem(tokens, item);
    });
    Stream<TermSearchResult<T>> matches =
        tokens.expand((TokenizedItem<T> item) {
      // Creates a cross-product of tokens and terms
      Iterable<TermMatch> matching = item.tokens.expand((token) {
        return terms.expand((_term) {
          for (final matcher in matchers) {
            final matches = matcher.apply(this, item, _term, token);
            if (matches.isNotEmpty) {
              return matches;
            }
          }
          return const [];
        });
      });

      if (matching.isEmpty) return [];

      final matchedTerms =
          matching.map((TermMatch match) => match.term).toSet();
      final matchedTokens = matching.toSet();
      final termResult = TermSearchResult(
        item.result,
        matchedTerms,
        matchedTokens,
        matchedTerms.length >= terms.length,
      );
      log.fine('Scorers: $scorers');
      search.scorers.forEach(
          (scorer) => scorer.scoreTerm(search, termResult, termResult.score));
      termResult.scoreValue;
      return [termResult];
    });

    return matches;
  }
}

extension TermSearchResultStream<T> on Stream<TermSearchResult<T>> {
  Stream<TermSearchResult<T>> whereMatchedAll() {
    return where((result) => result.matchAll);
  }

  /// Produces a stream of the top N results.  This stream will emit only when there is a change
  /// to the list of top results.
  Stream<List<TermSearchResult<T>>> topScores([int count = 10]) {
    return sortSample(count);
  }
}

extension TermSearchResultList<T> on List<TermSearchResult<T>> {
  List<TermSearchResult<T>> whereMatchedAll() {
    return [...where((result) => result.matchAll)];
  }

  List<TermSearchResult<T>> sortedByScore() {
    final sorted = [...this];
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }
}

const List<SearchScoring> _defaultScoring = [
  MatchAllTermsScoring(),
  MatchedTokensScoring(),
  MatchedTermsScoring(),
];

final List<TermMatcher> _defaultMatchers = [
  EqualsMatch(),
  StartsWithMatch(),
  ContainsMatch(),
];
