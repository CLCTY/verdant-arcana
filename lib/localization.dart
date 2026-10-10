import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  String language = 'zh';
  Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      'verdant_language',
    );
    if (['zh', 'en', 'ja'].contains(saved)) language = saved!;
  }

  Future<void> setLanguage(String value) async {
    if (!['zh', 'en', 'ja'].contains(value) || value == language) return;
    if (!await (await SharedPreferences.getInstance()).setString(
      'verdant_language',
      value,
    )) {
      throw StateError('Language preference could not be saved');
    }
    language = value;
    notifyListeners();
  }
}

final appPreferences = AppPreferences();

class AppLocaleScope extends InheritedNotifier<AppPreferences> {
  AppLocaleScope({super.key, required super.child})
    : super(notifier: appPreferences);
}

String tr(String source, [BuildContext? context]) {
  if (context != null) {
    context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
  }
  final language = appPreferences.language;
  if (language == 'zh') {
    for (final entry in translations.entries) {
      if (entry.value.contains(source)) return entry.key;
    }
    return source;
  }
  final index = language == 'ja' ? 1 : 0;
  final direct = translations[source];
  if (direct != null) return direct[index];
  // Persisted spread names may have been written in another language.
  for (final entry in translations.entries) {
    if (entry.value.contains(source)) return entry.value[index];
  }
  final patterns = <(RegExp, String Function(Match))>[
    (
      RegExp(r'^已删除 (\d+) 条记录$'),
      (m) => index == 0 ? 'Deleted ${m[1]} entries' : '${m[1]}件を削除しました',
    ),
    (
      RegExp(r'^(\d+) / (\d+) 张已展开$'),
      (m) => index == 0
          ? '${m[1]} / ${m[2]} cards revealed'
          : '${m[1]} / ${m[2]}枚をめくりました',
    ),
    (
      RegExp(r'^展开第(\d+)张牌$'),
      (m) => index == 0 ? 'Reveal card ${m[1]}' : '${m[1]}枚目をめくる',
    ),
    (
      RegExp(r'^(.+)，(\d+)张牌$'),
      (m) => index == 0 ? '${m[1]}, ${m[2]} cards' : '${m[1]}、${m[2]}枚',
    ),
    (
      RegExp(r'^已选 (\d+) 条$'),
      (m) => index == 0 ? '${m[1]} selected' : '${m[1]}件選択中',
    ),
    (
      RegExp(r'^(\d+) 次记录 · 长按可选择删除$'),
      (m) => index == 0
          ? '${m[1]} entries · Long-press to select'
          : '${m[1]}件の記録・長押しで選択',
    ),
    (
      RegExp(r'^(.+) · (\d+) 张$'),
      (m) =>
          index == 0 ? '${tr(m[1]!)} · ${m[2]} cards' : '${tr(m[1]!)}・${m[2]}枚',
    ),
    (RegExp(r'^(.+) · 正位$'), (m) => '${m[1]} · ${tr('正位')}'),
    (RegExp(r'^(.+)，(正位|逆位)$'), (m) => '${m[1]}, ${tr(m[2]!)}'),
    (
      RegExp(r'^输入 (.+) 的密钥$'),
      (m) => index == 0 ? 'Enter your ${tr(m[1]!)} key' : '${tr(m[1]!)} のキーを入力',
    ),
    (
      RegExp(r'^将当前问题、牌阵和牌面发送给 (.+)。$'),
      (m) => index == 0
          ? 'Send this question, spread and cards to ${tr(m[1]!)}.'
          : '現在の問い、スプレッド、カードを ${tr(m[1]!)} に送信します。',
    ),
    (
      RegExp(r'^请求失败（(\d+)），请检查模型配置。$'),
      (m) => index == 0
          ? 'Request failed (${m[1]}). Check the model settings.'
          : 'リクエストに失敗しました（${m[1]}）。モデル設定を確認してください。',
    ),
    (
      RegExp(r'^关于(.+)，我现在可以关注什么？$'),
      (m) => index == 0
          ? 'What can I focus on about ${tr(m[1]!)}?'
          : '${tr(m[1]!)}について、今何に意識を向けるとよいでしょうか？',
    ),
  ];
  for (final (pattern, translate) in patterns) {
    final match = pattern.firstMatch(source);
    if (match != null) return translate(match);
  }
  return source;
}

String localizedDate(DateTime d, {bool weekday = false}) {
  final lang = appPreferences.language;
  final date = lang == 'en'
      ? '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}'
      : '${d.month}月${d.day}日';
  if (!weekday) return date;
  final days = lang == 'en'
      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
      : lang == 'ja'
      ? const ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日']
      : const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '$date  ${days[d.weekday - 1]}';
}

const _majorNamesJa = {
  'fool': '愚者',
  'magician': '魔術師',
  'high_priestess': '女教皇',
  'empress': '女帝',
  'emperor': '皇帝',
  'hierophant': '教皇',
  'lovers': '恋人',
  'chariot': '戦車',
  'strength': '力',
  'hermit': '隠者',
  'wheel': '運命の輪',
  'justice': '正義',
  'hanged_man': '吊るされた男',
  'death': '死神',
  'temperance': '節制',
  'devil': '悪魔',
  'tower': '塔',
  'star': '星',
  'moon': '月',
  'sun': '太陽',
  'judgement': '審判',
  'world': '世界',
};
const _suitsJa = {
  'wands': 'ワンド',
  'cups': 'カップ',
  'swords': 'ソード',
  'pentacles': 'ペンタクル',
};
const _ranksJa = {
  'ace': 'エース',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
  'ten': '10',
  'page': 'ペイジ',
  'knight': 'ナイト',
  'queen': 'クイーン',
  'king': 'キング',
};

