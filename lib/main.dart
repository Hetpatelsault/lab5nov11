import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ------------------------------------------------------------
/// DATA SOURCES
/// ------------------------------------------------------------
const String kDataUrl =
    'https://nawazchowdhury.github.io/pokemontcg/api.json';
const String kPtcgApiTwoRandom =
    'https://api.pokemontcg.io/v2/cards?pageSize=2&random=true';
const String? kPtcgApiKey = null;

void main() => runApp(const MyApp());

/// ------------------------------------------------------------
/// ROOT APP
/// ------------------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Battle (Clean)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blueGrey[800],
        scaffoldBackgroundColor: Colors.grey[50],
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.indigo,
        ).copyWith(secondary: Colors.tealAccent[400]),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          shadowColor: Colors.grey[300],
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const BattlePage(),
    );
  }
}

/// ------------------------------------------------------------
/// MODEL
/// ------------------------------------------------------------
class PokemonBattleCard {
  final String name;
  final String? smallImage;
  final String? largeImage;
  final int hp;

  PokemonBattleCard({
    required this.name,
    required this.smallImage,
    required this.largeImage,
    required this.hp,
  });

  factory PokemonBattleCard.fromJson(Map<String, dynamic> json) {
    final img = json['images'] ?? {};
    final hpString = (json['hp'] ?? '0').toString();
    final hp = int.tryParse(hpString.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    return PokemonBattleCard(
      name: json['name'] ?? 'Unknown',
      smallImage: img['small'],
      largeImage: img['large'],
      hp: hp,
    );
  }
}

/// ------------------------------------------------------------
/// SERVICE (with fallback)
/// ------------------------------------------------------------
class PokemonApiService {
  static const _maxAttempts = 3;
  static Duration _backoff(int a) => Duration(milliseconds: 600 * (1 << a));

  static int _hpFromId(String id) {
    final sum = id.codeUnits.fold<int>(0, (a, b) => a + b);
    return 40 + (sum % 150);
  }

  static Future<({List<PokemonBattleCard> cards, bool fromFallback})>
      fetchTwoRandom() async {
    final headers = <String, String>{};
    if (kPtcgApiKey != null && kPtcgApiKey!.isNotEmpty) {
      headers['X-Api-Key'] = kPtcgApiKey!;
    }

    // Try official API
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final resp = await http
            .get(Uri.parse(kPtcgApiTwoRandom), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body)['data'] as List;
          final cards =
              data.map((e) => PokemonBattleCard.fromJson(e)).take(2).toList();
          return (cards: cards, fromFallback: false);
        }
      } catch (_) {
        if (attempt < _maxAttempts - 1) await Future.delayed(_backoff(attempt));
      }
    }

    // Local fallback
    final local = await _fetchLocal();
    local.shuffle();
    final picked = local.take(2).toList();
    final fallbackCards = picked.map((c) {
      final hp = _hpFromId(c.name);
      return PokemonBattleCard(
        name: c.name,
        smallImage: c.smallImage,
        largeImage: c.largeImage,
        hp: hp,
      );
    }).toList();
    return (cards: fallbackCards, fromFallback: true);
  }

  static Future<List<PokemonBattleCard>> _fetchLocal() async {
    final resp = await http.get(Uri.parse(kDataUrl));
    final parsed = json.decode(resp.body);
    final list = parsed is List ? parsed : parsed['data'];
    return (list as List)
        .map((e) => PokemonBattleCard.fromJson(e))
        .toList();
  }
}

/// ------------------------------------------------------------
/// BATTLE PAGE (minimal layout)
/// ------------------------------------------------------------
class BattlePage extends StatefulWidget {
  const BattlePage({super.key});

  @override
  State<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends State<BattlePage> {
  PokemonBattleCard? _left;
  PokemonBattleCard? _right;
  bool _loading = true;
  String? _error;
  bool _usedFallback = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await PokemonApiService.fetchTwoRandom();
      setState(() {
        _left = result.cards[0];
        _right = result.cards[1];
        _usedFallback = result.fromFallback;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _winnerText() {
    if (_left == null || _right == null) return '';
    if (_left!.hp == _right!.hp) return 'It\'s a Draw!';
    return _left!.hp > _right!.hp
        ? '${_left!.name} wins!'
        : '${_right!.name} wins!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pokémon Battle of HP')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _battleView(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        onPressed: _loadCards,
        label: const Text('Draw Again'),
        icon: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _battleView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pokeCard(_left),
                const SizedBox(width: 10),
                const Center(
                  child: Text('VS',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                _pokeCard(_right),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _winnerText(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (_usedFallback)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(label: Text('BATTLE')),
            ),
        ],
      ),
    );
  }

  Widget _pokeCard(PokemonBattleCard? card) {
    if (card == null) return const SizedBox.shrink();
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(6),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(
                child: Image.network(
                  card.smallImage ?? '',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported, size: 60),
                ),
              ),
              const SizedBox(height: 6),
              Text(card.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              Text('HP: ${card.hp}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 10),
            const Text('Something went wrong'),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _loadCards, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
