/// Called when A and B are in the SAME category → returns one bridge question C.
String bridgeSuggestion(String categoryName, String textA, String textB) {
  final a = _lastWord(textA);
  final b = _lastWord(textB);

  const bridges = <String, String Function(String, String)>{
    'sports': _sportsBridge,
    'science': _scienceBridge,
    'history': _historyBridge,
    'animals': _animalsBridge,
    'technology': _techBridge,
    'geography': _geoBridge,
    'food': _foodBridge,
    'arts': _artsBridge,
    'math': _mathBridge,
    'politics': _politicsBridge,
    'nature': _natureBridge,
    'health': _healthBridge,
    'religion': _religionBridge,
    'family': _familyBridge,
    'education': _educationBridge,
    'entertainment': _entertainmentBridge,
    'travel': _travelBridge,
    'business': _businessBridge,
    'mythology': _mythologyBridge,
    'festivals': _festivalsBridge,
    'spirituality': _spiritualityBridge,
    'bollywood': _bollywoodBridge,
    'asian_culture': _asianCultureBridge,
    'health_wellness': _healthWellnessBridge,
    // Children & India focused categories
    'relation_names': _relationNamesBridge,
    'greetings': _greetingsBridge,
    'hindi_grammar': _hindiGrammarBridge,
    'english_grammar': _englishGrammarBridge,
    'maths_secondary': _mathsSecondaryBridge,
    'indian_states': _indianStatesBridge,
    'indian_foods': _indianFoodsBridge,
    'indian_music_genres': _indianMusicBridge,
    'indian_shlokas': _indianShlokasBridge,
    'computer_basics': _computerBasicsBridge,
    'encyclopedia': _encyclopediaBridge,
    'indian_home_hacks': _indianHomeHacksBridge,
    'indian_kitchen_hacks': _indianKitchenHacksBridge,
    'indian_languages': _indianLanguagesBridge,
    'indian_freedom_fighters': _indianFreedomFightersBridge,
    'indian_dance_forms': _indianDanceFormsBridge,
    'indian_national_symbols': _indianNationalSymbolsBridge,
    'moral_stories': _moralStoriesBridge,
    'indoor_games': _indoorGamesBridge,
    'body_parts': _bodyPartsBridge,
    'colors_shapes': _colorsShapesBridge,
  };

  final fn = bridges[categoryName] ?? _defaultBridge;
  return fn(a, b);
}

/// Called when A and B are in DIFFERENT categories →
/// returns C (about A's category) and D (about B's category).
(String c, String d) depthSuggestions(
    String catA, String textA, String catB, String textB) {
  return (
    _depthQuestion(catA, textA),
    _depthQuestion(catB, textB),
  );
}

// ── Bridge functions (same category) ──────────────────────────────────────

String _sportsBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know which Indian players are champions at both? 🏆';

String _scienceBridge(String a, String b) =>
    'You explored $a and $b — want to discover how they both work together in a rocket launch? 🚀';

String _historyBridge(String a, String b) =>
    'You asked about $a and $b — want to see how they connect on the same historical timeline? ⏳';

String _animalsBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know if they would ever meet in the wild? 🌿';

String _techBridge(String a, String b) =>
    'Since you explored $a and $b, want to see how modern tech is changing both of them today? 📱';

String _geoBridge(String a, String b) =>
    'You asked about $a and $b — want to know what makes both places so special and unique? 🗺️';

String _foodBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both are made in traditional Indian kitchens? 🍛';

String _artsBridge(String a, String b) =>
    'You asked about $a and $b — want to discover how both appear in India\'s rich culture? 🎨';

String _mathBridge(String a, String b) =>
    'Since you asked about $a and $b, want to see how both appear in everyday life around you? 🔢';

String _politicsBridge(String a, String b) =>
    'You asked about $a and $b — want to know how they shaped India\'s history together? 🏛️';

String _natureBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover how both are connected in our ecosystem? 🌱';

String _healthBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both can help keep you healthy and strong? 💪';

String _religionBridge(String a, String b) =>
    'You asked about $a and $b — want to discover how both bring peace and wisdom to people? 🙏';

String _familyBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both make families stronger and happier? 👨‍👩‍👧‍👦';

String _educationBridge(String a, String b) =>
    'You explored $a and $b — want to see how both can make learning more fun and effective? 📚';

String _entertainmentBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both can create amazing fun experiences? 🎉';

String _travelBridge(String a, String b) =>
    'You asked about $a and $b — want to discover what makes both perfect travel destinations? ✈️';

String _businessBridge(String a, String b) =>
    'Since you explored $a and $b, want to know how both can lead to successful careers? 💼';

String _mythologyBridge(String a, String b) =>
    'You asked about $a and $b — want to see how both teach us important life lessons? 📖';

String _festivalsBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover how both celebrations bring joy and unity to communities? 🎊';

String _spiritualityBridge(String a, String b) =>
    'You explored $a and $b — want to see how both practices can bring inner peace and enlightenment? 🧘';

