import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = 'https://bilgzpjavnjtzjswzets.supabase.co';
const supabaseKey = 'sb_publishable_sQG7syqn_o3gO86rhqatzg_5L3uuFzq';
SupabaseClient get sb => Supabase.instance.client;

const types = ['لابتوب', 'كمبيوتر مكتبي', 'قطع وملحقات'];
const typeIcons = [Icons.laptop_mac, Icons.desktop_windows, Icons.memory];
const typeColors = [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0891B2)];
const conds = ['مستعمل', 'جديد'];
const currencies = ['دولار', 'ليرة سورية'];
const cities = ['دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس', 'إدلب', 'دير الزور', 'الحسكة', 'الرقة', 'درعا', 'السويداء', 'القنيطرة'];

int ti(String t) {
  final i = types.indexOf(t);
  return i < 0 ? 0 : i;
}

String latin(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var o = s;
  for (var i = 0; i < 10; i++) {
    o = o.replaceAll(ar[i], '$i');
  }
  return o;
}

String fmt(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

Color cardColor(ColorScheme cs) => cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest;

void toast(BuildContext c, String m) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

String errText(Object e) => e.toString().split('\n').first;

Future<bool> ensureAuth() async {
  try {
    if (sb.auth.currentUser == null) await sb.auth.signInAnonymously();
  } catch (_) {}
  return sb.auth.currentUser != null;
}

Future<void> openUrl(BuildContext c, String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    toast(c, 'تعذّر فتح التطبيق');
  }
}

String waPhone(String raw) {
  var d = latin(raw).replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) {
    d = d.substring(2);
  } else if (d.startsWith('0')) {
    d = '963${d.substring(1)}';
  }
  return d;
}

class Ad {
  final Map<String, dynamic> m;
  Ad(this.m);
  String s(String k) => (m[k] ?? '') as String;
  String get id => s('id');
  int get price => (m['price'] as num).toInt();
  bool get sold => m['sold'] == true;
  bool get mine => m['owner'] != null && m['owner'] == sb.auth.currentUser?.id;
  Ad copy({bool? sold}) => Ad({...m, 'sold': sold ?? this.sold});
  List<String> get images => ((m['images'] ?? []) as List).map((e) => e.toString()).toList();
  List<String> get specs => [s('cpu'), s('ram'), s('storage')].where((e) => e.isNotEmpty).toList();
  String get priceText {
    final cur = s('currency') == 'دولار' ? '\$' : 'ل.س';
    return '${fmt(price)} $cur';
  }

  String get post {
    final l = <String>['💻 للبيع: ${s('title')}', '📌 ${s('type')} - ${s('cond')}'];
    final sp = {'المعالج': s('cpu'), 'الرام': s('ram'), 'التخزين': s('storage')};
    for (final e in sp.entries) {
      if (e.value.isNotEmpty) l.add('⚙️ ${e.key}: ${e.value}');
    }
    if (s('descr').isNotEmpty) l.add('📝 ${s('descr')}');
    l.add('💰 السعر: $priceText');
    l.add('📍 المدينة: ${s('city')}');
    l.add('📞 للتواصل: ${s('phone')}');
    return l.join('\n');
  }
}

Widget tag(BuildContext c, String t, {IconData? icon, Color? bg, Color? fg}) {
  final cs = Theme.of(c).colorScheme;
  final col = fg ?? cs.onSurfaceVariant;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg ?? cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: col), const SizedBox(width: 4)],
      Text(t, style: TextStyle(fontSize: 12, color: col)),
    ]),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  await ensureAuth();
  runApp(const App());
}

