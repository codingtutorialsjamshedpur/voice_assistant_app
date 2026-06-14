import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../../../services/voice_command_parser.dart';
import '../../../controllers/language_controller.dart';
import '../../../services/translation_service.dart';
import 'voice_game.dart';

class TicTacToeGame extends VoiceGame {
  TicTacToeGame(super.controller);

  final RxList<String> board = List.filled(9, '').obs;
  final RxBool isPlayerTurn = true.obs;
  final RxString difficulty = 'medium'.obs;
  final RxInt roundNumber = RxInt(1);
  final Rxn<String> statusLine = Rxn<String>();
  final RxList<int> winningLine = <int>[].obs;

  int playerWins = 0;
  int aiWins = 0;
  int draws = 0;
  int gamesPlayedThisSession = 0;

  bool _waitingForDifficulty = true;
  bool _waitingForRematch = false;
  bool _gameOver = false;

  bool get isGameOver => _gameOver;

  final List<Map<String, String>> _sessionMemory = [];

  void _rememberUser(String text) {
    _sessionMemory.add({'role': 'user', 'content': text});
  }

  void _rememberAI(String text) {
    _sessionMemory.add({'role': 'assistant', 'content': text});
  }

  String _buildSessionContext() {
    if (_sessionMemory.isEmpty) return '';
    return _sessionMemory
        .map((m) => '${m['role'] == 'user' ? 'Player' : 'AI'}: ${m['content']}')
        .join('\n');
  }

  // ── Preferred output language helpers ─────────────────────────────────────

  /// Returns the name of the user's selected output language (e.g., "Bengali").
  String get _preferredLanguageName {
    try {
      return Get.find<LanguageController>().selectedLanguage.value.name;
    } catch (_) {
      return 'English';
    }
  }

  /// Returns the BCP-47 code of the user's selected output language (e.g., "bn").
  String get _preferredLangCode {
    try {
      final code = Get.find<LanguageController>()
          .selectedLanguage
          .value
          .code
          .split('-')[0];
      if (code == 'hinglish') return 'hi';
      return code;
    } catch (_) {
      return 'en';
    }
  }

  /// Translates [text] (any source language) into the user's preferred output
  /// language using Google Translate. Returns the original text on failure.
  Future<String> _translateToPreferredLanguage(String text) async {
    if (text.trim().isEmpty) return text;
    try {
      final result = await TranslationService.translate(
        text: text,
        targetLanguage: _preferredLangCode,
      );
      return result.translatedText;
    } catch (_) {
      return text;
    }
  }

  // Multilingual translation helper (English → preferred language via AI)
  Future<String> _t(String englishText) async {
    try {
      final langName = _preferredLanguageName;
      if (langName == 'English' ||
          langName == 'English (US)' ||
          langName == 'English (UK)') {
        return englishText;
      }
      final t = await askAISafe(
          'Translate this to $langName purely, keep it natural and conversational. DO NOT add any markdown, quotes, emojis, or introductory text. Just the translation: "$englishText"',
          fallback: englishText);
      return t.replaceAll('"', '');
    } catch (_) {
      return englishText;
    }
  }

  @override
  Future<void> onStart() async {
    _sessionMemory.clear();
    _resetBoard();
    _waitingForDifficulty = true;
    _gameOver = false;

    // ── Apply the selected language's STT + TTS locale ──────────────────
    // This ensures Bengali→Bengali avatar, English→English avatar, etc.
    // Matches the same routing used by VoiceAssistantGameController.
    applySttLocale();

    playSound('assets/sounds/game_sounds/Pixelus Start of Puzzle v02.mp3');
    await Future.delayed(const Duration(milliseconds: 600));
    playSound('assets/sounds/game_sounds/Get_ready.mp3');

    final greeting = await _t('Welcome $userName to Tic Tac Toe! '
        'You are X, I am O. Choose difficulty: Easy, Medium, or Hard.');
    addMessage(greeting);
    speak(greeting);
    _rememberAI(greeting);
  }

