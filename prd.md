# Reverb – V1 Product Requirements Document

---

## 1. Overview

Reverb is a voice-first personal memory app that captures thoughts, categorizes them automatically, and converts actionable inputs into todos and reminders.

The goal is to reduce friction between thinking and acting by turning raw thoughts into structured, usable information.

---

## 2. Core Value Proposition

“Capture thoughts instantly. Turn them into organized, actionable memory.”

---

## 3. Target Users

- students
- developers
- founders
- individuals who frequently think and forget

---

## 4. Core Features (V1 Scope)

---

### 4.1 Voice Capture

- Single-tap recording
- Fast start (<1 second)
- Works offline
- Minimal UI friction

---

### 4.2 Speech-to-Text (STT)

#### Priority Order

1. Device STT (primary, offline)
2. OpenAI Whisper (fallback, online only)

#### Behavior

- If offline → use device STT only
- If online → optionally use Whisper for better accuracy
- If Whisper fails → fallback silently to device STT
- No blocking allowed

---

### 4.3 Processing

After transcription:

- Generate:
  - Summary (1–2 lines)

Uses:

- OpenAI API (initially)

---

### 4.4 Categorization

All entries are automatically classified into:

- Thought (default)
- Todo (actionable)
- Idea (conceptual)
- Reminder (time-based)

---

#### Classification Logic (Deterministic – V1)

**Reminder triggers:**

- "remind me"
- "remind me to"
- "remind me at"
- "remind me in"

**Todo triggers:**

- "i need to"
- "i should"
- "todo"
- "don't forget to"

**Idea triggers:**

- "idea:"
- "what if"
- "i could build"
- "this might be useful"

Else → Thought

---

#### Optional AI Classification (Fallback)

Prompt:
"Classify into [thought, todo, idea, reminder]. Return only one word."

---

### 4.5 Structured Memory Feed

#### Layout

- Tab-based navigation:
  - All
  - Todos
  - Ideas
  - Thoughts

---

#### Card Content

Each entry displays:

- Summary (primary)
- Transcript preview (secondary)
- Timestamp

---

#### Additional by Type

**Todos:**

- Extracted task title
- Checkbox (mark complete)

**Reminders:**

- Scheduled time
- Notification indicator

---

### 4.6 Todo Extraction

From transcript:

Example:
“i need to fix lexy onboarding flow tomorrow”

Extract:

“Fix Lexy onboarding flow”

Store as:

- `task_title`

---

### 4.7 Reminder Handling

- Extract time using natural language parsing
- Store as `trigger_time`
- Schedule local notification

If no valid time:

- treat as Todo

---

### 4.8 Local Notifications

Use:

- flutter_local_notifications

Requirements:

- Must trigger when app is:
  - foreground
  - background
  - terminated

- Must configure:
  - Android notification channels
  - permission handling

---

### 4.9 Storage

Store locally:

- transcript
- summary
- category
- timestamp
- task_title (if applicable)
- trigger_time (if applicable)
- is_complete (for todos)

No cloud sync in V1

---

## 5. User Flow

---

### Capture Flow

User opens app
→ taps record
→ speaks
→ stops recording
→ transcription + processing
→ categorized entry saved

---

### Todo Flow

User says:
“I need to finish assignment”

→ classified as Todo
→ task extracted
→ shown in Todos tab

---

### Reminder Flow

User says:
“remind me to call mom tomorrow at 6”

→ classified as Reminder
→ time extracted
→ notification scheduled

---

## 6. Data Model

Thought:

- id
- transcript
- summary
- created_at
- type (thought | todo | idea | reminder)
- task_title (optional)
- trigger_time (optional)
- is_complete (optional)
- metadata (optional JSON)

---

## 7. Offline Behavior

- Device STT works offline
- Whisper requires internet
- No blocking when offline
- Optional future: queue for later processing

---

## 8. Constraints

- <2 taps to capture
- fast startup
- no backend required
- no authentication
- no cloud sync
- minimal UI

---

## 9. Success Criteria

- user captures thought in <10 seconds
- todos extracted correctly
- reminders trigger reliably
- user opens app daily

---

## 10. Out of Scope (V1)

- IFTTT / automation
- smart home integration
- cloud sync
- semantic search
- local AI models
- advanced task management

---

## 11. Future Scope

- semantic search (embeddings)
- cloud sync (Supabase or similar)
- cross-device usage
- automation triggers
- local AI inference
- memory graph
- local storage would exist anyways, and optional cloud sync that user can enable, convex would work. convex would give a cool realtime layer like saying "u save on phone boom sync to laptop without refresh" which is cool for normies + ppl who dont know abt convex. so this gotta be for later, the sync logic is hard to handle with fallbacks, race conditions and transaction controls
---