String _bollywoodBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both have shaped Indian cinema and culture? 🎬';

String _asianCultureBridge(String a, String b) =>
    'You asked about $a and $b — want to discover how both represent the beautiful diversity of Asian culture? 🌸';

String _healthWellnessBridge(String a, String b) =>
    'Since you explored $a and $b, want to know how both ancient wisdom and modern science work together for wellness? 🌿';

// ── Children & India focused bridge functions ──────────────────────────────

String _relationNamesBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both relationships make our family tree so special? 👨‍👩‍👧‍👦';

String _greetingsBridge(String a, String b) =>
    'You asked about $a and $b — want to discover how both greetings spread love and respect in our culture? 🙏';

String _hindiGrammarBridge(String a, String b) =>
    'Since you explored $a and $b, want to see how both make Hindi language so beautiful and expressive? 📝';

String _englishGrammarBridge(String a, String b) =>
    'You asked about $a and $b — want to know how both help you speak English like a pro? 📚';

String _mathsSecondaryBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover how both concepts work together to solve amazing problems? 🧮';

String _indianStatesBridge(String a, String b) =>
    'You explored $a and $b — want to know what makes both states unique gems of incredible India? 🇮🇳';

String _indianFoodsBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover how both dishes represent the delicious diversity of India? 🍛';

String _indianMusicBridge(String a, String b) =>
    'You asked about $a and $b — want to see how both create the magical symphony of Indian music? 🎵';

String _indianShlokasBridge(String a, String b) =>
    'Since you explored $a and $b, want to know how both carry the ancient wisdom that guides our hearts? 🕉️';

String _computerBasicsBridge(String a, String b) =>
    'You asked about $a and $b — want to discover how both work together to make computers so amazing? 💻';

String _encyclopediaBridge(String a, String b) =>
    'Since you asked $a and $b, want to explore how both questions unlock the fascinating world of knowledge? 🤔';

String _indianHomeHacksBridge(String a, String b) =>
    'You explored $a and $b — want to know how both desi tricks make our homes cleaner and happier? 🏠';

String _indianKitchenHacksBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover how both tips make cooking easier and tastier? 👩‍🍳';

String _indianLanguagesBridge(String a, String b) =>
    'You asked about $a and $b — want to see how both languages connect the beautiful diversity of India? 🗣️';

String _indianFreedomFightersBridge(String a, String b) =>
    'Since you explored $a and $b, want to know how both heroes fought together for our freedom? 🇮🇳';

String _indianDanceFormsBridge(String a, String b) =>
    'You asked about $a and $b — want to discover how both dances tell stories through graceful movements? 💃';

String _indianNationalSymbolsBridge(String a, String b) =>
    'Since you asked about $a and $b, want to know how both represent the pride and glory of India? 🦚';

String _moralStoriesBridge(String a, String b) =>
    'You explored $a and $b — want to see how both stories teach us to become better human beings? 📖';

String _indoorGamesBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover how both games bring families together for fun times? 🎲';

String _bodyPartsBridge(String a, String b) =>
    'You asked about $a and $b — want to know how both work together to make your amazing body function? 🫀';

String _colorsShapesBridge(String a, String b) =>
    'Since you explored $a and $b, want to see how both create the beautiful world of art and design around us? 🎨';

String _defaultBridge(String a, String b) =>
    'Since you asked about $a and $b, want to discover what secretly links them together? 🔗';

// ── Depth functions (different categories) ────────────────────────────────