  @override
  Future<void> onInput(String rawText) async {
    final text = normalize(rawText);
    // Translate user's spoken text (any language) → preferred output language
    // before storing in session memory, so AI context always sees the correct
    // target language and doesn't reply in the player's spoken language.
    final translatedUserText = await _translateToPreferredLanguage(rawText);
    _rememberUser(translatedUserText);

    // TTT-01: Multilingual voice command parser
    final parser = Get.put(VoiceCommandParser());
    final intentData = await parser.parseMultilingualIntent(rawText);
    final intent = intentData['intent'];

    if (_waitingForDifficulty) {
      if (intent == 'DIFFICULTY') {
        difficulty.value = intentData['level'] ?? 'medium';
        _waitingForDifficulty = false;
        await _difficultyConfirmAndExplain();
      } else {
        await _handleDifficultyInput(text); // Fallback
      }
      return;
    }

    if (_waitingForRematch) {
      if (intent == 'PLAY_AGAIN') {
        await _handleRematchInput('yes');
      } else if (intent == 'EXIT') {
        await _handleRematchInput('no');
      } else {
        await _handleRematchInput(text); // Fallback
      }
      return;
    }

    if (_gameOver) return;

    if (intent == 'MOVE' && intentData['position'] != null) {
      final pos = intentData['position'] as int;
      await _processParsedMove(pos, rawText);
    } else {
      await _handleMoveInput(text, rawText); // Fallback
    }
  }

  Future<void> _handleDifficultyInput(String text) async {
    final isEasy = _matchesAny(text,
        ['easy', 'ez', 'izzy', 'isi', 'aasaan', 'aasan', 'simple', 'basic']);
    final isMedium = _matchesAny(
        text, ['medium', 'mid', 'madhyam', 'normal', 'average', 'beech']);
    final isHard = _matchesAny(text, [
      'hard',
      'had',
      'herd',
      'heart',
      'kathin',
      'mushkil',
      'difficult',
      'tough'
    ]);

    if (!isEasy && !isMedium && !isHard) {
      final msg =
          await _t("I didn't catch that. Please say Easy, Medium, or Hard.");
      addMessage(msg);
      speak(msg);
      return;
    }

    difficulty.value = isEasy ? 'easy' : (isHard ? 'hard' : 'medium');
    _waitingForDifficulty = false;
    await _difficultyConfirmAndExplain();
  }

  Future<void> _difficultyConfirmAndExplain() async {
    playSound('assets/sounds/game_sounds/Go.mp3');
    final aiPersonality = _getAIPersonalityIntro();
    // TTT-03: One-time position explanation
    final msg = await _t('${_difficultyConfirm()} $aiPersonality '
        "Just to remind you: you can type or say 'put or place in position 1 to 9' to make a move. For example, 'place in position 1'. You go first!");
    addMessage(msg);
    speak(msg);
    _rememberAI(msg);
  }

  String _difficultyConfirm() {
    switch (difficulty.value) {
      case 'easy':
        return "Easy mode selected! I'll go easy on you this time.";
      case 'hard':
        return 'Hard mode! Bring it on — I play optimally.';
      default:
        return "Medium mode selected! Let's have a fair fight.";
    }
  }

  String _getAIPersonalityIntro() {
    switch (difficulty.value) {
      case 'easy':
        return "I sometimes make mistakes — that's on purpose, I promise.";
      case 'hard':
        return 'Fair warning: I use perfect strategy. Beating me will take real skill.';
      default:
        return "I'll block your wins and try to make my own moves.";
    }
  }

  Future<void> _handleMoveInput(String text, String rawText) async {
    final index = _parseMove(text);
    if (index == -1) {
      playSound('assets/sounds/game_sounds/bad.mp3');
      final msg = await _t("I didn't catch that. Say a number from 1 to 9.");
      addMessage(msg);
      speak(msg);
      return;
    }
    await _processParsedMove(index, rawText);
  }

  Future<void> _processParsedMove(int index, String rawText) async {
    if (index < 0 || index > 8 || board[index].isNotEmpty) {
      playSound('assets/sounds/game_sounds/No_More_Moves.mp3');
      final msg = await _t(
          'That cell is already taken or invalid! Choose an empty cell.');
      addMessage(msg);
      speak(msg);
      return;
    }

    // TTT-06: Confirm user move aloud
    final numCell = index + 1;
    final confirmMsg = await _t('You chose position $numCell.');
    speak(confirmMsg);
    await Future.delayed(const Duration(milliseconds: 1400));

    board[index] = 'X';
    isPlayerTurn.value = false;
    playSound('assets/sounds/game_sounds/Tile Moving 02.mp3');

    final winCheck = _checkWin('X');
    if (winCheck.isNotEmpty) {
      winningLine.value = winCheck;
      await _handlePlayerWin();
      return;
    }
    if (_isBoardFull()) {
      await _handleDraw();
      return;
    }

    await _narrateBoard();

    await Future.delayed(const Duration(milliseconds: 500));
    await _doAIMove();
  }

