## 💌 TogetherRemind "Poke" MVP

### 🎯 Core Purpose
A playful, instant way for couples to send a small emotional signal — "I’m thinking of you" — without typing or scheduling. It’s the modernized, private version of Facebook’s *poke* built for two people.

---

## 🧩 Core Mechanics

### 1. **One-tap Send**
- Big primary button: **"Send Nudge"** (or customizable label).
- On tap:
  - Create a record in the backend: `interaction(type="poke")`.
  - Trigger **push notification** on partner’s device.
  - Play a **short animation** + haptic + sound locally for feedback.

### 2. **Partner Receives**
- Partner gets:
  - Push: "You’ve been nudged 💫"
  - Opening the app triggers:
    - A **visual burst animation** (e.g. heart pulse, ripple, or spark).
    - Haptic + sound feedback (heartbeat or pop).
    - Option buttons: ❤️ (send back) or 🙂 (smile response).

> Minimal copy, maximal emotional effect. Should feel immediate and alive.

### 3. **Instant Response Loop**
- If the partner taps ❤️ "Send Back":
  - Reverse notification goes to sender.
  - Short reciprocal animation plays ("You poked each other!").

> This creates a quick dopamine loop — exactly like the old poke wars but 1:1 and more affectionate.

---

## ✨ Emotional Design Cues

| Element | Description |
|----------|--------------|
| **Animation** | Lottie animation of pulse, heart pop, or sparkle burst (0.8–1.2s). |
| **Haptic** | Medium impact + 50ms delay double pulse. |
| **Sound** | Soft "bloop" or "heartbeat" — short, warm. |
| **Copy Tone** | Casual, sweet, never gamified ("You sent a nudge 💫"). |
| **Privacy** | No history required for MVP; just "sent" and "received" feedback. |

---

## 🧱 Technical Slice

**Frontend:** Flutter  
**Backend:** Supabase Realtime or simple HTTP endpoint  
**Push:** Firebase Cloud Messaging (iOS via APNs)  

```sql
table pokes {
  id uuid primary key,
  sender_id uuid,
  receiver_id uuid,
  created_at timestamp default now()
}
```

When sender taps:
1. Insert row → server triggers partner’s push notification.
2. Both clients subscribe to real-time "pokes" channel to animate immediately.

---

## 🧠 UX Flow Summary

1. **Home Screen:** "Send Nudge" button.  
2. **Tap:** Heart pulse animation → push to partner.  
3. **Partner Receives:** Notification → open app → burst animation.  
4. **Respond:** Optional "Send Back ❤️".  
5. **Both See:** Mutual confirmation animation + confetti moment.  

> End of loop in <5 seconds = high repeat engagement.

---

## 🔒 Constraints for MVP
- No text, emojis, or voice messages yet.  
- Rate limit: 1 poke every 30 seconds to prevent spam.  
- Offline: store and send when back online.  
- Use only one default animation/sound to simplify v1.

---

## ✅ MVP Success Criteria

| Metric | Target |
|--------|--------|
| Time to send poke | <1.5 s |
| Response rate | >50% respond with "❤️ Send back" |
| Subjective delight | 8/10 avg user feedback ("fun to use") |
| Daily engagement | 1+ poke per day per user |
