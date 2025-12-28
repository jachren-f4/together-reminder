import * as fs from 'fs';
import * as path from 'path';

interface Question {
  id: string;
  category: string;
  prompt: string;
  content: string;
}

interface Quiz {
  quizId: string;
  title: string;
  description?: string;
  branch: string;
  questions: Question[];
}

// Title/description mappings based on question themes
// Titles must be ≤16 characters
const titleDescriptionMap: Record<string, Record<string, { title: string; description: string }>> = {
  lighthearted: {
    quiz_001: {
      title: "Daily Habits",
      description: "Discover who's the adventurous eater, the snooze button champion, and the social butterfly in your relationship."
    },
    quiz_002: {
      title: "Social Vibes",
      description: "Find out who lights up the room, who cries at movies, and who keeps up with the latest trends."
    },
    quiz_003: {
      title: "Home Life",
      description: "Explore your domestic dynamics—from cooking to cleaning to who controls the thermostat."
    },
    quiz_004: {
      title: "Little Things",
      description: "It's the small stuff that counts! See who remembers dates, who's always running late, and more."
    },
    quiz_005: {
      title: "Weekend Modes",
      description: "Are you the planner or the spontaneous one? Discover your weekend personalities."
    },
    quiz_006: {
      title: "Pet Peeves",
      description: "Everyone has quirks that bug their partner. Find out where you each stand!"
    },
    quiz_007: {
      title: "Food & Cravings",
      description: "From midnight snacks to favorite cuisines, explore your culinary compatibility."
    },
    quiz_008: {
      title: "Morning Person?",
      description: "Early bird or night owl? Discover your sleep and wake patterns as a couple."
    },
    quiz_009: {
      title: "Tech Habits",
      description: "Who's glued to their phone? Who forgets to charge? Explore your digital lives."
    },
    quiz_010: {
      title: "Travel Style",
      description: "Planner vs. wanderer, beach vs. mountains—discover how you'd travel together."
    },
    quiz_011: {
      title: "Comfort Zone",
      description: "Who pushes boundaries and who plays it safe? Find out your comfort levels."
    },
    quiz_012: {
      title: "Money Matters",
      description: "Saver or spender? Discover your financial personalities without the serious talk."
    },
  },
  playful: {
    quiz_001: {
      title: "Silly Side",
      description: "Who dances in public? Who laughs at their own jokes? Embrace your playful sides!"
    },
    quiz_002: {
      title: "Game Night",
      description: "Discover who's the competitive gamer and who's just there for the snacks."
    },
    quiz_003: {
      title: "Random Talents",
      description: "Uncover hidden talents and weird skills you might not know about each other."
    },
    quiz_004: {
      title: "Guilty Pleasures",
      description: "Reality TV binges? Singing in the shower? Share your secret indulgences."
    },
    quiz_005: {
      title: "Dare or Dare",
      description: "Who would do the craziest things? Test your adventurous spirits!"
    },
    quiz_006: {
      title: "Party Mode",
      description: "Find out who's the DJ, who's the dancer, and who's raiding the fridge."
    },
    quiz_007: {
      title: "Inner Child",
      description: "Embrace your childlike sides—from cartoons to candy preferences."
    },
    quiz_008: {
      title: "Hypotheticals",
      description: "Would you rather questions that reveal your quirky decision-making."
    },
    quiz_009: {
      title: "Embarrassing!",
      description: "Who's more likely to trip in public or call someone the wrong name?"
    },
    quiz_010: {
      title: "Dream Life",
      description: "Fantasy careers, dream homes, and wild aspirations—dream together!"
    },
    quiz_011: {
      title: "Superpowers",
      description: "If you had powers, who'd be the hero and who'd be the sidekick?"
    },
    quiz_012: {
      title: "Time Machine",
      description: "Past or future? Explore where you'd go if time travel were real."
    },
  },
  connection: {
    quiz_001: {
      title: "Heart to Heart",
      description: "Explore how you express feelings and connect on a deeper emotional level."
    },
    quiz_002: {
      title: "Love Language",
      description: "Discover how you each give and receive love in your relationship."
    },
    quiz_003: {
      title: "Quality Time",
      description: "How do you spend meaningful moments together? Find your connection style."
    },
    quiz_004: {
      title: "Support System",
      description: "Who's the rock? Who needs the hug? Understand your support dynamics."
    },
    quiz_005: {
      title: "Dream Together",
      description: "Explore your shared hopes, dreams, and visions for the future."
    },
    quiz_006: {
      title: "Listening Skills",
      description: "Who really hears what the other is saying? Test your attentiveness."
    },
    quiz_007: {
      title: "Appreciation",
      description: "How do you show gratitude? Discover your appreciation patterns."
    },
    quiz_008: {
      title: "Trust & Truth",
      description: "The foundation of connection—explore your trust in each other."
    },
    quiz_009: {
      title: "Intimacy",
      description: "Beyond the physical—discover your emotional intimacy styles."
    },
    quiz_010: {
      title: "Being Present",
      description: "Who's better at being in the moment? Explore your mindfulness."
    },
    quiz_011: {
      title: "Shared Joy",
      description: "What makes you both light up? Find your sources of shared happiness."
    },
    quiz_012: {
      title: "Deep Talks",
      description: "Who initiates the meaningful conversations? Explore your depth."
    },
  },
  attachment: {
    quiz_001: {
      title: "Safe Space",
      description: "Explore your security needs and how you create safety in your relationship."
    },
    quiz_002: {
      title: "Independence",
      description: "Balance between together time and alone time—find your sweet spot."
    },
    quiz_003: {
      title: "Reassurance",
      description: "Who needs more comfort? Understand your reassurance patterns."
    },
    quiz_004: {
      title: "Conflict Style",
      description: "Fight or flight? Discover how you each handle disagreements."
    },
    quiz_005: {
      title: "Boundaries",
      description: "Personal space and limits—explore your boundary styles."
    },
    quiz_006: {
      title: "Anxious Moments",
      description: "When worry creeps in, how do you each cope? Understand your patterns."
    },
    quiz_007: {
      title: "Comfort Seeking",
      description: "How do you find comfort in each other during tough times?"
    },
    quiz_008: {
      title: "Past Patterns",
      description: "How do old experiences shape your current relationship dynamics?"
    },
    quiz_009: {
      title: "Vulnerability",
      description: "Who opens up first? Explore your comfort with being vulnerable."
    },
    quiz_010: {
      title: "Jealousy",
      description: "The green-eyed monster—understand your relationship with jealousy."
    },
    quiz_011: {
      title: "Stability",
      description: "What makes your relationship feel stable? Find your anchors."
    },
    quiz_012: {
      title: "Future Fears",
      description: "Worries about tomorrow—explore how you handle uncertainty together."
    },
  },
  growth: {
    quiz_001: {
      title: "Evolution",
      description: "How have you both changed since you got together? Celebrate your growth!"
    },
    quiz_002: {
      title: "Learning Curve",
      description: "What have you learned from each other? Discover your mutual influence."
    },
    quiz_003: {
      title: "New Adventures",
      description: "Who pushes for new experiences? Explore your adventurous sides."
    },
    quiz_004: {
      title: "Goal Getters",
      description: "Personal and shared goals—discover your ambitions as a couple."
    },
    quiz_005: {
      title: "Adaptability",
      description: "Life throws curveballs. See who adapts faster to change."
    },
    quiz_006: {
      title: "Self-Growth",
      description: "Who's more focused on personal development? Explore your growth mindsets."
    },
    quiz_007: {
      title: "Breaking Habits",
      description: "Old habits die hard. See who's better at making positive changes."
    },
    quiz_008: {
      title: "Dream Chasing",
      description: "Who encourages dreams? Who makes them happen? Find your dynamic."
    },
    quiz_009: {
      title: "Feedback",
      description: "How do you give and receive constructive feedback as a couple?"
    },
    quiz_010: {
      title: "Challenges",
      description: "When life gets hard, who steps up? Explore your resilience."
    },
    quiz_011: {
      title: "Inspiration",
      description: "How do you inspire each other to be better? Discover your influence."
    },
    quiz_012: {
      title: "Future Self",
      description: "Where do you see yourselves in 5 years? Dream about your future."
    },
  },
};