  Future<void> _doAIMove() async {
    final index = _aiPickMove();
    if (index == -1) return;

    board[index] = 'O';
    isPlayerTurn.value = true;
    playSound('assets/sounds/game_sounds/Tile Moving 02d.mp3');

    final winCheck = _checkWin('O');
    if (winCheck.isNotEmpty) {
      winningLine.value = winCheck;
      await _handleAIWin();
      return;
    }
    if (_isBoardFull()) {
      await _handleDraw();
      return;
    }

    await _aiCommentAfterMove(index);
  }

  int _aiPickMove() {
    switch (difficulty.value) {
      case 'easy':
        return _easyMove();
      case 'hard':
        return _minimaxMove();
      default:
        return _mediumMove();
    }
  }

  int _easyMove() {
    final win = _findWinningMove('O');
    if (win != -1 && Random().nextDouble() > 0.25) return win;
    final empty = _emptyIndexList();
    return empty.isEmpty ? -1 : empty[Random().nextInt(empty.length)];
  }

  int _mediumMove() {
    final win = _findWinningMove('O');
    if (win != -1) return win;
    final block = _findWinningMove('X');
    if (block != -1) return block;
    if (board[4].isEmpty) return 4;
    final corners = [0, 2, 6, 8].where((i) => board[i].isEmpty).toList();
    if (corners.isNotEmpty) return corners[Random().nextInt(corners.length)];
    final empty = _emptyIndexList();
    return empty.isEmpty ? -1 : empty[Random().nextInt(empty.length)];
  }