String _depthQuestion(String category, String text) {
  final t = _lastWord(text);
  switch (category) {
    case 'sports':
      return 'Want to know how sports like $t can actually make you smarter and faster? 🧠';
    case 'science':
      return 'The science behind $t connects to everyday life in surprising ways — want to know how? 🔬';
    case 'history':
      return 'The history of $t shaped the world we live in — want to explore how? 📜';
    case 'animals':
      return 'The animal $t has incredible survival secrets — want to find out? 🦁';
    case 'technology':
      return 'The technology in $t is changing millions of lives — want to know the coolest part? ⚡';
    case 'geography':
      return 'The place $t has some of the most unusual features on Earth — want to know? 🌍';
    case 'food':
      return 'Did you know $t has a fascinating history behind how it was first made? 🍽️';
    case 'arts':
      return 'Want to know how $t connects to India\'s oldest traditions? 🎭';
    case 'math':
      return 'Want to see where $t shows up in nature and everyday life around you? 🔢';
    case 'politics':
      return 'The leader or event in $t had a huge impact — want to know exactly why? 🏛️';
    case 'nature':
      return 'Want to know the most surprising fact about $t that most people never hear? 🌿';
    case 'health':
      return 'Want to discover how $t can help you live a healthier and happier life? 💊';
    case 'religion':
      return 'The spiritual meaning behind $t has guided people for thousands of years — want to learn? 🕉️';
    case 'family':
      return 'Want to know how $t creates stronger bonds and beautiful memories in families? 💝';
    case 'education':
      return 'The learning method behind $t can unlock amazing potential — want to discover how? 🎓';
    case 'entertainment':
      return 'Want to know the creative secrets that make $t so entertaining and fun? 🎪';
    case 'travel':
      return 'The hidden gems and stories of $t make it an incredible adventure — want to explore? 🗺️';
    case 'business':
      return 'Want to discover how $t creates opportunities and changes people\'s lives? 📈';
    case 'mythology':
      return 'The ancient wisdom in $t teaches us timeless lessons — want to uncover them? 🏺';
    case 'festivals':
      return 'The celebration of $t brings communities together in the most beautiful ways — want to discover how? 🎆';
    case 'spirituality':
      return 'The practice of $t can transform your inner world and bring lasting peace — want to learn more? ✨';
    case 'bollywood':
      return 'The story behind $t shows how Indian cinema touches hearts worldwide — want to explore? 🎭';
    case 'asian_culture':
      return 'The cultural phenomenon of $t connects millions across Asia and beyond — want to discover why? 🌏';
    case 'health_wellness':
      return 'The ancient healing power of $t has been trusted for generations — want to know the secrets? 🌱';

    // Children & India focused categories depth questions
    case 'relation_names':
      return 'Want to know how the relationship $t makes our Indian families so loving and connected? 👨‍👩‍👧‍👦';
    case 'greetings':
      return 'The greeting $t carries beautiful cultural meaning — want to learn how it brings people together? 🙏';
    case 'hindi_grammar':
      return 'Want to discover how $t makes Hindi such a rich and expressive language? 📝';
    case 'english_grammar':
      return 'The grammar rule $t can help you become confident in English — want to master it? 📚';
    case 'maths_secondary':
      return 'Want to see how $t appears in real-life situations and makes problem-solving fun? 🧮';
    case 'indian_states':
      return 'The state $t has amazing stories and unique culture — want to explore what makes it special? 🇮🇳';
    case 'indian_foods':
      return 'Want to know the delicious secrets behind how $t is made in different parts of India? 🍛';
    case 'indian_music_genres':
      return 'The music style $t has deep cultural roots — want to discover its beautiful history? 🎵';
    case 'indian_shlokas':
      return 'The shloka $t carries ancient wisdom that can guide your life — want to understand its meaning? 🕉️';
    case 'computer_basics':
      return 'Want to discover how $t works and how it can make your digital life easier? 💻';
    case 'encyclopedia':
      return 'The question $t opens doors to fascinating knowledge — want to explore the amazing answers? 🤔';
    case 'indian_home_hacks':
      return 'Want to learn how the desi trick $t can solve everyday problems in your home? 🏠';
    case 'indian_kitchen_hacks':
      return 'The cooking tip $t can make your kitchen adventures more fun — want to try it? 👩‍🍳';
    case 'indian_languages':
      return 'The language $t connects millions of people — want to know its beautiful features? 🗣️';
    case 'indian_freedom_fighters':
      return 'The hero $t made incredible sacrifices for our freedom — want to know their inspiring story? 🇮🇳';
    case 'indian_dance_forms':
      return 'The dance $t tells stories through beautiful movements — want to learn its cultural significance? 💃';
    case 'indian_national_symbols':
      return 'Want to discover why $t was chosen to represent the pride and values of India? 🦚';
    case 'moral_stories':
      return 'The story $t teaches important life lessons — want to discover the wisdom it shares? 📖';
    case 'indoor_games':
      return 'Want to know how the game $t can bring your family together for fun and learning? 🎲';
    case 'body_parts':
      return 'Want to discover the amazing ways your $t works to keep you healthy and active? 🫀';
    case 'colors_shapes':
      return 'Want to see how $t appears in nature and art all around you? 🎨';

    default:
      return 'Your question about $t connects to some surprising real-world facts — want to explore? 🌟';
  }
}

// ── Phase 3: cluster prediction ───────────────────────────────────────────

/// Called when total queries >= 5.
/// [topCategory] is the user's most frequent category.
/// [secondCategory] is the second most frequent (or null).
/// [topWeight] is the top category's proportion (0.0–1.0).
String clusterSuggestion({
  required String topCategory,
  String? secondCategory,
  required double topWeight,
}) {
  if (secondCategory != null && topWeight < 0.7) {
    return 'You keep exploring both $topCategory and $secondCategory — '
        'want to discover the surprising connections between them? 🌐';
  }
  return 'You are really into $topCategory! Want to explore the most fascinating '
      '$topCategory fact that surprises everyone? ⭐';
}

// ── Utility ───────────────────────────────────────────────────────────────

String _lastWord(String text) {
  final cleaned = text.replaceAll(RegExp(r'[?!.,]'), '').trim();
  final words = cleaned.split(' ');
  return words.isNotEmpty ? words.last.toLowerCase() : cleaned.toLowerCase();
}