ThemeData mkTheme(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF1D4ED8), brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surfaceContainerLow,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'سوق الكمبيوتر',
        debugShowCheckedModeBanner: false,
        theme: mkTheme(Brightness.light),
        darkTheme: mkTheme(Brightness.dark),
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

  Future<void> load() async {
    try {
      final rows = await sb.from('ads').select().order('created_at', ascending: false);
      ads = (rows as List).map((e) => Ad(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      toast(context, 'تعذّر تحميل الإعلانات: ${errText(e)}');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final a = await Navigator.push<Ad>(context, MaterialPageRoute(builder: (_) => const FormPage()));
    if (a == null) return;
    if (!await ensureAuth()) {
      if (mounted) toast(context, 'فعّل Allow anonymous sign-ins في Supabase');
      return;
    }
    try {
      await sb.from('ads').insert(a.m);
      if (mounted) toast(context, 'تم نشر الإعلان');
      await load();
    } catch (e) {
      if (mounted) toast(context, 'تعذّر النشر: ${errText(e)}');
    }
  }

  Future<void> update(Ad a) async {
    try {
      await sb.from('ads').update(a.m).eq('id', a.id);
      await load();
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحفظ: ${errText(e)}');
    }
  }

  Future<void> remove(String id) async {
    try {
      await sb.from('ads').delete().eq('id', id);
      await load();
    } catch (e) {
      if (mounted) toast(context, 'تعذّر الحذف: ${errText(e)}');
    }
  }

  Widget header() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1E3A8A), Color(0xFF0EA5E9)]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.storefront, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('سوق الكمبيوتر السوري', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh, color: Colors.white)),
          ]),
          const Text('لابتوبات وكمبيوترات وقطع من كل المحافظات', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          TextField(
            style: const TextStyle(color: Colors.black87),
            onChanged: (v) => setState(() => q = latin(v.trim())),
            decoration: const InputDecoration(
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.search, color: Colors.black54),
              hintText: 'ابحث: لينوفو، i5، 8GB ...',
              hintStyle: TextStyle(color: Colors.black45),
            ),
          ),
        ]),
      );

  Widget filters(ColorScheme cs, int n) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(children: [
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
              for (var i = -1; i < types.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(i < 0 ? Icons.apps : typeIcons[i], size: 18),
                    label: Text(i < 0 ? 'الكل' : types[i]),
                    selected: type == (i < 0 ? null : types[i]),
                    onSelected: (_) => setState(() => type = i < 0 ? null : types[i]),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: cardColor(cs), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: city,
                      icon: const Icon(Icons.location_on_outlined),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('كل المدن')),
                        ...cities.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                      ],
                      onChanged: (v) => setState(() => city = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$n إعلان', style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = ads.where((a) {
      if (type != null && a.s('type') != type) return false;
      if (city != null && a.s('city') != city) return false;
      final hay = '${a.s('title')} ${a.s('cpu')} ${a.s('ram')} ${a.s('storage')} ${a.s('descr')}'.toLowerCase();
      return q.isEmpty || hay.contains(q.toLowerCase());
    }).toList();
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Developer by Hasan', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.outline)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('أضف إعلان')),
      body: RefreshIndicator(
        onRefresh: load,
        edgeOffset: 120,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: header()),
          SliverToBoxAdapter(child: filters(cs, f.length)),
          if (loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (f.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: cs.outline),
                  const SizedBox(height: 8),
                  Text('لا توجد إعلانات هنا بعد', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('اضغط "أضف إعلان" وكن أول من ينشر', style: TextStyle(color: cs.outline)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
              sliver: SliverList.builder(
                itemCount: f.length,
                itemBuilder: (_, i) => AdCard(
                  ad: f[i],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(ad: f[i], onUpdate: update, onDelete: remove))),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  const AdCard({super.key, required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final i = ti(ad.s('type'));
    final c = typeColors[i];
    return Opacity(
      opacity: ad.sold ? .55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: cardColor(cs),
          elevation: 2,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 70,
                  height: 70,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, .3)!]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ad.images.isEmpty
                      ? Icon(typeIcons[i], color: Colors.white, size: 32)
                      : Image.network(
                          ad.images.first,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          errorBuilder: (_, __, ___) => Icon(typeIcons[i], color: Colors.white, size: 32),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ad.s('title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      tag(context, ad.s('cond'), bg: ad.s('cond') == 'جديد' ? const Color(0xFFDCFCE7) : null, fg: ad.s('cond') == 'جديد' ? const Color(0xFF166534) : null),
                      for (final s in ad.specs) tag(context, s),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.location_on, size: 15, color: cs.outline),
                      const SizedBox(width: 2),
                      Text(ad.s('city'), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(ad.priceText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.primary)),
                  if (ad.sold) ...[const SizedBox(height: 6), tag(context, 'تم البيع', bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B))],
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final Ad ad;
  final Future<void> Function(Ad) onUpdate;
  final Future<void> Function(String) onDelete;
  const DetailPage({super.key, required this.ad, required this.onUpdate, required this.onDelete});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Ad ad = widget.ad;

  Future<void> edit() async {
    final r = await Navigator.push<Ad>(context, MaterialPageRoute(builder: (_) => FormPage(ad: ad)));
    if (r != null) {
      setState(() => ad = r);
      await widget.onUpdate(r);
    }
  }

  Future<void> del() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الإعلان؟'),
        content: const Text('لا يمكن التراجع عن الحذف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await widget.onDelete(ad.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget info(ColorScheme cs, IconData ic, String k, String v) => v.isEmpty
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor(cs), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(ic, color: cs.primary),
            const SizedBox(width: 12),
            Text(k, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final i = ti(ad.s('type'));
    final c = typeColors[i];
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), minimumSize: const Size.fromHeight(50)),
                onPressed: () => openUrl(context, 'https://wa.me/${waPhone(ad.s('phone'))}'),
                icon: const Icon(Icons.chat),
                label: const Text('تواصل واتساب'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: ad.post));
                  if (context.mounted) toast(context, 'تم النسخ، الصقه في مجموعة فيسبوك');
                },
                icon: const Icon(Icons.copy),
                label: const Text('نسخ للمجموعات'),
              ),
            ),
          ]),
        ),
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [c, Color.lerp(c, Colors.black, .4)!]),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 8, 22),
          child: Column(children: [
            Row(children: [
              const BackButton(color: Colors.white),
              const Spacer(),
              if (ad.mine) ...[
                IconButton(onPressed: edit, icon: const Icon(Icons.edit, color: Colors.white)),
                IconButton(onPressed: del, icon: const Icon(Icons.delete_outline, color: Colors.white)),
              ],
            ]),
            if (ad.images.isEmpty) Icon(typeIcons[i], size: 60, color: Colors.white) else Gallery(urls: ad.images),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(ad.s('title'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Text(ad.priceText, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            if (ad.sold) ...[const SizedBox(height: 10), tag(context, 'تم البيع', bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B))],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            info(cs, Icons.category_outlined, 'النوع', ad.s('type')),
            info(cs, Icons.verified_outlined, 'الحالة', ad.s('cond')),
            info(cs, Icons.developer_board, 'المعالج', ad.s('cpu')),
            info(cs, Icons.memory, 'الرام', ad.s('ram')),
            info(cs, Icons.storage, 'التخزين', ad.s('storage')),
            info(cs, Icons.location_on_outlined, 'المدينة', ad.s('city')),
            info(cs, Icons.phone_outlined, 'الهاتف', ad.s('phone')),
            if (ad.s('descr').isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: cardColor(cs), borderRadius: BorderRadius.circular(14)),
                child: Text(ad.s('descr'), style: const TextStyle(height: 1.5)),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => openUrl(context, 'https://wa.me/?text=${Uri.encodeComponent(ad.post)}'),
              icon: const Icon(Icons.share),
              label: const Text('مشاركة الإعلان عبر واتساب'),
            ),
            if (ad.mine)
              SwitchListTile(
                title: const Text('تم البيع'),
                value: ad.sold,
                onChanged: (v) async {
                  final n = ad.copy(sold: v);
                  setState(() => ad = n);
                  await widget.onUpdate(n);
                },
              ),
          ]),
        ),
      ]),
    );
  }
}

