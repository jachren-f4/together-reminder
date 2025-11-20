# Poke & Remind Buttons - Home Screen Integration Spec

**Status:** Ready for Implementation
**Date:** 2025-11-17
**Mockup Reference:** `mockups/poke/18-final-with-bevel.html`

---

## Overview

Add Poke and Remind buttons directly to the home screen, positioned in the Side Quests section header for quick access to social features.

---

## Changes Required

### 1. Remove Existing UI Elements

**IMPORTANT:** The following existing UI elements must be removed:

- ❌ **Floating Action Button (FAB)** on home screen (if present)
- ❌ Any existing Poke/Remind action buttons in other locations on home screen
- ❌ Bottom action grid (if implemented from earlier designs)

**Keep these elements:**
- ✅ Inbox in bottom navigation (already handles poke viewing)
- ✅ Existing `PokeBottomSheet` for sending pokes
- ✅ Existing `PokeResponseDialog` for receiving pokes
- ✅ Existing reminder functionality

---

## Visual Specifications

### Button Container

**Location:** Side Quests section header, right side

**Layout:**
```
[Side Quests ........................... [Poke] [Remind]]
```

**Container Properties:**
- Display: `flex`
- Gap between buttons: `10px`
- Alignment: Right side of section header
- Flex shrink: `0` (prevent wrapping)

### Individual Button Styling

Each button (Poke and Remind) has identical styling:

#### Base Button
```css
padding: 8px 14px
border: 1px solid #000
background: #fff
font-size: 10px
text-transform: uppercase
letter-spacing: 0.5px
font-weight: 600
white-space: nowrap
position: relative
box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.15)
cursor: pointer
```

#### Typography
- Font family: Georgia, 'Times New Roman', serif
- Font size: `10px`
- Font weight: `600`
- Text transform: `uppercase`
- Letter spacing: `0.5px`

#### Bevel Shadow Effect
- Box shadow: `4px 4px 0 rgba(0, 0, 0, 0.15)`
- **Note:** Each button has its own independent shadow (NOT wrapped in a container)
- Shadow offset: 4px right, 4px down
- No blur (hard edge shadow)
- Matches the quest card bevel style

#### Hover State
```css
background: #000
color: #fff
transition: all 0.2s ease
```

When hovering, the dot indicator (if present) also inverts:
```css
.dot {
  background: #fff  /* inverts from black to white on hover */
}
```

### Dot Indicator (Notification State)

**Purpose:** Shows when user has unread pokes or pending reminders

**Position:** Top-right corner of button

**Styling:**
```css
position: absolute
top: -4px
right: -4px
width: 8px
height: 8px
background: #000
border-radius: 50%
border: 2px solid #fff
```

**Animation:**
```css
@keyframes pulse {
  0%, 100% {
    transform: scale(1);
    opacity: 1;
  }
  50% {
    transform: scale(1.2);
    opacity: 0.8;
  }
}
animation: pulse 2s ease-in-out infinite
```

**Visibility Logic:**
- **Poke button:** Show dot when user has unread pokes from partner
- **Remind button:** Show dot when user has pending/unread reminders
- Both dots can show simultaneously
- Dots are independent (not mutually exclusive)

---

## Layout Integration

### Section Header Structure

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // Section heading
    Text(
      'SIDE QUESTS',
      style: TextStyle(
        fontSize: 16,
        letterSpacing: 2,
        fontWeight: FontWeight.w400,
      ),
    ),

    // Button container
    Row(
      children: [
        _buildActionButton('Poke', hasUnreadPokes),
        SizedBox(width: 10),
        _buildActionButton('Remind', hasPendingReminders),
      ],
    ),
  ],
)
```

### Button Widget Structure

```dart
Widget _buildActionButton(String label, bool showIndicator) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          offset: Offset(4, 4),
          blurRadius: 0,  // Hard edge shadow
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleButtonTap(label),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              if (showIndicator)
                Positioned(
                  top: -4,
                  right: -4,
                  child: _buildDotIndicator(),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

### Dot Indicator Widget

```dart
Widget _buildDotIndicator() {
  return Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: Colors.black,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: _buildPulseAnimation(),
  );
}

Widget _buildPulseAnimation() {
  return AnimatedBuilder(
    animation: _pulseController,
    builder: (context, child) {
      return Transform.scale(
        scale: 1.0 + (_pulseController.value * 0.2),
        child: Opacity(
          opacity: 1.0 - (_pulseController.value * 0.2),
          child: child,
        ),
      );
    },
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    ),
  );
}
```

---

## Interaction Behavior

### Button Tap Actions

**Poke Button:**
- Opens `PokeBottomSheet` (existing bottom sheet component)
- Sheet slides up from bottom of screen
- User can send a poke to partner

**Remind Button:**
- Navigate to existing reminder screen
- Opens reminder functionality

### Touch Target Size

**Current button size:**
- Padding: `8px 14px` (height: ~26px, variable width)
- With shadow: effective touch area increases by 4px on right/bottom

**Accessibility note:**
- Current touch targets may be smaller than iOS (44pt) / Android (48dp) guidelines
- Consider increasing padding if users report mis-taps
- 10px gap between buttons helps prevent accidental taps

---

## State Management

### Dot Indicator State

**Data Sources:**
- **Poke dot:** Check `PokeService` for unread pokes
- **Remind dot:** Check reminder service for pending notifications

**State Updates:**
- Listen to poke/reminder state changes via streams/listeners
- Update dot visibility reactively
- Dots should disappear when user views/dismisses the notification

**Implementation Pattern:**
```dart
StreamBuilder<bool>(
  stream: _pokeService.hasUnreadPokesStream,
  builder: (context, snapshot) {
    final hasUnreadPokes = snapshot.data ?? false;
    return _buildActionButton('Poke', hasUnreadPokes);
  },
)
```

---

## Responsive Considerations

### Small Screens (iPhone SE)
- Buttons may wrap if "Side Quests" heading is too wide
- **Future work:** Add media query to hide buttons or reduce padding on very small screens

### Landscape Mode
- Should have sufficient space with current design
- **Future work:** Test on physical devices

### Partner Name Length
- Not applicable (buttons are in Side Quests section, not partner section)

---

## Implementation Checklist

- [ ] Remove existing FAB or other poke/remind buttons from home screen
- [ ] Create `_buildActionButton()` widget method
- [ ] Create `_buildDotIndicator()` widget with pulse animation
- [ ] Add buttons to Side Quests section header
- [ ] Wire up Poke button tap handler (navigate to poke screen)
- [ ] Wire up Remind button tap handler (navigate to reminder screen)
- [ ] Implement dot indicator state management for Poke button
- [ ] Implement dot indicator state management for Remind button
- [ ] Add hover effect (for web/desktop)
- [ ] Test touch target size on physical devices
- [ ] Test with both dots showing simultaneously
- [ ] Test visual alignment with quest cards (bevel matching)
- [ ] Update user onboarding if needed (explain new button location)

---

## Visual Reference

See mockup: `mockups/poke/18-final-with-bevel.html`

**Key Visual Features:**
- Independent button shadows (not wrapped container)
- Poke on LEFT, Remind on RIGHT
- Pulsing black dot in top-right corner when active
- White background, black border, black text
- Inverted on hover (black background, white text)

---

**Last Updated:** 2025-11-17
