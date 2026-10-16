import 'package:intl/intl.dart';

import 'models.dart';
import 'store.dart';

/// Result of a chat turn: reply text plus an optional suggested tool
/// (the UI shows an "Open tool" button — nothing auto-executes).
class ChatReply {
  final String text;
  final String? toolId;
  const ChatReply(this.text, {this.toolId});
}

/// On-device demo intelligence: original, template-based generators
/// personalized from each VA's memory. Always labeled "Demo mode" in the UI.
/// Never pretends to be a live AI model.
class DemoEngine {
  static String _mem(Map<String, String> m, String key) =>
      (m[key] ?? '').trim();

  static String _peso(num n) {
    final f = NumberFormat('#,##0.##', 'en_PH');
    return '₱${f.format(n)}';
  }

  // ================================================================ tools
  static String runTool(
    String vaId,
    String toolId,
    Map<String, String> inputs,
    Map<String, String> memory,
    AppStore store,
  ) {
    try {
      switch (vaId) {
        case VaIds.life:
          return _life(toolId, inputs, memory, store);
        case VaIds.business:
          return _business(toolId, inputs, memory, store);
        case VaIds.creator:
          return _creator(toolId, inputs, memory, store);
        case VaIds.home:
          return _home(toolId, inputs, memory, store);
        case VaIds.reply:
          return _reply(toolId, inputs, memory, store);
        case VaIds.travel:
          return _travel(toolId, inputs, memory, store);
        case VaIds.study:
          return _study(toolId, inputs, memory, store);
        default:
          return 'I don\'t recognize that assistant yet.';
      }
    } catch (e) {
      return 'Hmm, I hit a snag running that in demo mode. Try simpler inputs, or connect a live AI key in Profile → AI.';
    }
  }

  // ------------------------------------------------------------------ life
  static String _life(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    switch (toolId) {
      case 'daily_planner':
        return _planDay(inputs['dump'] ?? '', memory);
      case 'daily_briefing':
        return _briefing(store, memory);
      case 'ask':
        return _genericAsk('Life VA', inputs['q'] ?? '', memory,
            'I help with your day: tasks, reminders, goals, and plans.');
      default:
        return 'Life VA demo result ready.';
    }
  }

  static String _planDay(String dump, Map<String, String> memory) {
    final text = dump.trim();
    if (text.isEmpty) {
      return 'Tell me what\'s on your plate — e.g. "I have work at 9, lunch with Mom at 1, need groceries" — and I\'ll build your day plan.';
    }
    // Split into items, pull out time mentions like "at 9", "9am", "1:30pm".
    final rawItems = text
        .split(RegExp(r'[,.\n;]'))
        .map((e) => e.trim())
        .where((e) => e.length > 1)
        .toList();
    final timed = <_TimedItem>[];
    final untimed = <String>[];
    final timeRe =
        RegExp(r'(\bat\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false);
    for (final item in rawItems) {
      final m = timeRe.firstMatch(item);
      if (m != null) {
        var h = int.parse(m.group(2)!);
        final min = int.tryParse(m.group(3) ?? '0') ?? 0;
        final ap = (m.group(4) ?? '').toLowerCase();
        if (ap == 'pm' && h < 12) h += 12;
        if (ap == 'am' && h == 12) h = 0;
        if (h >= 0 && h < 24) {
          final label = item.replaceAll(timeRe, '').trim();
          timed.add(_TimedItem(h * 60 + min, _cap(label.isEmpty ? item : label)));
          continue;
        }
      }
      untimed.add(_cap(item));
    }
    timed.sort((a, b) => a.minutes.compareTo(b.minutes));
    final buf = StringBuffer('🗓️ Your day plan\n\n');
    if (timed.isEmpty && untimed.isEmpty) {
      return 'I couldn\'t pick out any items — try listing them separated by commas, with times like "at 9am".';
    }
    for (final t in timed) {
      final h24 = t.minutes ~/ 60, mm = t.minutes % 60;
      final ap = h24 >= 12 ? 'PM' : 'AM';
      var h12 = h24 % 12;
      if (h12 == 0) h12 = 12;
      buf.writeln(
          '• ${h12.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')} $ap — ${t.label}');
    }
    if (untimed.isNotEmpty) {
      buf.writeln('\n📌 Fit these in between:');
      for (final u in untimed) {
        buf.writeln('• $u');
      }
    }
    final routine = _mem(memory, 'routine');
    if (routine.isNotEmpty) buf.writeln('\n(Built around your routine: $routine)');
    buf.writeln('\nTip: add the timed ones as Reminders so I can nudge you.');
    return buf.toString();
  }

