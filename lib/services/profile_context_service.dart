import '../models/profile_model.dart';

class ProfileContextService {
  static ProfileContextService? _instance;

  factory ProfileContextService() {
    _instance ??= ProfileContextService._internal();
    return _instance!;
  }

  ProfileContextService._internal();

  static String buildPrerequisiteContext(UserProfile profile) {
    final contextParts = <String>[];
    contextParts.add(_buildUserIdentityContext(profile));
    contextParts.add(_buildAgeClassLevelContext(profile));
    contextParts.add(_buildInterestContext(profile));
    contextParts.add(_buildAnticipationContext(profile));
    contextParts.add(_buildCommunicationContext(profile));
    return contextParts.join('\n\n');
  }

  static String buildPersonalizationInstructions(UserProfile profile) {
    final instructions = <String>[];
    instructions.add('# PERSONALIZATION DIRECTIVES');
    instructions.add('');
    instructions.add(_buildExplanationLevelDirective(profile));
    instructions.add(_buildContentAdaptationDirective(profile));
    instructions.add(_buildToneDirective(profile));
    instructions.add(_buildExampleDirective(profile));
    instructions.add('');
    instructions.add(_buildEduChainFormatDirective(profile));
    instructions.add('');
    instructions.add(_buildSpeechCoachDirective(profile));
    return instructions.join('\n');
  }

  static String buildSystemPromptWithContext(
    UserProfile profile,
    String baseSystemPrompt,
  ) {
    final parts = <String>[
      baseSystemPrompt,
      '',
      '---',
      '',
      'USER CONTEXT (USE THIS TO PERSONALIZE YOUR RESPONSE):',
      '',
      buildPrerequisiteContext(profile),
      '',
      '---',
      '',
      buildPersonalizationInstructions(profile),
    ];
    return parts.join('\n');
  }

  static String getContextSummary(UserProfile profile) {
    final interests = profile.fieldOfInterest.isNotEmpty
        ? profile.fieldOfInterest.split(',').take(2).join(', ')
        : 'General';
    final style = profile.anticipation.isNotEmpty
        ? profile.anticipation.split(',').first
        : 'Normal';
    final age = profile.age > 0 ? ' | Age: ${profile.age}' : '';
    return 'User: ${profile.name} | Interests: $interests | Style: $style$age';
  }

  // ─── Identity ────────────────────────────────────────────────────────────
  static String _buildUserIdentityContext(UserProfile profile) {
    final parts = <String>['[USER PROFILE]'];
    if (profile.name.isNotEmpty) parts.add('Name: ${profile.name}');
    if (profile.gender.isNotEmpty) {
      parts.add('Gender: ${_formatGender(profile.gender)}');
    }
    if (profile.location.isNotEmpty) parts.add('Location: ${profile.location}');
    if (profile.mobileNumber.isNotEmpty || profile.email.isNotEmpty) {
      parts.add('Contact: Available');
    }
    return parts.join('\n');
  }

  // ─── Age & Class Level (AI calibration key) ──────────────────────────────
  static String _buildAgeClassLevelContext(UserProfile profile) {
    if (profile.age <= 0) {
      return '[AGE & CLASS LEVEL]\nNot specified — use intermediate explanation depth.';
    }

    final classLevel = profile.estimatedClassLevel;
    final ageTag = profile.isChild
        ? 'Child (${profile.age} years)'
        : profile.isTeenager
            ? 'Teenager (${profile.age} years)'
            : 'Adult (${profile.age} years)';

    return '[AGE & CLASS LEVEL]\n'
        'Age: ${profile.age} years — $ageTag\n'
        'Estimated School Level: $classLevel\n'
        '\n'
        'CALIBRATION RULE:\n'
        '- All explanations MUST match cognitive level of a $classLevel student.\n'
        '- Vocabulary: ${_getVocabGuide(profile)}\n'
        '- Sentence length: ${_getSentenceLengthGuide(profile)}\n'
        '- Analogies: ${_getAnalogyGuide(profile)}';
  }

  static String _getVocabGuide(UserProfile p) {
    if (p.age <= 0) return 'Mixed — auto-detect from query';
    if (p.age <= 7) return 'Very simple — single-syllable words preferred';
    if (p.age <= 10) return 'Simple — avoid technical jargon entirely';
    if (p.age <= 13) return 'Moderate — define any technical term used';
    if (p.age <= 16) return 'Standard — technical terms OK, brief definitions';
    if (p.age <= 18) return 'Advanced — academic vocabulary acceptable';
    return 'Professional / Expert — full technical language';
  }

