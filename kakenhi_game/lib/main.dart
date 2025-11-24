import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- データモデル ---
class CardData {
  final int id;
  final String top; // 研究キーワード
  final String middle; // 接続詞・修飾語
  final String bottom; // 締めの言葉

  CardData({required this.id, required this.top, required this.middle, required this.bottom});

  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      id: json['id'],
      top: json['top'],
      middle: json['middle'] ?? "",
      bottom: json['bottom'],
    );
  }
}

class Player {
  String name;
  List<CardData> hand = [];
  List<CardData> selectedCards = []; // 選んで並べたカード
  
  Player({required this.name});
  
  String get fullTitle {
    // 選んだカードをつなげてタイトルにする
    if (selectedCards.isEmpty) return "（未作成）";
    return selectedCards.map((card) => "${card.top}${card.middle}${card.bottom}").join("");
  }
}

void main() {
  runApp(const KakenhiGameApp());
}

class KakenhiGameApp extends StatelessWidget {
  const KakenhiGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '科研費ゲーム',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto', // 日本語フォントが化ける場合はここを調整
      ),
      home: const SetupScreen(),
    );
  }
}

// --- 画面1: プレイヤー設定 ---
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int playerCount = 3; // デフォルト3人
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  void _updateControllers() {
    // 人数に合わせて入力欄を増減
    while (_controllers.length < playerCount) {
      _controllers.add(TextEditingController(text: "プレイヤー${_controllers.length + 1}"));
    }
    while (_controllers.length > playerCount) {
      _controllers.removeLast();
    }
  }

  Future<void> _startGame() async {
    // JSONデータの読み込み
    final String response = await rootBundle.loadString('assets/cards.json');
    final List<dynamic> data = json.decode(response);
    List<CardData> deck = data.map((json) => CardData.fromJson(json)).toList();

    // シャッフル
    deck.shuffle(Random());

    // プレイヤー作成と手札配り（各6枚）
    List<Player> players = [];
    for (int i = 0; i < playerCount; i++) {
      Player p = Player(name: _controllers[i].text);
      // 山札から6枚引く
      for (int j = 0; j < 6; j++) {
        if (deck.isNotEmpty) {
          p.hand.add(deck.removeLast());
        }
      }
      players.add(p);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameLoopScreen(players: players)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("科研費ゲーム - 設定")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("プレイヤー人数を選択", style: TextStyle(fontSize: 18)),
            Slider(
              value: playerCount.toDouble(),
              min: 3,
              max: 6,
              divisions: 3,
              label: "$playerCount人",
              onChanged: (val) {
                setState(() {
                  playerCount = val.toInt();
                  _updateControllers();
                });
              },
            ),
            Expanded(
              child: ListView.builder(
                itemCount: playerCount,
                itemBuilder: (context, index) {
                  return TextField(
                    controller: _controllers[index],
                    decoration: InputDecoration(labelText: "プレイヤー ${index + 1} の名前"),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("ゲーム開始！", style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 画面2: ゲームループ（端末を回す -> タイトル作成） ---
class GameLoopScreen extends StatefulWidget {
  final List<Player> players;
  const GameLoopScreen({super.key, required this.players});

  @override
  State<GameLoopScreen> createState() => _GameLoopScreenState();
}

class _GameLoopScreenState extends State<GameLoopScreen> {
  int currentPlayerIndex = 0;
  bool isPassing = true; // 「次の人に渡してください」画面かどうか

  void _nextPlayer() {
    if (currentPlayerIndex < widget.players.length - 1) {
      setState(() {
        currentPlayerIndex++;
        isPassing = true;
      });
    } else {
      // 全員終了 -> 結果発表画面へ
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ResultScreen(players: widget.players)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Player player = widget.players[currentPlayerIndex];

    if (isPassing) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("次は ${player.name} さんの番です", style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
              const Icon(Icons.phone_android, size: 100, color: Colors.blue),
              const SizedBox(height: 20),
              const Text("スマホを渡してください", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isPassing = false;
                  });
                },
                child: const Text("準備OK（自分の番です）"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("${player.name} のターン")),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("カードをタップしてタイトルを作成してください", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          // 選択済みエリア（タイトル）
          Container(
            height: 150,
            width: double.infinity,
            color: Colors.blue[50],
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("【研究課題名】", style: TextStyle(color: Colors.blue)),
                Expanded(
                  child: player.selectedCards.isEmpty
                      ? const Center(child: Text("ここをタップしたカードが入ります"))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: player.selectedCards.length,
                          itemBuilder: (context, index) {
                            final card = player.selectedCards[index];
                            return GestureDetector(
                              onTap: () {
                                // 選択解除（手札に戻す）
                                setState(() {
                                  player.selectedCards.removeAt(index);
                                  player.hand.add(card);
                                });
                              },
                              child: Card(
                                color: Colors.white,
                                elevation: 4,
                                child: Container(
                                  width: 100,
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(card.top, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(card.middle, style: const TextStyle(fontSize: 10)),
                                      Text(card.bottom, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const Divider(),
          // 手札エリア
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
              ),
              itemCount: player.hand.length,
              itemBuilder: (context, index) {
                final card = player.hand[index];
                return GestureDetector(
                  onTap: () {
                    // 手札から選択エリアへ移動
                    setState(() {
                      player.hand.removeAt(index);
                      player.selectedCards.add(card);
                    });
                  },
                  child: Card(
                    color: Colors.grey[100],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(card.top, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(card.middle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(card.bottom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 決定ボタン
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: player.selectedCards.isEmpty ? null : _nextPlayer,
                  child: const Text("これで決定！"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 画面3: 結果発表・プレゼン ---
class ResultScreen extends StatefulWidget {
  final List<Player> players;
  const ResultScreen({super.key, required this.players});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int? timerSeconds;
  Timer? _timer;
  int? activePlayerIndex; // 現在プレゼン中のプレイヤー

  void _startTimer(int index) {
    _timer?.cancel();
    setState(() {
      activePlayerIndex = index;
      timerSeconds = 30; // 30秒プレゼン
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (timerSeconds! > 0) {
            timerSeconds = timerSeconds! - 1;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showVoteDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("優勝者は誰？"),
          children: widget.players.map((p) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showWinner(p);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(p.name, style: const TextStyle(fontSize: 18)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showWinner(Player winner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("🎉 採択決定！ 🎉", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(winner.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("この研究課題に予算がつきました！"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ダイアログ閉じる
                Navigator.pop(context); // タイトル画面に戻る
              },
              child: const Text("タイトルへ戻る"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("プレゼン＆投票"),
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_vote),
            onPressed: _showVoteDialog,
            tooltip: "投票へ",
          )
        ],
      ),
      body: ListView.separated(
        itemCount: widget.players.length,
        separatorBuilder: (ctx, i) => const Divider(),
        itemBuilder: (context, index) {
          final p = widget.players[index];
          final isActive = (activePlayerIndex == index);

          // タイトル生成（カードを単純連結）
          // 実際はカードの中のどの言葉を使うか選ぶ必要がありますが、
          // 見た目のインパクト重視で、ここでは3段組みで表示します。
          return Card(
            margin: const EdgeInsets.all(8),
            color: isActive ? Colors.yellow[50] : Colors.white,
            shape: isActive ? RoundedRectangleBorder(side: const BorderSide(color: Colors.orange, width: 2), borderRadius: BorderRadius.circular(4)) : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (isActive)
                        Text("残り: ${timerSeconds}秒", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                      if (!isActive)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.timer),
                          label: const Text("プレゼン開始"),
                          onPressed: () => _startTimer(index),
                        )
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text("研究課題名：", style: TextStyle(color: Colors.grey)),
                  // 作成されたタイトルを表示
                  Wrap(
                    spacing: 4,
                    children: p.selectedCards.map((c) {
                      return Chip(
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.top, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(c.middle, style: const TextStyle(fontSize: 10)),
                            Text(c.bottom, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        backgroundColor: Colors.white,
                        elevation: 2,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
            icon: const Icon(Icons.check_circle),
            label: const Text("全員の発表終了 -> 投票へ", style: TextStyle(fontSize: 18)),
            onPressed: _showVoteDialog,
          ),
        ),
      ),
    );
  }
}