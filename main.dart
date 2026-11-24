import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ----------------------------- الإعدادات -----------------------------
const startTokens = 10;
const boxCost = 3;
const dailyReward = 5;

// (قيمة الجائزة، الوزن)
const prizes = <(int, double)>[
  (0, 45), (1, 25), (2, 15), (5, 8), (10, 5), (25, 1.5), (50, 0.5),
];

// (الاسم بالعربي، الاسم بالإنجليزي، السعر)
const titles = <(String, String, int)>[
  ('🥉 برونزي', '🥉 Bronze', 100),
  ('🥈 فضي', '🥈 Silver', 300),
  ('🥇 ذهبي', '🥇 Gold', 1000),
  ('💎 ماسي', '💎 Diamond', 3000),
];

const _t = {
  'ar': {
    'app': 'Techno-Point',
    'home': 'الصناديق',
    'rewards': 'المكافآت',
    'profile': 'حسابي',
    'balance': 'رصيدك',
    'tokens': 'توكن',
    'pick': 'اختر صندوقاً',
    'cost': 'التكلفة',
    'no_funds': 'رصيدك لا يكفي ❌',
    'won': 'ربحت',
    'empty': 'الصندوق فارغ هذه المرة 😅',
    'ok': 'تمام',
    'daily': 'المكافأة اليومية',
    'claim': 'استلم',
    'wait': 'متاحة بعد',
    'claimed': 'تم استلام المكافأة ✅',
    'ranks': 'الرتب',
    'owned': 'مملوكة',
    'bought': 'تمت الترقية 🎉',
    'boxes': 'صناديق مفتوحة',
    'best': 'أكبر جائزة',
    'rank': 'رتبتك',
    'lang': 'English',
    'reset': 'إعادة ضبط اللعبة',
    'note': 'التوكنات داخل اللعبة فقط ولا تمثل أموالاً حقيقية.',
  },
  'en': {
    'app': 'Techno-Point',
    'home': 'Boxes',
    'rewards': 'Rewards',
    'profile': 'Profile',
    'balance': 'Your balance',
    'tokens': 'tokens',
    'pick': 'Pick a box',
    'cost': 'Cost',
    'no_funds': 'Not enough tokens ❌',
    'won': 'You won',
    'empty': 'The box was empty 😅',
    'ok': 'OK',
    'daily': 'Daily reward',
    'claim': 'Claim',
    'wait': 'Available in',
    'claimed': 'Reward claimed ✅',
    'ranks': 'Ranks',
    'owned': 'Owned',
    'bought': 'Upgraded 🎉',
    'boxes': 'Boxes opened',
    'best': 'Best prize',
    'rank': 'Your rank',
    'lang': 'العربية',
    'reset': 'Reset game',
    'note': 'Tokens exist only inside the game and have no real-money value.',
  },
};

// ------------------------------ حالة اللعبة ------------------------------
class Game extends ChangeNotifier {
  Game(this.p);
  final SharedPreferences p;
  final _rng = Random();

  int get tokens => p.getInt('tokens') ?? startTokens;
  int get boxes => p.getInt('boxes') ?? 0;
  int get best => p.getInt('best') ?? 0;
  int get level => p.getInt('level') ?? 0;
  int get lastDaily => p.getInt('lastDaily') ?? 0;
  String get lang => p.getString('lang') ?? 'ar';

  String s(String k) => _t[lang]![k]!;
  String titleName(int i) => lang == 'ar' ? titles[i].$1 : titles[i].$2;

  Duration get dailyWait {
    final end = lastDaily + const Duration(hours: 24).inMilliseconds;
    final left = end - DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: left > 0 ? left : 0);
  }

  bool get canClaim => dailyWait == Duration.zero;

  Future<void> _set(String k, int v) => p.setInt(k, v);

  /// يفتح صندوق. يرجع قيمة الجائزة أو null لو الرصيد لا يكفي.
  Future<int?> openBox() async {
    if (tokens < boxCost) return null;
    final total = prizes.fold<double>(0, (a, e) => a + e.$2);
    var x = _rng.nextDouble() * total;
    var prize = 0;
    for (final e in prizes) {
      x -= e.$2;
      if (x < 0) {
        prize = e.$1;
        break;
      }
    }
    await _set('tokens', tokens - boxCost + prize);
    await _set('boxes', boxes + 1);
    if (prize > best) await _set('best', prize);
    notifyListeners();
    return prize;
  }

  Future<void> claimDaily() async {
    if (!canClaim) return;
    await _set('tokens', tokens + dailyReward);
    await _set('lastDaily', DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<bool> buyTitle(int i) async {
    if (level > i || tokens < titles[i].$3) return false;
    await _set('tokens', tokens - titles[i].$3);
    await _set('level', i + 1);
    notifyListeners();
    return true;
  }

  Future<void> toggleLang() async {
    await p.setString('lang', lang == 'ar' ? 'en' : 'ar');
    notifyListeners();
  }

  Future<void> reset() async {
    final l = lang;
    await p.clear();
    await p.setString('lang', l);
    notifyListeners();
  }
}

// --------------------------------- التطبيق ---------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(QuestApp(game: Game(prefs)));
}

