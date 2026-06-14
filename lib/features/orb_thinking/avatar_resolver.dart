/// Avatar Resolver
/// Maps keywords to avatar asset paths with priority system
class AvatarResolver {
  static const _keywordMap = <String, String>{
    // Diamond orbs (checked first - higher priority)
    'royal': 'assets/images/diamond orb/diamond_orb.png',
    'luxury': 'assets/images/diamond orb/diamond_orb.png',
    'diamond': 'assets/images/diamond orb/diamond_orb.png',
    'premium': 'assets/images/diamond orb/diamond_orb.png',
    'grand': 'assets/images/diamond orb/diamond_orb.png',
    'majestic': 'assets/images/diamond orb/diamond_orb.png',
    // Hindi diamond orb keywords
    'राजसी': 'assets/images/diamond orb/diamond_orb.png', // royal
    'शाही': 'assets/images/diamond orb/diamond_orb.png', // royal/majestic
    'हीरा': 'assets/images/diamond orb/diamond_orb.png', // diamond
    'प्रीमियम': 'assets/images/diamond orb/diamond_orb.png', // premium
    'महान': 'assets/images/diamond orb/diamond_orb.png', // grand

    'smile': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'happy': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'joy': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'celebrate': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'wonderful': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'great': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'love': 'assets/images/diamond orb/diamond_orb__smiling.png',
    'delight': 'assets/images/diamond orb/diamond_orb__smiling.png',
    // Hindi smiling keywords
    'खुश': 'assets/images/diamond orb/diamond_orb__smiling.png', // happy
    'मुस्कान': 'assets/images/diamond orb/diamond_orb__smiling.png', // smile
    'खुशी':
        'assets/images/diamond orb/diamond_orb__smiling.png', // joy/happiness
    'प्रेम': 'assets/images/diamond orb/diamond_orb__smiling.png', // love
    'अद्भुत': 'assets/images/diamond orb/diamond_orb__smiling.png', // wonderful
    'बेहतरीन': 'assets/images/diamond orb/diamond_orb__smiling.png', // great

    'music': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'song': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'melody': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'rhythm': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'beat': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'tune': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'dance': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    'singing': 'assets/images/diamond orb/diamond_orb_listening_music.png',
    // Hindi music keywords
    'संगीत':
        'assets/images/diamond orb/diamond_orb_listening_music.png', // music
    'गाना': 'assets/images/diamond orb/diamond_orb_listening_music.png', // song
    'धुन':
        'assets/images/diamond orb/diamond_orb_listening_music.png', // melody/tune
    'नृत्य':
        'assets/images/diamond orb/diamond_orb_listening_music.png', // dance
    'गायन':
        'assets/images/diamond orb/diamond_orb_listening_music.png', // singing

    'silent': 'assets/images/diamond orb/diamond_orb_silent.png',
    'quiet': 'assets/images/diamond orb/diamond_orb_silent.png',
    'peace': 'assets/images/diamond orb/diamond_orb_silent.png',
    'calm': 'assets/images/diamond orb/diamond_orb_silent.png',
    'shh': 'assets/images/diamond orb/diamond_orb_silent.png',
    'hush': 'assets/images/diamond orb/diamond_orb_silent.png',
    'still': 'assets/images/diamond orb/diamond_orb_silent.png',
    // Hindi silent keywords
    'शांत': 'assets/images/diamond orb/diamond_orb_silent.png', // calm/peaceful
    'चुप': 'assets/images/diamond orb/diamond_orb_silent.png', // quiet/silent
    'शांति': 'assets/images/diamond orb/diamond_orb_silent.png', // peace
    'मौन': 'assets/images/diamond orb/diamond_orb_silent.png', // silent

    // Simple orbs
    'angry': 'assets/images/simple orb/angry.png',
    'furious': 'assets/images/simple orb/angry.png',
    'rage': 'assets/images/simple orb/angry.png',
    'mad': 'assets/images/simple orb/angry.png',
    'frustrated': 'assets/images/simple orb/angry.png',
    'upset': 'assets/images/simple orb/angry.png',
    // Hindi angry keywords
    'गुस्सा': 'assets/images/simple orb/angry.png', // angry
    'क्रोध': 'assets/images/simple orb/angry.png', // rage/anger
    'नाराज': 'assets/images/simple orb/angry.png', // upset/annoyed

    'dream': 'assets/images/simple orb/dreaming.png',
    'imagine': 'assets/images/simple orb/dreaming.png',
    'fantasy': 'assets/images/simple orb/dreaming.png',
    'vision': 'assets/images/simple orb/dreaming.png',
    'wonder': 'assets/images/simple orb/dreaming.png',
    // Hindi dreaming keywords
    'सपना': 'assets/images/simple orb/dreaming.png', // dream
    'कल्पना': 'assets/images/simple orb/dreaming.png', // imagination

    'excited': 'assets/images/simple orb/excited.png',
    'amazing': 'assets/images/simple orb/excited.png',
    'wow': 'assets/images/simple orb/excited.png',
    'incredible': 'assets/images/simple orb/excited.png',
    'fantastic': 'assets/images/simple orb/excited.png',
    // Hindi excited keywords
    'उत्साहित': 'assets/images/simple orb/excited.png', // excited
    'वाह': 'assets/images/simple orb/excited.png', // wow
    'अविश्वसनीय': 'assets/images/simple orb/excited.png', // incredible

    'exercise': 'assets/images/simple orb/exercising.png',
    'workout': 'assets/images/simple orb/exercising.png',
    'fitness': 'assets/images/simple orb/exercising.png',
    'running': 'assets/images/simple orb/exercising.png',
    'sport': 'assets/images/simple orb/exercising.png',
    'active': 'assets/images/simple orb/exercising.png',
    // Hindi exercise keywords
    'व्यायाम': 'assets/images/simple orb/exercising.png', // exercise
    'खेल': 'assets/images/simple orb/exercising.png', // sport/game
    'दौड़ना': 'assets/images/simple orb/exercising.png', // running

    'tired': 'assets/images/simple orb/exhausted.png',
    'exhausted': 'assets/images/simple orb/exhausted.png',
    'sleepy': 'assets/images/simple orb/exhausted.png',
    'worn': 'assets/images/simple orb/exhausted.png',
    'fatigue': 'assets/images/simple orb/exhausted.png',
    // Hindi tired keywords
    'थका': 'assets/images/simple orb/exhausted.png', // tired
    'नींद': 'assets/images/simple orb/exhausted.png', // sleepy

    'flirt': 'assets/images/simple orb/flirting.png',
    'wink': 'assets/images/simple orb/flirting.png',
    'charming': 'assets/images/simple orb/flirting.png',
    'playful': 'assets/images/simple orb/flirting.png',

    'laugh': 'assets/images/simple orb/laughing.png',
    'funny': 'assets/images/simple orb/laughing.png',
    'hilarious': 'assets/images/simple orb/laughing.png',
    'comedy': 'assets/images/simple orb/laughing.png',
    'joke': 'assets/images/simple orb/laughing.png',
    'humor': 'assets/images/simple orb/laughing.png',
    // Hindi laughing keywords
    'हंसना': 'assets/images/simple orb/laughing.png', // laugh
    'मजाकिया': 'assets/images/simple orb/laughing.png', // funny
    'चुटकुला': 'assets/images/simple orb/laughing.png', // joke

    'lie': 'assets/images/simple orb/lying.png',
    'false': 'assets/images/simple orb/lying.png',
    'dishonest': 'assets/images/simple orb/lying.png',
    'trick': 'assets/images/simple orb/lying.png',
    'deceive': 'assets/images/simple orb/lying.png',

    'nervous': 'assets/images/simple orb/nervous.png',
    'anxious': 'assets/images/simple orb/nervous.png',
    'worried': 'assets/images/simple orb/nervous.png',
    'stress': 'assets/images/simple orb/nervous.png',
    'fear': 'assets/images/simple orb/nervous.png',
    // Hindi nervous keywords
    'चिंतित': 'assets/images/simple orb/nervous.png', // worried
    'डर': 'assets/images/simple orb/nervous.png', // fear

    'cards': 'assets/images/simple orb/playing_cards.png',
    'game': 'assets/images/simple orb/playing_cards.png',
    'play': 'assets/images/simple orb/playing_cards.png',
    'poker': 'assets/images/simple orb/playing_cards.png',
    'strategy': 'assets/images/simple orb/playing_cards.png',

    'chess': 'assets/images/simple orb/playing_chess.png',
    'think': 'assets/images/simple orb/thinking.png',
    'plan': 'assets/images/simple orb/playing_chess.png',
    'move': 'assets/images/simple orb/playing_chess.png',
    // Hindi thinking keywords
    'सोचना': 'assets/images/simple orb/thinking.png', // think
    'विचार': 'assets/images/simple orb/thinking.png', // thought

    'read': 'assets/images/simple orb/reading_newspaper.png',
    'newspaper': 'assets/images/simple orb/reading_newspaper.png',
    'news': 'assets/images/simple orb/reading_newspaper.png',
    'article': 'assets/images/simple orb/reading_newspaper.png',
    'journal': 'assets/images/simple orb/reading_newspaper.png',

    'christmas': 'assets/images/simple orb/santa_avatar.png',
    'santa': 'assets/images/simple orb/santa_avatar.png',
    'gift': 'assets/images/simple orb/santa_avatar.png',
    'holiday': 'assets/images/simple orb/santa_avatar.png',
    'winter': 'assets/images/simple orb/santa_avatar.png',

    'search': 'assets/images/simple orb/searching.png',
    'find': 'assets/images/simple orb/searching.png',
    'look': 'assets/images/simple orb/searching.png',
    'explore': 'assets/images/simple orb/searching.png',
    'investigate': 'assets/images/simple orb/searching.png',

    'speak': 'assets/images/simple orb/speaking.png',
    'say': 'assets/images/simple orb/speaking.png',
    'talk': 'assets/images/simple orb/speaking.png',
    'tell': 'assets/images/simple orb/speaking.png',
    'explain': 'assets/images/simple orb/speaking.png',

    'teach': 'assets/images/simple orb/teaching.png',
    'learn': 'assets/images/simple orb/teaching.png',
    'educate': 'assets/images/simple orb/teaching.png',
    'lesson': 'assets/images/simple orb/teaching.png',
    'guide': 'assets/images/simple orb/teaching.png',

    'consider': 'assets/images/simple orb/thinking.png',
    'ponder': 'assets/images/simple orb/thinking.png',
    'reflect': 'assets/images/simple orb/thinking.png',
    'wondering': 'assets/images/simple orb/thinking.png',

    'sick': 'assets/images/simple orb/unwell.png',
    'unwell': 'assets/images/simple orb/unwell.png',
    'ill': 'assets/images/simple orb/unwell.png',
    'health': 'assets/images/simple orb/unwell.png',
    'pain': 'assets/images/simple orb/unwell.png',
    'hurt': 'assets/images/simple orb/unwell.png',

    'skate': 'assets/images/simple orb/skateboarding.png',
    'cool': 'assets/images/simple orb/skateboarding.png',
    'adventure': 'assets/images/simple orb/skateboarding.png',
    'thrill': 'assets/images/simple orb/skateboarding.png',

    'whistle': 'assets/images/simple orb/whistling.png',
    'hum': 'assets/images/simple orb/whistling.png',
    'cheerful': 'assets/images/simple orb/whistling.png',

    'yoga': 'assets/images/simple orb/yoga.png',
    'meditate': 'assets/images/simple orb/yoga.png',
    'spiritual': 'assets/images/simple orb/yoga.png',
    'zen': 'assets/images/simple orb/yoga.png',
    'balance': 'assets/images/simple orb/yoga.png',
    'breathe': 'assets/images/simple orb/yoga.png',

    'naughty': 'assets/images/simple orb/naughty.png',
    'mischievous': 'assets/images/simple orb/naughty.png',
    'cheeky': 'assets/images/simple orb/naughty.png',
    'sneaky': 'assets/images/simple orb/naughty.png',

    'sneeze': 'assets/images/simple orb/sneezing.png',
    'cold': 'assets/images/simple orb/sneezing.png',
    'virus': 'assets/images/simple orb/sneezing.png',
    'allergy': 'assets/images/simple orb/sneezing.png',

    'glasses': 'assets/images/simple orb/wearing_round_glasses.png',
    'wise': 'assets/images/simple orb/wearing_round_glasses.png',
    'intellectual': 'assets/images/simple orb/wearing_round_glasses.png',
    'scholar': 'assets/images/simple orb/wearing_round_glasses.png',
    'knowledge': 'assets/images/simple orb/wearing_round_glasses.png',

    'sunglasses': 'assets/images/simple orb/wearing_sunglasses.png',
    'summer': 'assets/images/simple orb/wearing_sunglasses.png',
    'style': 'assets/images/simple orb/wearing_sunglasses.png',
    'fashion': 'assets/images/simple orb/wearing_sunglasses.png',

    'ghost': 'assets/images/simple orb/funny_ghost_avatar.png',
    'spooky': 'assets/images/simple orb/funny_ghost_avatar.png',
    'haunted': 'assets/images/simple orb/funny_ghost_avatar.png',
    'mystery': 'assets/images/simple orb/funny_ghost_avatar.png',
    'strange': 'assets/images/simple orb/funny_ghost_avatar.png',

    'cowboy': 'assets/images/simple orb/cowboy hat.png',
    'western': 'assets/images/simple orb/cowboy hat.png',
    'wild': 'assets/images/simple orb/cowboy hat.png',
    'ranch': 'assets/images/simple orb/cowboy hat.png',

    'angle': 'assets/images/simple orb/angle.png',
    'direction': 'assets/images/simple orb/angle.png',
    'point': 'assets/images/simple orb/angle.png',
    'geometry': 'assets/images/simple orb/angle.png',

    'blink': 'assets/images/simple orb/blinking_one_eye.png',
    'eye': 'assets/images/simple orb/blinking_one_eye.png',
    'notice': 'assets/images/simple orb/blinking_one_eye.png',

    'toddler': 'assets/images/simple orb/toddler.png',
    'child': 'assets/images/simple orb/toddler.png',
    'baby': 'assets/images/simple orb/toddler.png',
    'little': 'assets/images/simple orb/toddler.png',
    'kid': 'assets/images/simple orb/toddler.png',

    'smiley': 'assets/images/simple orb/smiley.png',
    'grin': 'assets/images/simple orb/smiley.png',
    'beam': 'assets/images/simple orb/smiley.png',
  };

  /// Returns asset path or null if no match
  static String? resolve(String word) {
    // Clean the word by removing punctuation but preserving Hindi and English characters
    // Hindi Unicode range: \u0900-\u097F, English: a-z
    // Also removes Hindi punctuation like । (U+0964) and ॥ (U+0965)
    final cleaned =
        word.toLowerCase().replaceAll(RegExp(r'[^\u0900-\u097Fa-z]'), '');
    return _keywordMap[cleaned];
  }

  /// Scans a full sentence and returns first matching asset
  /// Diamond orbs take priority over simple orbs
  static String? resolveFromSentence(String sentence) {
    for (final word in sentence.split(' ')) {
      final result = resolve(word);
      if (result != null) return result;
    }
    return null;
  }

  /// Get all unique avatar paths for preloading
  static Set<String> getAllAvatarPaths() {
    return _keywordMap.values.toSet();
  }
}