function updateQuizFile(filePath: string, branch: string, quizId: string): void {
  const content = fs.readFileSync(filePath, 'utf-8');
  const quiz: Quiz = JSON.parse(content);

  const metadata = titleDescriptionMap[branch]?.[quizId];

  if (metadata) {
    quiz.title = metadata.title;
    quiz.description = metadata.description;

    // Write back with proper formatting
    fs.writeFileSync(filePath, JSON.stringify(quiz, null, 2) + '\n');
    console.log(`✓ Updated ${branch}/${quizId}: "${metadata.title}"`);
  } else {
    console.log(`⚠ No metadata for ${branch}/${quizId}`);
  }
}

function main(): void {
  const baseDir = path.join(__dirname, '../data/puzzles/you-or-me');
  const branches = ['lighthearted', 'playful', 'connection', 'attachment', 'growth'];

  let updated = 0;
  let skipped = 0;

  for (const branch of branches) {
    const branchDir = path.join(baseDir, branch);

    if (!fs.existsSync(branchDir)) {
      console.log(`Directory not found: ${branchDir}`);
      continue;
    }

    const files = fs.readdirSync(branchDir).filter(f => f.startsWith('quiz_') && f.endsWith('.json'));

    for (const file of files) {
      const quizId = file.replace('.json', '');
      const filePath = path.join(branchDir, file);

      try {
        updateQuizFile(filePath, branch, quizId);
        updated++;
      } catch (error) {
        console.error(`Error updating ${filePath}:`, error);
        skipped++;
      }
    }
  }

  console.log(`\nDone! Updated: ${updated}, Skipped: ${skipped}`);
}

main();