  static String _briefing(AppStore store, Map<String, String> memory) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = store.collectionOf('life_tasks');
    final dueToday = tasks.where((t) {
      if (t['done'] == 'true') return false;
      final d = DateTime.tryParse(t['due'] ?? '');
      if (d == null) return false;
      final dd = DateTime(d.year, d.month, d.day);
      return !dd.isAfter(today);
    }).toList();
    final upcoming = store.reminders
        .where((r) => r.at.isAfter(now.subtract(const Duration(hours: 1))))
        .take(5)
        .toList();
    final goals = store.collectionOf('life_goals');
    final hour = now.hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final buf = StringBuffer('☀️ $greet! Here\'s your briefing.\n\n');
    buf.writeln('📋 Tasks needing attention: ${dueToday.length}');
    for (final t in dueToday.take(5)) {
      buf.writeln('• ${t['title']}');
    }
    buf.writeln('\n⏰ Upcoming reminders: ${upcoming.length}');
    for (final r in upcoming) {
      buf.writeln(
          '• ${r.title} — ${DateFormat('MMM d, h:mm a').format(r.at)}');
    }
    buf.writeln('\n🎯 Active goals: ${goals.length}');
    for (final g in goals.take(3)) {
      buf.writeln('• ${g['title']}');
    }
    final priorities = _mem(memory, 'priorities');
    if (priorities.isNotEmpty) {
      buf.writeln('\n⭐ Your priorities: $priorities');
    }
    buf.writeln('\nOne thing at a time — you\'ve got this.');
    return buf.toString();
  }

  // -------------------------------------------------------------- business
  static String _business(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    switch (toolId) {
      case 'profit_calculator':
        return _profit(inputs, memory);
      case 'customer_messages':
        return _customerMsg(inputs, memory);
      case 'product_description':
        return _productDesc(inputs, memory);
      case 'marketing_ideas':
        return _marketing(inputs, memory);
      case 'ask':
        final biz = _mem(memory, 'business_name');
        return _genericAsk('Business VA', inputs['q'] ?? '', memory,
            'I help with products, pricing, profit math, inventory, customers, and marketing${biz.isNotEmpty ? ' for $biz' : ''}.');
      default:
        return 'Business VA demo result ready.';
    }
  }

  static String _profit(Map<String, String> inputs, Map<String, String> memory) {
    final costTotal = double.tryParse(inputs['cost_total'] ?? '') ?? 0;
    final qty = double.tryParse(inputs['qty'] ?? '') ?? 0;
    final sell = double.tryParse(inputs['sell_price'] ?? '') ?? 0;
    if (costTotal <= 0 || qty <= 0 || sell <= 0) {
      return 'Give me three numbers: total cost, quantity, and selling price each — e.g. cost ₱3,000, qty 50, price ₱120.';
    }
    final revenue = sell * qty;
    final profit = revenue - costTotal;
    final margin = revenue > 0 ? profit / revenue * 100 : 0;
    final unitCost = costTotal / qty;
    final breakEven = sell > unitCost ? (costTotal / (sell - unitCost)) : 0;
    final buf = StringBuffer('📊 Profit breakdown\n\n');
    buf.writeln('Revenue: ${_peso(revenue)} (${_peso(sell)} × ${qty.toStringAsFixed(0)} pcs)');
    buf.writeln('Total cost: ${_peso(costTotal)}');
    buf.writeln('Profit: ${_peso(profit)}');
    buf.writeln('Margin: ${margin.toStringAsFixed(1)}%');
    buf.writeln('Cost per unit: ${_peso(unitCost)}');
    if (breakEven > 0) {
      buf.writeln(
          'Break-even: sell ${breakEven.ceil()} pcs to cover costs.');
    }
    if (margin < 20) {
      buf.writeln(
          '\n⚠️ Margin is thin — consider raising the price or cutting unit cost.');
    } else if (margin >= 40) {
      buf.writeln('\n✅ Healthy margin — room for promos or discounts.');
    }
    final biz = _mem(memory, 'business_name');
    if (biz.isNotEmpty) buf.writeln('\nTracked for $biz.');
    return buf.toString();
  }

  static String _customerMsg(
      Map<String, String> inputs, Map<String, String> memory) {
    final situation = (inputs['situation'] ?? '').trim();
    final tone = (inputs['tone'] ?? 'Friendly').trim();
    final biz = _mem(memory, 'business_name');
    final name = biz.isNotEmpty ? biz : 'us';
    if (situation.isEmpty) {
      return 'Tell me what the customer said, and I\'ll draft the perfect reply.';
    }
    final lower = situation.toLowerCase();
    String draft;
    if (lower.contains('late') ||
        lower.contains('delay') ||
        lower.contains('waiting')) {
      draft =
          'Hi! Thank you so much for your patience — I\'m really sorry your order is running late. I\'m packing it right now and I\'ll send it out today. As a small thank-you for waiting, I\'d love to include a little extra in your package. 💛';
    } else if (lower.contains('price') ||
        lower.contains('discount') ||
        lower.contains('tawad')) {
      draft =
          'Hi! Thank you for asking. Our price reflects the quality ingredients and care we put into every piece. I can\'t lower it, but if you order 5 or more, I\'ll happily give you a bundle deal. Let me know! 😊';
    } else if (lower.contains('available') ||
        lower.contains('stock') ||
        lower.contains('order')) {
      draft =
          'Hi! Yes, it\'s available! 🎉 Just send me your name, address, and how many you\'d like, and I\'ll confirm your order right away. Thank you for choosing $name!';
    } else {
      draft =
          'Hi! Thank you for reaching out — I really appreciate it. Here\'s the quick answer: I\'ll take care of this for you personally. If you need anything else, just message me anytime. 😊 — $name';
    }
    if (tone == 'Professional') {
      draft = draft.replaceAll('🎉', '').replaceAll('💛', '').replaceAll('😊', '').trim();
      draft = 'Hello, and thank you for your message.\n\n$draft\n\nBest regards.';
    }
    return '✉️ Draft reply ($tone tone):\n\n$draft\n\n(Tweak it in your own voice before sending!)';
  }

  static String _productDesc(
      Map<String, String> inputs, Map<String, String> memory) {
    final product = (inputs['product'] ?? '').trim();
    final details = (inputs['details'] ?? '').trim();
    if (product.isEmpty) return 'Tell me the product name first.';
    final biz = _mem(memory, 'business_name');
    final buf = StringBuffer('📝 $product\n\n');
    buf.writeln(details.isEmpty
        ? 'Made fresh in small batches, with care in every piece.'
        : details);
    buf.writeln('\nWhy you\'ll love it:');
    buf.writeln('• Quality you can taste in every bite');
    buf.writeln('• Made fresh — never mass-produced');
    buf.writeln('• Perfect for gifts, merienda, or cravings');
    buf.writeln('\n📩 Message us to order — we reply fast!');
    if (biz.isNotEmpty) buf.writeln('— $biz');
    return buf.toString();
  }

  static String _marketing(
      Map<String, String> inputs, Map<String, String> memory) {
    final product = (inputs['product'] ?? 'your product').trim();
    final budget = (inputs['budget'] ?? 'Free / ₱0').trim();
    final buf = StringBuffer('📣 Marketing ideas for "$product" ($budget)\n\n');
    buf.writeln('1. Behind-the-scenes video: show how it\'s made — people love process.');
    buf.writeln('2. "First 10 buyers" promo: urgency beats discounts.');
    buf.writeln('3. Ask happy customers for a quick video review; repost it.');
    buf.writeln('4. Bundle deal: pair it with your bestseller for a set price.');
    buf.writeln('5. Weekend market or pop-up: nothing beats free taste tests.');
    if (budget != 'Free / ₱0') {
      buf.writeln('6. Boost your best post to nearby barangays for 3 days.');
    }
    final customers = _mem(memory, 'customers');
    if (customers.isNotEmpty) {
      buf.writeln('\n💡 Start with your regulars: $customers');
    }
    return buf.toString();
  }

  // --------------------------------------------------------------- creator
  static String _creator(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    final niche = _mem(memory, 'niche');
    final tone = _mem(memory, 'tone');
    final platforms = _mem(memory, 'platforms');
    final context =
        '${niche.isNotEmpty ? 'Niche: $niche. ' : ''}${tone.isNotEmpty ? 'Tone: $tone. ' : ''}${platforms.isNotEmpty ? 'Platforms: $platforms.' : ''}';
    switch (toolId) {
      case 'content_ideas':
        return _contentIdeas(inputs, context, niche);
      case 'script_generator':
        return _script(inputs, context, tone);
      case 'hook_generator':
        return _hooks(inputs, context);
      case 'caption_generator':
        return _caption(inputs, context, tone);
      case 'hashtag_ideas':
        return _hashtags(inputs);
      case 'content_calendar':
        return _calendar(inputs, context, niche);
      case 'comment_replies':
        return _commentReply(inputs, tone);
      case 'brand_collab':
        return _collab(inputs, context);
      case 'ask':
        return _genericAsk('Creator VA', inputs['q'] ?? '', memory,
            'I help with content ideas, scripts, hooks, captions, and growth strategy.');
      default:
        return 'Creator VA demo result ready.';
    }
  }

  static String _contentIdeas(
      Map<String, String> inputs, String context, String niche) {
    final count = (int.tryParse(inputs['count'] ?? '') ?? 10).clamp(3, 20);
    final topic = (inputs['topic'] ?? '').trim();
    final focus = topic.isNotEmpty ? topic : (niche.isNotEmpty ? niche : 'your niche');
    final ideas = [
      'The #1 mistake beginners make with $focus (and the 10-second fix)',
      'I tried $focus for 7 days straight — here\'s what happened',
      'POV: you finally figured out $focus',
      '$focus on a budget: my exact routine under ₱500',
      '3 things I wish someone told me before starting $focus',
      'Rating $focus trends: worth it or skip?',
      'The 30-second $focus routine for busy mornings',
      '$focus myths I used to believe',
      'What pros do differently with $focus',
      'My honest $focus favorites right now (no sponsorship)',
      'Beginner vs pro: $focus edition',
      'The $focus hack that saves me 20 minutes daily',
    ];
    final buf = StringBuffer('💡 $count content ideas — $focus\n\n');
    for (var i = 0; i < count; i++) {
      buf.writeln('${i + 1}. ${ideas[i % ideas.length]}');
    }
    if (context.isNotEmpty) buf.writeln('\n($context)');
    return buf.toString();
  }

  static String _script(Map<String, String> inputs, String context, String tone) {
    final topic = (inputs['topic'] ?? 'your topic').trim();
    final length = (inputs['length'] ?? '30 sec').trim();
    return '🎬 Script — "$topic" ($length)\n\n'
        '[0–3s HOOK]\n"Stop doing $topic the hard way — here\'s the shortcut."\n\n'
        '[3–10s SETUP]\n"Most people struggle because they skip this one step."\n\n'
        '[10–25s PAYOFF]\nWalk through the 3 key moves, one per beat. Show, don\'t just tell.\n\n'
        '[25–30s CTA]\n"Follow for part 2 — I\'m breaking down the advanced version tomorrow."\n\n'
        'Delivery tip: energy up in the first 3 seconds, then settle into a $tone conversational pace.'
        '${context.isNotEmpty ? '\n\n($context)' : ''}';
  }

  static String _hooks(Map<String, String> inputs, String context) {
    final topic = (inputs['topic'] ?? 'this').trim();
    final count = (int.tryParse(inputs['count'] ?? '') ?? 5).clamp(3, 10);
    final hooks = [
      'Nobody talks about this $topic trick…',
      'I wasted 6 months on $topic before learning this.',
      'If you do $topic, watch this first.',
      'The $topic mistake that\'s costing you views.',
      '3 $topic secrets pros won\'t share.',
      'This $topic hack feels illegal to know.',
      'Stop scrolling if you care about $topic.',
    ];
    final buf = StringBuffer('🪝 $count hooks\n\n');
    for (var i = 0; i < count; i++) {
      buf.writeln('${i + 1}. "${hooks[i % hooks.length]}"');
    }
    return buf.toString();
  }

  static String _caption(Map<String, String> inputs, String context, String tone) {
    final topic = (inputs['topic'] ?? 'today\'s post').trim();
    final t = tone.isEmpty ? 'friendly' : tone.toLowerCase();
    return '✍️ Caption ($t tone)\n\n'
        'Today\'s little win: $topic ✨\n'
        'Here\'s the thing nobody tells you — consistency beats perfection, every single time.\n\n'
        'Save this for later 📌 and tell me: what\'s YOUR take?\n'
        '👇 Drop it in the comments — I read every single one.'
        '${context.isNotEmpty ? '\n\n($context)' : ''}';
  }

  static String _hashtags(Map<String, String> inputs) {
    final topic = (inputs['topic'] ?? 'lifestyle').trim();
    final tag = topic.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').replaceAll(' ', '');
    return '#️⃣ Hashtag set\n\n'
        'Broad: #fyp #foryou #viral\n'
        'Niche: #${tag.isEmpty ? 'lifestyle' : tag} #${tag.isEmpty ? 'creator' : '${tag}ph'} #pinoycreator\n'
        'Community: #smallcreator #contentcreatorph\n\n'
        'Use 3–5 per post. Rotate sets weekly and watch which ones bring profile visits.';
  }

  static String _calendar(Map<String, String> inputs, String context, String niche) {
    final focus = (inputs['focus'] ?? '').trim();
    final theme = focus.isEmpty ? (niche.isEmpty ? 'your niche' : niche) : focus;
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final plan = [
      'Educational: teach one $theme tip',
      'Behind the scenes: your real process',
      'Trending format applied to $theme',
      'Storytime: a lesson you learned',
      'Quick hack or shortcut',
      'Community: answer a follower question',
      'Rest or repost your best performer',
    ];
    final buf = StringBuffer('📅 7-day content calendar — $theme\n\n');
    for (var i = 0; i < 7; i++) {
      buf.writeln('${days[i]}: ${plan[i]}');
    }
    buf.writeln('\nBatch-film 3 in one session to stay ahead.');
    return buf.toString();
  }

  static String _commentReply(Map<String, String> inputs, String tone) {
    final comment = (inputs['comment'] ?? '').trim();
    if (comment.isEmpty) return 'Paste the comment and I\'ll draft replies.';
    final t = tone.isEmpty ? 'Friendly' : tone;
    return '💬 Reply drafts ($t)\n\n'
        'Warm: "This made my day — thank you for watching! 💛"\n'
        'Playful: "Okay, this comment deserves its own video 😄"\n'
        'Engaging: "Great question! I\'m actually covering that in tomorrow\'s post — stay tuned 👀"\n\n'
        'Original comment: "$comment"';
  }

  static String _collab(Map<String, String> inputs, String context) {
    final brand = (inputs['brand'] ?? 'the brand').trim();
    final deliverable = (inputs['deliverable'] ?? '1 video post').trim();
    return '🤝 Brand pitch — $brand\n\n'
        'Subject: Collaboration idea for $brand\n\n'
        'Hi $brand team! I create content about ${context.isEmpty ? 'lifestyle' : context} '
        'and I\'d love to feature you in an authentic, story-driven post.\n\n'
        'Proposal: $deliverable\n'
        'What you get: my creative concept, posting within 7 days, and usage rights for 30 days.\n\n'
        'Rate-card tip: price = (your average views ÷ 1,000) × ₱150–₱300 as a starting point. '
        'Always get deliverables and payment terms in writing.';
  }

  // ------------------------------------------------------------------ home
  static String _home(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    switch (toolId) {
      case 'cleaning_schedule':
        return _cleaning(inputs, memory);
      case 'meal_planner':
        return _meals(inputs, memory);
      case 'plant_care':
        return _plant(inputs, memory);
      case 'pet_care':
        return _pet(inputs, memory);
      case 'family_tasks':
        return _family(inputs, memory);
      case 'ask':
        return _genericAsk('Home VA', inputs['q'] ?? '', memory,
            'I help with cleaning, meals, groceries, bills, plants, and pets.');
      default:
        return 'Home VA demo result ready.';
    }
  }

  static String _cleaning(Map<String, String> inputs, Map<String, String> memory) {
    final size = (inputs['size'] ?? '2BR').trim();
    final buf = StringBuffer('🧹 Weekly cleaning schedule ($size)\n\n');
    buf.writeln('Mon: Bathrooms (30 min)');
    buf.writeln('Tue: Dust + surfaces (20 min)');
    buf.writeln('Wed: Kitchen deep-clean (30 min)');
    buf.writeln('Thu: Floors — vacuum & mop (30 min)');
    buf.writeln('Fri: Laundry + linens (20 min)');
    buf.writeln('Sat: Tidy + declutter one area (20 min)');
    buf.writeln('Sun: Rest ✨ (just a 10-min reset)');
    final household = _mem(memory, 'household');
    if (household.isNotEmpty) buf.writeln('\nHousehold: $household — split days fairly!');
    return buf.toString();
  }

  static String _meals(Map<String, String> inputs, Map<String, String> memory) {
    final days = (int.tryParse(inputs['days'] ?? '') ?? 7).clamp(1, 14);
    final prefs = (inputs['prefs'] ?? '').trim();
    final meals = [
      'Chicken adobo + rice', 'Ginisang ampalaya + fried fish',
      'Pork sinigang + rice', 'Tortang talong + rice',
      'Chicken tinola + rice', 'Pinakbet + grilled bangus',
      'Spaghetti + garlic bread', 'Beef nilaga + rice',
      'Fried chicken + coleslaw', 'Monggo + rice',
      'Pancit canton + lumpia', 'Daing na bangus + tomatoes',
      'Kare-kare + rice', 'Chicken curry + rice',
    ];
    final buf = StringBuffer('🍳 $days-day meal plan\n');
    if (prefs.isNotEmpty) buf.writeln('Preferences: $prefs');
    buf.writeln('');
    for (var i = 0; i < days; i++) {
      buf.writeln('Day ${i + 1}: ${meals[i % meals.length]}');
    }
    buf.writeln('\nShop once for the week\'s proteins; buy veggies mid-week for freshness.');
    return buf.toString();
  }

  static String _plant(Map<String, String> inputs, Map<String, String> memory) {
    final plant = (inputs['plant'] ?? 'your plant').trim();
    final action = (inputs['action'] ?? 'Just checking').trim();
    if (action == 'Watered today') {
      return '🪴 Noted! You watered your $plant today.\n\n'
          'Next check: in 3–4 days — stick a finger 2cm into the soil. '
          'Dry? Water again. Damp? Wait.\n\n'
          'Tip: set a Reminder so I can nudge you.';
    }
    if (action == 'Fertilized today') {
      return '🪴 Noted! You fertilized your $plant today.\n\n'
          'Next feeding: in 2–4 weeks (half-strength is safer than full). '
          'Watch for yellowing tips — that means too much.';
    }
    if (action == 'Repotted today') {
      return '🪴 Noted! You repotted your $plant today.\n\n'
          'Keep it in bright indirect light for a week and hold off on fertilizer for 2 weeks while roots settle.';
    }
    return '🪴 $plant check-up:\n\n'
        '• Light: bright indirect is the sweet spot for most houseplants\n'
        '• Water: only when the top 2cm of soil is dry\n'
        '• Leaves: wipe dust monthly so they can breathe\n\n'
        'Tell me what you did ("Watered today") and I\'ll track it.';
  }

  static String _pet(Map<String, String> inputs, Map<String, String> memory) {
    final pet = (inputs['pet'] ?? '').trim();
    final need = (inputs['need'] ?? '').trim();
    final who = pet.isEmpty ? _mem(memory, 'pets') : pet;
    final name = who.isEmpty ? 'your pet' : who;
    if (need.isEmpty) {
      return '🐾 Tell me what you need for $name — feeding schedule, training, vet prep?';
    }
    return '🐾 Pet care — $name\n\n'
        'Here\'s a solid routine:\n'
        '• Meals: same times daily (puppies 3–4x/day, adults 2x)\n'
        '• Water: fresh bowl, refilled morning and night\n'
        '• Exercise: at least 30 minutes of play or walks\n'
        '• Vet: annual checkup, keep vaccines on schedule\n\n'
        'Your note: "$need"\nSet a daily Reminder and I\'ll nudge you until it\'s habit.';
  }

  static String _family(Map<String, String> inputs, Map<String, String> memory) {
    final members = (inputs['members'] ?? '').trim();
    final tasks = (inputs['tasks'] ?? '').trim();
    if (members.isEmpty || tasks.isEmpty) {
      return 'List the family members and the tasks, and I\'ll split them fairly.';
    }
    final people = members.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final taskList = tasks.split(RegExp(r'[,;\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final buf = StringBuffer('👨‍👩‍👧 Fair task split\n\n');
    for (var i = 0; i < taskList.length; i++) {
      buf.writeln('• ${taskList[i]} → ${people[i % people.length]}');
    }
    buf.writeln('\nRotate weekly so nobody\'s stuck with the worst chore forever.');
    return buf.toString();
  }

  // ----------------------------------------------------------------- reply
  static String _reply(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    final defaultTone = _mem(memory, 'default_tone');
    switch (toolId) {
      case 'rewrite':
      case 'change_tone':
        return _rewrite(inputs, defaultTone);
      case 'translate':
        return _translate(inputs);
      case 'reply_message':
        return _replyTo(inputs, defaultTone);
      case 'email_reply':
        return _email(inputs);
      case 'customer_reply':
        return _customerReply(inputs);
      case 'work_message':
        return _workMsg(inputs);
      case 'personal_message':
        return _personalMsg(inputs);
      case 'apology':
        return _apology(inputs);
      case 'meeting_response':
        return _meeting(inputs);
      case 'ask':
        return _genericAsk('Reply VA', inputs['q'] ?? '', memory,
            'I rewrite messages, draft replies, and translate — tell me what to write.');
      default:
        return 'Reply VA demo result ready.';
    }
  }

  static String _toneGuide(String tone) {
    switch (tone) {
      case 'Professional':
        return 'clear, respectful, no slang, no emojis';
      case 'Friendly':
        return 'warm, upbeat, a light emoji or two is fine';
      case 'Casual':
        return 'relaxed, conversational, like texting a friend';
      case 'Polite':
        return 'courteous and gentle, softens every request';
      case 'Funny':
        return 'playful with light humor, never mean';
      case 'Sweet':
        return 'tender and affectionate, heartfelt';
      case 'Firm':
        return 'direct and confident, polite but leaves no wiggle room';
      default:
        return 'natural and clear';
    }
  }

  static String _rewrite(Map<String, String> inputs, String defaultTone) {
    final draft = (inputs['draft'] ?? '').trim();
    var tone = (inputs['tone'] ?? '').trim();
    if (tone.isEmpty) tone = defaultTone.isEmpty ? 'Friendly' : defaultTone;
    if (draft.isEmpty) return 'Paste your draft and I\'ll rewrite it in a $tone tone.';
    final guide = _toneGuide(tone);
    // Template-based rewrite: restructure politely, keep meaning.
    final sentences = draft.split(RegExp(r'(?<=[.!?])\s+')).where((e) => e.trim().isNotEmpty).toList();
    final buf = StringBuffer('✏️ Rewritten ($tone tone — $guide):\n\n');
    if (tone == 'Professional') {
      buf.writeln('I wanted to follow up regarding the following:');
      for (final s in sentences) {
        buf.writeln('• ${_cap(s.trim())}');
      }
      buf.writeln('\nPlease let me know your thoughts at your earliest convenience.');
    } else if (tone == 'Firm') {
      buf.writeln('I need to be direct about this:');
      for (final s in sentences) {
        buf.writeln(_cap(s.trim()));
      }
      buf.writeln('\nI trust we can resolve this promptly.');
    } else if (tone == 'Funny') {
      buf.writeln('Okay, deep breath — here goes 😄');
      for (final s in sentences) {
        buf.writeln('• ${_cap(s.trim())}');
      }
      buf.writeln('\nNo pressure, but my day is 10% better already just sending this.');
    } else if (tone == 'Sweet') {
      buf.writeln('Hey you 💛');
      for (final s in sentences) {
        buf.writeln(_cap(s.trim()));
      }
      buf.writeln('\nJust wanted you to know I mean every word.');
    } else {
      buf.writeln('Hi! Quick note:');
      for (final s in sentences) {
        buf.writeln('• ${_cap(s.trim())}');
      }
      buf.writeln('\nThanks so much! 😊');
    }
    buf.writeln('\n(Original meaning preserved — adjust any line to taste.)');
    return buf.toString();
  }

  static String _translate(Map<String, String> inputs) {
    final text = (inputs['text'] ?? '').trim();
    final target = (inputs['target'] ?? 'Tagalog').trim();
    if (text.isEmpty) return 'Give me the text to translate.';
    // Demo: honest about scope — a small phrasebook for common phrases,
    // otherwise a graceful fallback.
    final phrasebook = <String, Map<String, String>>{
      'thank you': {'Tagalog': 'Salamat', 'Cebuano': 'Salamat', 'Taglish': 'Thank you!'},
      'good morning': {'Tagalog': 'Magandang umaga', 'Cebuano': 'Maayong buntag', 'Taglish': 'Good morning!'},
      'good night': {'Tagalog': 'Magandang gabi', 'Cebuano': 'Maayong gabii', 'Taglish': 'Good night!'},
      'how are you': {'Tagalog': 'Kumusta ka?', 'Cebuano': 'Kumusta ka?', 'Taglish': 'Kumusta?'},
      'i love you': {'Tagalog': 'Mahal kita', 'Cebuano': 'Gihigugma tika', 'Taglish': 'Love you!'},
      'sorry': {'Tagalog': 'Pasensya na', 'Cebuano': 'Pasayloa ko', 'Taglish': 'Sorry!'},
      'where are you': {'Tagalog': 'Nasaan ka?', 'Cebuano': 'Asa ka?', 'Taglish': 'Where are you?'},
    };
    final key = text.toLowerCase().replaceAll(RegExp(r'[.!?]'), '').trim();
    final hit = phrasebook[key]?[target] ?? phrasebook[key]?['Tagalog'];
    if (hit != null) {
      return '🌐 "$text" → $target:\n\n$hit';
    }
    return '🌐 Demo translation is limited to common phrases.\n\n'
        'For full translation of longer text, connect a live AI key in Profile → AI — '
        'it will translate naturally, including $target.';
  }

  static String _replyTo(Map<String, String> inputs, String defaultTone) {
    final message = (inputs['message'] ?? '').trim();
    final context = (inputs['context'] ?? '').trim();
    if (message.isEmpty) return 'Paste their message and I\'ll draft your reply.';
    final tone = defaultTone.isEmpty ? 'Friendly' : defaultTone;
    return '💬 Draft reply ($tone${context.isNotEmpty ? ' — $context' : ''}):\n\n'
        '"Thanks for letting me know! I\'ve got it handled — I\'ll update you once it\'s done. Really appreciate you reaching out. 😊"\n\n'
        'Their message: "$message"\n\nAdjust the middle sentence to your actual answer, then send.';
  }

  static String _email(Map<String, String> inputs) {
    final email = (inputs['email'] ?? '').trim();
    final point = (inputs['point'] ?? '').trim();
    if (email.isEmpty || point.isEmpty) {
      return 'Paste the email you received and what you want to say — I\'ll draft a professional reply.';
    }
    return '📧 Draft email reply:\n\n'
        'Subject: Re: your message\n\n'
        'Hi,\n\nThank you for your email.\n\n$point\n\n'
        'Please let me know if you need anything else.\n\nBest regards';
  }

  static String _customerReply(Map<String, String> inputs) {
    final message = (inputs['message'] ?? '').trim();
    if (message.isEmpty) return 'Paste the customer\'s message.';
    return '🛎️ Draft customer reply:\n\n'
        '"Hi! Thank you so much for messaging us — we really appreciate you. '
        'I\'m looking into this right now and I\'ll get back to you within the hour. 💛"\n\n'
        'Their message: "$message"';
  }

  static String _workMsg(Map<String, String> inputs) {
    final draft = (inputs['draft'] ?? '').trim();
    if (draft.isEmpty) return 'Give me your draft or key points.';
    return '💼 Polished work message:\n\n'
        '"Hi team — quick update: $draft '
        'Let me know if you have questions. Thanks!"\n\n'
        'Short, clear, confident. That\'s the whole formula.';
  }

  static String _personalMsg(Map<String, String> inputs) {
    final draft = (inputs['draft'] ?? '').trim();
    final who = (inputs['who'] ?? 'them').trim();
    if (draft.isEmpty) return 'Tell me what you want to say.';
    return '💌 For $who:\n\n'
        '"$draft 💛"\n\nSometimes the simplest words mean the most. Send it as-is if it feels right.';
  }

  static String _apology(Map<String, String> inputs) {
    final what = (inputs['what'] ?? '').trim();
    if (what.isEmpty) return 'Tell me what happened, honestly, and I\'ll help you own it well.';
    return '🙏 Draft apology:\n\n'
        '"I\'m really sorry about what happened ($what). '
        'You didn\'t deserve that, and I take full responsibility. '
        'Here\'s what I\'ll do differently: I\'ll make sure it doesn\'t happen again, starting today. '
        'I hope you can forgive me."\n\n'
        'A good apology: own it, don\'t excuse it, say what changes.';
  }

  static String _meeting(Map<String, String> inputs) {
    final invite = (inputs['invite'] ?? '').trim();
    final action = (inputs['action'] ?? 'Accept').trim();
    if (invite.isEmpty) return 'Paste the meeting details.';
    switch (action) {
      case 'Decline politely':
        return '📅 Draft decline:\n\n"Thanks so much for the invite! I won\'t be able to make it this time, but please keep me in the loop — and send me notes if there\'s anything I should know. 🙏"';
      case 'Propose new time':
        return '📅 Draft reschedule:\n\n"Thanks for setting this up! I can\'t make the proposed time — would [suggest 2 options] work instead? Happy to adjust around what suits the group."';
      default:
        return '📅 Draft accept:\n\n"Thanks for the invite — I\'m in! I\'ll be there. Let me know if there\'s anything I should prepare beforehand. 👍"';
    }
  }

  // ---------------------------------------------------------------- travel
  static String _travel(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    switch (toolId) {
      case 'plan_trip':
        return _tripPlan(inputs, memory);
      case 'itinerary':
        return _itinerary(inputs, memory);
      case 'travel_budget':
        return _travelBudget(inputs, memory);
      case 'packing_list':
        return _packing(inputs, memory);
      case 'accommodation':
        return _accommodation(inputs, memory);
      case 'food_planner':
        return _foodPlan(inputs, memory);
      case 'transportation':
        return _transport(inputs, memory);
      case 'places_to_visit':
        return _places(inputs, memory);
      case 'travel_alerts':
        return _alerts(inputs, memory);
      case 'ask':
        return _genericAsk('Travel VA', inputs['q'] ?? '', memory,
            'I plan trips: itineraries, budgets, packing, food, and transport — where to next?');
      default:
        return 'Travel VA demo result ready.';
    }
  }

  static String _tripPlan(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? '').trim();
    final days = int.tryParse(inputs['days'] ?? '') ?? 0;
    final budget = double.tryParse(inputs['budget'] ?? '') ?? 0;
    final travelers = int.tryParse(inputs['travelers'] ?? '') ?? 1;
    if (dest.isEmpty || days <= 0 || budget <= 0) {
      return 'Tell me: destination, number of days, and total budget — e.g. "plan a 4-day Boracay trip for ₱15,000".';
    }
    final style = _mem(memory, 'budget_style');
    final perDay = budget / days;
    final buf = StringBuffer('🗺️ $days-day $dest trip plan\n');
    if (style.isNotEmpty) buf.writeln('Travel style: $style');
    buf.writeln('Travelers: $travelers · Budget: ${_peso(budget)} (${_peso(perDay)}/day)\n');
    // Budget split: 35% stay, 25% food, 20% transport, 15% activities, 5% buffer
    final stay = budget * 0.35, food = budget * 0.25, trans = budget * 0.20,
        act = budget * 0.15, buffer = budget * 0.05;
    buf.writeln('💰 Suggested budget split:');
    buf.writeln('• Stay: ${_peso(stay)}');
    buf.writeln('• Food: ${_peso(food)}');
    buf.writeln('• Transport: ${_peso(trans)}');
    buf.writeln('• Activities: ${_peso(act)}');
    buf.writeln('• Emergency buffer: ${_peso(buffer)}\n');
    buf.writeln('📍 Day-by-day:');
    final themes = ['Arrival + sunset spot', 'Main attractions day', 'Adventure / island day', 'Food crawl + souvenirs', 'Chill morning + departure'];
    for (var i = 0; i < days; i++) {
      buf.writeln('Day ${i + 1}: ${themes[i % themes.length]}');
    }
    buf.writeln('\nOpen the Itinerary tool for an hour-by-hour version.');
    return buf.toString();
  }

  static String _itinerary(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? 'your destination').trim();
    final days = (int.tryParse(inputs['days'] ?? '') ?? 3).clamp(1, 14);
    final interests = (inputs['interests'] ?? 'sightseeing, food').trim();
    final buf = StringBuffer('📍 $days-day $dest itinerary\nInterests: $interests\n\n');
    final slots = [
      ('8:00 AM', 'Breakfast at a local favorite spot'),
      ('10:00 AM', 'Morning attraction / viewpoint'),
      ('12:30 PM', 'Lunch — try the local specialty'),
      ('2:30 PM', 'Afternoon activity or museum'),
      ('5:00 PM', 'Sunset viewpoint'),
      ('7:00 PM', 'Dinner + night market stroll'),
    ];
    for (var d = 1; d <= days; d++) {
      buf.writeln('—— Day $d ——');
      for (final s in slots) {
        buf.writeln('${s.$1} — ${s.$2}');
      }
      buf.writeln('');
    }
    final prefs = _mem(memory, 'preferences');
    if (prefs.isNotEmpty) buf.writeln('Tuned to your preferences: $prefs');
    return buf.toString();
  }

  static String _travelBudget(Map<String, String> inputs, Map<String, String> memory) {
    final budget = double.tryParse(inputs['budget'] ?? '') ?? 0;
    final days = int.tryParse(inputs['days'] ?? '') ?? 0;
    if (budget <= 0 || days <= 0) {
      return 'Give me your total budget and number of days.';
    }
    final perDay = budget / days;
    return '💰 Travel budget — ${_peso(budget)} over $days days\n\n'
        '• Stay (35%): ${_peso(budget * 0.35)} — ${_peso(budget * 0.35 / days)}/night\n'
        '• Food (25%): ${_peso(budget * 0.25)} — ${_peso(perDay * 0.25)}/day\n'
        '• Transport (20%): ${_peso(budget * 0.20)}\n'
        '• Activities (15%): ${_peso(budget * 0.15)}\n'
        '• Buffer (5%): ${_peso(budget * 0.05)}\n\n'
        'Daily target: ${_peso(perDay)}. Track spending in the Business VA\'s Expenses tool — it works for trips too.';
  }

  static String _packing(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? 'your trip').trim();
    final days = (int.tryParse(inputs['days'] ?? '') ?? 3).clamp(1, 30);
    final style = (inputs['style'] ?? 'Mixed').trim();
    final buf = StringBuffer('🎒 Packing list — $dest ($days days, $style)\n\n');
    buf.writeln('Essentials:');
    buf.writeln('• Valid ID + bookings (screenshots offline)');
    buf.writeln('• Cash + one backup payment method');
    buf.writeln('• Phone charger + power bank');
    buf.writeln('• Basic meds + personal hygiene kit\n');
    buf.writeln('Clothes (${(days).clamp(3, 7)} sets, do laundry if longer):');
    buf.writeln('• Tops, bottoms, sleepwear, underwear');
    buf.writeln('• Light jacket (malls, flights, mountains)');
    if (style == 'Beach' || style == 'Mixed') {
      buf.writeln('• Swimwear, rash guard, flip-flops');
      buf.writeln('• Reef-safe sunscreen, dry bag');
    }
    if (style == 'Mountain' || style == 'Mixed') {
      buf.writeln('• Sturdy shoes, extra socks, rain shell');
    }
    if (style == 'City') buf.writeln('• One nicer outfit for dinners');
    buf.writeln('\nRoll clothes to save space. Lay everything out the night before.');
    return buf.toString();
  }

  static String _accommodation(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? '').trim();
    final perNight = double.tryParse(inputs['budget_night'] ?? '') ?? 0;
    if (dest.isEmpty || perNight <= 0) {
      return 'Tell me the destination and your per-night budget.';
    }
    String tier;
    if (perNight < 1500) {
      tier = 'Hostels, fan rooms, and homestays — look for places with 8.5+ ratings and free cancellation.';
    } else if (perNight < 4000) {
      tier = 'Mid-range inns and boutique hotels — aircon, hot shower, and breakfast included in most.';
    } else {
      tier = 'Resorts and serviced apartments — beachfront or city-center, with pools and in-house dining.';
    }
    return '🏨 Where to stay in $dest (~${_peso(perNight)}/night)\n\n$tier\n\n'
        'Booking tips:\n• Book refundable rates until plans are final\n• Message the host about check-in time and parking\n• Save 10–15% by booking mid-week stays';
  }

  static String _foodPlan(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? 'your destination').trim();
    final days = (int.tryParse(inputs['days'] ?? '') ?? 3).clamp(1, 14);
    final perDay = double.tryParse(inputs['budget_day'] ?? '') ?? 0;
    if (perDay <= 0) return 'Tell me your food budget per day.';
    final buf = StringBuffer('🍜 Food plan — $dest ($days days, ${_peso(perDay)}/day)\n\n');
    buf.writeln('Daily split:');
    buf.writeln('• Breakfast ${_peso(perDay * 0.2)} — bakery, carinderia, or hotel freebie');
    buf.writeln('• Lunch ${_peso(perDay * 0.3)} — local eateries over tourist strips');
    buf.writeln('• Snacks ${_peso(perDay * 0.15)} — street food crawl!');
    buf.writeln('• Dinner ${_peso(perDay * 0.35)} — one nice meal per trip\n');
    buf.writeln('Rules of thumb:');
    buf.writeln('• Follow the locals\' queue — it\'s never wrong');
    buf.writeln('• One "splurge meal" per trip is worth it; keep the rest simple');
    buf.writeln('• Carry water and light snacks for travel days');
    return buf.toString();
  }

  static String _transport(Map<String, String> inputs, Map<String, String> memory) {
    final from = (inputs['from'] ?? '').trim();
    final to = (inputs['to'] ?? '').trim();
    if (from.isEmpty || to.isEmpty) return 'Tell me where you\'re coming from and going to.';
    return '🚌 $from → $to\n\n'
        'Options to compare:\n'
        '• Bus: cheapest, book a day ahead for long hauls\n'
        '• Van/shuttle: faster, departs when full\n'
        '• Flight: best for 6+ hour land trips — watch for seat sales\n'
        '• Ferry: for island hops — check schedules the night before\n\n'
        'At your destination:\n'
        '• Tricycles and jeeps for short hops — agree on the fare first\n'
        '• Ride-hailing apps for late nights\n'
        '• Rent a motorbike only if you\'re licensed and confident';
  }

  static String _places(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? '').trim();
    final interests = (inputs['interests'] ?? '').trim();
    if (dest.isEmpty) return 'Which destination should I curate?';
    return '🏝️ Places to visit — $dest\n'
        '${interests.isNotEmpty ? 'Interests: $interests\n' : ''}\n'
        'A balanced must-see mix:\n'
        '• The famous viewpoint — go at opening time to beat crowds\n'
        '• One "local secret" spot — ask your host, not the brochure\n'
        '• The food street or public market\n'
        '• A nature stop: beach, falls, or viewpoint\n'
        '• The old town / heritage area for golden hour\n\n'
        'Plan max 3 stops per day — trips are for enjoying, not rushing.';
  }

  static String _alerts(Map<String, String> inputs, Map<String, String> memory) {
    final dest = (inputs['destination'] ?? 'your destination').trim();
    return '⚠️ Pre-trip checklist — $dest\n\n'
        '• Check the weather forecast 3 days before\n'
        '• Save emergency numbers + nearest hospital location offline\n'
        '• Tell someone your itinerary\n'
        '• Photocopy your ID; keep originals in the hotel safe\n'
        '• Download offline maps for the area\n'
        '• Bring more cash than you think — ATMs can be scarce\n'
        '• Respect local customs and dress codes at religious sites\n\n'
        'Have an amazing trip! ✈️';
  }

  // ----------------------------------------------------------------- study
  static String _study(String toolId, Map<String, String> inputs,
      Map<String, String> memory, AppStore store) {
    switch (toolId) {
      case 'explain_topic':
        return _explain(inputs, memory);
      case 'make_notes':
        return _notes(inputs, memory);
      case 'flashcards':
        return _flashcards(inputs, memory);
      case 'make_quiz':
        return _quiz(inputs, memory);
      case 'study_planner':
        return _studyPlan(inputs, memory);
      case 'exam_prep':
        return _examPrep(inputs, memory);
      case 'ask':
        return _genericAsk('Study VA', inputs['q'] ?? '', memory,
            'I explain topics, make notes, quizzes, flashcards, and study plans.');
      default:
        return 'Study VA demo result ready.';
    }
  }

  static String _explain(Map<String, String> inputs, Map<String, String> memory) {
    final topic = (inputs['topic'] ?? '').trim();
    final subject = (inputs['subject'] ?? _mem(memory, 'subjects')).trim();
    if (topic.isEmpty) return 'What topic should I explain?';
    return '💡 $topic${subject.isNotEmpty ? ' ($subject)' : ''} — simply explained\n\n'
        'Think of it like this: every big idea is built from small, simple pieces. '
        'Start with the "why" — why does $topic matter in real life? '
        'Then learn the 3–4 key terms, then one worked example.\n\n'
        'Study loop:\n'
        '1. Read the concept once, slowly\n'
        '2. Close the notes and explain it out loud in your own words\n'
        '3. Whatever you stumble on — that\'s what to review\n\n'
        'Want me to quiz you on it? Open "Make a Quiz".';
  }

  static String _notes(Map<String, String> inputs, Map<String, String> memory) {
    final topic = (inputs['topic'] ?? 'your topic').trim();
    final subject = (inputs['subject'] ?? _mem(memory, 'subjects')).trim();
    return '📝 Study notes — $topic${subject.isNotEmpty ? ' ($subject)' : ''}\n\n'
        'KEY TERMS\n• Define each new term in ONE sentence, in your own words.\n\n'
        'CORE IDEAS\n• Idea 1: the big picture — what is this about?\n• Idea 2: how does it work, step by step?\n• Idea 3: one real-life example.\n\n'
        'COMMON MISTAKES\n• Write down the trap answers and why they\'re wrong.\n\n'
        'ONE-SENTENCE SUMMARY\n• If you can\'t summarize it in one sentence, review once more.\n\n'
        'Copy this structure into your notebook and fill it in — that act of writing IS the studying.';
  }

  static String _flashcards(Map<String, String> inputs, Map<String, String> memory) {
    final topic = (inputs['topic'] ?? 'your topic').trim();
    final count = (int.tryParse(inputs['count'] ?? '') ?? 8).clamp(3, 15);
    final buf = StringBuffer('🃏 $count flashcards — $topic\n\n');
    final prompts = [
      'Define the single most important term in $topic.',
      'What is the "why" behind $topic?',
      'Name 3 key facts about $topic.',
      'Give one real-life example of $topic.',
      'What is the most common mistake with $topic?',
      'Explain $topic as if to a 10-year-old.',
      'What comes BEFORE $topic in the learning sequence?',
      'What comes AFTER it?',
    ];
    for (var i = 0; i < count; i++) {
      buf.writeln('Card ${i + 1} — Q: ${prompts[i % prompts.length]}');
      buf.writeln('         A: (write your answer, then check your notes)\n');
    }
    buf.writeln('Review daily: right pile grows, wrong pile repeats tomorrow.');
    return buf.toString();
  }

  static String _quiz(Map<String, String> inputs, Map<String, String> memory) {
    final topic = (inputs['topic'] ?? 'your topic').trim();
    final count = (int.tryParse(inputs['count'] ?? '') ?? 5).clamp(3, 10);
    final buf = StringBuffer('❓ Quiz — $topic ($count questions)\n\n');
    final qs = [
      'Which statement BEST describes the main idea of $topic?',
      'True or false: (write one tricky statement about $topic)',
      'Fill in the blank: "The key principle of $topic is ___."',
      'Short answer: give one example of $topic in real life.',
      'Which of these is NOT related to $topic — and why?',
    ];
    for (var i = 0; i < count; i++) {
      buf.writeln('${i + 1}. ${qs[i % qs.length]}');
    }
    buf.writeln('\nAnswers: check your notes — the struggle to recall is what builds memory.');
    buf.writeln('Log your confidence afterwards in "My Progress".');
    return buf.toString();
  }

  static String _studyPlan(Map<String, String> inputs, Map<String, String> memory) {
    final goal = (inputs['goal'] ?? '').trim();
    final days = (int.tryParse(inputs['days'] ?? '') ?? 5).clamp(1, 60);
    final hours = (double.tryParse(inputs['hours'] ?? '') ?? 2).clamp(0.5, 12);
    if (goal.isEmpty) {
      return 'Tell me what you\'re preparing for — e.g. "biology exam Friday, make a study plan".';
    }
    final buf = StringBuffer('🗓️ Study plan — $goal\n$days days × ${hours.toStringAsFixed(1)}h/day\n\n');
    final phases = ['Learn: read + take structured notes', 'Practice: flashcards + worked examples', 'Test: quiz yourself, review mistakes', 'Review: weak spots only, then rest'];
    for (var d = 1; d <= days; d++) {
      final phase = d <= days * 0.4
          ? phases[0]
          : d <= days * 0.7
              ? phases[1]
              : d < days
                  ? phases[2]
                  : phases[3];
      buf.writeln('Day $d: $phase');
    }
    buf.writeln('\nSession recipe: 25 min focus → 5 min break, repeat. No phones during focus blocks.');
    final exams = _mem(memory, 'exam_dates');
    if (exams.isNotEmpty) buf.writeln('Your exam dates: $exams');
    return buf.toString();
  }

  static String _examPrep(Map<String, String> inputs, Map<String, String> memory) {
    final subject = (inputs['subject'] ?? 'your subject').trim();
    final date = (inputs['date'] ?? '').trim();
    final topics = (inputs['topics'] ?? '').trim();
    final buf = StringBuffer('🎓 Exam prep — $subject\n');
    if (date.isNotEmpty) {
      final d = DateTime.tryParse(date);
      if (d != null) {
        final left = d.difference(DateTime.now()).inDays;
        buf.writeln('Exam: ${DateFormat('MMM d, yyyy').format(d)} ($left days left)\n');
      }
    }
    buf.writeln('Final countdown:');
    buf.writeln('• 3 days out: full practice test under timed conditions');
    buf.writeln('• 2 days out: review ONLY your mistake list');
    buf.writeln('• 1 day out: light review + early sleep (sleep beats cramming)');
    buf.writeln('• Exam day: real breakfast, arrive early, read every question twice');
    if (topics.isNotEmpty) buf.writeln('\nYour topics:\n$topics');
    return buf.toString();
  }

  // ---------------------------------------------------------------- helpers
  static String _genericAsk(
      String vaName, String q, Map<String, String> memory, String about) {
    if (q.trim().isEmpty) return 'Ask me anything — I\'m listening.';
    final lower = q.toLowerCase();
    if (lower.contains('who are you') || lower.contains('what can you do')) {
      return 'I\'m $vaName, one of your 7 Tasky assistants. $about\n\n'
          'Tap my tool buttons above for guided help, or just keep chatting — '
          'I\'ll point you to the right tool. (Demo mode: my answers are generated on-device. '
          'Connect a live AI key in Profile → AI for full AI answers.)';
    }
    return 'Good question! In demo mode I give my best on-device answer:\n\n'
        '$about\n\nFor "$q" — try one of my tool buttons above; they\'re built for exactly this. '
        'Or connect a live AI key in Profile → AI and I\'ll answer anything in full.';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ================================================================== chat
  static ChatReply chat(
    String vaId,
    String text,
    Map<String, String> memory,
    AppStore store,
  ) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return const ChatReply('I\'m listening — what\'s on your mind?');

    // --- consequential: reminders (suggest tool, never auto-create)
    if (_hasAny(t, ['remind me', 'reminder', 'nudge me', 'notify me'])) {
      return const ChatReply(
        'I can set that reminder for you — tap below and I\'ll ask when, then confirm before anything is scheduled.',
        toolId: 'reminders',
      );
    }
    // --- tasks
    if (_hasAny(t, ['add task', 'to-do', 'todo', 'task'])) {
      return const ChatReply('Let\'s get it on your list — open My Tasks and add it in seconds.', toolId: 'my_tasks');
    }
    // --- planning
    if (_hasAny(t, ['plan my day', 'schedule my day', 'my day', 'brain dump'])) {
      return const ChatReply('Drop everything on your mind into the Daily Planner and I\'ll turn it into a timed plan.', toolId: 'daily_planner');
    }
    // --- briefing
    if (_hasAny(t, ['briefing', 'my day today', 'what\'s today', 'whats today', 'overview'])) {
      return ChatReply(_briefing(store, memory));
    }
    // --- business
    if (_hasAny(t, ['profit', 'margin', 'break-even', 'breakeven', 'how much will i earn'])) {
      return const ChatReply('Let\'s run the numbers — open the Profit Calculator.', toolId: 'profit_calculator');
    }
    if (_hasAny(t, ['marketing', 'promote', 'advertise'])) {
      return const ChatReply('I\'ve got ideas — open Marketing Ideas and tell me your budget.', toolId: 'marketing_ideas');
    }
    if (_hasAny(t, ['product description', 'listing'])) {
      return const ChatReply('Let\'s write a listing that sells — open Product Description.', toolId: 'product_description');
    }
    // --- creator
    if (_hasAny(t, ['content idea', 'video idea', 'tiktok idea', 'post idea'])) {
      return const ChatReply('Fresh ideas coming up — open Content Ideas.', toolId: 'content_ideas');
    }
    if (_hasAny(t, ['hook'])) {
      return const ChatReply('Let\'s craft scroll-stoppers — open the Hook Generator.', toolId: 'hook_generator');
    }
    if (_hasAny(t, ['caption'])) {
      return const ChatReply('I\'ll write it with personality — open the Caption Generator.', toolId: 'caption_generator');
    }
    if (_hasAny(t, ['hashtag'])) {
      return const ChatReply('Reach the right crowd — open Hashtag Ideas.', toolId: 'hashtag_ideas');
    }
    if (_hasAny(t, ['script'])) {
      return const ChatReply('Beat-by-beat script time — open the Script Generator.', toolId: 'script_generator');
    }
    // --- home
    if (_hasAny(t, ['grocery', 'groceries'])) {
      final key = vaId == VaIds.home ? 'grocery_list' : 'shopping_list';
      return ChatReply('Here\'s your list — add what you need.', toolId: key);
    }
    if (_hasAny(t, ['meal', 'dinner', 'lunch', 'cook'])) {
      return const ChatReply('Let\'s plan your meals — open the Meal Planner.', toolId: 'meal_planner');
    }
    if (_hasAny(t, ['watered', 'plant'])) {
      return const ChatReply('Tell the Plant Care tool what you did and I\'ll track it.', toolId: 'plant_care');
    }
    // --- reply
    if (_hasAny(t, ['rewrite', 'rephrase', 'sound professional', 'make this sound'])) {
      return const ChatReply('Paste it into Rewrite My Message and pick your tone.', toolId: 'rewrite');
    }
    if (_hasAny(t, ['translate', 'tagalog', 'in english'])) {
      return const ChatReply('I\'ll translate it naturally — open Translate.', toolId: 'translate');
    }
    if (_hasAny(t, ['apolog', 'sorry'])) {
      return const ChatReply('Let\'s make it sincere — open the Apology helper.', toolId: 'apology');
    }
    if (_hasAny(t, ['email'])) {
      return const ChatReply('I\'ll draft it — open Email Reply.', toolId: 'email_reply');
    }
    // --- travel
    if (_hasAny(t, ['plan a trip', 'trip to', 'travel to', 'vacation'])) {
      return const ChatReply('Adventure time! Open Plan a Trip with your destination, days, and budget.', toolId: 'plan_trip');
    }
    if (_hasAny(t, ['itinerary'])) {
      return const ChatReply('Day-by-day coming up — open the Itinerary builder.', toolId: 'itinerary');
    }
    if (_hasAny(t, ['packing', 'pack for'])) {
      return const ChatReply('Pack once, pack right — open the Packing List.', toolId: 'packing_list');
    }
    if (_hasAny(t, ['budget for', 'travel budget'])) {
      return const ChatReply('Let\'s split it smartly — open the Travel Budget tool.', toolId: 'travel_budget');
    }
    // --- study
    if (_hasAny(t, ['quiz'])) {
      return const ChatReply('Test yourself — open Make a Quiz.', toolId: 'make_quiz');
    }
    if (_hasAny(t, ['flashcard'])) {
      return const ChatReply('Active recall time — open Flashcards.', toolId: 'flashcards');
    }
    if (_hasAny(t, ['study plan', 'exam'])) {
      return ChatReply(
        'Let\'s build your plan — open the Study Planner.',
        toolId: _hasAny(t, ['exam']) ? 'exam_prep' : 'study_planner',
      );
    }
    if (_hasAny(t, ['explain'])) {
      return const ChatReply('I\'ll break it down simply — open Explain a Topic.', toolId: 'explain_topic');
    }
    // --- goals / shopping
    if (_hasAny(t, ['goal'])) {
      return const ChatReply('Big dreams deserve tracking — open Goals.', toolId: 'goals');
    }
    if (_hasAny(t, ['bill'])) {
      return const ChatReply('Stay on top of due dates — open Bills.', toolId: 'bills');
    }
    // --- greetings / identity
    if (_hasAny(t, ['hello', 'hi', 'hey', 'kumusta'])) {
      final va = VaIds.all.contains(vaId) ? vaId : VaIds.life;
      final name = _mem(memory, 'customName');
      return ChatReply(
          'Hello! ${name.isNotEmpty ? 'I\'m $name, ' : ''}your ${_nounOf(va)} assistant. What can I help with today?');
    }
    if (_hasAny(t, ['thank'])) {
      return const ChatReply('Anytime! That\'s what I\'m here for. 💛');
    }
    // --- fallback: route to the VA's ask tool
    return ChatReply(
      'Here\'s my best on-device take:\n\n${_fallbackAnswer(vaId, text, memory)}\n\n'
      'Want the full AI treatment? Connect a key in Profile → AI, or tap Ask for a guided answer.',
      toolId: 'ask',
    );
  }

  static bool _hasAny(String text, List<String> keys) {
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  static String _nounOf(String vaId) {
    switch (vaId) {
      case VaIds.business:
        return 'business';
      case VaIds.creator:
        return 'creator';
      case VaIds.home:
        return 'home';
      case VaIds.reply:
        return 'reply';
      case VaIds.travel:
        return 'travel';
      case VaIds.study:
        return 'study';
      default:
        return 'life';
    }
  }

  static String _fallbackAnswer(String vaId, String text, Map<String, String> memory) {
    switch (vaId) {
      case VaIds.business:
        return 'For business questions, I shine with specifics: give me your costs, prices, or quantities and I\'ll do the math. The Profit Calculator is the fastest win.';
      case VaIds.creator:
        final niche = _mem(memory, 'niche');
        return niche.isNotEmpty
            ? 'For your $niche content: lead with a bold hook in the first 3 seconds, deliver one clear payoff, and end with a question to drive comments. My Content Ideas tool has 12+ tailored starters.'
            : 'Tell me your niche in my Memory (🧠 button above) and I\'ll tailor every idea to it.';
      case VaIds.home:
        return 'For home questions, specifics help: tell me the room, the plant, or the pet, and I\'ll give you a concrete routine.';
      case VaIds.reply:
        return 'Paste the message or draft into one of my writing tools and I\'ll shape it in your chosen tone.';
      case VaIds.travel:
        final style = _mem(memory, 'budget_style');
        return 'Give me a destination, days, and budget and I\'ll build the full plan${style.isNotEmpty ? ' in your $style style' : ''}.';
      case VaIds.study:
        return 'Tell me the subject and topic — I\'ll explain it simply, then quiz you so it sticks.';
      default:
        return 'Tell me a bit more — what\'s the situation, and what outcome do you want? The more specific, the better my plan.';
    }
  }
}

class _TimedItem {
  final int minutes;
  final String label;
  _TimedItem(this.minutes, this.label);
}
