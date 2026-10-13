import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ضع هنا بيانات مشروعك من Supabase (Project Settings > API)
const supabaseUrl = 'https://bilgzpjavnjtzjswzets.supabase.co';
const supabaseKey = 'sb_publishable_sQG7syqn_o3gO86rhqatzg_5L3uuFzq';
SupabaseClient get sb => Supabase.instance.client;

const types = ['لابتوب', 'كمبيوتر مكتبي', 'قطع وملحقات'];
const conds = ['مستعمل', 'جديد'];
const currencies = ['دولار', 'ليرة سورية'];
const cities = ['دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس', 'إدلب', 'دير الزور', 'الحسكة', 'الرقة', 'درعا', 'السويداء', 'القنيطرة'];

String latin(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var o = s;
  for (var i = 0; i < 10; i++) {
    o = o.replaceAll(ar[i], '$i');
  }
  return o;
}

String fmt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

class Ad {
  final Map<String, dynamic> m;
  Ad(this.m);
  String s(String k) => (m[k] ?? '') as String;
  String get id => s('id');
  int get price => (m['price'] as num).toInt();
  bool get sold => m['sold'] == true;
  bool get mine => m['owner'] != null && m['owner'] == sb.auth.currentUser?.id;
  Ad copy({bool? sold}) => Ad({...m, 'sold': sold ?? this.sold});
  String get priceText {
    final cur = s('currency') == 'دولار' ? '\$' : 'ل.س';
    return '${fmt(price)} $cur';
  }

