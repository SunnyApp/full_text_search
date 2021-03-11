// ignore_for_file: prefer_single_quotes,omit_local_variable_types
import 'package:flutter_test/flutter_test.dart';
import 'package:full_text_search/searches.dart';
import 'package:full_text_search/term_search_result.dart';

void main() {
  var one = Searchable(
      name: 'John Bob Richards',
      phone: '480-123-2313',
      address: '123 East Johnson Lane');
  var two = Searchable(
      name: 'Joe John Johnson',
      phone: 'john@john.com',
      address: '44 E Johns Creek Eight');
  var three = Searchable(
      name: 'Emiliano Kihn',
      phone: '+06(4)0703332600',
      address: '34101 Kristopher Estates Suite 848 John, TN 09343-4760');
  var four = Searchable(
      name: 'Richard Noneby',
      phone: 'Viola17@Bogan.com',
      address: '323 Rita Street Suite 521 East Samsonmouth, ND 62494');
  final searchables = [
    one,
    two,
    three,
    four,
  ];

  final mac = Searchable(name: "Mac");
  final macdonaldDouglas = Searchable(name: "Macdonald Douglas");
  final bigMacGruber = Searchable(name: "Big Mac", address: "Gruber");

  test("When isMatchAll = true, natural sorting is retained", () async {
    final List<Searchable> matches = await FullTextSearch<Searchable>(
        term: "John",
        items: searchables,
        isMatchAll: true,
        tokenize: (s) => [s.name, s.phone, s.address]).findResults();
    expect(matches, containsAll([one, two, three]));
  });

  test("When isMatchAll = false, we sort by numTokens correctly", () async {
    final List<TermSearchResult<Searchable>> matches2 =
        await FullTextSearch<Searchable>(
            term: "John",
            items: searchables,
            isMatchAll: false,
            isStartsWith: false,
            tokenize: (s) => [s.name, s.phone, s.address]).execute();
    expect(
        matches2.map((_) => _.result), containsAllInOrder([two, one, three]));
  });

  test("When isMatchAll = false, we sort by numTerms correctly", () async {
    final List<Searchable> matches = await FullTextSearch<Searchable>(
        term: "Joe John Johnson",
        items: searchables,
        isMatchAll: false,
        tokenize: (s) => [s.name, s.phone, s.address]).findResults();
    expect(matches, containsAllInOrder([two, one, three]));
  });

  test(
      "When isMatchAll = false, applies proper weights for partial matches (2 term)",
      () async {
    final matches = await FullTextSearch<Searchable>(
        term: "Mac G",
        items: [bigMacGruber, macdonaldDouglas, mac],
        isMatchAll: false,
        isStartsWith: false,
        tokenize: (s) => [s.name]).execute();
    expect(matches[1].result, macdonaldDouglas);
    expect(matches[2].result, bigMacGruber);
    expect(matches[0].result, mac);
  });

  test("When isMatchAll = false, applies proper weights for partial matches",
      () async {
    final matches = await FullTextSearch<Searchable>(
        term: "Mac",
        items: [bigMacGruber, macdonaldDouglas, mac],
        isMatchAll: false,
        isStartsWith: false,
        tokenize: (s) => [s.name]).execute();
    expect(matches[0].result, mac);
    expect(matches[1].result, macdonaldDouglas);
    expect(matches[2].result, bigMacGruber);
  });

  test("When isMatchAll = false, we sort by numTerms correctly", () async {
    final matches = await FullTextSearch<Searchable>(
        term: "Joe John Johnson",
        items: searchables,
        isMatchAll: false,
        tokenize: (s) => [s.name, s.phone, s.address]).execute();

    expect(matches.map((r) => r.result), containsAllInOrder([two, one, three]));
  });
}

class Searchable {
  final String? name;
  final String? phone;
  final String? address;

  Searchable({this.name, this.phone, this.address});

  @override
  String toString() => "$name:$phone:$address";
}