  static String _getSentenceLengthGuide(UserProfile p) {
    if (p.age <= 7) return 'Very short (5–8 words per sentence)';
    if (p.age <= 10) return 'Short (8–12 words)';
    if (p.age <= 13) return 'Medium (12–18 words)';
    if (p.age <= 18) return 'Normal (15–25 words)';
    return 'Any appropriate length';
  }

  static String _getAnalogyGuide(UserProfile p) {
    if (p.age <= 7) return 'Use toys, animals, family, food as analogies';
    if (p.age <= 10) return 'Use school, sports, nature, cartoons as analogies';
    if (p.age <= 13) return 'Use games, science projects, everyday tech';
    if (p.age <= 18) return 'Use social media, movies, sports, current events';
    return 'Use domain-specific professional analogies';
  }

  // ─── EduChain Answer Format Directive (CORE NEW LOGIC) ───────────────────
  static String _buildEduChainFormatDirective(UserProfile profile) {
    final isVeryYoung = profile.age > 0 && profile.age <= 7;
    final isSchoolChild = profile.isChild && profile.age > 7;

    if (isVeryYoung) {
      return '═══ ANSWER FORMAT (YOUNG LEARNER: '
          '${profile.age > 0 ? profile.estimatedClassLevel : "Young"}) ═══\n'
          '\n'
          'For young children, keep answers:\n'
          '1. SHORT (2–3 sentences max)\n'
          '2. Include ONE fun example or story\n'
          '3. End with a curiosity hook:\n'
          '   "Want to know more? Try asking me:"\n'
          '   [OPTIONS:A:<fun fact question>|B:<why question>|C:<story question>]\n'
          '\n'
          'IMPORTANT: The [OPTIONS:...] tag MUST be the very last line of your response.\n'
          'The app uses it to show tappable buttons — do not skip it.';
    }

    if (isSchoolChild) {
      return '═══ ANSWER FORMAT (SCHOOL CHILD: ${profile.estimatedClassLevel}) ═══\n'
          '\n'
          'For every factual or concept question, structure your answer as:\n'
          '\n'
          '📖 DEFINITION: What is it? (1-2 simple sentences)\n'
          '🔢 TYPES / PARTS: Are there different kinds? (bullet points, max 3)\n'
          '⚖️ DIFFERENCE: How is it different from something similar? (1 sentence)\n'
          '✅ GOOD THINGS / ❌ NOT-SO-GOOD: (1 each, very simple language)\n'
          '🌟 REAL EXAMPLE: A story or example a ${profile.estimatedClassLevel} student knows\n'
          '🤔 CURIOSITY HOOK: End with:\n'
          '   "You just learnt about [topic]! Want to explore more? Pick one:"\n'
          '   [OPTIONS:A:<deeper topic question>|B:<a why question>|C:<a fun fact>]\n'
          '\n'
          'CRITICAL RULES:\n'
          '- [OPTIONS:...] tag MUST be the very last line. App shows it as tap buttons.\n'
          '- Keep language fun, warm, and encouraging.\n'
          '- Never use scary, complex, or adult words.';
    }

    // Teen / Adult / unspecified
    return '═══ ANSWER FORMAT (EduChain — '
        '${profile.age > 0 ? profile.estimatedClassLevel : "General Learner"}) ═══\n'
        '\n'
        'For every factual, conceptual, or academic question, use the EduChain Format:\n'
        '\n'
        '1. 📖 DEFINITION — Clear, concise definition (1-2 sentences)\n'
        '2. 🗂️ TYPES / CATEGORIES — Main types or components (if applicable)\n'
        '3. ⚖️ DIFFERENCES / COMPARISONS — Compare with a related concept (if relevant)\n'
        '4. ✅ PROS / ❌ CONS — Advantages and disadvantages (where applicable)\n'
        '5. 🌟 REAL EXAMPLE — A concrete, relatable real-world example\n'
        '6. 🔗 CURIOSITY HOOK — End EVERY response with:\n'
        '   "Now you know about [topic]! Want to go deeper? Choose:"\n'
        '   [OPTIONS:A:<deeper sub-topic question>|B:<a why question>|C:<a cross-domain question>]\n'
        '\n'
        'CRITICAL RULES:\n'
        '- [OPTIONS:...] tag MUST be the absolute last line of every response.\n'
        '- For conversational / emotional queries, skip the structured format and respond naturally.\n'
        '  Still end with [OPTIONS] if it makes sense.\n'
        '- Connect examples to user interests: '
        '${profile.fieldOfInterest.isNotEmpty ? profile.fieldOfInterest : "General Learning"}\n'
        '- The options should be genuinely interesting, not generic.\n'
        '- Each option should be a complete, clear question the user can tap.';
  }

