#!/bin/bash

# Content Inventory Script for TogetherRemind
# Analyzes all quest content across branches and outputs markdown report

set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
APP_ASSETS="/Users/joakimachren/Desktop/togetherremind/app/assets/brands/togetherremind/data"
API_PUZZLES="/Users/joakimachren/Desktop/togetherremind/api/data/puzzles"
OUTPUT_FILE="/Users/joakimachren/Desktop/togetherremind/docs/CONTENT_INVENTORY.md"

echo -e "${BLUE}Analyzing TogetherRemind content...${NC}"

# Function to count items in JSON array
count_json_array() {
    local file="$1"
    local key="$2"
    if [[ -f "$file" ]]; then
        if [[ -n "$key" ]]; then
            jq ".$key | length" "$file" 2>/dev/null || echo "0"
        else
            jq 'length' "$file" 2>/dev/null || echo "0"
        fi
    else
        echo "0"
    fi
}

# Function to count questions in classic quiz format (flat array)
count_classic_questions() {
    local file="$1"
    if [[ -f "$file" ]]; then
        jq 'length' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to count unique categories in classic quiz
count_classic_categories() {
    local file="$1"
    if [[ -f "$file" ]]; then
        jq '[.[].category] | unique | length' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to count affirmation statements
count_affirmation_statements() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local quizzes=$(jq '.quizzes | length' "$file" 2>/dev/null || echo "0")
        # Each quiz has 5 statements
        echo $((quizzes * 5))
    else
        echo "0"
    fi
}

# Function to count affirmation quizzes
count_affirmation_quizzes() {
    local file="$1"
    if [[ -f "$file" ]]; then
        jq '.quizzes | length' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to count linked clues
count_linked_clues() {
    local file="$1"
    if [[ -f "$file" ]]; then
        jq '.clues | length' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to count word search words
count_wordsearch_words() {
    local file="$1"
    if [[ -f "$file" ]]; then
        jq '.words | length' "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Start building markdown output
cat > "$OUTPUT_FILE" << 'EOF'
# TogetherRemind Content Inventory

> Auto-generated report of all quest content across branches.
> Run `./scripts/content_inventory.sh` to regenerate.

EOF

echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# ============================================
# CLASSIC QUIZ
# ============================================
echo -e "${GREEN}Analyzing Classic Quiz...${NC}"

cat >> "$OUTPUT_FILE" << 'EOF'

---

## Classic Quiz

Multiple choice questions organized by category and branch.

| Branch | Questions | Categories | File |
|--------|-----------|------------|------|
EOF

CLASSIC_TOTAL=0
for branch in lighthearted deeper spicy; do
    file="$APP_ASSETS/classic-quiz/$branch/questions.json"
    if [[ -f "$file" ]]; then
        questions=$(count_classic_questions "$file")
        categories=$(count_classic_categories "$file")
        echo "| $branch | $questions | $categories | \`data/classic-quiz/$branch/questions.json\` |" >> "$OUTPUT_FILE"
        CLASSIC_TOTAL=$((CLASSIC_TOTAL + questions))
    else
        echo "| $branch | 0 | 0 | *(missing)* |" >> "$OUTPUT_FILE"
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "**Total Classic Quiz Questions: $CLASSIC_TOTAL**" >> "$OUTPUT_FILE"

# ============================================
# AFFIRMATION
# ============================================
echo -e "${GREEN}Analyzing Affirmation...${NC}"

cat >> "$OUTPUT_FILE" << 'EOF'

---

## Affirmation

5-point Likert scale quizzes with 5 statements each.

| Branch | Quizzes | Statements | File |
|--------|---------|------------|------|
EOF

AFFIRMATION_QUIZZES=0
AFFIRMATION_STATEMENTS=0
for branch in emotional practical spiritual; do
    file="$APP_ASSETS/affirmation/$branch/quizzes.json"
    if [[ -f "$file" ]]; then
        quizzes=$(count_affirmation_quizzes "$file")
        statements=$(count_affirmation_statements "$file")
        echo "| $branch | $quizzes | $statements | \`data/affirmation/$branch/quizzes.json\` |" >> "$OUTPUT_FILE"
        AFFIRMATION_QUIZZES=$((AFFIRMATION_QUIZZES + quizzes))
        AFFIRMATION_STATEMENTS=$((AFFIRMATION_STATEMENTS + statements))
    else
        echo "| $branch | 0 | 0 | *(missing)* |" >> "$OUTPUT_FILE"
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "**Total Affirmation: $AFFIRMATION_QUIZZES quizzes, $AFFIRMATION_STATEMENTS statements**" >> "$OUTPUT_FILE"

# ============================================
# YOU OR ME
# ============================================
echo -e "${GREEN}Analyzing You or Me...${NC}"

cat >> "$OUTPUT_FILE" << 'EOF'

---

## You or Me

"Who's more likely to..." binary choice questions.

| Branch | Questions | File |
|--------|-----------|------|
EOF

YOUORME_TOTAL=0
for branch in playful reflective intimate; do
    file="$APP_ASSETS/you-or-me/$branch/questions.json"
    if [[ -f "$file" ]]; then
        questions=$(jq '.questions | length' "$file" 2>/dev/null || echo "0")
        echo "| $branch | $questions | \`data/you-or-me/$branch/questions.json\` |" >> "$OUTPUT_FILE"
        YOUORME_TOTAL=$((YOUORME_TOTAL + questions))
    else
        echo "| $branch | 0 | *(missing)* |" >> "$OUTPUT_FILE"
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "**Total You or Me Questions: $YOUORME_TOTAL**" >> "$OUTPUT_FILE"

# ============================================
# LINKED (API)
# ============================================
echo -e "${GREEN}Analyzing Linked Puzzles...${NC}"

cat >> "$OUTPUT_FILE" << 'EOF'

---

## Linked (Crossword Puzzles)

Server-delivered puzzles from API. Clues include text and emoji hints.

| Puzzle ID | Title | Grid | Clues | File |
|-----------|-------|------|-------|------|
EOF

LINKED_PUZZLES=0
LINKED_CLUES=0

# Check branch paths
for branch in casual romantic adult; do
    branch_dir="$API_PUZZLES/linked/$branch"
    if [[ -d "$branch_dir" ]]; then
        for puzzle_file in "$branch_dir"/*.json; do
            if [[ -f "$puzzle_file" ]] && [[ "$(basename "$puzzle_file")" != "manifest.json" ]] && [[ "$(basename "$puzzle_file")" != "puzzle-order.json" ]]; then
                puzzle_id=$(basename "$puzzle_file" .json)
                title=$(jq -r '.title // "Untitled"' "$puzzle_file" 2>/dev/null)
                rows=$(jq '.size.rows // .rows // "?"' "$puzzle_file" 2>/dev/null)
                cols=$(jq '.size.cols // .cols // "?"' "$puzzle_file" 2>/dev/null)
                clues=$(count_linked_clues "$puzzle_file")
                echo "| $puzzle_id | $title | ${rows}×${cols} | $clues | \`api/data/puzzles/linked/$branch/$puzzle_id.json\` |" >> "$OUTPUT_FILE"
                LINKED_PUZZLES=$((LINKED_PUZZLES + 1))
                LINKED_CLUES=$((LINKED_CLUES + clues))
            fi
        done
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "**Total Linked: $LINKED_PUZZLES puzzles, $LINKED_CLUES clues**" >> "$OUTPUT_FILE"

# Branch status
echo "" >> "$OUTPUT_FILE"
echo "### Branch Status" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Branch | Puzzles |" >> "$OUTPUT_FILE"
echo "|--------|---------|" >> "$OUTPUT_FILE"
for branch in casual romantic adult; do
    branch_dir="$API_PUZZLES/linked/$branch"
    if [[ -d "$branch_dir" ]]; then
        count=$(find "$branch_dir" -name "*.json" ! -name "manifest.json" ! -name "puzzle-order.json" 2>/dev/null | wc -l | tr -d ' ')
        echo "| $branch | $count |" >> "$OUTPUT_FILE"
    else
        echo "| $branch | *(no directory)* |" >> "$OUTPUT_FILE"
    fi
done

# ============================================
# WORD SEARCH (API)
# ============================================
echo -e "${GREEN}Analyzing Word Search Puzzles...${NC}"

cat >> "$OUTPUT_FILE" << 'EOF'

---

## Word Search

Server-delivered word grid puzzles from API.

| Puzzle ID | Title | Grid | Words | File |
|-----------|-------|------|-------|------|
EOF

WORDSEARCH_PUZZLES=0
WORDSEARCH_WORDS=0

# Check branch paths
for branch in everyday passionate naughty; do
    branch_dir="$API_PUZZLES/word-search/$branch"
    if [[ -d "$branch_dir" ]]; then
        for puzzle_file in "$branch_dir"/*.json; do
            if [[ -f "$puzzle_file" ]] && [[ "$(basename "$puzzle_file")" != "manifest.json" ]] && [[ "$(basename "$puzzle_file")" != "puzzle-order.json" ]]; then
                puzzle_id=$(basename "$puzzle_file" .json)
                title=$(jq -r '.title // "Untitled"' "$puzzle_file" 2>/dev/null)
                grid_size=$(jq -r '.gridSize // 10' "$puzzle_file" 2>/dev/null)
                words=$(count_wordsearch_words "$puzzle_file")
                echo "| $puzzle_id | $title | ${grid_size}×${grid_size} | $words | \`api/data/puzzles/word-search/$branch/$puzzle_id.json\` |" >> "$OUTPUT_FILE"
                WORDSEARCH_PUZZLES=$((WORDSEARCH_PUZZLES + 1))
                WORDSEARCH_WORDS=$((WORDSEARCH_WORDS + words))
            fi
        done
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "**Total Word Search: $WORDSEARCH_PUZZLES puzzles, $WORDSEARCH_WORDS words**" >> "$OUTPUT_FILE"

# Branch status
echo "" >> "$OUTPUT_FILE"
echo "### Branch Status" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Branch | Puzzles |" >> "$OUTPUT_FILE"
echo "|--------|---------|" >> "$OUTPUT_FILE"
for branch in everyday passionate naughty; do
    branch_dir="$API_PUZZLES/word-search/$branch"
    if [[ -d "$branch_dir" ]]; then
        count=$(find "$branch_dir" -name "*.json" ! -name "manifest.json" ! -name "puzzle-order.json" 2>/dev/null | wc -l | tr -d ' ')
        echo "| $branch | $count |" >> "$OUTPUT_FILE"
    else
        echo "| $branch | *(no directory)* |" >> "$OUTPUT_FILE"
    fi
done

# ============================================
# SUMMARY
# ============================================
echo -e "${GREEN}Generating summary...${NC}"

cat >> "$OUTPUT_FILE" << EOF

---

## Summary

### Daily Quests (App Assets)

| Activity | Branches | Total Items | Format |
|----------|----------|-------------|--------|
| Classic Quiz | 3 | $CLASSIC_TOTAL questions | Multiple choice |
| Affirmation | 3 | $AFFIRMATION_STATEMENTS statements | 5-point scale |
| You or Me | 3 | $YOUORME_TOTAL questions | Binary choice |

**Total Static Content: $((CLASSIC_TOTAL + AFFIRMATION_STATEMENTS + YOUORME_TOTAL)) items**

### Side Quests (API Puzzles)

| Activity | Puzzles | Total Items | Format |
|----------|---------|-------------|--------|
| Linked | $LINKED_PUZZLES | $LINKED_CLUES clues | Crossword grid |
| Word Search | $WORDSEARCH_PUZZLES | $WORDSEARCH_WORDS words | Word grid |

**Total API Content: $((LINKED_PUZZLES + WORDSEARCH_PUZZLES)) puzzles**

### Content Runway (at 1 quest/day per type)

| Activity | Unique Days | Notes |
|----------|-------------|-------|
| Classic Quiz | ~$((CLASSIC_TOTAL / 10)) days | Cycles through branches |
| Affirmation | ~$((AFFIRMATION_QUIZZES)) days | 1 quiz = 5 statements |
| You or Me | ~$((YOUORME_TOTAL / 10)) days | Cycles through branches |
| Linked | ~$LINKED_PUZZLES days | Sequential progression |
| Word Search | ~$WORDSEARCH_PUZZLES days | Sequential progression |

---

*Report generated by \`scripts/content_inventory.sh\`*
EOF

echo ""
echo -e "${GREEN}✅ Content inventory complete!${NC}"
echo -e "   Output: ${BLUE}$OUTPUT_FILE${NC}"
echo ""
echo "=== Quick Summary ==="
echo "Classic Quiz:  $CLASSIC_TOTAL questions"
echo "Affirmation:   $AFFIRMATION_STATEMENTS statements ($AFFIRMATION_QUIZZES quizzes)"
echo "You or Me:     $YOUORME_TOTAL questions"
echo "Linked:        $LINKED_CLUES clues ($LINKED_PUZZLES puzzles)"
echo "Word Search:   $WORDSEARCH_WORDS words ($WORDSEARCH_PUZZLES puzzles)"
echo "===================="
