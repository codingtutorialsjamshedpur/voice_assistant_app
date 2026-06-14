import '../../models/language_model.dart';

class TriggerWordConfiguration {
  final String triggerWord;
  final List<String> variants;
  final String language;
  final TriggerWordType type;
  final double confidenceThreshold;
  final int pauseBeforeTrigger;
  final String description;

  const TriggerWordConfiguration({
    required this.triggerWord,
    required this.variants,
    required this.language,
    required this.type,
    this.confidenceThreshold = 0.75,
    this.pauseBeforeTrigger = 300,
    required this.description,
  });

  factory TriggerWordConfiguration.fromLanguage(
    String language,
    TriggerWordType type,
  ) {
    final isEndOfThought = type == TriggerWordType.endOfThought;
    return TriggerWordConfiguration(
      triggerWord: isEndOfThought
          ? _getEndOfThoughtTrigger(language)
          : _getExitTrigger(language),
      variants: isEndOfThought
          ? _getEndOfThoughtVariants(language)
          : _getExitVariants(language),
      language: language,
      type: type,
      confidenceThreshold: 0.75,
      pauseBeforeTrigger: 300,
      description: isEndOfThought
          ? 'Trigger word to finish speaking'
          : 'Trigger word to exit app',
    );
  }

  static String _getEndOfThoughtTrigger(String language) {
    const triggers = {
      'hi': 'हो गया',
      'en-US': 'done',
      'en-GB': 'done',
      'hinglish': 'ho gaya',
      'bn': 'হয়ে গেছে',
      'pa': 'ਹੋ ਗਿਆ',
      'ta': 'முடிந்தது',
      'te': 'చేసాను',
      'kn': 'ಮುಗಿಯಿತು',
      'ml': 'സാധിച്ചു',
      'gu': 'થઈ ગયું',
      'mr': 'झाले',
      'ur': 'ہو گیا',
      'or': 'ହୋଇଗଲା',
      'as': 'সমাপ্ত',
      'mai': 'भोग गइल',
      'ne': 'भएको छ',
      'si': 'සිදුවිණි',
      'sa': 'समृद्धम्',
      'ks': 'مکمل ہویا',
      'fr': 'fait',
      'de': 'fertig',
      'es': 'listo',
      'it': 'fatto',
      'pt-BR': 'pronto',
      'ru': 'готово',
      'nl': 'klaar',
      'pl': 'gotowe',
      'uk': 'готово',
      'sv': 'klart',
      'nb': 'ferdig',
      'fi': 'valmis',
      'cs': 'hotovo',
      'tr': 'bitti',
      'vi': 'xong',
      'zh': '完成',
      'ja': '終了',
      'ko': '완료',
      'ar': 'انتهى',
      'id': 'selesai',
    };
    return triggers[language] ?? 'done';
  }