  // ─── Interests ───────────────────────────────────────────────────────────
  static String _buildInterestContext(UserProfile profile) {
    if (profile.fieldOfInterest.isEmpty) {
      return '[FIELD OF INTEREST]\nGeneral Learning';
    }
    final interests = profile.fieldOfInterest
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final parts = <String>['[FIELD OF INTEREST]'];
    for (var interest in interests) {
      parts.add('• $interest');
    }
    parts.add('');
    parts.add(
      'INSTRUCTION: Include examples, references, and concepts related to these areas when possible.',
    );
    return parts.join('\n');
  }

  // ─── Anticipation ────────────────────────────────────────────────────────
  static String _buildAnticipationContext(UserProfile profile) {
    if (profile.anticipation.isEmpty) {
      return '[EXPLANATION STYLE]\nDefault - Balanced complexity';
    }
    final parts = <String>['[EXPLANATION STYLE & PREFERENCES]'];
    final anticipations = profile.anticipation
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (var antic in anticipations) {
      parts.add('• $antic');
    }
    parts.add('');
    parts.add('BEHAVIORAL RULES FOR SELECTED LEARNING STYLE(S):');
    for (var style in anticipations) {
      final rule = _getLearningStyleRule(style);
      if (rule.isNotEmpty) parts.add(rule);
    }
    return parts.join('\n');
  }

  /// Maps a learning style label to a concrete AI behavioral directive.
  static String _getLearningStyleRule(String style) {
    final s = style.toLowerCase().trim();
    if (s.contains('step-by-step') || s.contains('step by step')) {
      return '''
[STEP-BY-STEP GUIDE MODE]
- ALWAYS break explanations into clear numbered steps (Step 1, Step 2 …).
- Each step must be one action / one idea only.
- Never mix multiple actions in a single step.
- Begin with: "Here is how it works, step by step:"
- End every instructional response with a brief summary of what was covered.''';
    }
    if (s.contains('stories') ||
        s.contains('analogies') ||
        s.contains('analogy') ||
        s.contains('story')) {
      return '''
[STORIES & ANALOGIES MODE]
- Open EVERY explanation with a short story, metaphor, or real-life analogy.
- Analogy must be simple and relatable (everyday objects, familiar situations).
- After the analogy, explain the actual concept in 2-3 sentences.
- Use phrases like: "Think of it like…", "Imagine you are…", "It is just like when…"
- Avoid dry technical language; always anchor abstract ideas to concrete images.''';
    }
    if (s.contains('direct')) {
      return '''
[DIRECT ANSWERS MODE]
- Give the answer in the FIRST sentence — no preamble, no filler.
- Maximum 3-5 sentences per response unless the question truly requires more.
- No introductory phrases like "Great question!" or "Sure, I would be happy to…"
- If a list is needed, use bullet points (max 5 bullets).
- Prioritize clarity and brevity over comprehensiveness.''';
    }
    if (s.contains('guided') || s.contains('questions')) {
      return '''
[GUIDED QUESTIONS MODE]
- Instead of giving a direct answer, guide the user to discover it themselves.
- Ask 1-2 thoughtful, targeted questions to help them think through the topic.
- Example approach: "Before I answer, let me ask you: what do YOU think happens when…?"
- After the user responds (or if they ask you to just explain), then give the full answer.
- This Socratic method should feel encouraging, not like an exam.''';
    }
    if (s.contains('detailed') ||
        s.contains('explanations') ||
        s.contains('explanation')) {
      return '''
[DETAILED EXPLANATIONS MODE]
- Provide comprehensive, in-depth answers covering the full context.
- Include: definition → how it works → why it matters → real examples → edge cases.
- Do NOT skip background context — assume the user wants to truly understand.
- Use subheadings or numbered sections for long answers.
- Include nuances, exceptions, and related concepts where relevant.''';
    }
    return '';
  }