class QuestApp extends StatelessWidget {
  const QuestApp({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (_, __) => MaterialApp(
        title: 'Techno-Point',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7C4DFF),
        ),
        builder: (ctx, child) => Directionality(
          textDirection: game.lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        home: HomeShell(game: game),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.game});
  final Game game;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final pages = [BoxesPage(game: g), RewardsPage(game: g), ProfilePage(game: g)];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/icon.png', width: 34, height: 34),
            ),
            const SizedBox(width: 10),
            Text(g.s('app')),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Chip(label: Text('🪙 ${g.tokens}')),
            ),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.inventory_2), label: g.s('home')),
          NavigationDestination(icon: const Icon(Icons.card_giftcard), label: g.s('rewards')),
          NavigationDestination(icon: const Icon(Icons.person), label: g.s('profile')),
        ],
      ),
    );
  }
}

// -------------------------------- الصناديق --------------------------------
class BoxesPage extends StatelessWidget {
  const BoxesPage({super.key, required this.game});
  final Game game;

  Future<void> _open(BuildContext context) async {
    final prize = await game.openBox();
    if (!context.mounted) return;
    if (prize == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(game.s('no_funds'))));
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(prize > 0 ? '🎉' : '📭', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                prize > 0
                    ? '${game.s('won')} $prize ${game.s('tokens')}'
                    : game.s('empty'),
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(game.s('ok')))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(game.s('balance')),
                Text('🪙 ${game.tokens}',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                Text('${game.s('cost')}: $boxCost ${game.s('tokens')}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(game.s('pick'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _open(context),
                  child: Ink(
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                        child: Text('🎁', style: TextStyle(fontSize: 44))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------- المكافآت --------------------------------
class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key, required this.game});
  final Game game;
  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  String _fmt(Duration d) =>
      '${d.inHours}h ${d.inMinutes.remainder(60)}m';

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Text('🎁', style: TextStyle(fontSize: 32)),
            title: Text('${g.s('daily')} (+$dailyReward)'),
            subtitle: Text(g.canClaim
                ? g.s('claim')
                : '${g.s('wait')} ${_fmt(g.dailyWait)}'),
            trailing: FilledButton(
              onPressed: g.canClaim
                  ? () async {
                      await g.claimDaily();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(g.s('claimed'))));
                    }
                  : null,
              child: Text(g.s('claim')),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(g.s('ranks'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (var i = 0; i < titles.length; i++)
          Card(
            child: ListTile(
              title: Text(g.titleName(i)),
              subtitle: Text('${titles[i].$3} 🪙'),
              trailing: g.level > i
                  ? Text(g.s('owned'))
                  : FilledButton.tonal(
                      onPressed: () async {
                        final ok = await g.buyTitle(i);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(ok ? g.s('bought') : g.s('no_funds'))));
                      },
                      child: const Text('🪙'),
                    ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------- حسابي ----------------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.game});
  final Game game;

  @override
  Widget build(BuildContext context) {
    final g = game;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                  title: Text(g.s('rank')),
                  trailing:
                      Text(g.level > 0 ? g.titleName(g.level - 1) : '—')),
              ListTile(title: Text(g.s('boxes')), trailing: Text('${g.boxes}')),
              ListTile(
                  title: Text(g.s('best')),
                  trailing: Text('${g.best} 🪙')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(onPressed: g.toggleLang, child: Text(g.s('lang'))),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: g.reset, child: Text(g.s('reset'))),
        const SizedBox(height: 24),
        Text(g.s('note'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