  String get post {
    final l = <String>['💻 للبيع: ${s('title')}', '📌 ${s('type')} - ${s('cond')}'];
    final specs = {'المعالج': s('cpu'), 'الرام': s('ram'), 'التخزين': s('storage')};
    for (final e in specs.entries) {
      if (e.value.isNotEmpty) l.add('⚙️ ${e.key}: ${e.value}');
    }
    if (s('descr').isNotEmpty) l.add('📝 ${s('descr')}');
    l.add('💰 السعر: $priceText');
    l.add('📍 المدينة: ${s('city')}');
    l.add('📞 للتواصل: ${s('phone')}');
    return l.join('\n');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  try {
    if (sb.auth.currentSession == null) await sb.auth.signInAnonymously();
  } catch (_) {}
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'سوق الكمبيوتر',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0E7C66)),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Ad> ads = [];
  String q = '';
  String? type, city;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  void toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> load() async {
    try {
      final rows = await sb.from('ads').select().order('created_at', ascending: false);
      ads = (rows as List).map((e) => Ad(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      if (mounted) toast('تعذّر تحميل الإعلانات، تحقق من الإنترنت');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final a = await Navigator.push<Ad>(context, MaterialPageRoute(builder: (_) => const FormPage()));
    if (a == null) return;
    try {
      await sb.from('ads').insert(a.m);
      await load();
    } catch (_) {
      if (mounted) toast('تعذّر نشر الإعلان');
    }
  }

  Future<void> update(Ad a) async {
    try {
      await sb.from('ads').update(a.m).eq('id', a.id);
      await load();
    } catch (_) {
      if (mounted) toast('تعذّر حفظ التعديل');
    }
  }

  Future<void> remove(String id) async {
    try {
      await sb.from('ads').delete().eq('id', id);
      await load();
    } catch (_) {
      if (mounted) toast('تعذّر حذف الإعلان');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = ads.where((a) {
      if (type != null && a.s('type') != type) return false;
      if (city != null && a.s('city') != city) return false;
      final hay = '${a.s('title')} ${a.s('cpu')} ${a.s('ram')} ${a.s('storage')} ${a.s('descr')}'.toLowerCase();
      return q.isEmpty || hay.contains(q.toLowerCase());
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('سوق الكمبيوتر السوري'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('أضف إعلان')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  onChanged: (v) => setState(() => q = latin(v.trim())),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث: لينوفو، i5، 8GB ...', border: OutlineInputBorder()),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                  for (final t in <String?>[null, ...types])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(label: Text(t ?? 'الكل'), selected: type == t, onSelected: (_) => setState(() => type = t)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: city,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('كل المدن')),
                    ...cities.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                  ],
                  onChanged: (v) => setState(() => city = v),
                ),
              ),
              Expanded(
                child: f.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد إعلانات. اضغط "أضف إعلان" لنشر أول إعلان.', textAlign: TextAlign.center)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: f.length,
                        itemBuilder: (_, i) {
                          final a = f[i];
                          final specs = [a.s('cpu'), a.s('ram'), a.s('storage')].where((e) => e.isNotEmpty).join(' • ');
                          return Opacity(
                            opacity: a.sold ? .55 : 1,
                            child: Card(
                              child: ListTile(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(ad: a, onUpdate: update, onDelete: remove))),
                                title: Text(a.s('title'), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${a.s('type')} • ${a.s('cond')} • ${a.s('city')}${specs.isEmpty ? '' : '\n$specs'}'),
                                isThreeLine: specs.isNotEmpty,
                                trailing: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(a.priceText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (a.sold) const Text('تم البيع', style: TextStyle(color: Colors.red)),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

class DetailPage extends StatefulWidget {
  final Ad ad;
  final void Function(Ad) onUpdate;
  final void Function(String) onDelete;
  const DetailPage({super.key, required this.ad, required this.onUpdate, required this.onDelete});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Ad ad = widget.ad;

  void toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> edit() async {
    final r = await Navigator.push<Ad>(context, MaterialPageRoute(builder: (_) => FormPage(ad: ad)));
    if (r != null) {
      setState(() => ad = r);
      widget.onUpdate(r);
    }
  }

  Future<void> del() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      widget.onDelete(ad.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> wa() async {
    var d = latin(ad.s('phone')).replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) {
      d = d.substring(2);
    } else if (d.startsWith('0')) {
      d = '963${d.substring(1)}';
    }
    try {
      await launchUrl(Uri.parse('https://wa.me/$d'), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) toast('تعذّر فتح واتساب');
    }
  }

  Widget row(String k, String v) => v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 90, child: Text(k, style: TextStyle(color: Colors.grey[700]))),
            Expanded(child: Text(v)),
          ]),
        );

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الإعلان'), actions: !ad.mine ? null : [
        IconButton(onPressed: edit, icon: const Icon(Icons.edit)),
        IconButton(onPressed: del, icon: const Icon(Icons.delete_outline)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(ad.s('title'), style: th.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(ad.priceText, style: th.textTheme.titleLarge?.copyWith(color: th.colorScheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        row('النوع', ad.s('type')),
        row('الحالة', ad.s('cond')),
        row('المعالج', ad.s('cpu')),
        row('الرام', ad.s('ram')),
        row('التخزين', ad.s('storage')),
        row('المدينة', ad.s('city')),
        row('الهاتف', ad.s('phone')),
        row('الوصف', ad.s('descr')),
        const Divider(height: 32),
        FilledButton.icon(onPressed: wa, icon: const Icon(Icons.chat), label: const Text('تواصل عبر واتساب')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: ad.post));
            if (mounted) toast('تم نسخ نص الإعلان، الصقه في مجموعة فيسبوك');
          },
          icon: const Icon(Icons.copy),
          label: const Text('نسخ نص الإعلان للصقه في مجموعة'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => Share.share(ad.post), icon: const Icon(Icons.share), label: const Text('مشاركة الإعلان')),
        SwitchListTile(
          title: const Text('تم البيع'),
          value: ad.sold,
          onChanged: !ad.mine ? null : (v) {
            final n = ad.copy(sold: v);
            setState(() => ad = n);
            widget.onUpdate(n);
          },
        ),
      ]),
    );
  }
}

class FormPage extends StatefulWidget {
  final Ad? ad;
  const FormPage({super.key, this.ad});
  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final key = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.ad?.s('title'));
  late final cpu = TextEditingController(text: widget.ad?.s('cpu'));
  late final ram = TextEditingController(text: widget.ad?.s('ram'));
  late final storage = TextEditingController(text: widget.ad?.s('storage'));
  late final price = TextEditingController(text: widget.ad?.price.toString());
  late final phone = TextEditingController(text: widget.ad?.s('phone'));
  late final desc = TextEditingController(text: widget.ad?.s('descr'));
  late String type = widget.ad?.s('type') ?? types[0];
  late String cond = widget.ad?.s('cond') ?? conds[0];
  late String city = widget.ad?.s('city') ?? cities[0];
  late String currency = widget.ad?.s('currency') ?? currencies[0];

  @override
  void dispose() {
    for (final c in [title, cpu, ram, storage, price, phone, desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget tf(String label, TextEditingController c, {bool req = false, TextInputType? kt, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: kt,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null : null,
        ),
      );

  Widget dd(String label, String v, List<String> items, void Function(String) f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: v,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (x) {
            if (x != null) setState(() => f(x));
          },
        ),
      );

  void submit() {
    if (!key.currentState!.validate()) return;
    final p = int.tryParse(latin(price.text).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    Navigator.pop(
      context,
      Ad({
        ...?widget.ad?.m,
        'title': title.text.trim(),
        'type': type,
        'cond': cond,
        'cpu': cpu.text.trim(),
        'ram': ram.text.trim(),
        'storage': storage.text.trim(),
        'city': city,
        'phone': latin(phone.text.trim()),
        'descr': desc.text.trim(),
        'currency': currency,
        'price': p,
        'sold': widget.ad?.sold ?? false,
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.ad == null ? 'إعلان جديد' : 'تعديل الإعلان')),
        body: Form(
          key: key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            tf('عنوان الإعلان (مثال: لابتوب HP ProBook)', title, req: true),
            dd('النوع', type, types, (x) => type = x),
            dd('الحالة', cond, conds, (x) => cond = x),
            tf('المعالج (مثال: Core i5 الجيل 8)', cpu),
            tf('الرام (مثال: 8GB)', ram),
            tf('التخزين (مثال: SSD 256GB)', storage),
            Row(children: [
              Expanded(flex: 3, child: tf('السعر', price, req: true, kt: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: dd('العملة', currency, currencies, (x) => currency = x)),
            ]),
            dd('المدينة', city, cities, (x) => city = x),
            tf('رقم الهاتف / واتساب', phone, req: true, kt: TextInputType.phone),
            tf('وصف إضافي', desc, lines: 3),
            FilledButton(onPressed: submit, child: const Text('حفظ الإعلان')),
          ]),
        ),
      );
}