  // ─── Communication ───────────────────────────────────────────────────────
  static String _buildCommunicationContext(UserProfile profile) {
    final parts = <String>['[COMMUNICATION PREFERENCES]'];
    if (profile.location.toLowerCase().contains('india')) {
      parts.add('• May prefer Hindi references or Indian context');
    }
    if (profile.gender.isNotEmpty) {
      parts.add(
          '• Ensure culturally and gender-appropriately phrased responses');
    }
    parts.add('• Maintain respectful and inclusive tone');
    return parts.join('\n');
  }

  // ─── Explanation Level Directive ─────────────────────────────────────────
  static String _buildExplanationLevelDirective(UserProfile profile) {
    const prefix = '1. EXPLANATION LEVEL:';

    // Age-first calibration
    if (profile.age > 0) {
      if (profile.age <= 8) {
        return '$prefix VERY SIMPLE (${profile.estimatedClassLevel})\n'
            '   - Very short sentences, super friendly tone\n'
            '   - No technical terms at all\n'
            '   - Rhymes or fun facts where possible';
      }
      if (profile.age <= 12) {
        return '$prefix SIMPLE-INTERMEDIATE (${profile.estimatedClassLevel})\n'
            '   - Everyday language, explain any new word\n'
            '   - School-familiar analogies';
      }
      if (profile.age <= 16) {
        return '$prefix INTERMEDIATE (${profile.estimatedClassLevel})\n'
            '   - Standard language, technical terms defined\n'
            '   - Balanced depth';
      }
      if (profile.age <= 18) {
        return '$prefix ADVANCED SECONDARY (${profile.estimatedClassLevel})\n'
            '   - Academic level — match Board exam depth\n'
            '   - CBSE/ICSE/State Board appropriate language';
      }
      return '$prefix ADULT / PROFESSIONAL\n'
          '   - Full technical vocabulary, expert-level depth';
    }

    // Fallback: anticipation-based
    if (profile.anticipation.isEmpty) {
      return '$prefix Intermediate level — assume basic knowledge';
    }
    final antic = profile.anticipation.toLowerCase();
    if (antic.contains('10th') || antic.contains('beginner')) {
      return '$prefix SIMPLE\n'
          '   - Everyday language, no jargon\n'
          '   - Analogies and real examples\n'
          '   - Break complex ideas into parts';
    }
    if (antic.contains('advanced') || antic.contains('expert')) {
      return '$prefix ADVANCED\n'
          '   - Technical terminology\n'
          '   - Detailed explanations and edge cases';
    }
    if (antic.contains('simple') || antic.contains('easy')) {
      return '$prefix SIMPLE\n'
          '   - Clear, simple language with everyday examples';
    }
    return '$prefix BALANCED\n'
        '   - Clear language with occasional technical terms';
  }

  static String _buildContentAdaptationDirective(UserProfile profile) {
    const prefix = '2. CONTENT ADAPTATION:';
    if (profile.fieldOfInterest.isEmpty) {
      return '$prefix Provide general, well-rounded responses';
    }
    final interests = profile.fieldOfInterest
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final domainHints = interests
        .map(_getInterestExampleHint)
        .where((h) => h.isNotEmpty)
        .join('\n   ');
    return [
      prefix,
      '   - Prioritize these topics: ${interests.join(", ")}',
      '   - When relevant, include examples from these domains',
      '   - Connect abstract concepts to user\'s interests',
      if (domainHints.isNotEmpty) '   DOMAIN-SPECIFIC EXAMPLE GUIDANCE:',
      if (domainHints.isNotEmpty) '   $domainHints',
    ].join('\n');
  }