String cardName(String id, String original, String english) {
  if (appPreferences.language == 'zh') return original;
  if (appPreferences.language == 'en') {
    return english
        .toLowerCase()
        .split(' ')
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
  if (_majorNamesJa.containsKey(id)) return _majorNamesJa[id]!;
  final parts = id.split('_');
  return '${_suitsJa[parts[0]]}の${_ranksJa[parts[1]]}';
}

List<String> cardWords(String id, List<String> original) =>
    appPreferences.language == 'zh'
    ? original
    : cardTranslations[id]![appPreferences.language == 'ja' ? 1 : 0].split(',');
String cardCopy(String id, String field, String original) {
  if (appPreferences.language == 'zh') return original;
  final row = cardTranslations[id]!;
  final ja = appPreferences.language == 'ja';
  if (field == 'reflection') {
    final word = row[ja ? 1 : 0].split(',').first;
    return ja
        ? '$wordについて、今日試せる小さな一歩は何でしょうか？'
        : 'What small step could you take toward ${word.toLowerCase()} today?';
  }
  return row[(field == 'meaning' ? 2 : 4) + (ja ? 1 : 0)];
}

const translations = <String, List<String>>{
  '暂时无法读取日记，请稍后重试。': [
    'Cannot load the journal. Please try later.',
    '日記を読み込めませんでした。しばらくしてからお試しください。',
  ],
  '配置 AI 接入': ['Configure AI', 'AI 接続を設定'],
  "星笺": ["Arcana Notes", "星の便り"],
  "GitHub 仓库": ["GitHub repository", "GitHub リポジトリ"],
  "无法打开链接，请稍后重试。": [
    "Could not open the link. Please try again.",
    "リンクを開けませんでした。もう一度お試しください。",
  ],
  "设置": ["Settings", "設定"],
  "今日": ["Today", "今日"],
  "占卜": ["Reading", "占い"],
  "牌库": ["Deck", "カード"],
  "日记": ["Journal", "日記"],
  "语言": ["Language", "言語"],
  "外观与内容": ["Appearance & content", "外観とコンテンツ"],
  "让指引更贴近你": ["Make guidance your own", "自分に合ったガイダンスを"],
  "AI 接入": ["AI connection", "AI 接続"],
  "连接 DeepSeek 官方或 OpenCode Go": [
    "Connect DeepSeek or OpenCode Go",
    "DeepSeek または OpenCode Go に接続",
  ],
  "OLED 纯黑背景": ["OLED pure black", "OLED ブラック"],
  "跟随系统壁纸配色": ["Use system wallpaper colors", "システムの壁紙カラーを使用"],
  "动态取色": ["Dynamic colors", "ダイナミックカラー"],
  "支持的设备跟随壁纸或系统强调色，不支持时使用默认翡翠配色。": [
    "Use wallpaper or system accent colors where supported; otherwise use the emerald palette.",
    "対応端末では壁紙またはシステムのアクセントカラーを使用し、非対応端末ではエメラルド配色を使用します。",
  ],
  "完整塔罗牌库": ["Complete tarot deck", "すべてのタロットカード"],
  "22 张大阿卡纳 · 56 张小阿卡纳": [
    "22 Major Arcana · 56 Minor Arcana",
    "大アルカナ22枚・小アルカナ56枚",
  ],
  "私人日记": ["Private journal", "プライベート日記"],
  "保存在当前设备。长按记录可选择删除。": [
    "Stored on this device. Long-press entries to select and delete.",
    "この端末に保存されます。長押しで記録を選択して削除できます。",
  ],
  "卡牌提供思考的视角，选择始终由你自己做出。": [
    "Cards offer a perspective. Your choices remain your own.",
    "カードは考える視点を提供します。選択はいつでもあなた自身のものです。",
  ],
  "今日，听见内心": ["Listen within, today", "今日、心の声に耳を澄ます"],
  "留一点时间，给自己。": ["Take a little time for yourself.", "自分のために、少し時間を。"],
  "查看今日牌义": ["View today's card meaning", "今日のカードの意味を見る"],
  "今日一牌": ["Daily card", "今日の一枚"],
  "今天，给自己的一个指引": ["A little guidance for today", "今日の自分へのガイダンス"],
  "每日一牌": ["Daily card", "今日の一枚"],
  "今日指引": ["Today's guidance", "今日のガイダンス"],
  "正位": ["Upright", "正位置"],
  "逆位": ["Reversed", "逆位置"],
  "为新的可能，留一盏灯。": [
    "Leave a light on for new possibilities.",
    "新しい可能性のために、灯りをともす。",
  ],
  "查看今日指引": ["Read today's guidance", "今日のガイダンスを読む"],
  "带着问题来？  开始一次占卜 →": [
    "Have a question? Start a reading →",
    "問いがありますか？ 占いを始める →",
  ],
  "此刻，你想问什么？": ["What's on your mind?", "今、何を問いかけたいですか？"],
  "把问题留在这里，让牌成为一次思考的开始。": [
    "Leave your question here. Let the cards begin a reflection.",
    "ここに問いを書いて、カードを思索のきっかけにしましょう。",
  ],
  "你的问题": ["Your question", "あなたの問い"],
  "我可以怎样看待眼前的变化？": [
    "How can I approach the changes ahead?",
    "目の前の変化にどう向き合えばよいでしょうか？",
  ],
  "关系": ["Relationships", "人間関係"],
  "工作": ["Work", "仕事"],
  "自我": ["Self", "自分自身"],
  "选择牌阵": ["Choose a spread", "スプレッドを選ぶ"],
  "开始占卜": ["Start reading", "占いを始める"],
  "给问题一点空间，也给自己一点时间。": [
    "Give your question space, and yourself time.",
    "問いに余白を、自分には時間を。",
  ],
  "轻触展开": ["Tap to reveal", "タップしてめくる"],
  "牌面已展开，听听它们的故事。": [
    "The cards are revealed. Listen to their story.",
    "カードが開かれました。その物語を聞いてみましょう。",
  ],
  "深呼吸，点击牌背，让牌面慢慢展开。": [
    "Breathe, then tap each card to reveal it.",
    "深呼吸して、カードをタップし、ゆっくりめくりましょう。",
  ],
  "正在洗牌": ["Shuffling", "シャッフル中"],
  "查看解读": ["View interpretation", "リーディングを見る"],
  "重新洗牌": ["Shuffle again", "もう一度シャッフル"],
  "牌阵解读": ["Spread interpretation", "スプレッドのリーディング"],
  "给自己的一个问题": ["A question for yourself", "自分への問い"],
  "此刻的感受": ["Your reflections", "今の気持ち"],
  "写下你看见的、感受到的…": [
    "Write what you noticed and felt…",
    "気づいたこと、感じたことを書いてみましょう…",
  ],
  "保存到日记": ["Save to journal", "日記に保存"],
  "已保存到日记": ["Saved to journal", "日記に保存しました"],
  "保存失败，请重试。": ["Could not save. Please try again.", "保存できませんでした。もう一度お試しください。"],
  "解读是一种思考的视角，行动与选择仍然属于你。": [
    "A reading offers perspective. Your actions and choices remain yours.",
    "リーディングは考える視点です。行動と選択はあなた自身のものです。",
  ],
  "认识每一张牌": ["Explore every card", "一枚一枚のカードを知る"],
  "从象征出发，找到属于你的理解。": [
    "Explore the symbols and find your own understanding.",
    "象徴を手がかりに、自分なりの理解を見つけましょう。",
  ],
  "搜索牌名或关键词": ["Search cards or keywords", "カード名やキーワードを検索"],
  "全部": ["All", "すべて"],
  "大阿卡纳": ["Major Arcana", "大アルカナ"],
  "权杖": ["Wands", "ワンド"],
  "圣杯": ["Cups", "カップ"],
  "宝剑": ["Swords", "ソード"],
  "星币": ["Pentacles", "ペンタクル"],
  "没有找到这张牌，试试其他关键词。": [
    "No cards found. Try another keyword.",
    "カードが見つかりません。別のキーワードをお試しください。",
  ],
  "把此刻，留给未来的自己": ["Keep this moment for your future self", "今を、未来の自分へ残す"],
  "完成一次抽牌后，保存解读和感受。\n你的记录会在这里慢慢积累。": [
    "Save readings and reflections after drawing cards.\nYour entries will collect here.",
    "カードを引いたら、解釈や気持ちを保存しましょう。\nここに記録が少しずつたまっていきます。",
  ],
  "留住每一次看见": ["Keep each insight", "気づきを残す"],
  "全选": ["Select all", "すべて選択"],
  "删除所选记录": ["Delete selected entries", "選択した記録を削除"],
  "取消": ["Cancel", "キャンセル"],
  "撤销": ["Undo", "元に戻す"],
  "恢复失败，请重试。": [
    "Could not restore. Please try again.",
    "復元できませんでした。もう一度お試しください。",
  ],
  "删除失败，请重试。": [
    "Could not delete. Please try again.",
    "削除できませんでした。もう一度お試しください。",
  ],
  "位置": ["Position", "位置"],
  "AI 深入解读": ["AI interpretation", "AI リーディング"],
  "连接你的解读服务，获得结合问题与牌阵的解读。": [
    "Connect a provider for a reading tailored to your question and spread.",
    "サービスに接続すると、問いとスプレッドに合わせたリーディングを得られます。",
  ],
  "正在整理牌面的故事…": ["Preparing the cards' story…", "カードの物語をまとめています…"],
  "重新解读": ["Read again", "もう一度読む"],
  "生成 AI 解读": ["Generate AI reading", "AI リーディングを生成"],
  "连接 AI 服务": ["Connect AI provider", "AI サービスに接続"],
  "更换服务": ["Change provider", "サービスを変更"],
  "重新解读会再次调用所选服务。": [
    "Reading again sends a new request to your provider.",
    "再リーディングは、サービスへの新たなリクエストを送信します。",
  ],
  "解读失败，请重试。": [
    "Reading failed. Please try again.",
    "リーディングに失敗しました。もう一度お試しください。",
  ],
  "选择解读服务": ["Choose your provider", "リーディングサービスを選ぶ"],
  "保存配置后，在牌阵解读中点击「AI 深入解读」。": [
    "Save your settings, then choose AI interpretation in a reading.",
    "設定を保存し、リーディング画面で「AI リーディング」を選んでください。",
  ],
  "模型": ["Model", "モデル"],
  "显示密钥": ["Show key", "キーを表示"],
  "隐藏密钥": ["Hide key", "キーを隠す"],
  "DeepSeek 官方": ["DeepSeek official", "DeepSeek 公式"],
  "Web 预览的密钥仅保留到页面刷新。手机端使用系统安全存储。": [
    "Web keys are cleared on refresh. Mobile builds use system secure storage.",
    "Web のキーは再読み込み時に消去されます。モバイルではシステムの安全なストレージを使用します。",
  ],
  "密钥保存在系统安全存储中，各服务独立保存。": [
    "Keys use system secure storage and are separate for each provider.",
    "キーはシステムの安全なストレージに、サービスごとに保存されます。",
  ],
  "OpenCode Go 主要面向编程代理请求。塔罗用途是否允许及可用，需以服务方规则和账户权限为准。": [
    "OpenCode Go primarily serves coding agents. Tarot use depends on provider rules and account access.",
    "OpenCode Go は主にコーディングエージェント向けです。タロットでの利用可否は、サービスの規則とアカウントの権限によります。",
  ],
  "AI 解读仅发送当前问题、牌阵和牌面。日记感受不会发送。": [
    "Only the current question, spread and cards are sent. Journal reflections stay local.",
    "現在の問い、スプレッド、カードのみを送信します。日記の感想は送信しません。",
  ],
  "保存配置": ["Save settings", "設定を保存"],
  "测试连接并保存": ["Test & save", "接続テストと保存"],
  "测试会向所选服务发送一条简短请求。": [
    "Testing sends a short request to the selected provider.",
    "テストは選択したサービスに短いリクエストを送信します。",
  ],
  "移除当前服务的密钥": ["Remove this provider's key", "このサービスのキーを削除"],
  "请填写该服务的 API Key。": [
    "Enter this provider's API key.",
    "このサービスの API キーを入力してください。",
  ],
  "已移除当前服务的密钥。": ["This provider's key was removed.", "このサービスのキーを削除しました。"],
  "连接成功，配置已保存。": ["Connected. Settings saved.", "接続できました。設定を保存しました。"],
  "配置已保存。": ["Settings saved.", "設定を保存しました。"],
  "请先在设置中填写 API Key。": [
    "Add an API key in settings first.",
    "先に設定で API キーを入力してください。",
  ],
  "密钥无效或没有访问权限，请检查该服务的 API Key。": [
    "Invalid key or insufficient access. Check your API key.",
    "キーが無効、または権限がありません。API キーを確認してください。",
  ],
  "账户余额或额度不足，请检查服务账户。": [
    "Insufficient balance or quota. Check your provider account.",
    "残高または利用枠が不足しています。サービスのアカウントを確認してください。",
  ],
  "当前模型或接口不可用，请检查服务的模型权限。": [
    "Model or endpoint unavailable. Check your model access.",
    "モデルまたは API が利用できません。モデルへのアクセス権を確認してください。",
  ],
  "请求过于频繁或额度已用完，请稍后重试。": [
    "Rate limit or quota reached. Please try later.",
    "リクエスト制限、または利用枠に達しました。しばらくしてからお試しください。",
  ],
  "服务暂时不可用，请稍后重试。": [
    "Service temporarily unavailable. Please try later.",
    "サービスが一時的に利用できません。しばらくしてからお試しください。",
  ],
  "服务没有返回解读正文，请重试。": [
    "No reading was returned. Please try again.",
    "リーディングの本文が返されませんでした。もう一度お試しください。",
  ],
  "请求超时，请检查网络后重试。": [
    "Request timed out. Check your connection and retry.",
    "タイムアウトしました。接続を確認してお試しください。",
  ],
  "连接失败。浏览器可能受到跨域限制；可在 Android 应用中尝试。": [
    "Connection failed. Browser CORS restrictions may apply; try the Android app.",
    "接続できませんでした。ブラウザの CORS 制限の可能性があります。Android アプリでお試しください。",
  ],
  "无法连接服务，请检查网络。": [
    "Cannot connect. Check your network.",
    "接続できません。ネットワークを確認してください。",
  ],
  "服务响应格式不正确，请稍后重试。": [
    "Unexpected response format. Please try later.",
    "応答の形式が正しくありません。しばらくしてからお試しください。",
  ],
  "服务响应无法读取，请稍后重试。": [
    "Could not read the response. Please try later.",
    "応答を読み取れませんでした。しばらくしてからお試しください。",
  ],
  "无法读取 AI 配置，请重新设置服务和密钥。": [
    "Could not load AI settings. Configure your provider and key again.",
    "AI 設定を読み取れませんでした。サービスとキーを設定し直してください。",
  ],
  "单张指引": ["One-card guidance", "一枚のガイダンス"],
  "聚焦当下，给自己一个思考的方向。": [
    "Focus on the present and find a direction for reflection.",
    "今に意識を向け、考える方向を見つけます。",
  ],
  "当下的指引": ["Present guidance", "今のガイダンス"],
  "二选一抉择": ["Two choices", "二つの選択肢"],
  "分别看见两个选择所带来的可能。": [
    "Explore the possibilities behind two choices.",
    "二つの選択肢がもたらす可能性を見つめます。",
  ],
  "选择 A": ["Choice A", "選択肢 A"],
  "选择 B": ["Choice B", "選択肢 B"],
  "是非澄清": ["Clarity", "判断を明確に"],
  "从支持与阻碍两个角度，澄清你的判断。": [
    "Clarify your judgment through support and obstacles.",
    "支えと障害の二つの視点から、判断を明確にします。",
  ],
  "支持因素": ["Supporting factors", "支えとなる要素"],
  "阻碍因素": ["Obstacles", "障害となる要素"],
  "三张牌 · 现状": ["Situation · 3 cards", "現状・3枚"],
  "现状、需要留意、可以尝试，梳理一个小行动。": [
    "Explore your situation, what to notice and a next step.",
    "現状、気をつけること、試せることから、小さな一歩を考えます。",
  ],
  "当下的状态": ["Current situation", "現在の状態"],
  "需要留意": ["What to notice", "気をつけること"],
  "可以尝试": ["What to try", "試せること"],
  "三张牌 · 时间": ["Timeline · 3 cards", "時間の流れ・3枚"],
  "回顾过去、理解现在，探索未来的可能。": [
    "Reflect on the past, understand the present and explore possibilities.",
    "過去を振り返り、現在を理解し、未来の可能性を探ります。",
  ],
  "过去的影响": ["Past influences", "過去の影響"],
  "现在的状态": ["Present state", "現在の状態"],
  "未来的可能": ["Future possibilities", "未来の可能性"],
  "关系之镜": ["Relationship mirror", "関係を映す鏡"],
  "理解彼此的感受，以及关系中的连接。": [
    "Explore each perspective and the connection between you.",
    "互いの気持ちと、関係のつながりを理解します。",
  ],
  "我的感受": ["My feelings", "自分の気持ち"],
  "对方的视角": ["Their perspective", "相手の視点"],
  "关系的连接": ["Your connection", "関係のつながり"],
  "四元素": ["Four elements", "四元素"],
  "从行动、感受、思考、现实四个方面看问题。": [
    "Explore action, feelings, thought and practical matters.",
    "行動、感情、思考、現実の四つの側面から問いを見ます。",
  ],
  "火 · 行动": ["Fire · Action", "火・行動"],
  "水 · 感受": ["Water · Feelings", "水・感情"],
  "风 · 思考": ["Air · Thought", "風・思考"],
  "土 · 现实": ["Earth · Practicality", "地・現実"],
  "五张十字": ["Five-card cross", "5枚のクロス"],
  "聚焦核心，辨认阻碍、基础、建议与趋势。": [
    "Explore the core, obstacles, foundation, advice and direction.",
    "核心、障害、基盤、助言、流れを見つめます。",
  ],
  "问题核心": ["Core issue", "問いの核心"],
  "当前阻碍": ["Current obstacle", "現在の障害"],
  "内在基础": ["Inner foundation", "内面の基盤"],
  "行动建议": ["Suggested action", "行動への助言"],
  "发展趋势": ["Direction", "今後の流れ"],
  "凯尔特十字": ["Celtic Cross", "ケルト十字"],
  "用十个位置深入梳理一个复杂问题。": [
    "Explore a complex question through ten positions.",
    "十の位置から、複雑な問いを深く見つめます。",
  ],
  "当前处境": ["Current situation", "現在の状況"],
  "交叉挑战": ["Crossing challenge", "交差する課題"],
  "深层基础": ["Underlying foundation", "深い基盤"],
  "过去影响": ["Past influence", "過去の影響"],
  "意识目标": ["Conscious goal", "意識している目標"],
  "近期发展": ["Near-term development", "近い将来の展開"],
  "自我态度": ["Your attitude", "自分の姿勢"],
  "环境影响": ["External influences", "周囲の影響"],
  "期待与担忧": ["Hopes & concerns", "期待と不安"],
  "可能结果": ["Possible outcome", "考えられる結果"],
};

const cardTranslations = <String, List<String>>{
  "fool": [
    "Beginnings,Freedom,Exploration",
    "始まり,自由,探求",
    "Take a curious first step, with practical support for the unknown.",
    "好奇心を持って一歩踏み出し、未知への備えも整えましょう。",
    "Check risks before acting from impulse or fear.",
    "衝動や恐れに流されず、始める前にリスクを確認しましょう。",
  ],
  "magician": [
    "Action,Resources,Creation",
    "行動,資源,創造",
    "Use the skills and resources you already have to make an idea real.",
    "今ある力と資源を使い、考えを具体的な行動に変えましょう。",
    "Replace appearances and unrealized ideas with honest, practical work.",
    "見せかけや構想だけに頼らず、実際に使える力を確かめましょう。",
  ],
  "high_priestess": [
    "Intuition,Stillness,Insight",
    "直感,静けさ,内面",
    "Listen quietly to feelings and details before speaking or deciding.",
    "静かに感情や細部を観察し、まだ見えない情報に余白を残しましょう。",
    "Separate intuition from assumption and look for real evidence.",
    "雑音から距離を置き、推測を事実と混同せず直感の根拠を探しましょう。",
  ],
  "empress": [
    "Nurture,Abundance,Creativity",
    "育むこと,豊かさ,創造力",
    "Care for your body, relationships and creativity; growth takes nourishment.",
    "体、人間関係、創造力をいたわり、成長をゆっくり育みましょう。",
    "Restore balance when giving too much or neglecting your own needs.",
    "与えすぎや自己放置を見直し、自分の必要も大切にしましょう。",
  ],
  "emperor": [
    "Structure,Boundaries,Responsibility",
    "秩序,境界,責任",
    "Create clear, workable structures and accept realistic responsibilities.",
    "実行できるルールを作り、引き受けられる責任を果たしましょう。",
    "Keep rules flexible rather than controlling everything or abandoning structure.",
    "支配しすぎず、秩序も手放さず、目的に役立つ柔軟なルールにしましょう。",
  ],
  "hierophant": [
    "Tradition,Learning,Beliefs",
    "伝統,学び,信念",
    "Learn from trusted experience while understanding why a rule exists.",
    "信頼できる経験から学び、規範の意味を理解して自分に合う形を選びましょう。",
    "Question inherited answers respectfully and make room for your judgment.",
    "既存の答えを尊重しつつ、今の状況に合う自分の判断も大切にしましょう。",
  ],
  "lovers": [
    "Connection,Values,Choice",
    "つながり,価値観,選択",
    "Choose in line with your values and communicate needs honestly.",
    "価値観に沿って選び、互いの必要を率直に伝えましょう。",
    "Clarify conflicting values instead of sacrificing yourself to please others.",
    "価値観の違いを明らかにし、迎合のために自分を忘れないようにしましょう。",
  ],
  "chariot": [
    "Direction,Will,Progress",
    "方向,意志,前進",
    "Coordinate competing forces and move steadily toward a clear goal.",
    "異なる力を調整し、明確な方向へ着実に進みましょう。",
    "Regain direction and balance before increasing your pace.",
    "方向やペースを整え、無理に加速する前にバランスを取り戻しましょう。",
  ],
  "strength": [
    "Courage,Gentleness,Patience",
    "勇気,優しさ,忍耐",
    "Meet challenges with patience, emotional acceptance and gentle persistence.",
    "感情を受け止め、忍耐と穏やかな粘り強さで課題に向き合いましょう。",
    "Reduce self-criticism and express your needs kindly but firmly.",
    "自責を減らし、必要なことを優しく、しかしはっきり伝えましょう。",
  ],
  "hermit": [
    "Solitude,Reflection,Wisdom",
    "独りの時間,内省,知恵",
    "Step back from noise and reflect on your own experience.",
    "雑音から離れ、自分の経験と内面を落ち着いて見つめましょう。",
    "Notice when solitude becomes isolation; seek trustworthy support.",
    "独りの時間が孤立に変わっていないか確かめ、信頼できる支えを探しましょう。",
  ],
  "wheel": [
    "Cycles,Change,Opportunity",
    "周期,変化,機会",
    "Adapt to changing conditions and focus on what you can influence.",
    "状況の変化に合わせ、自分が働きかけられることに意識を向けましょう。",
    "Review repeating patterns and take one grounded step amid uncertainty.",
    "繰り返すパターンを見直し、不確かさの中でも現実的な一歩を選びましょう。",
  ],
  "justice": [
    "Fairness,Truth,Accountability",
    "公平,真実,責任",
    "Consider evidence and consequences, then make a fair decision.",
    "根拠と結果を考え、公平な判断と責任ある行動を選びましょう。",
    "Examine bias and unequal standards before judging yourself or others.",
    "偏りや不公平な基準を見直し、事実を十分に確かめましょう。",
  ],
  "hanged_man": [
    "Pause,Perspective,Release",
    "休止,視点,手放すこと",
    "Pause and try another perspective instead of forcing progress.",
    "無理に進めず、立ち止まって別の視点から状況を見ましょう。",
    "Distinguish a useful pause from avoidance or needless sacrifice.",
    "必要な休止と回避を区別し、無意味な犠牲を見直しましょう。",
  ],
  "death": [
    "Endings,Transformation,Renewal",
    "終わり,変容,再生",
    "Let an outdated pattern end to make room for renewal.",
    "役目を終えた習慣を手放し、新しい始まりのための余白を作りましょう。",
    "Acknowledge fear of change and release what no longer supports you.",
    "変化への恐れを認め、今の自分を支えないものを少しずつ手放しましょう。",
  ],
  "temperance": [
    "Balance,Integration,Patience",
    "調和,統合,忍耐",
    "Blend different needs and find a sustainable rhythm.",
    "異なる必要を調整し、続けられる穏やかなリズムを見つけましょう。",
    "Restore proportion where haste or extremes have upset your balance.",
    "焦りや極端さで崩れたバランスを、適切な配分で整えましょう。",
  ],
  "devil": [
    "Attachment,Awareness,Choice",
    "執着,気づき,選択",
    "Recognize limiting attachments and the choices still available to you.",
    "自分を縛る執着に気づき、残されている選択肢を見つめましょう。",
    "Loosen a harmful habit with support and realistic, gradual steps.",
    "有害な習慣から、支えと現実的な小さな一歩を通して離れましょう。",
  ],
  "tower": [
    "Disruption,Truth,Rebuilding",
    "揺らぎ,真実,再構築",
    "When assumptions collapse, protect essentials and rebuild on firmer ground.",
    "前提が崩れたら、大切なものを守り、より確かな基盤を作り直しましょう。",
    "Address a known weak point rather than delaying needed change.",
    "必要な変化を先延ばしにせず、気づいている弱点に向き合いましょう。",
  ],
  "star": [
    "Hope,Healing,Trust",
    "希望,癒し,信頼",
    "Rebuild hope gently and let a small action become a new beginning.",
    "希望をゆっくり育て直し、小さな行動を新しい始まりにしましょう。",
    "Allow tiredness and make your expectations small enough for today.",
    "疲れを認め、期待を今日できる一つのことまで小さくしましょう。",
  ],
  "moon": [
    "Awareness,Intuition,Uncertainty",
    "気づき,直感,不確かさ",
    "Acknowledge unease, separate feelings from facts and allow uncertainty.",
    "不安を認め、感情と事実を区別し、まだ分からないことを受け止めましょう。",
    "Organize known facts as unclear feelings gradually become clearer.",
    "分かっている事実を整理し、不安と本当の必要をゆっくり見分けましょう。",
  ],
  "sun": [
    "Clarity,Joy,Growth",
    "明晰さ,喜び,成長",
    "Notice progress, speak openly and align actions with your feelings.",
    "進歩に気づき、率直に話し、行動を本当の気持ちに合わせましょう。",
    "Let go of comparison and excessive expectations; return to your own pace.",
    "比較や高すぎる期待を手放し、自分に合ったペースに戻りましょう。",
  ],
  "judgement": [
    "Awakening,Review,Response",
    "目覚め,振り返り,応答",
    "Review experience honestly and respond to what matters now.",
    "経験を率直に振り返り、今大切なことに応えましょう。",
    "Reduce harsh self-judgment and give yourself a thoughtful fresh start.",
    "厳しい自己評価をゆるめ、納得できる再出発の機会を作りましょう。",
  ],
  "world": [
    "Completion,Integration,New cycle",
    "完成,統合,新たな周期",
    "Recognize completion and integrate what you learned before moving on.",
    "達成を認め、学びを自分の中に取り込んで次へ進みましょう。",
    "Finish loose ends without demanding a flawless ending.",
    "完璧な終わりを求めすぎず、残っていることを一つずつ整えましょう。",
  ],
  "wands_ace": [
    "Inspiration,Energy,Beginnings",
    "ひらめき,活力,始まり",
    "Give new enthusiasm a concrete first step.",
    "新しい意欲を、具体的な最初の一歩にしましょう。",
    "Prepare and restore energy before chasing a spark.",
    "ひらめきを追う前に、準備と活力を整えましょう。",
  ],
  "wands_two": [
    "Planning,Vision,Choice",
    "計画,展望,選択",
    "Compare possibilities and choose a direction to explore.",
    "可能性を比べ、探ってみたい方向を選びましょう。",
    "Move beyond hesitation with a modest, realistic plan.",
    "迷いを超えるため、現実的な小さな計画を立てましょう。",
  ],
  "wands_three": [
    "Expansion,Outlook,Cooperation",
    "拡大,見通し,協力",
    "Look beyond the immediate task and prepare for growth.",
    "目先の課題を越えて見渡し、成長に備えましょう。",
    "Review expectations and delays before expanding further.",
    "さらに広げる前に、期待や遅れを見直しましょう。",
  ],
  "wands_four": [
    "Celebration,Stability,Belonging",
    "祝福,安定,居場所",
    "Appreciate shared progress and the support around you.",
    "共に得た進歩と、周囲の支えを喜びましょう。",
    "Clarify what makes a shared space feel safe and welcoming.",
    "共に過ごす場所の安心と居心地を見直しましょう。",
  ],
  "wands_five": [
    "Competition,Differences,Practice",
    "競争,違い,練習",
    "Use differing views to learn rather than simply win.",
    "勝つことだけでなく、異なる意見から学びましょう。",
    "Reduce pointless conflict and discuss clear shared rules.",
    "不毛な対立を減らし、共通のルールを話し合いましょう。",
  ],
  "wands_six": [
    "Recognition,Confidence,Progress",
    "評価,自信,前進",
    "Accept recognition while acknowledging the people who helped.",
    "評価を受け止め、支えてくれた人にも感謝しましょう。",
    "Build confidence beyond praise and external approval.",
    "称賛や他人の承認だけに頼らない自信を育みましょう。",
  ],
  "wands_seven": [
    "Boundaries,Courage,Persistence",
    "境界,勇気,粘り強さ",
    "Stand up for what matters without fighting every challenge.",
    "大切なものを守りつつ、すべてを争いにしないようにしましょう。",
    "Choose your battles and ask for support when overwhelmed.",
    "取り組む課題を選び、抱えきれないときは支えを求めましょう。",
  ],
  "wands_eight": [
    "Momentum,Communication,Change",
    "勢い,伝達,変化",
    "Respond promptly while keeping communication clear.",
    "明確に伝え合いながら、必要なことに素早く応えましょう。",
    "Slow scattered urgency and verify information before acting.",
    "焦りを落ち着かせ、動く前に情報を確かめましょう。",
  ],
  "wands_nine": [
    "Resilience,Caution,Endurance",
    "回復力,用心,持久力",
    "Protect your progress and respect your need for rest.",
    "これまでの進歩を守り、休息の必要も尊重しましょう。",
    "Notice exhaustion and lower defenses that no longer help.",
    "疲労に気づき、役に立たなくなった防御をゆるめましょう。",
  ],
  "wands_ten": [
    "Burden,Responsibility,Limits",
    "負担,責任,限界",
    "Review your workload and share responsibilities where possible.",
    "仕事量を見直し、分けられる責任は分かち合いましょう。",
    "Release unnecessary duties instead of carrying everything alone.",
    "不要な役目を手放し、一人ですべてを背負わないようにしましょう。",
  ],
  "wands_page": [
    "Curiosity,Discovery,Expression",
    "好奇心,発見,表現",
    "Explore an interest with an open mind and small experiments.",
    "関心を持ったことを、柔軟な気持ちと小さな試みで探りましょう。",
    "Turn restless ideas into one focused learning step.",
    "落ち着かない構想を、一つの具体的な学びに変えましょう。",
  ],
  "wands_knight": [
    "Passion,Adventure,Action",
    "情熱,冒険,行動",
    "Act boldly while respecting practical limits.",
    "現実の限界を尊重しながら、勇気を持って行動しましょう。",
    "Regulate impatience so enthusiasm does not become recklessness.",
    "意欲が無謀さに変わらないよう、焦りを整えましょう。",
  ],
  "wands_queen": [
    "Confidence,Warmth,Independence",
    "自信,温かさ,自立",
    "Express yourself warmly and trust your creative strength.",
    "温かく自分を表現し、創造する力を信じましょう。",
    "Care for insecurity without controlling others or hiding yourself.",
    "不安をいたわり、他人を支配したり自分を隠したりしないようにしましょう。",
  ],
  "wands_king": [
    "Leadership,Vision,Responsibility",
    "指導力,展望,責任",
    "Lead with a clear vision and support others' initiative.",
    "明確な展望で導き、他の人の自主性も支えましょう。",
    "Keep ambition grounded and listen before imposing your direction.",
    "野心を現実に結びつけ、方針を押しつける前に耳を傾けましょう。",
  ],
  "cups_ace": [
    "Openness,Feeling,Connection",
    "心を開くこと,感情,つながり",
    "Make room for a new feeling or caring connection.",
    "新しい感情や思いやりのあるつながりに、心の余白を作りましょう。",
    "Acknowledge withheld feelings and care for your emotional capacity.",
    "抑えている感情を認め、心の余力をいたわりましょう。",
  ],
  "cups_two": [
    "Reciprocity,Trust,Partnership",
    "相互性,信頼,協力",
    "Build connection through honesty and mutual respect.",
    "率直さと互いへの尊重を通して、つながりを育みましょう。",
    "Discuss unequal expectations and restore healthy boundaries.",
    "期待のずれを話し合い、健全な境界を整えましょう。",
  ],
  "cups_three": [
    "Friendship,Sharing,Support",
    "友情,分かち合い,支援",
    "Enjoy companionship and accept support from your community.",
    "仲間との時間を楽しみ、周囲の支えを受け取りましょう。",
    "Balance belonging with your needs and avoid exclusion or excess.",
    "仲間意識と自分の必要を両立し、排除や過剰を避けましょう。",
  ],
  "cups_four": [
    "Pause,Reflection,Opportunity",
    "休止,内省,機会",
    "Pause to understand your feelings and notice quiet opportunities.",
    "立ち止まって気持ちを理解し、目立たない機会にも気づきましょう。",
    "Reengage gently when withdrawal prevents you from receiving support.",
    "閉じこもりが支えを遠ざけているなら、少しずつ外に目を向けましょう。",
  ],
  "cups_five": [
    "Loss,Grief,Remaining support",
    "喪失,悲しみ,残る支え",
    "Allow grief while noticing the support that remains.",
    "悲しみを受け止めながら、今も残る支えに目を向けましょう。",
    "Let recovery unfold without denying what hurt.",
    "傷ついたことを否定せず、回復を少しずつ進めましょう。",
  ],
  "cups_six": [
    "Memory,Kindness,Roots",
    "思い出,優しさ,原点",
    "Draw warmth from the past without losing sight of the present.",
    "過去の温かさを受け取りながら、今を見失わないようにしましょう。",
    "Update old patterns instead of living entirely through nostalgia.",
    "懐かしさだけに留まらず、古いパターンを今に合わせて見直しましょう。",
  ],
  "cups_seven": [
    "Possibilities,Imagination,Choice",
    "可能性,想像力,選択",
    "Compare imagined possibilities with real information before choosing.",
    "想像した可能性と現実の情報を比べて選びましょう。",
    "Narrow scattered options to a grounded, workable choice.",
    "散らばった選択肢を、実行できる現実的なものに絞りましょう。",
  ],
  "cups_eight": [
    "Departure,Searching,Values",
    "旅立ち,探求,価値観",
    "Leave what no longer nourishes you and seek what matters.",
    "心を満たさなくなったものから離れ、大切なものを探しましょう。",
    "Clarify whether staying or leaving serves your real needs.",
    "留まることと離れることのどちらが、本当の必要に合うか確かめましょう。",
  ],
  "cups_nine": [
    "Satisfaction,Gratitude,Enjoyment",
    "満足,感謝,楽しみ",
    "Appreciate what is enough and enjoy earned satisfaction.",
    "十分にあるものに感謝し、得られた満足を味わいましょう。",
    "Look beneath appearances to understand what fulfillment means to you.",
    "表面の豊かさだけでなく、自分にとっての充足を考えましょう。",
  ],
  "cups_ten": [
    "Harmony,Belonging,Shared joy",
    "調和,居場所,共に喜ぶこと",
    "Nurture shared wellbeing through genuine communication.",
    "本音で伝え合い、共に安心して過ごせる関係を育みましょう。",
    "Discuss real needs rather than preserving a picture of perfection.",
    "完璧な関係を演じるより、実際の必要を話し合いましょう。",
  ],
  "cups_page": [
    "Sensitivity,Curiosity,Expression",
    "感受性,好奇心,表現",
    "Listen to tender feelings and express them with curiosity.",
    "繊細な感情に耳を傾け、好奇心を持って表現しましょう。",
    "Ground emotional reactions and do not confuse fantasy with fact.",
    "感情を落ち着かせ、空想と事実を混同しないようにしましょう。",
  ],
  "cups_knight": [
    "Romance,Imagination,Invitation",
    "ロマンス,想像力,誘い",
    "Bring heartfelt ideas into sincere, considerate action.",
    "心からの思いを、誠実で思いやりのある行動にしましょう。",
    "Check idealized promises against consistency and reality.",
    "理想的な約束を、実際の行動や現実と照らし合わせましょう。",
  ],
  "cups_queen": [
    "Empathy,Intuition,Care",
    "共感,直感,いたわり",
    "Offer understanding while listening to your own emotional needs.",
    "理解を示しながら、自分自身の心の必要にも耳を傾けましょう。",
    "Protect boundaries when others' emotions become too heavy.",
    "他人の感情を抱えすぎているなら、境界を守りましょう。",
  ],
  "cups_king": [
    "Composure,Compassion,Balance",
    "落ち着き,思いやり,均衡",
    "Respond to strong feelings with steady, compassionate judgment.",
    "強い感情に、落ち着きと思いやりのある判断で応えましょう。",
    "Acknowledge feelings rather than controlling or suppressing them.",
    "感情を支配したり抑えたりするより、まず認めましょう。",
  ],
  "swords_ace": [
    "Clarity,Truth,Decision",
    "明晰さ,真実,決断",
    "Clarify the facts and state a clean, honest intention.",
    "事実を明確にし、率直な意図を言葉にしましょう。",
    "Check confusion and assumptions before making a firm decision.",
    "決断を固める前に、混乱や思い込みを確かめましょう。",
  ],
  "swords_two": [
    "Hesitation,Balance,Choice",
    "ためらい,均衡,選択",
    "Gather missing information and consider both sides of a decision.",
    "足りない情報を集め、選択の両面を考えましょう。",
    "Face the choice you have postponed, without demanding perfect certainty.",
    "完全な確信を求めすぎず、先延ばしにした選択に向き合いましょう。",
  ],
  "swords_three": [
    "Pain,Honesty,Healing",
    "痛み,率直さ,癒し",
    "Acknowledge painful truth and seek supportive ways to heal.",
    "つらい事実を認め、回復を支える方法を探しましょう。",
    "Release repeated self-blame and give healing time.",
    "繰り返す自責をゆるめ、癒しに時間を与えましょう。",
  ],
  "swords_four": [
    "Rest,Recovery,Stillness",
    "休息,回復,静けさ",
    "Take a deliberate pause to recover your clarity and strength.",
    "意識的に休み、明晰さと力を取り戻しましょう。",
    "Recognize exhaustion or restlessness and adjust your recovery rhythm.",
    "疲労や落ち着かなさに気づき、回復のリズムを調整しましょう。",
  ],
  "swords_five": [
    "Conflict,Cost,Boundaries",
    "対立,代償,境界",
    "Consider the cost of winning and protect mutual dignity.",
    "勝つことの代償を考え、互いの尊厳を守りましょう。",
    "Step out of destructive conflict and repair what can be repaired.",
    "傷つけ合う対立から離れ、修復できることに取り組みましょう。",
  ],
  "swords_six": [
    "Transition,Distance,Recovery",
    "移行,距離,回復",
    "Move toward calmer conditions with realistic support.",
    "現実的な支えを得ながら、より穏やかな状況へ進みましょう。",
    "Address unresolved concerns that make a transition difficult.",
    "移行を難しくしている未解決の気がかりに向き合いましょう。",
  ],
  "swords_seven": [
    "Strategy,Privacy,Honesty",
    "戦略,私的領域,誠実さ",
    "Plan thoughtfully while examining the honesty of your approach.",
    "慎重に計画し、自分の方法が誠実か確かめましょう。",
    "Clear hidden assumptions and take responsibility for your choices.",
    "隠れた思い込みを明らかにし、自分の選択に責任を持ちましょう。",
  ],
  "swords_eight": [
    "Restriction,Fear,Perspective",
    "制限,恐れ,視点",
    "Identify actual limits and one small freedom you can use.",
    "本当の制限と、使える小さな自由を見つけましょう。",
    "Challenge limiting beliefs gradually and accept helpful support.",
    "自分を縛る考えを少しずつ見直し、役立つ支援を受け取りましょう。",
  ],
  "swords_nine": [
    "Worry,Stress,Compassion",
    "心配,緊張,自分への優しさ",
    "Name your worries and seek practical support rather than facing them alone.",
    "心配を言葉にし、一人で抱えず現実的な支えを求めましょう。",
    "Allow recovery and discuss worries that keep repeating.",
    "回復を許し、繰り返す不安について誰かと話しましょう。",
  ],
  "swords_ten": [
    "Ending,Exhaustion,Renewal",
    "終わり,消耗,再生",
    "Recognize an ending and protect space for recovery.",
    "終わりを認め、回復するための余白を守りましょう。",
    "Rebuild gently rather than reopening an exhausted pattern.",
    "疲れきったパターンに戻らず、穏やかに立て直しましょう。",
  ],
  "swords_page": [
    "Curiosity,Observation,Learning",
    "好奇心,観察,学び",
    "Ask clear questions, observe carefully and verify information.",
    "明確に問い、よく観察し、情報を確認しましょう。",
    "Slow hasty conclusions and communicate without unnecessary sharpness.",
    "早合点を避け、不必要に鋭い言葉を使わず伝えましょう。",
  ],
  "swords_knight": [
    "Drive,Focus,Debate",
    "推進力,集中,議論",
    "Pursue a clear goal while listening to other perspectives.",
    "明確な目標を追いながら、別の視点にも耳を傾けましょう。",
    "Reduce haste and aggression before words or actions cause harm.",
    "言葉や行動で傷つける前に、焦りや攻撃性を落ち着かせましょう。",
  ],
  "swords_queen": [
    "Independence,Discernment,Boundaries",
    "自立,洞察,境界",
    "Use clear independent judgment with honest, considerate boundaries.",
    "自立した明確な判断で境界を守り、率直さと思いやりを両立しましょう。",
    "Keep your standards while checking defensiveness and incomplete facts.",
    "基準を保ちながら、防御的な態度や不足した情報を確かめましょう。",
  ],
  "swords_king": [
    "Reason,Standards,Judgment",
    "理性,基準,判断",
    "Combine consistent reasoning with respect for people.",
    "一貫した論理と、人への尊重を組み合わせて判断しましょう。",
    "Check rigid authority and bias against evidence and context.",
    "硬直した権威や偏見を、根拠と具体的な状況に照らして見直しましょう。",
  ],
  "pentacles_ace": [
    "Opportunity,Practice,Foundation",
    "機会,実践,基盤",
    "Prepare concretely for a promising practical opportunity.",
    "現実的な機会に向けて、具体的に準備し基盤を作りましょう。",
    "Check resources and conditions rather than surface rewards.",
    "表面の利益だけでなく、資源や条件を確かめましょう。",
  ],
  "pentacles_two": [
    "Balance,Adaptation,Resources",
    "均衡,調整,資源",
    "Coordinate tasks and distribute time, money and energy flexibly.",
    "複数の課題を調整し、時間、お金、力を柔軟に配分しましょう。",
    "Simplify overload and make priorities explicit.",
    "負担を減らし、優先順位を明確にしましょう。",
  ],
  "pentacles_three": [
    "Cooperation,Skill,Building",
    "協力,技能,積み重ね",
    "Build skills and reliable results through clear teamwork.",
    "明確な分担で協力し、技能と安定した成果を育みましょう。",
    "Clarify roles, standards and feedback where cooperation has weakened.",
    "協力がうまくいかないなら、役割、基準、フィードバックを具体化しましょう。",
  ],
  "pentacles_four": [
    "Protection,Security,Control",
    "守ること,安心,管理",
    "Care for security without preventing necessary movement of resources.",
    "安心を守りながら、必要な資源の流れも止めないようにしましょう。",
    "Set budgets and boundaries as you loosen control or manage loss.",
    "管理をゆるめるときも失う不安があるときも、予算と境界を整えましょう。",
  ],
  "pentacles_five": [
    "Hardship,Need,Support",
    "困難,不足,支援",
    "Seek available help when practical pressure feels isolating.",
    "現実の重圧で孤立を感じるなら、利用できる支えを探しましょう。",
    "Accept returning support and rebuild your resources steadily.",
    "戻りつつある支援を受け入れ、資源を着実に立て直しましょう。",
  ],
  "pentacles_six": [
    "Giving,Receiving,Fairness",
    "与えること,受け取ること,公平",
    "Balance giving and receiving with respect for independence.",
    "互いの自立を尊重し、与えることと受け取ることの均衡を見ましょう。",
    "Clarify unequal exchanges or conditions attached to help.",
    "不公平なやり取りや、支援に付く条件を明らかにしましょう。",
  ],
  "pentacles_seven": [
    "Patience,Assessment,Investment",
    "忍耐,評価,投入",
    "Review progress and choose how to cultivate long-term effort.",
    "進歩を振り返り、長期的な努力をどう続けるか考えましょう。",
    "Reassess methods and timelines when effort and results diverge.",
    "努力と成果が合わないなら、方法と期限を見直しましょう。",
  ],
  "pentacles_eight": [
    "Focus,Practice,Craft",
    "集中,練習,技術",
    "Improve through focused practice and steady small refinements.",
    "集中した練習と小さな改善を積み重ね、力を磨きましょう。",
    "Replace mechanical repetition or perfectionism with purposeful practice.",
    "機械的な反復や完璧主義を、目的のある練習に変えましょう。",
  ],
  "pentacles_nine": [
    "Independence,Harvest,Enjoyment",
    "自立,実り,楽しみ",
    "Enjoy the independence and comfort your effort has created.",
    "努力で築いた自立や心地よさを認め、成果を楽しみましょう。",
    "Define enough for yourself instead of comparing appearances of success.",
    "成功の見た目を比べず、自分にとって十分とは何か考えましょう。",
  ],
  "pentacles_ten": [
    "Legacy,Stability,Long term",
    "継承,安定,長期的視点",
    "Use lasting resources to support loved ones and future needs.",
    "長く続く資源を、大切な人や未来の必要のために活かしましょう。",
    "Discuss responsibilities and real needs in shared long-term plans.",
    "共有する長期計画の責任、境界、本当の必要を話し合いましょう。",
  ],
  "pentacles_page": [
    "Learning,Practice,Planning",
    "学び,実践,計画",
    "Turn interest into practical learning and steady skill building.",
    "関心を具体的な学びと実践につなげ、着実に技能を育みましょう。",
    "Choose a small goal and a workable habit to ground your plan.",
    "小さな目標と続けられる習慣で、計画を実行に移しましょう。",
  ],
  "pentacles_knight": [
    "Diligence,Reliability,Consistency",
    "勤勉,信頼性,継続",
    "Keep commitments through steady, reliable action.",
    "着実で信頼できる行動を続け、約束を果たしましょう。",
    "Adjust rigid routines or delays without losing consistency.",
    "継続を大切にしつつ、硬直した習慣や先延ばしを調整しましょう。",
  ],
  "pentacles_queen": [
    "Care,Practicality,Abundance",
    "いたわり,実用性,豊かさ",
    "Care practically for your body, environment and resources.",
    "体、環境、資源を現実的な方法でいたわりましょう。",
    "Check your capacity when overgiving or pressure makes you neglect yourself.",
    "与えすぎや重圧で自分を忘れているなら、力と資源の余裕を確かめましょう。",
  ],
  "pentacles_king": [
    "Management,Maturity,Stability",
    "管理,成熟,安定",
    "Manage resources responsibly with a sustainable long-term view.",
    "資源を成熟した姿勢で管理し、持続できる長期的な選択をしましょう。",
    "Let resources serve life rather than status, money or control.",
    "地位、お金、支配に振り回されず、資源を生活のために活かしましょう。",
  ],
};

String translateUi(String source, BuildContext context) => tr(source, context);
