import 'package:flutter/material.dart';

import 'models.dart';

/// Static definitions of the seven Tasky virtual assistants.
/// All copy is original; no brand marks anywhere.
class VaDefs {
  static final Map<String, VaDef> _defs = {
    for (final v in _buildAll()) v.id: v,
  };

  static VaDef get(String id) => _defs[id]!;
  static List<VaDef> get all => VaIds.all.map((id) => _defs[id]!).toList();

  static List<VaDef> _buildAll() => [
        _life(),
        _business(),
        _creator(),
        _home(),
        _reply(),
        _travel(),
        _study(),
      ];

  // ---------------------------------------------------------------- Life VA
  static VaDef _life() => VaDef(
        id: VaIds.life,
        title: 'Life VA',
        noun: 'life',
        glyph: '🌿',
        colorA: const Color(0xFF059669),
        colorB: const Color(0xFF34D399),
        tagline: 'Your day, organized — tasks, plans, and gentle nudges.',
        systemPrompt:
            'You are a warm, practical personal life assistant. You help the user '
            'plan their day, track tasks, set reminders, and stay on top of goals. '
            'Keep answers short, structured, and actionable.',
        memoryFields: const [
          MemoryFieldDef(
              key: 'routine',
              label: 'Daily routine notes',
              hint: 'e.g. Gym at 6am, work 9–6, dinner with family'),
          MemoryFieldDef(
              key: 'priorities',
              label: 'Current priorities',
              hint: 'e.g. Finish project report, drink more water'),
        ],
        tools: const [
          ToolDef(
            id: 'my_tasks',
            title: 'My Tasks',
            glyph: '✅',
            blurb: 'Your personal to-do list.',
            kind: ToolKind.list,
            listKey: 'life_tasks',
            checkField: 'done',
            itemFields: [
              FieldDef(key: 'title', label: 'Task'),
              FieldDef(key: 'due', label: 'Due', type: FieldType.date),
              FieldDef(
                  key: 'note', label: 'Note', type: FieldType.multiline),
            ],
          ),
          ToolDef(
            id: 'reminders',
            title: 'Reminders',
            glyph: '⏰',
            blurb: 'Get nudged at the right moment.',
            kind: ToolKind.reminder,
            consequential: true,
          ),
          ToolDef(
            id: 'daily_planner',
            title: 'Daily Planner',
            glyph: '🗓️',
            blurb: 'Turn a messy brain-dump into a timed day plan.',
            inputs: [
              FieldDef(
                key: 'dump',
                label: 'What\'s on your plate today?',
                type: FieldType.multiline,
                hint: 'e.g. I have work at 9, lunch with Mom at 1, need groceries',
              ),
            ],
          ),
          ToolDef(
            id: 'goals',
            title: 'Goals',
            glyph: '🎯',
            blurb: 'Track the big things you\'re working toward.',
            kind: ToolKind.list,
            listKey: 'life_goals',
            itemFields: [
              FieldDef(key: 'title', label: 'Goal'),
              FieldDef(key: 'target', label: 'Target date',
                  type: FieldType.date),
              FieldDef(key: 'note', label: 'Why it matters',
                  type: FieldType.multiline),
            ],
          ),
          ToolDef(
            id: 'shopping_list',
            title: 'Shopping List',
            glyph: '🛒',
            blurb: 'Never forget the milk again.',
            kind: ToolKind.list,
            listKey: 'life_shopping',
            checkField: 'checked',
            itemFields: [
              FieldDef(key: 'item', label: 'Item'),
              FieldDef(key: 'qty', label: 'Qty'),
            ],
          ),
          ToolDef(
            id: 'daily_briefing',
            title: 'Daily Briefing',
            glyph: '☀️',
            blurb: 'Your day at a glance — tasks, reminders, goals.',
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Life VA',
            glyph: '💭',
            blurb: 'Ask anything about your day and plans.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );

  // ------------------------------------------------------------ Business VA
  static VaDef _business() => VaDef(
        id: VaIds.business,
        title: 'Business VA',
        noun: 'business',
        glyph: '💼',
        colorA: const Color(0xFFD97706),
        colorB: const Color(0xFFFBBF24),
        tagline: 'Products, sales, and profit — your pocket CFO.',
        systemPrompt:
            'You are a sharp, encouraging small-business assistant. You help with '
            'products, pricing, profit math, inventory, customers, and marketing ideas. '
            'Always show your math clearly.',
        memoryFields: const [
          MemoryFieldDef(
              key: 'business_name',
              label: 'Business name',
              hint: 'e.g. Maria\'s Homemade Cookies'),
          MemoryFieldDef(
              key: 'products',
              label: 'Products & prices',
              hint: 'e.g. Choco chip ₱120/box, Oatmeal ₱100/box'),
          MemoryFieldDef(
              key: 'customers',
              label: 'Key customers',
              hint: 'e.g. Cafe Luna (weekly), office officemates'),
          MemoryFieldDef(
              key: 'inventory',
              label: 'Inventory notes',
              hint: 'e.g. 40 boxes on hand, flour restock Friday'),
        ],
        tools: const [
          ToolDef(
            id: 'products',
            title: 'Products',
            glyph: '🏷️',
            blurb: 'Your catalog with prices and costs.',
            kind: ToolKind.list,
            listKey: 'biz_products',
            itemFields: [
              FieldDef(key: 'name', label: 'Product name'),
              FieldDef(key: 'price', label: 'Selling price (₱)',
                  type: FieldType.number),
              FieldDef(
                  key: 'cost', label: 'Cost per unit (₱)',
                  type: FieldType.number),
              FieldDef(key: 'stock', label: 'Stock on hand',
                  type: FieldType.number),
            ],
          ),
          ToolDef(
            id: 'sales',
            title: 'Sales',
            glyph: '🧾',
            blurb: 'Log every sale as it happens.',
            kind: ToolKind.list,
            listKey: 'biz_sales',
            itemFields: [
              FieldDef(key: 'item', label: 'What was sold'),
              FieldDef(key: 'qty', label: 'Qty', type: FieldType.number),
              FieldDef(
                  key: 'amount', label: 'Total amount (₱)',
                  type: FieldType.number),
              FieldDef(key: 'date', label: 'Date', type: FieldType.date),
            ],
          ),
          ToolDef(
            id: 'expenses',
            title: 'Expenses',
            glyph: '💸',
            blurb: 'Track where the money goes.',
            kind: ToolKind.list,
            listKey: 'biz_expenses',
            itemFields: [
              FieldDef(key: 'name', label: 'Expense'),
              FieldDef(
                  key: 'amount', label: 'Amount (₱)',
                  type: FieldType.number),
              FieldDef(
                key: 'category',
                label: 'Category',
                type: FieldType.choice,
                options: [
                  'Inventory',
                  'Transport',
                  'Packaging',
                  'Marketing',
                  'Bills',
                  'Other'
                ],
              ),
              FieldDef(key: 'date', label: 'Date', type: FieldType.date),
            ],
          ),
          ToolDef(
            id: 'profit_calculator',
            title: 'Profit Calculator',
            glyph: '📊',
            blurb: 'Revenue, profit, and margin in seconds.',
            inputs: [
              FieldDef(
                  key: 'cost_total',
                  label: 'Total cost (₱)',
                  type: FieldType.number,
                  hint: 'e.g. 3000'),
              FieldDef(
                  key: 'qty', label: 'Quantity', type: FieldType.number,
                  hint: 'e.g. 50'),
              FieldDef(
                  key: 'sell_price',
                  label: 'Selling price each (₱)',
                  type: FieldType.number,
                  hint: 'e.g. 120'),
            ],
          ),
          ToolDef(
            id: 'inventory',
            title: 'Inventory',
            glyph: '📦',
            blurb: 'Know exactly what\'s on the shelf.',
            kind: ToolKind.list,
            listKey: 'biz_inventory',
            itemFields: [
              FieldDef(key: 'item', label: 'Item'),
              FieldDef(key: 'qty', label: 'Qty', type: FieldType.number),
              FieldDef(key: 'note', label: 'Note'),
            ],
          ),
          ToolDef(
            id: 'customers',
            title: 'Customers',
            glyph: '🤝',
            blurb: 'Remember who buys from you.',
            kind: ToolKind.list,
            listKey: 'biz_customers',
            itemFields: [
              FieldDef(key: 'name', label: 'Name'),
              FieldDef(key: 'contact', label: 'Contact'),
              FieldDef(
                  key: 'note', label: 'Notes', type: FieldType.multiline),
            ],
          ),
          ToolDef(
            id: 'customer_messages',
            title: 'Customer Messages',
            glyph: '✉️',
            blurb: 'Warm, professional replies to buyers.',
            inputs: [
              FieldDef(
                key: 'situation',
                label: 'What did the customer say or ask?',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'tone',
                label: 'Tone',
                type: FieldType.choice,
                options: ['Friendly', 'Professional', 'Apologetic', 'Playful'],
              ),
            ],
          ),
          ToolDef(
            id: 'product_description',
            title: 'Product Description',
            glyph: '📝',
            blurb: 'Listings that make people tap "buy".',
            inputs: [
              FieldDef(key: 'product', label: 'Product name'),
              FieldDef(
                key: 'details',
                label: 'Key details & benefits',
                type: FieldType.multiline,
              ),
            ],
          ),
          ToolDef(
            id: 'marketing_ideas',
            title: 'Marketing Ideas',
            glyph: '📣',
            blurb: 'Fresh ways to get the word out.',
            inputs: [
              FieldDef(key: 'product', label: 'Product or promo focus'),
              FieldDef(
                key: 'budget',
                label: 'Budget',
                type: FieldType.choice,
                options: ['Free / ₱0', 'Small (< ₱1,000)', 'Medium (< ₱5,000)'],
              ),
            ],
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Business VA',
            glyph: '💭',
            blurb: 'Talk shop — pricing, growth, decisions.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );

  // ------------------------------------------------------------- Creator VA
  static VaDef _creator() => VaDef(
        id: VaIds.creator,
        title: 'Creator VA',
        noun: 'creator',
        glyph: '🎨',
        colorA: const Color(0xFFDB2777),
        colorB: const Color(0xFFF472B6),
        tagline: 'Ideas, hooks, and scripts that stop the scroll.',
        systemPrompt:
            'You are a creative social-media strategist. You write scroll-stopping '
            'hooks, scripts, captions, and content plans. You are bold, specific, and '
            'never generic. All ideas you write are original.',
        memoryFields: const [
          MemoryFieldDef(
              key: 'niche',
              label: 'Content niche',
              hint: 'e.g. Skincare for beginners'),
          MemoryFieldDef(
            key: 'tone',
            label: 'Preferred tone',
            type: FieldType.choice,
            options: ['Friendly', 'Bold', 'Educational', 'Funny', 'Aesthetic'],
            hint: 'How your content should feel',
          ),
          MemoryFieldDef(
              key: 'platforms',
              label: 'Platforms',
              hint: 'e.g. TikTok, Instagram Reels'),
          MemoryFieldDef(
              key: 'style',
              label: 'Content style',
              hint: 'e.g. Talking head, aesthetic B-roll, demos'),
        ],
        tools: const [
          ToolDef(
            id: 'content_ideas',
            title: 'Content Ideas',
            glyph: '💡',
            blurb: 'Fresh video ideas for your niche.',
            inputs: [
              FieldDef(
                  key: 'count', label: 'How many ideas?',
                  type: FieldType.number, hint: 'e.g. 10'),
              FieldDef(
                  key: 'topic', label: 'Topic or focus (optional)'),
            ],
          ),
          ToolDef(
            id: 'script_generator',
            title: 'Script Generator',
            glyph: '🎬',
            blurb: 'A full script, beat by beat.',
            inputs: [
              FieldDef(key: 'topic', label: 'Video topic'),
              FieldDef(
                key: 'length',
                label: 'Length',
                type: FieldType.choice,
                options: ['15 sec', '30 sec', '60 sec', '3 min'],
              ),
            ],
          ),
          ToolDef(
            id: 'hook_generator',
            title: 'Hook Generator',
            glyph: '🪝',
            blurb: 'First-3-second lines that stop thumbs.',
            inputs: [
              FieldDef(key: 'topic', label: 'Video topic'),
              FieldDef(
                  key: 'count', label: 'How many hooks?',
                  type: FieldType.number, hint: 'e.g. 5'),
            ],
          ),
          ToolDef(
            id: 'caption_generator',
            title: 'Caption Generator',
            glyph: '✍️',
            blurb: 'Captions with personality + CTA.',
            inputs: [
              FieldDef(key: 'topic', label: 'What is the post about?'),
            ],
          ),
          ToolDef(
            id: 'hashtag_ideas',
            title: 'Hashtag Ideas',
            glyph: '#️⃣',
            blurb: 'Reach the right audience.',
            inputs: [
              FieldDef(key: 'topic', label: 'Post topic or niche'),
            ],
          ),
          ToolDef(
            id: 'content_calendar',
            title: 'Content Calendar',
            glyph: '📅',
            blurb: 'A 7-day posting plan.',
            inputs: [
              FieldDef(
                  key: 'focus', label: 'This week\'s focus (optional)'),
            ],
          ),
          ToolDef(
            id: 'comment_replies',
            title: 'Comment Replies',
            glyph: '💬',
            blurb: 'Witty, warm replies that build community.',
            inputs: [
              FieldDef(
                key: 'comment',
                label: 'The comment you received',
                type: FieldType.multiline,
              ),
            ],
          ),
          ToolDef(
            id: 'brand_collab',
            title: 'Brand Collaboration',
            glyph: '🤝',
            blurb: 'Pitch and rate-card help.',
            inputs: [
              FieldDef(key: 'brand', label: 'Brand name (or type of brand)'),
              FieldDef(
                  key: 'deliverable', label: 'What they want',
                  hint: 'e.g. 1 TikTok video + 2 stories'),
            ],
          ),
          ToolDef(
            id: 'content_tracker',
            title: 'Content Tracker',
            glyph: '📈',
            blurb: 'Log what you posted and how it did.',
            kind: ToolKind.list,
            listKey: 'creator_tracker',
            itemFields: [
              FieldDef(key: 'title', label: 'Post title/topic'),
              FieldDef(
                key: 'platform',
                label: 'Platform',
                type: FieldType.choice,
                options: ['TikTok', 'Instagram', 'YouTube', 'Facebook', 'Other'],
              ),
              FieldDef(
                key: 'status',
                label: 'Status',
                type: FieldType.choice,
                options: ['Idea', 'Filmed', 'Posted'],
              ),
              FieldDef(key: 'date', label: 'Date', type: FieldType.date),
            ],
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Creator VA',
            glyph: '💭',
            blurb: 'Strategy, trends, creative blocks.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );

  // ----------------------------------------------------------------- Home VA
  static VaDef _home() => VaDef(
        id: VaIds.home,
        title: 'Home VA',
        noun: 'home',
        glyph: '🏠',
        colorA: const Color(0xFF0D9488),
        colorB: const Color(0xFF2DD4BF),
        tagline: 'A calm, cared-for home — meals, chores, plants & pets.',
        systemPrompt:
            'You are a warm household manager. You help with cleaning schedules, '
            'meal plans, groceries, bills, plant and pet care. Practical, kind, '
            'and organized.',
        memoryFields: const [
          MemoryFieldDef(
              key: 'household',
              label: 'Household members',
              hint: 'e.g. Me, wife, baby'),
          MemoryFieldDef(
              key: 'pets', label: 'Pets', hint: 'e.g. Poodle named Coco'),
          MemoryFieldDef(
              key: 'plants',
              label: 'Plants',
              hint: 'e.g. Basil, monstera, snake plant'),
        ],
        tools: const [
          ToolDef(
            id: 'cleaning_schedule',
            title: 'Cleaning Schedule',
            glyph: '🧹',
            blurb: 'A tidy home without the overwhelm.',
            inputs: [
              FieldDef(
                key: 'size',
                label: 'Home size',
                type: FieldType.choice,
                options: ['Studio/1BR', '2BR', '3BR+', 'House'],
              ),
            ],
          ),
          ToolDef(
            id: 'grocery_list',
            title: 'Grocery List',
            glyph: '🛒',
            blurb: 'The household grocery run.',
            kind: ToolKind.list,
            listKey: 'home_grocery',
            checkField: 'checked',
            itemFields: [
              FieldDef(key: 'item', label: 'Item'),
              FieldDef(key: 'qty', label: 'Qty'),
            ],
          ),
          ToolDef(
            id: 'meal_planner',
            title: 'Meal Planner',
            glyph: '🍳',
            blurb: 'A week of meals, planned in a minute.',
            inputs: [
              FieldDef(
                key: 'days', label: 'How many days?',
                type: FieldType.number, hint: 'e.g. 7'),
              FieldDef(
                key: 'prefs',
                label: 'Preferences or restrictions',
                hint: 'e.g. No pork, budget-friendly'),
            ],
          ),
          ToolDef(
            id: 'bills',
            title: 'Bills',
            glyph: '🧾',
            blurb: 'Never miss a due date.',
            kind: ToolKind.list,
            listKey: 'home_bills',
            checkField: 'paid',
            itemFields: [
              FieldDef(key: 'name', label: 'Bill'),
              FieldDef(
                  key: 'amount', label: 'Amount (₱)',
                  type: FieldType.number),
              FieldDef(key: 'due', label: 'Due date', type: FieldType.date),
            ],
          ),
          ToolDef(
            id: 'home_tasks',
            title: 'Home Tasks',
            glyph: '🔧',
            blurb: 'Fixes, errands, and household to-dos.',
            kind: ToolKind.list,
            listKey: 'home_tasks',
            checkField: 'done',
            itemFields: [
              FieldDef(key: 'title', label: 'Task'),
              FieldDef(key: 'assignee', label: 'Who\'s doing it'),
            ],
          ),
          ToolDef(
            id: 'plant_care',
            title: 'Plant Care',
            glyph: '🪴',
            blurb: 'Watering and care reminders.',
            inputs: [
              FieldDef(key: 'plant', label: 'Which plant?'),
              FieldDef(
                key: 'action',
                label: 'What did you do?',
                type: FieldType.choice,
                options: [
                  'Watered today',
                  'Fertilized today',
                  'Repotted today',
                  'Just checking'
                ],
              ),
            ],
          ),
          ToolDef(
            id: 'pet_care',
            title: 'Pet Care',
            glyph: '🐾',
            blurb: 'Feeding, walks, vet visits.',
            inputs: [
              FieldDef(key: 'pet', label: 'Which pet?'),
              FieldDef(
                key: 'need',
                label: 'What do you need?',
                type: FieldType.multiline,
                hint: 'e.g. Feeding schedule for a poodle puppy'),
            ],
          ),
          ToolDef(
            id: 'household_inventory',
            title: 'Household Inventory',
            glyph: '📦',
            blurb: 'Know what you have and where.',
            kind: ToolKind.list,
            listKey: 'home_inventory',
            itemFields: [
              FieldDef(key: 'item', label: 'Item'),
              FieldDef(key: 'location', label: 'Where is it?'),
              FieldDef(key: 'qty', label: 'Qty', type: FieldType.number),
            ],
          ),
          ToolDef(
            id: 'family_tasks',
            title: 'Family Tasks',
            glyph: '👨‍👩‍👧',
            blurb: 'Share the load fairly.',
            inputs: [
              FieldDef(
                key: 'members',
                label: 'Family members',
                hint: 'e.g. Me, wife, teen son'),
              FieldDef(
                key: 'tasks',
                label: 'Tasks to split',
                type: FieldType.multiline,
                hint: 'e.g. Dishes, laundry, trash, vacuuming'),
            ],
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Home VA',
            glyph: '💭',
            blurb: 'Anything about running the home.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------- Reply VA
  static VaDef _reply() => VaDef(
        id: VaIds.reply,
        title: 'Reply VA',
        noun: 'reply',
        glyph: '💬',
        colorA: const Color(0xFF2563EB),
        colorB: const Color(0xFF60A5FA),
        tagline: 'Say it perfectly — every message, every tone.',
        systemPrompt:
            'You are an expert communication coach. You rewrite messages in any '
            'tone, draft replies, and translate. You keep the user\'s meaning and '
            'make every word land well.',
        memoryFields: const [
          MemoryFieldDef(
            key: 'default_tone',
            label: 'Default tone',
            type: FieldType.choice,
            options: [
              'Professional',
              'Friendly',
              'Casual',
              'Polite',
              'Funny',
              'Sweet',
              'Firm'
            ],
            hint: 'Your usual voice',
          ),
          MemoryFieldDef(
              key: 'languages',
              label: 'Languages you use',
              hint: 'e.g. English, Tagalog'),
        ],
        tools: const [
          ToolDef(
            id: 'reply_message',
            title: 'Reply to Message',
            glyph: '💬',
            blurb: 'The perfect reply to any message.',
            inputs: [
              FieldDef(
                key: 'message',
                label: 'Their message',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'context',
                label: 'Context (optional)',
                hint: 'e.g. My landlord about the leak'),
            ],
          ),
          ToolDef(
            id: 'email_reply',
            title: 'Email Reply',
            glyph: '📧',
            blurb: 'Professional emails, minus the stress.',
            inputs: [
              FieldDef(
                key: 'email',
                label: 'The email you received',
                type: FieldType.multiline,
              ),
              FieldDef(
                  key: 'point',
                  label: 'What do you want to say?',
                  type: FieldType.multiline),
            ],
          ),
          ToolDef(
            id: 'customer_reply',
            title: 'Customer Reply',
            glyph: '🛎️',
            blurb: 'Keep customers happy and coming back.',
            inputs: [
              FieldDef(
                key: 'message',
                label: 'Customer\'s message',
                type: FieldType.multiline,
              ),
            ],
          ),
          ToolDef(
            id: 'work_message',
            title: 'Work Message',
            glyph: '💼',
            blurb: 'Clear, confident workplace writing.',
            inputs: [
              FieldDef(
                key: 'draft',
                label: 'Your draft or key points',
                type: FieldType.multiline,
              ),
            ],
          ),
          ToolDef(
            id: 'personal_message',
            title: 'Personal Message',
            glyph: '💌',
            blurb: 'Heartfelt words for people you love.',
            inputs: [
              FieldDef(
                key: 'draft',
                label: 'What do you want to say?',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'who',
                label: 'Who is it for?',
                hint: 'e.g. My wife, my best friend'),
            ],
          ),
          ToolDef(
            id: 'apology',
            title: 'Apology',
            glyph: '🙏',
            blurb: 'Sincere apologies that actually land.',
            inputs: [
              FieldDef(
                key: 'what',
                label: 'What happened?',
                type: FieldType.multiline,
              ),
            ],
          ),
          ToolDef(
            id: 'meeting_response',
            title: 'Meeting Response',
            glyph: '📅',
            blurb: 'Accept, decline, or reschedule gracefully.',
            inputs: [
              FieldDef(
                key: 'invite',
                label: 'Meeting details',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'action',
                label: 'Your response',
                type: FieldType.choice,
                options: ['Accept', 'Decline politely', 'Propose new time'],
              ),
            ],
          ),
          ToolDef(
            id: 'rewrite',
            title: 'Rewrite My Message',
            glyph: '✏️',
            blurb: 'Same meaning, better words.',
            inputs: [
              FieldDef(
                key: 'draft',
                label: 'Your draft',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'tone',
                label: 'Tone',
                type: FieldType.choice,
                options: [
                  'Professional',
                  'Friendly',
                  'Casual',
                  'Polite',
                  'Funny',
                  'Sweet',
                  'Firm'
                ],
              ),
            ],
          ),
          ToolDef(
            id: 'translate',
            title: 'Translate',
            glyph: '🌐',
            blurb: 'Natural translations, not robot-speak.',
            inputs: [
              FieldDef(
                key: 'text',
                label: 'Text to translate',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'target',
                label: 'Translate to',
                type: FieldType.choice,
                options: ['Tagalog', 'English', 'Taglish', 'Cebuano', 'Spanish'],
              ),
            ],
          ),
          ToolDef(
            id: 'change_tone',
            title: 'Change Tone',
            glyph: '🎭',
            blurb: 'Professional, funny, firm — you choose.',
            inputs: [
              FieldDef(
                key: 'draft',
                label: 'Your message',
                type: FieldType.multiline,
              ),
              FieldDef(
                key: 'tone',
                label: 'New tone',
                type: FieldType.choice,
                options: [
                  'Professional',
                  'Friendly',
                  'Casual',
                  'Polite',
                  'Funny',
                  'Sweet',
                  'Firm'
                ],
              ),
            ],
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Reply VA',
            glyph: '💭',
            blurb: 'Communication advice, anytime.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );

  // --------------------------------------------------------------- Travel VA
  static VaDef _travel() => VaDef(
        id: VaIds.travel,
        title: 'Travel VA',
        noun: 'travel',
        glyph: '✈️',
        colorA: const Color(0xFFEA580C),
        colorB: const Color(0xFFFB923C),
        tagline: 'Trips planned to the peso — itineraries & budgets.',
        systemPrompt:
            'You are an enthusiastic travel planner who knows the Philippines inside '
            'out. You build day-by-day itineraries, realistic budgets in pesos, '
            'packing lists, and food plans. Practical and exciting.',
        memoryFields: const [
          MemoryFieldDef(
              key: 'destinations',
              label: 'Preferred destinations',
              hint: 'e.g. Beaches, Boracay, Palawan'),
          MemoryFieldDef(
            key: 'budget_style',
            label: 'Budget style',
            type: FieldType.choice,
            options: ['Budget', 'Mid-range', 'Comfort', 'Luxury'],
            hint: 'How you like to travel',
          ),
          MemoryFieldDef(
              key: 'preferences',
              label: 'Travel preferences',
              hint: 'e.g. Street food over fine dining, sunrise hikes'),
        ],
        tools: const [
          ToolDef(
            id: 'plan_trip',
            title: 'Plan a Trip',
            glyph: '🗺️',
            blurb: 'Full trip plan: days, budget, highlights.',
            inputs: [
              FieldDef(key: 'destination', label: 'Where to?'),
              FieldDef(
                  key: 'days', label: 'How many days?',
                  type: FieldType.number, hint: 'e.g. 4'),
              FieldDef(
                  key: 'budget', label: 'Total budget (₱)',
                  type: FieldType.number, hint: 'e.g. 15000'),
              FieldDef(
                  key: 'travelers',
                  label: 'Travelers',
                  type: FieldType.number,
                  hint: 'e.g. 2'),
            ],
          ),
          ToolDef(
            id: 'itinerary',
            title: 'Itinerary',
            glyph: '📍',
            blurb: 'Day-by-day, hour-by-hour.',
            inputs: [
              FieldDef(key: 'destination', label: 'Destination'),
              FieldDef(
                  key: 'days', label: 'Days', type: FieldType.number),
              FieldDef(
                key: 'interests',
                label: 'Interests',
                hint: 'e.g. Beach, food, history'),
            ],
          ),
          ToolDef(
            id: 'travel_budget',
            title: 'Travel Budget',
            glyph: '💰',
            blurb: 'Split your budget the smart way.',
            inputs: [
              FieldDef(
                  key: 'budget', label: 'Total budget (₱)',
                  type: FieldType.number),
              FieldDef(
                  key: 'days', label: 'Days', type: FieldType.number),
            ],
          ),
          ToolDef(
            id: 'packing_list',
            title: 'Packing List',
            glyph: '🎒',
            blurb: 'Pack once, pack right.',
            inputs: [
              FieldDef(key: 'destination', label: 'Destination'),
              FieldDef(
                  key: 'days', label: 'Days', type: FieldType.number),
              FieldDef(
                key: 'style',
                label: 'Trip style',
                type: FieldType.choice,
                options: ['Beach', 'City', 'Mountain', 'Mixed'],
              ),
            ],
          ),
          ToolDef(
            id: 'accommodation',
            title: 'Accommodation',
            glyph: '🏨',
            blurb: 'Where to stay for your budget.',
            inputs: [
              FieldDef(key: 'destination', label: 'Destination'),
              FieldDef(
                  key: 'budget_night',
                  label: 'Budget per night (₱)',
                  type: FieldType.number),
            ],
          ),
          ToolDef(
            id: 'food_planner',
            title: 'Food Planner',
            glyph: '🍜',
            blurb: 'Eat well without overspending.',
            inputs: [
              FieldDef(key: 'destination', label: 'Destination'),
              FieldDef(
                  key: 'days', label: 'Days', type: FieldType.number),
              FieldDef(
                  key: 'budget_day',
                  label: 'Food budget per day (₱)',
                  type: FieldType.number),
            ],
          ),
          ToolDef(
            id: 'transportation',
            title: 'Transportation',
            glyph: '🚌',
            blurb: 'Getting there and around.',
            inputs: [
              FieldDef(key: 'from', label: 'From'),
              FieldDef(key: 'to', label: 'To'),
            ],
          ),
          ToolDef(
            id: 'places_to_visit',
            title: 'Places to Visit',
            glyph: '🏝️',
            blurb: 'Must-see spots, curated for you.',
            inputs: [
              FieldDef(key: 'destination', label: 'Destination'),
              FieldDef(
                  key: 'interests',
                  label: 'What do you love?',
                  hint: 'e.g. Waterfalls, cafes, museums'),
            ],
          ),
          ToolDef(
            id: 'travel_alerts',
            title: 'Travel Alerts',
            glyph: '⚠️',
            blurb: 'A pre-trip safety & prep checklist.',
            inputs: [
              FieldDef(key: 'destination', label: 'Destination'),
            ],
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Travel VA',
            glyph: '💭',
            blurb: 'Anything about your next adventure.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------- Study VA
  static VaDef _study() => VaDef(
        id: VaIds.study,
        title: 'Study VA',
        noun: 'study',
        glyph: '📚',
        colorA: const Color(0xFF7C3AED),
        colorB: const Color(0xFFA78BFA),
        tagline: 'Explain, quiz, and plan — ace every exam.',
        systemPrompt:
            'You are a patient, encouraging tutor. You explain topics simply, make '
            'study plans, quizzes, and flashcards. You adapt to the student\'s level '
            'and keep them motivated.',
        memoryFields: const [
          MemoryFieldDef(
              key: 'subjects',
              label: 'Subjects',
              hint: 'e.g. Biology, Math, History'),
          MemoryFieldDef(
              key: 'exam_dates',
              label: 'Exam dates',
              hint: 'e.g. Biology exam Friday Oct 24'),
          MemoryFieldDef(
              key: 'level',
              label: 'Level',
              type: FieldType.choice,
              options: ['Elementary', 'High School', 'College', 'Self-study'],
              hint: 'Your study level',
            ),
        ],
        tools: const [
          ToolDef(
            id: 'explain_topic',
            title: 'Explain a Topic',
            glyph: '💡',
            blurb: 'Hard topic? Made simple.',
            inputs: [
              FieldDef(key: 'topic', label: 'Topic to explain'),
              FieldDef(
                  key: 'subject', label: 'Subject (optional)'),
            ],
          ),
          ToolDef(
            id: 'make_notes',
            title: 'Make Notes',
            glyph: '📝',
            blurb: 'Clean, structured study notes.',
            inputs: [
              FieldDef(key: 'topic', label: 'Topic'),
              FieldDef(
                  key: 'subject', label: 'Subject (optional)'),
            ],
          ),
          ToolDef(
            id: 'flashcards',
            title: 'Flashcards',
            glyph: '🃏',
            blurb: 'Q&A cards for active recall.',
            inputs: [
              FieldDef(key: 'topic', label: 'Topic'),
              FieldDef(
                  key: 'count', label: 'How many cards?',
                  type: FieldType.number, hint: 'e.g. 8'),
            ],
          ),
          ToolDef(
            id: 'make_quiz',
            title: 'Make a Quiz',
            glyph: '❓',
            blurb: 'Test yourself before the real test.',
            inputs: [
              FieldDef(key: 'topic', label: 'Topic'),
              FieldDef(
                  key: 'count', label: 'How many questions?',
                  type: FieldType.number, hint: 'e.g. 5'),
            ],
          ),
          ToolDef(
            id: 'study_planner',
            title: 'Study Planner',
            glyph: '🗓️',
            blurb: 'A plan that fits your exam date.',
            inputs: [
              FieldDef(
                key: 'goal',
                label: 'What are you preparing for?',
                hint: 'e.g. Biology exam Friday'),
              FieldDef(
                key: 'days', label: 'Days available',
                type: FieldType.number, hint: 'e.g. 5'),
              FieldDef(
                key: 'hours',
                label: 'Hours per day',
                type: FieldType.number,
                hint: 'e.g. 2'),
            ],
          ),
          ToolDef(
            id: 'study_timer',
            title: 'Study Timer',
            glyph: '⏱️',
            blurb: 'Focused sessions, real breaks.',
            kind: ToolKind.timer,
          ),
          ToolDef(
            id: 'scan_notes',
            title: 'Scan / Upload Notes',
            glyph: '📷',
            blurb: 'Snap or upload notes, get a study summary.',
            kind: ToolKind.scan,
            consequential: false,
          ),
          ToolDef(
            id: 'exam_prep',
            title: 'Exam Preparation',
            glyph: '🎓',
            blurb: 'Your final countdown checklist.',
            inputs: [
              FieldDef(key: 'subject', label: 'Subject'),
              FieldDef(
                  key: 'date', label: 'Exam date', type: FieldType.date),
              FieldDef(
                key: 'topics',
                label: 'Topics to cover',
                type: FieldType.multiline,
              ),
            ],
          ),
          ToolDef(
            id: 'my_progress',
            title: 'My Progress',
            glyph: '📈',
            blurb: 'Log what you studied and how confident you feel.',
            kind: ToolKind.list,
            listKey: 'study_progress',
            itemFields: [
              FieldDef(key: 'subject', label: 'Subject'),
              FieldDef(key: 'topic', label: 'Topic studied'),
              FieldDef(
                key: 'confidence',
                label: 'Confidence',
                type: FieldType.choice,
                options: ['1 — Lost', '2 — Shaky', '3 — Okay', '4 — Solid', '5 — Nailed it'],
              ),
              FieldDef(key: 'date', label: 'Date', type: FieldType.date),
            ],
          ),
          ToolDef(
            id: 'ask',
            title: 'Ask Study VA',
            glyph: '💭',
            blurb: 'Stuck? Ask away.',
            inputs: [
              FieldDef(
                  key: 'q', label: 'Your question', type: FieldType.multiline),
            ],
          ),
        ],
      );
}