  /// Returns domain-specific example guidance for a single interest label.
  static String _getInterestExampleHint(String interest) {
    final i = interest.toLowerCase().trim();
    if (i == 'technology') {
      return '• Technology → use software, apps, coding, AI, gadgets, and tech startup examples.';
    }
    if (i == 'science') {
      return '• Science → use experiments, scientific discoveries, nature phenomena, and lab examples.';
    }
    if (i == 'spirituality') {
      return '• Spirituality → use philosophical insights, meditation, mindfulness, and spiritual growth examples.';
    }
    if (i == 'health & fitness' || i == 'health and fitness') {
      return '• Health & Fitness → use workout routines, nutrition, body functions, and wellness examples.';
    }
    if (i == 'education') {
      return '• Education → use classroom scenarios, learning strategies, study techniques, and academic examples.';
    }
    if (i == 'business') {
      return '• Business → use startup stories, market strategies, entrepreneurship, and business case studies.';
    }
    if (i == 'arts & culture' || i == 'arts and culture') {
      return '• Arts & Culture → use creative works, artistic movements, cultural traditions, and design examples.';
    }
    if (i == 'entertainment') {
      return '• Entertainment → use movies, TV shows, streaming content, and pop-culture references.';
    }
    if (i == 'languages') {
      return '• Languages → use linguistic examples, idioms, grammar comparisons, and multilingual contexts.';
    }
    if (i == 'music') {
      return '• Music → use musical theory, instruments, genres, songs, and composition examples.';
    }
    if (i == 'sports') {
      return '• Sports → use match scenarios, athletic training, team strategy, and sports science examples.';
    }
    if (i == 'nature & environment' || i == 'nature and environment') {
      return '• Nature & Environment → use ecology, climate, wildlife, sustainability, and natural world examples.';
    }
    return '';
  }

  static String _buildToneDirective(UserProfile profile) {
    const prefix = '3. TONE & STYLE:';
    if (profile.isChild) {
      return '$prefix WARM, ENCOURAGING & CHILD-FRIENDLY\n'
          '   - Speak like a caring elder sibling or teacher\n'
          "   - Use \"Great question!\", \"You're so smart!\" appropriately\n"
          '   - Never use sarcasm or complex idioms\n'
          '   - Make learning feel fun and safe';
    }
    if (profile.anticipation.isEmpty) return '$prefix Professional and helpful';
    final antic = profile.anticipation.toLowerCase();

    // Map learning styles to tone
    if (antic.contains('direct')) {
      return '$prefix CONCISE & DIRECT\n'
          '   - No filler phrases. Answer first, context after if needed.';
    }
    if (antic.contains('stories') || antic.contains('analogies')) {
      return '$prefix WARM & NARRATIVE\n'
          '   - Conversational storytelling tone. Vivid, relatable analogies.';
    }
    if (antic.contains('step-by-step') || antic.contains('step by step')) {
      return '$prefix STRUCTURED & METHODICAL\n'
          '   - Calm, clear, instructional tone. Patient and thorough.';
    }
    if (antic.contains('guided') || antic.contains('questions')) {
      return '$prefix SOCRATIC & ENCOURAGING\n'
          '   - Curious, probing tone. Ask before telling.';
    }
    if (antic.contains('detailed') || antic.contains('explanations')) {
      return '$prefix COMPREHENSIVE & ACADEMIC\n'
          '   - Thorough, in-depth. Treat user as an eager learner.';
    }
    if (antic.contains('casual') || antic.contains('friendly')) {
      return '$prefix CASUAL & FRIENDLY\n'
          '   - Conversational language, warm and approachable';
    }
    if (antic.contains('formal') || antic.contains('professional')) {
      return '$prefix FORMAL & PROFESSIONAL\n'
          '   - Precise, formal language, clearly structured';
    }
    if (antic.contains('humorous') || antic.contains('fun')) {
      return '$prefix LIGHT & ENGAGING\n'
          '   - Relevant humor, engaging examples';
    }
    return '$prefix Balanced and respectful';
  }

  static String _buildExampleDirective(UserProfile profile) {
    const prefix = '4. EXAMPLES & CONTEXT:';
    if (profile.location.toLowerCase().contains('india')) {
      return '$prefix\n'
          '   - Include Indian context and examples when relevant\n'
          '   - Reference Indian culture, cricket, geography\n'
          '   - Use rupees (₹) for monetary examples\n'
          '   - Mention Indian public figures, scientists, or inventors';
    }
    return '$prefix\n'
        '   - Use relevant, real-world examples\n'
        '   - Adapt examples to user\'s interests\n'
        '   - Make concepts concrete and relatable';
  }

