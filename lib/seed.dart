import 'models.dart';
import 'store.dart';

/// First-run sample content. All original, realistic, per-VA.
/// Applied once per install (guarded by a prefs flag in [AppStore.load]),
/// so it can never duplicate.
class SeedData {
  static void apply(AppStore s) {
    _seedProfiles(s);
    _seedCollections(s);
  }

  static void _seedProfiles(AppStore s) {
    // Leave names blank (user renames), seed a few helpful memory fields.
    s.vaProfiles[VaIds.creator] = VaProfile(vaId: VaIds.creator, fields: {
      'niche': 'Everyday cooking for busy people',
      'tone': 'Friendly',
      'platforms': 'TikTok, Instagram Reels',
      'style': 'Quick talking-head demos',
    });
    s.vaProfiles[VaIds.business] = VaProfile(vaId: VaIds.business, fields: {
      'business_name': 'Sample Sweets Corner',
      'products': 'Choco chip cookies ₱120/box, Banana loaf ₱150',
      'customers': 'Weekend market stall regulars',
      'inventory': 'Flour, sugar, butter restocked weekly',
    });
    s.vaProfiles[VaIds.travel] = VaProfile(vaId: VaIds.travel, fields: {
      'destinations': 'Philippine beaches and waterfalls',
      'budget_style': 'Budget',
      'preferences': 'Street food, sunrise views, public transport',
    });
    s.vaProfiles[VaIds.home] = VaProfile(vaId: VaIds.home, fields: {
      'household': 'Me and my partner',
      'pets': 'Poodle puppy named Biscuit',
      'plants': 'Basil, pothos, snake plant',
    });
    s.vaProfiles[VaIds.study] = VaProfile(vaId: VaIds.study, fields: {
      'subjects': 'Biology, Mathematics',
      'exam_dates': '',
      'level': 'College',
    });
    s.vaProfiles[VaIds.reply] = VaProfile(vaId: VaIds.reply, fields: {
      'default_tone': 'Friendly',
      'languages': 'English, Tagalog',
    });
    s.vaProfiles[VaIds.life] = VaProfile(vaId: VaIds.life, fields: {
      'routine': 'Work 9am–6pm weekdays',
      'priorities': 'Health, savings, side business',
    });
  }

  static void _seedCollections(AppStore s) {
    final id = s.uuid;
    s.collections['life_tasks'] = [
      {
        'id': id.v4(),
        'title': 'Buy groceries for the week',
        'due': _isoDays(1),
        'note': 'Eggs, rice, chicken, veggies',
        'done': 'false',
      },
      {
        'id': id.v4(),
        'title': 'Call the bank about the new card',
        'due': _isoDays(2),
        'note': '',
        'done': 'false',
      },
      {
        'id': id.v4(),
        'title': 'Morning walk — 30 minutes',
        'due': _isoDays(0),
        'note': 'Around the village loop',
        'done': 'true',
      },
    ];
    s.collections['life_goals'] = [
      {
        'id': id.v4(),
        'title': 'Save ₱60,000 emergency fund',
        'target': _isoDays(180),
        'note': '₱10k per month, auto-transfer on payday',
      },
      {
        'id': id.v4(),
        'title': 'Read 12 books this year',
        'target': _isoDays(260),
        'note': 'One book a month, 20 pages a day',
      },
    ];
    s.collections['life_shopping'] = [
      {'id': id.v4(), 'item': 'Eggs (1 tray)', 'qty': '1', 'checked': 'false'},
      {'id': id.v4(), 'item': 'Rice 5kg', 'qty': '1', 'checked': 'false'},
      {'id': id.v4(), 'item': 'Dish soap', 'qty': '2', 'checked': 'true'},
    ];
    s.collections['biz_products'] = [
      {
        'id': id.v4(),
        'name': 'Choco chip cookies (box of 6)',
        'price': '120',
        'cost': '68',
        'stock': '24',
      },
      {
        'id': id.v4(),
        'name': 'Banana loaf',
        'price': '150',
        'cost': '85',
        'stock': '10',
      },
    ];
    s.collections['biz_sales'] = [
      {
        'id': id.v4(),
        'item': 'Choco chip cookies',
        'qty': '8',
        'amount': '960',
        'date': _isoDays(0),
      },
      {
        'id': id.v4(),
        'item': 'Banana loaf',
        'qty': '3',
        'amount': '450',
        'date': _isoDays(-1),
      },
    ];
    s.collections['biz_expenses'] = [
      {
        'id': id.v4(),
        'name': 'Flour + sugar restock',
        'amount': '850',
        'category': 'Inventory',
        'date': _isoDays(-2),
      },
      {
        'id': id.v4(),
        'name': 'Stall transport',
        'amount': '200',
        'category': 'Transport',
        'date': _isoDays(-1),
      },
    ];
    s.collections['biz_inventory'] = [
      {'id': id.v4(), 'item': 'Butter (bars)', 'qty': '12', 'note': 'Fridge'},
      {'id': id.v4(), 'item': 'Kraft boxes', 'qty': '50', 'note': 'Storeroom'},
    ];
    s.collections['biz_customers'] = [
      {
        'id': id.v4(),
        'name': 'Cafe Aroma',
        'contact': '0927-111-2233',
        'note': 'Orders 10 boxes every Friday',
      },
    ];
    s.collections['creator_tracker'] = [
      {
        'id': id.v4(),
        'title': '3-ingredient pancake hack',
        'platform': 'TikTok',
        'status': 'Posted',
        'date': _isoDays(-3),
      },
      {
        'id': id.v4(),
        'title': 'What I eat in a busy day',
        'platform': 'Instagram',
        'status': 'Filmed',
        'date': _isoDays(-1),
      },
    ];
    s.collections['home_grocery'] = [
      {'id': id.v4(), 'item': 'Cooking oil', 'qty': '1', 'checked': 'false'},
      {'id': id.v4(), 'item': 'Laundry detergent', 'qty': '1', 'checked': 'false'},
    ];
    s.collections['home_bills'] = [
      {
        'id': id.v4(),
        'name': 'Electricity',
        'amount': '2400',
        'due': _isoDays(10),
        'paid': 'false',
      },
      {
        'id': id.v4(),
        'name': 'Internet',
        'amount': '1699',
        'due': _isoDays(5),
        'paid': 'false',
      },
    ];
    s.collections['home_tasks'] = [
      {
        'id': id.v4(),
        'title': 'Deep-clean the bathroom',
        'assignee': 'Me',
        'done': 'false',
      },
      {
        'id': id.v4(),
        'title': 'Fix the wobbly chair',
        'assignee': 'Partner',
        'done': 'false',
      },
    ];
    s.collections['home_inventory'] = [
      {
        'id': id.v4(),
        'item': 'First-aid kit',
        'location': 'Hallway cabinet',
        'qty': '1',
      },
    ];
    s.collections['study_progress'] = [
      {
        'id': id.v4(),
        'subject': 'Biology',
        'topic': 'Cell structure',
        'confidence': '3 — Okay',
        'date': _isoDays(-1),
      },
      {
        'id': id.v4(),
        'subject': 'Mathematics',
        'topic': 'Quadratic equations',
        'confidence': '2 — Shaky',
        'date': _isoDays(-2),
      },
    ];
  }

  static String _isoDays(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    return DateTime(d.year, d.month, d.day).toIso8601String();
  }
}