  static List<String> _getEndOfThoughtVariants(String language) {
    const variants = {
      'hi': ['हो गया', 'होगया', 'हो गिया', 'ho gaya', 'hogaya'],
      'en-US': ['done', 'finished', "that's it"],
      'en-GB': ['done', 'finished', "that's it"],
      'hinglish': ['ho gaya', 'hogaya', 'हो गया'],
      'bn': [
        'হয়ে গেছে',
        'হয় গেছে',
        'হয়েছে',
        'হয়ে গেছি',
        'শেষ',
        'সম্পন্ন',
        'hoye gache',
        'hoyegache',
        'hoise'
      ],
      'pa': ['ਹੋ ਗਿਆ', 'ਹੋਗਿਆ', 'ਪੂਰਾ', 'ho gia'],
      'ta': ['முடிந்தது', 'முடிஞ்சு', 'செய்த', 'mudindru'],
      'te': ['చేసాను', 'ేసిన', 'సరியైనద', 'chesanu'],
      'kn': ['ಮುಗಿಯಿತು', 'ಮುಗಿಯಾಗಿದೆ', 'ಹೋದ', 'mugiyitu'],
      'ml': ['സാധിച്ചു', 'ചെയ്തു', 'പൂര്‍ത്തിയായി', 'sadhiccu'],
      'gu': ['થઈ ગયું', 'સમાપ્ત', 'પૂર્ણ', 'thai gayu'],
      'mr': ['झाले', 'संपल', 'पूर्ण', 'zhale'],
      'ur': ['ہو گیا', 'ہوگیا', 'مکمل', 'ho gaya'],
      'or': ['ହୋଇଗଲା', 'ସମ୍ପୂର୍ਣ', 'ଶେଷ', 'hoigala'],
      'as': ['সমাপ্ত', 'শেষ', 'ঠিক আছে', 'samapot'],
      'mai': ['भोग गइल', 'संपूर्ण', 'अंत', 'bhog gail'],
      'ne': ['भएको छ', 'सकिएको छ', 'खत्म', 'bhaeko cha'],
      'si': ['සිදුවිණි', 'අවසන්', 'ඉවරයි', 'siduvi'],
      'sa': ['समृद्धम्', 'समाप्तम्', 'पूर्णtham', 'samriddham'],
      'ks': ['مکمل ہویا', 'ختم', 'اختتام', 'mukamil hua'],
      'fr': ['fait', "c'est bon", 'terminé'],
      'de': ['fertig', 'erledigt', 'done'],
      'es': ['listo', 'hecho', 'terminado'],
      'it': ['fatto', 'pronto', 'finito'],
      'pt-BR': ['pronto', 'feito', 'terminado'],
      'ru': ['готово', 'сделано', 'готовий'],
      'nl': ['klaar', 'gedaan', 'voltooid'],
      'pl': ['gotowe', 'zrobione', 'skończone'],
      'uk': ['готово', 'зроблено', 'готовий'],
      'sv': ['klart', 'färdig', 'gjort'],
      'nb': ['ferdig', 'gjort', 'klar'],
      'fi': ['valmis', 'tehty', 'valmiina'],
      'cs': ['hotovo', 'hotovo', 'uděláno'],
      'tr': ['bitti', 'tamamlandı', 'hazır'],
      'vi': ['xong', 'hoàn thành', 'được rồi'],
      'zh': ['完成', '做完', '好了'],
      'ja': ['終了', '終わった', 'おしまい'],
      'ko': ['완료', '끝났어', '끝'],
      'ar': ['انتهى', 'خلص', 'تم'],
      'id': ['selesai', 'selesai', 'beres'],
    };
    return variants[language] ?? ['done'];
  }

  static String _getExitTrigger(String language) {
    const triggers = {
      'hi': 'अलविदा',
      'en-US': 'goodbye',
      'en-GB': 'goodbye',
      'hinglish': 'alvida',
      'bn': 'বিদায়',
      'pa': 'ਅਲਵਿਦਾ',
      'ta': 'வணக்கம்',
      'te': 'అలవిడా',
      'kn': 'ವಿದಾಯ',
      'ml': 'വിട',
      'gu': 'અલવિદા',
      'mr': 'अलविदा',
      'ur': 'الوداع',
      'or': 'ବିଦାୟ',
      'as': 'বিদায়',
      'mai': 'विदा',
      'ne': 'अलविदा',
      'si': 'ගිහින් සිටින්න',
      'sa': 'विदा',
      'ks': 'خدا حافظ',
      'fr': 'au revoir',
      'de': 'auf Wiedersehen',
      'es': 'adiós',
      'it': 'arrivederci',
      'pt-BR': 'adeus',
      'ru': 'до свидания',
      'nl': 'tot ziens',
      'pl': 'do widzenia',
      'uk': 'до побачення',
      'sv': 'hej då',
      'nb': 'ha det',
      'fi': 'näkemiin',
      'cs': 'na shledanou',
      'tr': 'hoşça kalın',
      'vi': 'tạm biệt',
      'zh': '再见',
      'ja': 'さようなら',
      'ko': '안녕히',
      'ar': 'وداعا',
      'id': 'selamat tinggal',
    };
    return triggers[language] ?? 'goodbye';
  }