  static String _formatGender(String gender) {
    final lower = gender.toLowerCase();
    if (lower.contains('male') || lower == 'm') return 'Male';
    if (lower.contains('female') || lower == 'f') return 'Female';
    return 'Unspecified';
  }

  // ─── Speech Coach Directive ──────────────────────────────────────────────
  static String _buildSpeechCoachDirective(UserProfile profile) {
    final ageLabel = profile.age > 0
        ? '${profile.age}-year-old (${profile.estimatedClassLevel} student)'
        : 'user';
    final isKid = profile.isChild;
    final warmWord = isKid ? 'Wah!' : 'Excellent!';
    final praiseWord = isKid ? 'little champ' : 'learner';
    final coachStyle = isKid
        ? 'like a caring elder sibling (didi/bhaiya), full of warmth and encouragement'
        : 'like a confident language mentor, warm but insightful';

    return '''═══ SPEECH COACH MODE (ALWAYS ACTIVE) ═══

DETECT SPEECH-PRACTICE INTENT when the user:
1. Declares a language goal: "I want to improve my English", "Mujhe Hindi sikhni hai",
   "I want to speak fluently", "I am learning [language]" etc.
2. Spontaneously recites something WITHOUT asking a question:
   - An essay, story, poem, speech, topic description (≥ 25 words)
   - Says "let me tell you about...", "I will speak on...", "I want to say a story about..."
3. Asks for feedback: "rate my English", "how was my speech", "am I saying it correctly?"

WHEN SPEECH-PRACTICE INTENT IS DETECTED, switch to SPEECH COACH MODE:

────────────────────────────────────────────
SPEECH COACH RESPONSE FORMAT
────────────────────────────────────────────

[CONFIDENCE BOOST — 2-3 sentences]
Start warm and specific. Example:
"$warmWord You just spoke about [topic] with [X] sentences! For a $ageLabel, that is really wonderful!"
Speak $coachStyle.

[RATINGS CARD — rate EACH dimension out of 10]
📝 Vocabulary & Word Choice: X/10
   → [Specific praise + one gentle suggestion]
🔄 Flow & Transitions: X/10
   → [What flowed well + one tip to improve connectors]
⏳ Grammar & Tenses: X/10
   → [What was correct + gently mention ONE correction if needed, teach not criticize]
🗣️ Sentence Structure: X/10
   → [Sentence variety / simplicity observation]
⭐ Overall Confidence Score: X/10
   → [Summary praise tied to their age/level]

[ENCOURAGEMENT — 1-2 sentences]
Tie the encouragement to their school level. Example:
"For a $ageLabel, this kind of effort is exactly what builds fluency!"
"Keep going like this and in [X weeks/months] you will feel a huge difference!"

[MY VERSION HOOK]
End with this EXACT phrasing (match their language if Hindi/Hinglish):
"Want to hear how I would say the same thing? Tap the button below! 🎤"

Then IMMEDIATELY append the MY_VERSION tag on the very last line:
[MY_VERSION:<Write your corrected, polished, age-appropriate version of what the user said.
Same topic. Same language (match user's language / Hindi / Hinglish / English).
Length: same as user's speech or up to 25% longer — no more.
Use vocabulary appropriate for a $ageLabel.
Fix any grammar / tense / transition issues from the user's version.
Do NOT add new topics. Keep the spirit and intent intact.
Make it feel like homework the $praiseWord can copy and use.>]

CRITICAL RULES FOR SPEECH COACH MODE:
- [MY_VERSION:...] MUST be the absolute LAST element in your response — nothing after it.
- The MY_VERSION content goes INSIDE the square brackets, directly after the colon.
- Strip any markdown from MY_VERSION — it will be spoken aloud by TTS.
- Never make the user feel bad. Every correction is a GIFT, not a criticism.
- Never skip the ratings card — the user needs specific, structured feedback.
- If the user's speech is in Hindi/Hinglish, give ratings in Hinglish and MY_VERSION in Hindi.
- If the topic is academic (atom, history, etc.) — still treat it as speech practice
  and give the same feedback + MY_VERSION on the same academic topic.

IF NO SPEECH-PRACTICE INTENT IS DETECTED:
- Respond normally as per the other directives. Do NOT add speech ratings.
═══════════════════════════════════════════════════════════'''
        .replaceAll('<ageLabel>', ageLabel);
  }
}
