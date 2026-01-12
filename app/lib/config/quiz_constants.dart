/// Quiz-related constants shared across the app.
///
/// These constants define quiz behavior and text that needs to be
/// consistent between game screens, results screens, and API responses.

/// The text shown for the 5th "fallback" option in classic quizzes.
/// This option is always added to classic quiz questions to give users
/// an out when none of the 4 specific answers fit perfectly.
const String kClassicQuizFallbackOptionText = "It depends / Something else";

/// The index of the fallback option (0-indexed, so 4 = 5th option)
const int kClassicQuizFallbackOptionIndex = 4;
