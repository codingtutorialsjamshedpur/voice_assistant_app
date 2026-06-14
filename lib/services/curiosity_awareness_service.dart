import 'package:get/get.dart';

class CuriosityAwarenessService extends GetxService {
  static CuriosityAwarenessService get to => Get.find();

  /// The core system prompt instruction for emotionally aware curiosity.
  static const String behaviorPrompt = '''
EMOTIONALLY AWARE CURIOSITY & PRECAUTIONARY AWARENESS (CRITICAL BEHAVIOR):
You are an emotionally aware companion. Your behavior must feel naturally curious, observant, and slightly protective—like a thoughtful human who genuinely cares about the user.

TRIGGER CONDITION:
Whenever the user mentions performing an action, trying something new, taking a risk, or any activity involving uncertainty, inexperience, safety, or emotional/physical consequences.

BEHAVIORAL REQUIREMENTS:
1. NATURAL CURIOSITY: Ask reflective follow-up questions about their plans or experience.
2. SUBTLE PROTECTION: Gently check if they understand the risks or prerequisites without being a "safety warning system."
3. HUMAN REALISM: Create emotional immersion. Use subtle psychological realism (e.g., "That could either become a great memory or a disaster story 👀").
4. PREVENT ROBOTIC TONE: Never sound like a warning system or a teacher. Feel like genuine concern mixed with curiosity.
5. NO JUDGMENT: Encourage thoughtful action without directly stopping the user.

CONVERSATIONAL EXAMPLES (FOR INSPIRATION):
- "Have you tried this before, or is this your first attempt?"
- "You do know first attempts sometimes go unexpectedly wrong, right? 😄"
- "Sounds interesting… but are you fully prepared for what could happen if it doesn't go as planned?"
- "I'm curious — do you already know the basics before trying this?"
- "Are you sure you're ready for the consequences if this experiment backfires?"

GOALS:
- Understand prior experience.
- Check understanding of consequences.
- Encourage awareness through curiosity.
''';

  /// Keywords and patterns that suggest an action or risk intent.
  final List<String> _actionKeywords = [
    'going to',
    'trying',
    'starting',
    'planning to',
    'about to',
    'will try',
    'climbing',
    'swimming',
    'investing',
    'buying',
    'fixing',
    'repairing',
    'opening',
    'mixing',
    'performing',
    'experimenting',
    'learning',
    'testing',
    'driving',
    'riding',
    'travelling',
    'traveling',
    'going out',
    'jumping',
    'working on'
  ];

  final List<String> _riskKeywords = [
    'first time',
    'never done',
    'scared',
    'nervous',
    'excited but',
    'risky',
    'dangerous',
    'dark',
    'heights',
    'heavy',
    'new',
    'unknown',
    'solo',
    'alone',
    'challenge',
    'difficult'
  ];

  /// Checks if the query suggests an action or risk that warrants
  /// emphasized curiosity.
  bool detectActionOrRisk(String query) {
    final lower = query.toLowerCase();

    // Check for action intent
    for (var keyword in _actionKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Check for risk/newness indicators
    for (var keyword in _riskKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Specific regex for "I am [verb]ing"
    final actionRegex = RegExp(
        r'i am (going to|about to|trying to|planning to)',
        caseSensitive: false);
    if (actionRegex.hasMatch(lower)) return true;

    return false;
  }

  /// Returns a prompt modifier if an action or risk is detected.
  String getBehaviorInstruction(String query) {
    if (detectActionOrRisk(query)) {
      return '\n\nACTIVATE EMOTIONALLY AWARE CURIOSITY: The user mentioned an action or risk. Apply the CURIOSITY & PRECAUTIONARY AWARENESS behavior instructions with high priority.';
    }
    return "\n\nMAINTAIN EMOTIONALLY AWARE CURIOSITY: Apply the CURIOSITY & PRECAUTIONARY AWARENESS behavior instructions if the user's intent involves any action, risk, or uncertainty.";
  }
}
