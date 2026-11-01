import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const bg = Color(0xFF080D19);
const panel = Color(0xFF121B2D);
const muted = Color(0xFF8C9AB5);
const blue = Color(0xFF6C8CFF);
const green = Color(0xFF36D6A0);
const red = Color(0xFFFF718B);

final money = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const CatatKuApp());
}

class CatatKuApp extends StatelessWidget {
  const CatatKuApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CatatKu',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark),
      useMaterial3: true,
      fontFamily: 'Roboto',
    ),
    home: const HomePage(),
  );
}

class Tx {
  final int? id;
  final String title, category, type, note;
  final int amount;
  final DateTime date;
  Tx({this.id, required this.title, required this.category, required this.type,
    required this.amount, required this.date, this.note = ''});
  Map<String, Object?> toMap() => {
    'id': id, 'title': title, 'category': category, 'type': type,
    'amount': amount, 'date': date.toIso8601String(), 'note': note,
  };
  factory Tx.fromMap(Map<String, Object?> m) => Tx(
    id: m['id'] as int, title: m['title'] as String,
    category: m['category'] as String, type: m['type'] as String,
    amount: m['amount'] as int, date: DateTime.parse(m['date'] as String),
    note: (m['note'] ?? '') as String,
  );
}

class Store {
  Store._();
  static final Store instance = Store._();
  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'catatku.db');
    _db = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('''CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL, category TEXT NOT NULL, type TEXT NOT NULL,
        amount INTEGER NOT NULL, date TEXT NOT NULL, note TEXT NOT NULL
      )''');
    });
    return _db!;
  }
  Future<List<Tx>> all() async {
    final rows = await (await db).query('transactions', orderBy: 'date DESC, id DESC');
    return rows.map(Tx.fromMap).toList();
  }
  Future<void> add(Tx tx) async => (await db).insert('transactions', tx.toMap());
  Future<void> delete(int id) async => (await db).delete('transactions', where: 'id=?', whereArgs: [id]);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Tx> items = [];
  bool loading = true;
  int monthOffset = 0;
  String filter = 'Semua';

  DateTime get month => DateTime(DateTime.now().year, DateTime.now().month + monthOffset, 1);
  List<Tx> get monthly => items.where((t) => t.date.year == month.year && t.date.month == month.month).toList();
  int get income => monthly.where((t) => t.type == 'income').fold(0, (a, b) => a + b.amount);
  int get expense => monthly.where((t) => t.type == 'expense').fold(0, (a, b) => a + b.amount);
  int get balance => items.fold(0, (a, b) => a + (b.type == 'income' ? b.amount : -b.amount));
  List<Tx> get visible {
    final source = filter == 'Semua' ? items : items.where((t) => t.type == (filter == 'Masuk' ? 'income' : 'expense')).toList();
    return source;
  }

  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    final data = await Store.instance.all();
    if (mounted) setState(() { items = data; loading = false; });
  }

  Future<void> addTx() async {
    final result = await showModalBottomSheet<Tx>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionSheet(),
    );
    if (result != null) { await Store.instance.add(result); await refresh(); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator()) :
        RefreshIndicator(onRefresh: refresh, child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [blue, Color(0xFF9B72FF)])),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CatatKu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                Text('Keuangan lebih teratur', style: TextStyle(color: muted, fontSize: 12)),
              ])),
              IconButton(onPressed: () => setState(() => monthOffset = 0), icon: const Icon(Icons.calendar_month_rounded, color: muted)),
            ]),
            const SizedBox(height: 24),
            GlassCard(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF263D76), Color(0xFF182442), Color(0xFF171D32)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Text('TOTAL SALDO', style: TextStyle(color: Color(0xFFCFD9F4), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.more_horiz, color: Colors.white70)]),
                const SizedBox(height: 9),
                FittedBox(alignment: Alignment.centerLeft, child: Text(money.format(balance), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800))),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: _balanceMini('Pemasukan', income, green, Icons.south_west_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _balanceMini('Pengeluaran', expense, red, Icons.north_east_rounded)),
                ]),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: Text('Ringkasan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              _monthPicker(),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard('Masuk', income, green, Icons.trending_up_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Keluar', expense, red, Icons.trending_down_rounded)),
            ]),
            const SizedBox(height: 22),
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Arus kas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: blue.withOpacity(.13), borderRadius: BorderRadius.circular(20)),
                  child: Text(DateFormat('MMM yyyy','id_ID').format(month), style: const TextStyle(color: Color(0xFFB6C5FF), fontSize: 11))),
              ]),
              const SizedBox(height: 8),
              SizedBox(height: 155, child: _chart()),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legend(green, 'Pemasukan'), const SizedBox(width: 18), _legend(red, 'Pengeluaran'),
              ]),
            ])),
            const SizedBox(height: 22),
            Row(children: [
              const Expanded(child: Text('Transaksi terbaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => setState(() => filter = filter == 'Semua' ? 'Masuk' : filter == 'Masuk' ? 'Keluar' : 'Semua'),
                child: Text(filter, style: const TextStyle(color: Color(0xFF9FB2FF)))),
            ]),
            if (visible.isEmpty)
              GlassCard(child: const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Column(children: [
                Icon(Icons.receipt_long_rounded, color: muted, size: 32), SizedBox(height: 8),
                Text('Belum ada transaksi', style: TextStyle(color: muted)),
                Text('Tekan tombol + untuk mencatat transaksi', style: TextStyle(color: muted, fontSize: 11)),
              ]))))
            else ...visible.take(30).map(_txTile),
          ],
        ))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addTx, backgroundColor: blue, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: const Text('Catat transaksi', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _balanceMini(String label, int value, Color color, IconData icon) => Row(children: [
    Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withOpacity(.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 17)),
    const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFFB7C4E2), fontSize: 10)),
      FittedBox(alignment: Alignment.centerLeft, child: Text(money.format(value), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800))),
    ])),
  ]);

  Widget _statCard(String title, int value, Color color, IconData icon) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 17), const SizedBox(width: 6), Text(title, style: const TextStyle(color: muted, fontSize: 12))]),
      const SizedBox(height: 10),
      FittedBox(alignment: Alignment.centerLeft, child: Text(money.format(value), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color))),
    ]),
  );

  Widget _monthPicker() => Row(children: [
    IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => monthOffset--), icon: const Icon(Icons.chevron_left, size: 20, color: muted)),
    Text(DateFormat('MMMM yyyy','id_ID').format(month), style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
    IconButton(visualDensity: VisualDensity.compact, onPressed: monthOffset >= 0 ? null : () => setState(() => monthOffset++), icon: const Icon(Icons.chevron_right, size: 20, color: muted)),
  ]);

  Widget _chart() {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final spotsIn = <FlSpot>[], spotsOut = <FlSpot>[];
    for (int d = 1; d <= days; d++) {
      final dayItems = monthly.where((t) => t.date.day == d);
      spotsIn.add(FlSpot(d.toDouble(), dayItems.where((t) => t.type == 'income').fold(0, (a,t)=>a+t.amount).toDouble()));
      spotsOut.add(FlSpot(d.toDouble(), dayItems.where((t) => t.type == 'expense').fold(0, (a,t)=>a+t.amount).toDouble()));
    }
    final maxY = [...spotsIn, ...spotsOut].fold<double>(0, (m,s) => s.y > m ? s.y : m);
    return LineChart(LineChartData(
      minY: 0, maxY: maxY == 0 ? 100 : maxY * 1.25,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(.06), dashArray: [4,4])),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: maxY <= 0 ? 1 : maxY * 1.25 / 3,
          getTitlesWidget: (v,_) => Text(v == 0 ? '0' : NumberFormat.compact(locale:'id_ID').format(v), style: const TextStyle(color: muted, fontSize: 9)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5, getTitlesWidget: (v,_) => Text(v.toInt().toString(), style: const TextStyle(color: muted, fontSize: 9)))),
      ),
      lineTouchData: const LineTouchData(enabled: true),
      lineBarsData: [
        _line(spotsIn, green), _line(spotsOut, red),
      ],
    ));
  }
  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots, isCurved: true, preventCurveOverShooting: true, barWidth: 2.5,
    color: color, dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withOpacity(.07)),
  );
  Widget _legend(Color color, String label) => Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: const TextStyle(color: muted, fontSize: 10))]);

  Widget _txTile(Tx tx) => Dismissible(
    key: ValueKey(tx.id), direction: DismissDirection.endToStart,
    background: Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.only(right: 18), alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: red.withOpacity(.15), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.delete_outline, color: red)),
    confirmDismiss: (_) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: panel, title: const Text('Hapus transaksi?'), content: const Text('Transaksi ini akan dihapus permanen dari perangkat.'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Batal')), TextButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Hapus', style: TextStyle(color:red)))],
    )) ?? false,
    onDismissed: (_) async { await Store.instance.delete(tx.id!); await refresh(); },
    child: GlassCard(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: (tx.type == 'income' ? green : red).withOpacity(.12), borderRadius: BorderRadius.circular(13)),
        child: Icon(_categoryIcon(tx.category), color: tx.type == 'income' ? green : red, size: 20)),
      const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 3), Text('${tx.category} • ${dateFmt.format(tx.date)}', style: const TextStyle(color: muted, fontSize: 10)),
      ])),
      const SizedBox(width: 8), Text('${tx.type == 'income' ? '+' : '-'}${money.format(tx.amount)}',
        style: TextStyle(color: tx.type == 'income' ? green : red, fontWeight: FontWeight.w800, fontSize: 12)),
    ])),
  );

  IconData _categoryIcon(String c) => switch(c) {
    'Makanan' => Icons.restaurant_rounded, 'Transportasi' => Icons.directions_car_rounded,
    'Belanja' => Icons.shopping_bag_rounded, 'Tagihan' => Icons.receipt_rounded,
    'Gaji' => Icons.work_rounded, 'Hadiah' => Icons.card_giftcard_rounded,
    'Kesehatan' => Icons.favorite_rounded, _ => Icons.category_rounded,
  };
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(17), this.gradient});
  @override Widget build(BuildContext context) => Container(
    padding: padding, decoration: BoxDecoration(
      gradient: gradient ?? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(.085), Colors.white.withOpacity(.025)]),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withOpacity(.10), width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 22, offset: const Offset(0, 12))],
    ), child: child,
  );
}

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});
  @override State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}