  static List<String> _getExitVariants(String language) {
    const variants = {
      'hi': ['अलविदा', 'alvida', 'भैया', 'bye'],
      'en-US': ['goodbye', 'bye', 'exit', 'see you'],
      'en-GB': ['goodbye', 'bye', 'exit', 'see you'],
      'hinglish': ['alvida', 'अलविदा', 'bye'],
      'bn': [
        'বিদায়',
        'আল্লাহ হাফেজ',
        'আবার দেখা হবে',
        'biday',
        'bidai',
        'bye'
      ],
      'pa': ['ਅਲਵਿਦਾ', 'alvida', 'ਬਾਏ'],
      'ta': ['வணக்கம்', 'கூட வணக்கம்', 'போ', 'vanakkam'],
      'te': ['అలిడా', 'नमस्कार', 'পোవడం', 'alvida'],
      'kn': ['ವಿದಾಯ', 'ಸುವರ್ಣಿಕ', 'ನಮಸ್ಕಾರ', 'vidaya'],
      'ml': ['വിട', 'സുഖമായ്', 'വിടപറയുന്നു', 'vida'],
      'gu': ['અલવિદા', 'વિદા', 'બાય', 'alvida'],
      'mr': ['अलविदा', 'सारे', 'जा', 'alvida'],
      'ur': ['الوداع', 'خدا حافظ', 'بائے', 'alvida'],
      'or': ['ବିଦାୟ', 'ନମସ୍ਕାਰ', 'ବାଇ', 'bidaya'],
      'as': ['বিদায়', 'নমস্কাৰ', 'বাই', 'bidaya'],
      'mai': ['विदा', 'नमस्ते', 'बाय', 'vida'],
      'ne': ['अलविदा', 'नमस्ते', 'बाई', 'alvida'],
      'si': ['ගිහින් සිටින්න', 'නිවිඩ', 'බායි', 'gihin sitinna'],
      'sa': ['विदा', 'नमस्ते', 'वन्दे', 'vida'],
      'ks': ['خدا حافظ', 'السلام', 'بائے', 'khuda hafiz'],
      'fr': ['au revoir', 'à bientôt', 'bye', 'adieu'],
      'de': ['auf Wiedersehen', 'tschüss', 'bye', 'wiedersehen'],
      'es': ['adiós', 'hasta luego', 'bye', 'salir'],
      'it': ['arrivederci', 'ciao', 'bye', 'addio'],
      'pt-BR': ['adeus', 'até logo', 'bye', 'tchau'],
      'ru': ['до свидания', 'пока', 'bye', 'прощай'],
      'nl': ['tot ziens', 'dag', 'bye', 'vaarwel'],
      'pl': ['do widzenia', 'pa', 'bye', 'żegnaj'],
      'uk': ['до побачення', 'пока', 'bye', 'на все добре'],
      'sv': ['hej då', 'farväl', 'bye', 'adjö'],
      'nb': ['ha det', 'farvel', 'bye', 'adjø'],
      'fi': ['näkemiin', 'terve', 'bye', 'moikka'],
      'cs': ['na shledanou', 'ahoj', 'bye', 'sbohem'],
      'tr': ['hoşça kalın', 'allahaismarladık', 'bye', 'güle güle'],
      'vi': ['tạm biệt', 'tạm biệt', 'bye', 'chào'],
      'zh': ['再见', '拜拜', 'bye', '再见吧'],
      'ja': ['さようなら', 'じゃあね', 'bye', 'さよなら'],
      'ko': ['안녕히', '또 봐', 'bye', '안녕'],
      'ar': ['وداعا', 'إلى اللقاء', 'bye', 'مع السلامة'],
      'id': ['selamat tinggal', 'dada', 'bye', 'selamat jalan'],
    };
    return variants[language] ?? ['goodbye', 'bye', 'exit'];
  }

  bool matches(String word) {
    final normalizedWord = word.toLowerCase().trim();
    if (triggerWord.toLowerCase() == normalizedWord) return true;
    for (final variant in variants) {
      if (variant.toLowerCase() == normalizedWord) return true;
    }
    return false;
  }

  double calculateSimilarity(String word) {
    final normalizedWord = word.toLowerCase().trim();
    final normalizedTrigger = triggerWord.toLowerCase();
    return _levenshteinSimilarity(normalizedWord, normalizedTrigger);
  }

  double _levenshteinSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    final matrix =
        List.generate(b.length + 1, (i) => List.filled(a.length + 1, 0));

    for (int i = 0; i <= a.length; i++) {
      matrix[0][i] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[j][0] = j;
    }

    for (int j = 1; j <= b.length; j++) {
      for (int i = 1; i <= a.length; i++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[j][i] = [
          matrix[j][i - 1] + 1,
          matrix[j - 1][i] + 1,
          matrix[j - 1][i - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    final distance = matrix[b.length][a.length];
    final maxLength = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLength);
  }
}