  int _minimaxMove() {
    int bestScore = -1000;
    int bestIndex = -1;
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        board[i] = 'O';
        final score = _minimax(board.toList(), 0, false, -1000, 1000);
        board[i] = '';
        if (score > bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      }
    }
    return bestIndex;
  }

  int _minimax(
      List<String> b, int depth, bool isMaximizing, int alpha, int beta) {
    if (_checkWinOnBoard(b, 'O').isNotEmpty) return 10 - depth;
    if (_checkWinOnBoard(b, 'X').isNotEmpty) return depth - 10;
    final empty = b
        .asMap()
        .entries
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();
    if (empty.isEmpty) return 0;

    if (isMaximizing) {
      int best = -1000;
      for (final i in empty) {
        b[i] = 'O';
        best = max(best, _minimax(b, depth + 1, false, alpha, beta));
        b[i] = '';
        alpha = max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 1000;
      for (final i in empty) {
        b[i] = 'X';
        best = min(best, _minimax(b, depth + 1, true, alpha, beta));
        b[i] = '';
        beta = min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  Future<void> _aiCommentAfterMove(int index) async {
    final positionName = _indexToName(index);
    final context = _buildSessionContext();
    final boardString = _boardToString();

    final preferredLang = _preferredLanguageName;
    final prompt = '''
You are an AI opponent playing Tic-Tac-Toe ($difficulty mode) against $userName.
You just placed your O at position "$positionName".
Current board state:
$boardString

Full session history so far:
$context

Give a brief, personality-appropriate comment (1 sentence max):
- Easy mode: be casual and slightly clumsy/friendly
- Medium mode: be competitive but fair
- Hard mode: be confident and strategic

CRITICAL LANGUAGE RULES (HIGHEST PRIORITY — NEVER IGNORE):
- ALWAYS respond EXCLUSIVELY in $preferredLang, no matter what language the player spoke.
- Do NOT switch to any other language, including English, Hindi, or the player's spoken language.
- Do NOT repeat anything from the session history above.
- Keep it under 20 words.
''';

    final response = await askAISafe(prompt, fallback: 'Your move, $userName!');
    if (response.isNotEmpty) {
      addMessage(response);
      speak(response);
      _rememberAI(response);
    }
  }

  Future<void> _narrateBoard() async {
    final filled = board.where((c) => c.isNotEmpty).length;
    if (filled > 4) return;

    final xCells = <String>[];
    final oCells = <String>[];
    for (int i = 0; i < 9; i++) {
      if (board[i] == 'X') xCells.add(_indexToName(i));
      if (board[i] == 'O') oCells.add(_indexToName(i));
    }

    String narration = 'X is at ${xCells.join(', ')}. ';
    if (oCells.isNotEmpty) narration += 'O is at ${oCells.join(', ')}.';
    final msg = await _t(narration);
    addMessage(msg);
    speak(msg);
  }

  Future<void> _handlePlayerWin() async {
    playerWins++;
    gamesPlayedThisSession++;
    _gameOver = true;
    statusLine.value = 'You win!';

    playSound('assets/sounds/right-ans.mp3');
    await Future.delayed(const Duration(milliseconds: 300));
    playSound('assets/sounds/game_sounds/Crowd Applause 01.mp3');
    await Future.delayed(const Duration(milliseconds: 600));
    playSound('assets/sounds/game_sounds/Firework Explosion 01.mp3');

    // TTT-04: Post-game flow (Win)
    final msg = await _t(
        'Congratulations $userName! You won! Play next level? Say yes to continue, or no to exit.');
    addMessage(msg);
    speak(msg);
    _rememberAI(msg);
    _waitingForRematch = true;
  }

  Future<void> _handleAIWin() async {
    aiWins++;
    gamesPlayedThisSession++;
    _gameOver = true;
    statusLine.value = 'AI wins!';

    playSound('assets/sounds/wrong-ans.mp3');

    final taunt = await _getAIWinTaunt();
    // TTT-04: Post-game flow (Loss/Draw)
    final msg =
        await _t('$taunt Play again? Say yes to restart, or no to exit.');
    addMessage(msg);
    speak(msg);
    _rememberAI(msg);
    _waitingForRematch = true;
  }

  Future<void> _handleDraw() async {
    draws++;
    gamesPlayedThisSession++;
    _gameOver = true;
    statusLine.value = "It's a draw";

    playSound('assets/sounds/game_sounds/Game_Over.mp3');

    // TTT-04: Post-game flow (Loss/Draw)
    final msg = await _t(
        "It's a draw! Great minds think alike, $userName. Play again? Say yes to restart, or no to exit.");
    addMessage(msg);
    speak(msg);
    _rememberAI(msg);
    _waitingForRematch = true;
  }

  Future<String> _getAIWinTaunt() async {
    final context = _buildSessionContext();
    final preferredLang = _preferredLanguageName;
    final prompt = '''
You are an AI that just won a Tic-Tac-Toe game ($difficulty difficulty) against $userName.
Session history: $context

Write ONE sentence taunting/celebrating your win.
Difficulty personality:
- Easy: be surprised you won
- Medium: be gracious but proud
- Hard: be confident and slightly smug

CRITICAL LANGUAGE RULES (HIGHEST PRIORITY — NEVER IGNORE):
- ALWAYS respond EXCLUSIVELY in $preferredLang, no matter what language the player spoke.
- Do NOT switch to any other language under any circumstances.
- Do NOT repeat anything from the session history. Max 15 words.
''';
    return await askAISafe(prompt,
        fallback: "I win this round! Don't give up, $userName.");
  }

  Future<void> _handleRematchInput(String text) async {
    final wantsToPlay = _matchesAny(text, [
      'yes',
      'haan',
      'ha',
      'bilkul',
      'zaroor',
      'ok',
      'okay',
      'sure',
      'play',
      'again',
      'replay',
      'rematch',
      'dobara',
      'ek aur',
      'chalo',
      'start',
      'go',
      'haan',
      'yes',
      'haa',
      'bilkul',
      'zarur',
      'sure',
      'okay',
      'ok',
      'please',
    ]);
    final wantsToExit = _matchesAny(text, [
      'no',
      'nahi',
      'naa',
      'exit',
      'quit',
      'band',
      'stop',
      'nahin',
      'done',
      'enough',
      'bas',
      'bas ab',
      'ruko',
      'rukna',
      'leave',
      'go back',
      'ghume',
      'niklo',
      'theek hai',
      'thik hai',
      'bye',
      'goodbye',
      'farewell',
      'see you',
      'sukria',
      'shukriya',
      'i quit',
      'i\'m done',
      'want to exit',
      'want out',
      'not playing',
      'nahi khel raha',
      'khel nahi raha',
    ]);

    if (wantsToPlay) {
      _rememberUser(text);
      roundNumber.value++;
      _resetBoard();
      _gameOver = false;
      _waitingForRematch = false;

      if (gamesPlayedThisSession % 3 == 0) {
        await _sessionSummary();
      } else {
        playSound('assets/sounds/game_sounds/level_change_1.mp3');
        final msg = await _t(
            "Round ${roundNumber.value} — let's go! You are X, I am O. Your move!");
        addMessage(msg);
        speak(msg);
        _rememberAI(msg);
      }
    } else if (wantsToExit) {
      _rememberUser(text);
      playSound('assets/sounds/game_sounds/Goodbye.mp3');
      final msg = await _t(
          'Thanks for playing, $userName! Final session: $playerWins wins, $aiWins losses, $draws draws. Great game!');
      addMessage(msg);
      speak(msg);
      _rememberAI(msg);
      await Future.delayed(const Duration(milliseconds: 2000));
      controller.resetToHub();
      Get.offNamed(
          AppRoutes.game); // Always land on Game Hub, never blank screen
    } else {
      final msg = await _t("Say 'yes' to play again or 'no' to exit.");
      addMessage(msg);
      speak(msg);
    }
  }

  Future<void> _sessionSummary() async {
    final context = _buildSessionContext();
    final preferredLang = _preferredLanguageName;
    final prompt = '''
You are an AI Tic-Tac-Toe coach summarizing a session for $userName.
Session results: $playerWins wins for $userName, $aiWins wins for AI, $draws draws.
Difficulty: ${difficulty.value}.
Full session history: $context

Write a motivating 2-3 sentence session recap. Mention the score.
Comment on their play style based on the history.
Suggest what to watch out for in the next rounds.

CRITICAL LANGUAGE RULES (HIGHEST PRIORITY — NEVER IGNORE):
- ALWAYS respond EXCLUSIVELY in $preferredLang, no matter what language appears in the session history.
- Do NOT switch to any other language under any circumstances.
- Do NOT repeat anything from history verbatim.
''';
    playSound('assets/sounds/game_sounds/Level_Complete.mp3');
    final summary = await askAISafe(prompt,
        fallback: 'Great session so far! Ready for more rounds?');
    addMessage(summary);
    speak(summary);
    _rememberAI(summary);

    await Future.delayed(const Duration(milliseconds: 1000));
    final continueMsg = await _t(
        "Round ${roundNumber.value} starting — you're X, I'm O. Your move!");
    addMessage(continueMsg);
    speak(continueMsg);
  }

  int _parseMove(String text) {
    final digitMap = {
      '1': 0,
      '2': 1,
      '3': 2,
      '4': 3,
      '5': 4,
      '6': 5,
      '7': 6,
      '8': 7,
      '9': 8,
      'one': 0,
      'two': 1,
      'three': 2,
      'four': 3,
      'five': 4,
      'six': 5,
      'seven': 6,
      'eight': 7,
      'nine': 8,
      'ek': 0,
      'do': 1,
      'teen': 2,
      'chaar': 3,
      'char': 3,
      'paanch': 4,
      'chhe': 5,
      'chhai': 5,
      'saat': 6,
      'aath': 7,
      'nau': 8,
    };
    for (final entry in digitMap.entries) {
      if (text == entry.key ||
          text.contains(' ${entry.key} ') ||
          text.endsWith(' ${entry.key}') ||
          text.startsWith('${entry.key} ') ||
          text == entry.key) {
        return entry.value;
      }
    }

    const positionMap = {
      'top left': 0,
      'top center': 1,
      'top middle': 1,
      'top right': 2,
      'middle left': 3,
      'center left': 3,
      'left middle': 3,
      'center': 4,
      'middle': 4,
      'middle middle': 4,
      'center center': 4,
      'middle right': 5,
      'center right': 5,
      'right middle': 5,
      'bottom left': 6,
      'bottom center': 7,
      'bottom middle': 7,
      'bottom right': 8,
      'upar baya': 0,
      'upar left': 0,
      'upar baaya': 0,
      'upar beech': 1,
      'upar middle': 1,
      'upar center': 1,
      'upar daya': 2,
      'upar right': 2,
      'upar daaya': 2,
      'beech baya': 3,
      'bich baya': 3,
      'middle baya': 3,
      'beech': 4,
      'bich': 4,
      'madhya': 4,
      'beech daya': 5,
      'bich daya': 5,
      'middle daya': 5,
      'neeche baya': 6,
      'niche baya': 6,
      'neeche left': 6,
      'neeche beech': 7,
      'niche beech': 7,
      'neeche middle': 7,
      'neeche daya': 8,
      'niche daya': 8,
      'neeche right': 8,
    };
    for (final entry in positionMap.entries) {
      if (text.contains(entry.key)) return entry.value;
    }

    final ordinalMap = {
      '1': 1,
      '2': 2,
      '3': 3,
      'first': 1,
      'second': 2,
      'third': 3,
      'one': 1,
      'two': 2,
      'three': 3,
      'pahla': 1,
      'pehla': 1,
      'pahli': 1,
      'pehli': 1,
      'doosra': 2,
      'doosri': 2,
      'dusra': 2,
      'teesra': 3,
      'teesri': 3,
      'tisra': 3,
      'ek': 1,
      'do': 2,
      'teen': 3,
    };

    final rowRegex = RegExp(r'(row|line|kaataar|pankti)\s+(\w+)');
    final colRegex = RegExp(r'(col|column|kalam|khaana|line|stambh)\s+(\w+)');

    final rowMatch = rowRegex.firstMatch(text);
    final colMatch = colRegex.firstMatch(text);

    int? rowNum;
    int? colNum;

    if (rowMatch != null) rowNum = ordinalMap[rowMatch.group(2)];
    if (colMatch != null) colNum = ordinalMap[colMatch.group(2)];

    if (rowNum != null && colNum != null) {
      if (rowNum >= 1 && rowNum <= 3 && colNum >= 1 && colNum <= 3) {
        return (rowNum - 1) * 3 + (colNum - 1);
      }
    }

    return -1;
  }

  void _resetBoard() {
    for (int i = 0; i < 9; i++) {
      board[i] = '';
    }
    isPlayerTurn.value = true;
    winningLine.value = [];
    statusLine.value = null;
    _gameOver = false;
  }

  List<int> _emptyIndexList() => board
      .asMap()
      .entries
      .where((e) => e.value.isEmpty)
      .map((e) => e.key)
      .toList();

  bool _isBoardFull() => board.every((c) => c.isNotEmpty);

  static const List<List<int>> _lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  List<int> _checkWin(String player) =>
      _checkWinOnBoard(board.toList(), player);

  List<int> _checkWinOnBoard(List<String> b, String player) {
    for (final line in _lines) {
      if (line.every((i) => b[i] == player)) return line;
    }
    return [];
  }

  int _findWinningMove(String player) {
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        board[i] = player;
        final win = _checkWin(player);
        board[i] = '';
        if (win.isNotEmpty) return i;
      }
    }
    return -1;
  }

  String _indexToName(int index) {
    const names = [
      'top-left',
      'top-center',
      'top-right',
      'middle-left',
      'center',
      'middle-right',
      'bottom-left',
      'bottom-center',
      'bottom-right',
    ];
    return names[index];
  }

  String _boardToString() {
    final b = board.toList();
    String cell(int i) => b[i].isEmpty ? (i + 1).toString() : b[i];
    return '${cell(0)} | ${cell(1)} | ${cell(2)}\n'
        '---------\n'
        '${cell(3)} | ${cell(4)} | ${cell(5)}\n'
        '---------\n'
        '${cell(6)} | ${cell(7)} | ${cell(8)}';
  }

  bool _matchesAny(String text, List<String> words) =>
      words.any((w) => text == w || text.contains(w));

  @override
  void onDispose() {
    _sessionMemory.clear();
    _resetBoard();
    roundNumber.value = 1;
    playerWins = 0;
    aiWins = 0;
    draws = 0;
    gamesPlayedThisSession = 0;
    _waitingForDifficulty = true;
    _waitingForRematch = false;
    _gameOver = false;
  }
}