class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  String type = 'expense', category = 'Makanan';
  DateTime date = DateTime.now();
  final incomeCats = ['Gaji','Bonus','Hadiah','Investasi','Lainnya'];
  final expenseCats = ['Makanan','Transportasi','Belanja','Tagihan','Kesehatan','Hiburan','Pendidikan','Lainnya'];
  @override void dispose() { title.dispose(); amount.dispose(); note.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final cats = type == 'income' ? incomeCats : expenseCats;
    if (!cats.contains(category)) category = cats.first;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 22),
      decoration: const BoxDecoration(color: Color(0xFF10182A), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 20),
        const Text('Catat transaksi', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 17),
        Row(children: [
          Expanded(child: _typeButton('Pengeluaran','expense',red)),
          const SizedBox(width: 10), Expanded(child: _typeButton('Pemasukan','income',green)),
        ]),
        const SizedBox(height: 15),
        _field('Nama transaksi', title, 'Contoh: Makan siang'),
        const SizedBox(height: 12),
        _field('Nominal (Rp)', amount, 'Contoh: 25000', numeric: true),
        const SizedBox(height: 12),
        const Text('Kategori', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: category, dropdownColor: panel, decoration: _decoration(),
          items: cats.map((c)=>DropdownMenuItem(value:c, child:Text(c))).toList(),
          onChanged: (v)=>setState(()=>category=v!),
        ),
        const SizedBox(height: 12),
        const Text('Tanggal', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white12)),
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (picked != null) setState(()=>date=picked);
          },
          icon: const Icon(Icons.calendar_today_rounded, size: 17), label: Text(dateFmt.format(date)),
        ),
        const SizedBox(height: 12),
        _field('Catatan (opsional)', note, 'Tambahkan keterangan'),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          onPressed: () {
            if (!form.currentState!.validate()) return;
            final value = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
            if (value == null || value <= 0) return;
            Navigator.pop(context, Tx(title: title.text.trim(), category: category, type: type,
              amount: value, date: date, note: note.text.trim()));
          }, child: const Text('Simpan transaksi', style: TextStyle(fontWeight: FontWeight.w800)),
        )),
      ]))),
    );
  }
  Widget _typeButton(String label, String value, Color color) {
    final active = type == value;
    return OutlinedButton(
      onPressed: ()=>setState(()=>type=value),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? color.withOpacity(.13) : Colors.transparent,
        foregroundColor: active ? color : muted,
        side: BorderSide(color: active ? color.withOpacity(.6) : Colors.white12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ), child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
  InputDecoration _decoration() => InputDecoration(
    filled: true, fillColor: Colors.white.withOpacity(.045),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: Colors.white.withOpacity(.10))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: Colors.white.withOpacity(.10))),
  );
  Widget _field(String label, TextEditingController c, String hint, {bool numeric = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 7),
    TextFormField(controller: c, keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : [],
      style: const TextStyle(fontSize: 14), decoration: _decoration().copyWith(hintText: hint, hintStyle: const TextStyle(color: Colors.white30, fontSize: 13)),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Bagian ini wajib diisi' : null,
    ),
  ]);
}