class Gallery extends StatefulWidget {
  final List<String> urls;
  const Gallery({super.key, required this.urls});
  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  int cur = 0;

  void zoom(String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: Stack(children: [
          Center(child: InteractiveViewer(child: Image.network(url))),
          Positioned(top: 8, right: 8, child: IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close, color: Colors.white))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: [
          SizedBox(
            height: 230,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PageView.builder(
                itemCount: widget.urls.length,
                onPageChanged: (x) => setState(() => cur = x),
                itemBuilder: (_, k) => GestureDetector(
                  onTap: () => zoom(widget.urls[k]),
                  child: Image.network(
                    widget.urls[k],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < widget.urls.length; k++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: k == cur ? Colors.white : Colors.white38),
              ),
          ]),
        ]),
      );
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
  late final List<String> urls = widget.ad?.images ?? [];
  final List<XFile> picked = [];
  bool saving = false;

  @override
  void dispose() {
    for (final c in [title, cpu, ram, storage, price, phone, desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget tf(String label, IconData ic, TextEditingController c, {bool req = false, TextInputType? kt, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: kt,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(ic)),
          validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null : null,
        ),
      );

  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Future<void> pick() async {
    final left = 3 - urls.length - picked.length;
    if (left <= 0) return;
    try {
      final p = ImagePicker();
      List<XFile> xs;
      if (left == 1) {
        final x = await p.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1280);
        xs = x == null ? [] : [x];
      } else {
        xs = await p.pickMultiImage(imageQuality: 70, maxWidth: 1280, limit: left);
      }
      if (!mounted) return;
      setState(() => picked.addAll(xs.take(left)));
    } catch (_) {
      toast(context, 'تعذّر اختيار الصور');
    }
  }

  Widget photos() {
    final cs = Theme.of(context).colorScheme;
    Widget tile(Widget child, VoidCallback onRemove) => Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 96, height: 96, child: child)),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 15, color: Colors.white)),
            ),
          ),
        ]);
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (var k = 0; k < urls.length; k++) tile(Image.network(urls[k], fit: BoxFit.cover), () => setState(() => urls.removeAt(k))),
      for (var k = 0; k < picked.length; k++) tile(Image.file(File(picked[k].path), fit: BoxFit.cover), () => setState(() => picked.removeAt(k))),
      if (urls.length + picked.length < 3)
        InkWell(
          onTap: pick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outlineVariant)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_a_photo_outlined, color: cs.primary),
              const SizedBox(height: 4),
              Text('إضافة', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
        ),
    ]);
  }

  Future<void> submit() async {
    if (!key.currentState!.validate() || saving) return;
    setState(() => saving = true);
    try {
      final all = [...urls];
      if (picked.isNotEmpty) {
        if (!await ensureAuth()) throw 'فعّل Allow anonymous sign-ins في Supabase';
        final uid = sb.auth.currentUser!.id;
        for (var i = 0; i < picked.length; i++) {
          final png = picked[i].path.toLowerCase().endsWith('.png');
          final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$i.${png ? 'png' : 'jpg'}';
          await sb.storage.from('ad-images').uploadBinary(
                path,
                await picked[i].readAsBytes(),
                fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg'),
              );
          all.add(sb.storage.from('ad-images').getPublicUrl(path));
        }
      }
      final p = int.tryParse(latin(price.text).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (!mounted) return;
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
          'images': all,
          'sold': widget.ad?.sold ?? false,
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, 'تعذّر رفع الصور: ${errText(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.ad == null ? 'إعلان جديد' : 'تعديل الإعلان')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: saving ? null : submit,
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
              label: Text(saving ? 'جارٍ الرفع...' : 'نشر الإعلان'),
            ),
          ),
        ),
        body: Form(
          key: key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            label('صور الجهاز (حتى 3 صور)'),
            photos(),
            const SizedBox(height: 14),
            label('نوع الجهاز'),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < types.length; i++)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(typeIcons[i], size: 18),
                  label: Text(types[i]),
                  selected: type == types[i],
                  onSelected: (_) => setState(() => type = types[i]),
                ),
            ]),
            const SizedBox(height: 14),
            tf('عنوان الإعلان (مثال: لابتوب HP ProBook)', Icons.title, title, req: true),
            label('الحالة'),
            SegmentedButton<String>(
              segments: [for (final c in conds) ButtonSegment(value: c, label: Text(c))],
              selected: {cond},
              onSelectionChanged: (s) => setState(() => cond = s.first),
            ),
            const SizedBox(height: 14),
            tf('المعالج (مثال: Core i5 الجيل 8)', Icons.developer_board, cpu),
            tf('الرام (مثال: 8GB)', Icons.memory, ram),
            tf('التخزين (مثال: SSD 256GB)', Icons.storage, storage),
            label('العملة'),
            SegmentedButton<String>(
              segments: [for (final c in currencies) ButtonSegment(value: c, label: Text(c))],
              selected: {currency},
              onSelectionChanged: (s) => setState(() => currency = s.first),
            ),
            const SizedBox(height: 14),
            tf('السعر', Icons.payments_outlined, price, req: true, kt: TextInputType.number),
            label('المدينة'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: city,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined)),
                items: cities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (x) {
                  if (x != null) setState(() => city = x);
                },
              ),
            ),
            tf('رقم الهاتف / واتساب', Icons.phone_outlined, phone, req: true, kt: TextInputType.phone),
            tf('وصف إضافي', Icons.notes, desc, lines: 3),
          ]),
        ),
      );
}
