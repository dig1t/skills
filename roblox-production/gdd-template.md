# Game Design Document Template

## Document Control

| Field | Value |
|-------|-------|
| **Game Title** | [Title] |
| **Version** | 1.0 |
| **Last Updated** | [Date] |
| **Author** | [Name] |
| **Status** | Draft / In Review / Approved |

---

## 1. Creative Overview

### 1.1 High Concept
*One paragraph that captures the essence of the game and core fantasy.*

> Example: "Welcome to the big world of [Game] on Roblox! Players drop into [setting] where they [core action]. Players collect [collectible], which [benefit]. The more [collectible] players gather, the more [progression benefit]."

### 1.2 Core Game Loop
*Describe the fundamental cycle players repeat, in plain language.*

```
[Action] → [Reward] → [Progression] → [Action]

Example:
Players collect pets → Pets perform activities to collect coins →
Coins unlock rarer pets and regions → Players collect more pets
```

### 1.3 Overview TLDR
*Bullet point summary for quick reference.*

- Players [primary action]
- [Core mechanic] allows [benefit]
- [Progression system] drives long-term engagement
- [Social/multiplayer hook]

### 1.4 Similar Games on Platform
| Game | What We Take | What's Different |
|------|--------------|------------------|
| [Game 1] | [Feature] | [Our twist] |
| [Game 2] | [Feature] | [Our twist] |

### 1.5 Similar Games Outside Roblox
[List 2-3 comparable games and why]

### 1.6 What Makes This a Standout Game
*Why will this succeed on Roblox specifically?*

### 1.7 Genre & Audience
- **Genre:** [Simulator / Tycoon / RPG / Shooter / Social / etc.]
- **Target Audience:** [Age range, e.g., 8-11]
- **Platforms:** Mobile, PC, Console (Xbox)

---

## 2. Starting Out

### 2.1 The Lobby / Starting Area
*Describe the first area players load into.*

The [Lobby Name] is the starting area players load into. It contains:
- [Key feature 1 with description]
- [Key feature 2 with description]
- [Key feature 3 with description]
- [Store/shop access]
- [Social features like leaderboards]

### 2.2 First Time User Experience (FTUE)

#### Contextual Instructions
*Step-by-step walkthrough of what new players experience.*

New players are greeted by [NPC name] who:
1. On entering FTUE, the camera [behavior]
2. "[Dialogue line 1]" - says the [NPC]
3. "[Dialogue line 2]"
4. The [reward/tutorial element] appears:
   - [Step detail]
   - [Step detail]
5. The [NPC] speaks again:
   - "[Dialogue explaining next step]"
6. The game releases the player from FTUE. The player's [reward] now [does action].

#### Contextual Tutorials
*List additional tutorial moments that appear later.*

Any FTUE elements beyond initial spawn are contextual when opening UI:
- [Screen 1] - [What is taught]
- [Screen 2] - [What is taught]
- [Screen 3] - [What is taught]

#### FTUE Discovery KPI: First Play Bounce Rate
*A discovery-relevant target the FTUE must be designed to beat.*

First Play Bounce Rate is the rate at which users leave after a short play session, and it is a NEGATIVE signal in the Roblox "Recommended For You" (RFY) ranker (it is one of the Most Important ranking signals as of 2026-06-15). It is measured at two thresholds:

| Window | Target |
|--------|--------|
| Bounce under 60 seconds | [Target %] |
| Bounce 61–180 seconds | [Target %] |

Design implication: the FTUE must hook players past the first ~3 minutes. This metric was split out from the old Qualified Play-Through Rate so first-impression quality is judged separately from deeper session quality. Pair it with Play Through Rate (PTR) — the rate users play after seeing the game in the RFY sort — which is now the headline click-quality metric (it replaced QPTR). See the Discovery & Retention KPIs section for the full ranking-signal scaffold.

### 2.3 Discovery & Retention KPIs

*Targets for the signals the Roblox "Recommended For You" (RFY) ranker measures. As of 2026-06-15 the ranker expanded its measurement window from 7 days to 28 days, reported as three separate averages: Day 1, Day 2–7, and Day 8–28. New signals surface in Creator Analytics → Acquisition → Home Recommendations.*

**Counting rule:** ALL ranking signals count ONLY users who ORGANICALLY joined from the Recommended For You sort on Home. Engagement from ads, curation, friends, search, or social feeds retrieval (getting the game *considered*) but NOT ranking — so frame these targets around organic RFY cohorts. You cannot buy rank.

#### Most Important Signals

| Signal | Target | Notes |
|--------|--------|-------|
| Play Through Rate (PTR) | [Target %] | Headline click-quality metric; rate users play after seeing the game in the RFY sort (replaced QPTR) |
| First Play Bounce Rate | [Target %] | NEGATIVE signal; measured at under 60s and 61–180s (see FTUE 2.2) |
| Play Days Per User | [Day 1] / [Day 2–7] / [Day 8–28] | Avg unique days users engage; reported across the three windows |
| Playtime Per User | [Day 1] / [Day 2–7] / [Day 8–28] | Avg time in game; capped at 60 min per user, per game, per day in the ranker |

#### Important Signals

| Signal | Target | Notes |
|--------|--------|-------|
| Intentional Co-Play Days Per User | [Day 1] / [Day 2–7] / [Day 8–28] | Avg unique days users come back to play WITH FRIENDS |
| Qualified Play Sessions Per User | [Day 1] / [Day 2–7] / [Day 8–28] | Avg qualified sessions per user who played through recommendations |
| Spend Days Per User | [Day 1] / [Day 2–7] / [Day 8–28] | Avg unique days users spend Robux |
| Robux Spent Per User | [Day 1] / [Day 2–7] / [Day 8–28] | Avg Robux spent (in-experience IAP; Rewarded Video ad revenue does NOT feed the ranker) |

*Roblox now publishes the relative importance ordering above (Most Important vs Important) but not exact numeric weights; weighting remains dynamic/personalized per user and context.*

---

## 3. Core Systems

### 3.1 [Primary System Name]

#### 3.1.1 Overview
[Description of the system]

#### 3.1.2 Mechanics
| Mechanic | Description |
|----------|-------------|
| [Mechanic 1] | [How it works] |
| [Mechanic 2] | [How it works] |

#### 3.1.3 Progression
| Level/Tier | Requirements | Unlocks |
|------------|--------------|---------|
| [Level 1] | [Requirement] | [What unlocks] |
| [Level 2] | [Requirement] | [What unlocks] |

### 3.2 [Secondary System Name]

[Repeat structure as needed]

---

## 4. Store & Economy

### 4.1 Physical Store (In-World)
*If applicable, describe the in-world store.*

The store building is located in [location]. Inside:
- When approaching an item, a GUI appears with price and purchase ability
- Items for sale include [types] for both coins and Robux
- Items refresh and rotate on [schedule]
- Speaking to [NPC] opens the full Store UI

### 4.2 User Interface Store

The store GUI is accessible anywhere from the HUD. It has tabs for:

| Tab | Contents | Currency |
|-----|----------|----------|
| [Tab 1] | [Items] | Coins / Robux |
| [Tab 2] | [Items] | Coins / Robux |
| [Tab 3] | [Items] | Coins / Robux |
| [Premium] | [Exclusive items] | Robux only |

#### Rotation Schedule
- **Hourly rotation:** [Item types]
- **Daily rotation:** [Item types]
- **Weekly rotation:** [Item types]

### 4.3 Currency System

| Currency | How Earned | How Spent | Notes |
|----------|------------|-----------|-------|
| [Coins] | Gameplay, activities | Basic items, progression | Soft currency |
| [Premium] | IAP, rare drops, achievements | Exclusive items, time-savers | Hard currency |

---

## 5. Player Customization

### 5.1 Avatar Customization
*Describe avatar customization options.*

Players can customize their avatar using items found within the game:
- **Obtainable via:** Purchase, codes, collectibles in regions
- **Types:** [List all attachment types]
  - Hats
  - Shirts
  - Pants
  - Face (masks, glasses)
  - Back (wings, packs)
  - [etc.]

#### Avatar Customization Screen
- Displays 3D view of the player avatar
- Displays 2D images of owned accessories
- Each accessory shows name and rarity
- Tabs for different accessory types
- Selecting an accessory equips it
- Closing the screen applies changes

### 5.2 [Collectible] Customization
*If players customize pets, items, shops, etc.*

[Description of customization options]

---

## 6. Regions / World Areas

### 6.1 Region Overview

Regions are unlocked by [method]. When approaching a locked region:
- If player doesn't meet requirements: [What happens]
- If player meets requirements: [What happens]

### 6.2 Region List

| Region | Theme | Unlock Requirement | Unique Content |
|--------|-------|-------------------|----------------|
| [Region 1] | [Theme] | Starting area | [Content] |
| [Region 2] | [Theme] | [Requirement] | [Content] |
| [Region 3] | [Theme] | [Requirement] | [Content] |

### 6.3 Region Features
- Regions have unique visuals
- Regions contain unique [activities/interactions]
- Regions have specific items for sale
- Regions have secret pathways
- Regions should snake (not straight lines) to prevent pop-in
- Some areas visible between regions for social discovery

---

## 7. Activities & Gameplay

### 7.1 Activity Types

| Type | Description | Reward |
|------|-------------|--------|
| **Automatic** | [Description] | [Reward type] |
| **Cooperative** | [Description] | [Reward type] |
| **Player-initiated** | [Description] | [Reward type] |

### 7.2 Activity Details

#### [Activity 1 Name]
- **How it works:** [Description]
- **Player involvement:** [Active/Passive]
- **Rewards:** [What players earn]

[Repeat for each activity type]

---

## 8. Collectibles / Core Items

### 8.1 [Collectible Name] Overview

[Collectibles] have characteristics that affect [gameplay impact]:

#### Types
| Type | Description | Rarity |
|------|-------------|--------|
| [Type 1] | [Description] | Common |
| [Type 2] | [Description] | Rare |
| [Type 3] | [Description] | Epic |
| [Type 4] | [Description] | Legendary |

#### Stats/Attributes
Each [collectible] has stats in these categories:
- **[Stat 1]:** [Effect]
- **[Stat 2]:** [Effect]
- **[Stat 3]:** [Effect]

#### Rarity Tiers
| Tier | Visual Indicator | Drop Rate | Stat Bonus |
|------|------------------|-----------|------------|
| Common | [Color/style] | 60% | 1x |
| Rare | [Color/style] | 30% | 1.5x |
| Epic | [Color/style] | 8% | 2.5x |
| Legendary | [Color/style] | 2% | 5x |

### 8.2 Collection System

#### Collection Screen
- Displays all [collectibles] discovered (owned or not)
- Shows: Name, Rarity, [other attributes]
- Tabs to filter by [category]
- Displays collection points/progress
- Selecting an item shows detailed 3D view

#### Inventory Screen
- Shows currently owned [collectibles]
- Shows equipped/active [collectibles]
- Maximum inventory size: [X] (upgradeable)
- Equip slots: [X] at start, upgradeable to [Y]

### 8.3 Fusion/Upgrade System
*If applicable*

- Players can fuse [X] of one rarity into [result]
- Fusion result is random from available pool
- Premium items cannot be fused
- [Other fusion rules]

---

## 9. HUD & User Interface

### 9.1 HUD at a Glance
*Include screenshot or mockup reference*

Note: All images are [build stage] and may not represent final UI.

### 9.2 HUD Elements in Detail

| Element | Location | Function |
|---------|----------|----------|
| [Code Bar] | [Position] | Expands on interaction, text field for codes |
| [Collection Icon] | [Position] | Shows X/Y collected, opens collection GUI |
| [Settings] | [Position] | Opens settings menu |
| [Gift Indicator] | [Position] | Shows when unclaimed rewards available |
| [Inventory] | [Position] | Opens inventory, shows "new" indicator |
| [Challenge Bar] | [Position] | Shows current challenge, progress, reward |
| [Achievements] | [Position] | Opens achievements, shows unlock indicator |

### 9.3 Key Screens

#### [Screen Name] Screen
- **Purpose:** [What this screen does]
- **Elements:**
  - [Element 1]: [Description]
  - [Element 2]: [Description]
- **Actions available:** [List of player actions]

[Repeat for each major screen]

---

## 10. Rewards & Achievements

### 10.1 Reward Screen
The Reward Screen appears when players earn something:
- Items animate in with particles and fanfare
- Different rarities have different effects/sounds
- Can display [item types]

### 10.2 [Special Reward] Screen
*E.g., Pet Pod opening, loot box, etc.*

- [Item] opens with animation sequence
- [Step 1 of animation]
- [Step 2 of animation]
- [Final reveal with attributes shown]

### 10.3 Achievements
A record of achievements and stats:
- Total [collectibles] earned and badges
- Total [currency] earned and badges
- Total [activities] completed and badges
- [Other trackable achievements]

### 10.4 Daily Login
- Displays current login day
- Shows today's reward
- Shows previous and upcoming rewards
- Consecutive logins increase rewards
- Missing a day resets streak
- Claim button triggers Reward Screen

---

## 11. Digital Code Redemption
*For licensed games with physical products*

### 11.1 Code Strategy Overview

| Principle | Details |
|-----------|---------|
| Codes are always free | No monetary value, posted to public site |
| Codes assigned by price point | Products grouped by retail price |
| One printed code per product | Redemption site generates multiple rewards |

### 11.2 Price Point Tiers

#### Tier 1: $X.99 and Under
- Products players buy frequently
- Awards: [Reward type, e.g., random common item]

#### Tier 2: Under $X.99
- Includes all Tier 1 rewards PLUS:
- Additional reward: [Accessory pack, etc.]

#### Tier 3: $X.99 and Up
- Includes all lower tier rewards PLUS:
- Premium exclusive: [Unique item pictured on package]

### 11.3 Code Types

| Code Type | Source | Rewards |
|-----------|--------|---------|
| Product codes | Physical packaging | Tiered by price point |
| Promo codes | Events, Discord, social | Variable rewards |
| Partner codes | Influencers, promotions | Exclusive items |

### 11.4 Redemption Flow
1. Player enters code in [location]
2. Code validated against database
3. Success: Reward screen shows earned items
4. Failure: "Invalid Code" message

---

## 12. Production Milestones

### 12.1 Phase Overview

| Phase | Target Date | Key Deliverables |
|-------|-------------|------------------|
| Documentation | [Date] | GDD approved, digital reward strategy |
| Priority Assets | [Date] | Assets for package design/print |
| Prototype | [Date] | Core loop playable, code redemption working |
| MVP | [Date] | Demo video, core loop testable |
| Alpha | [Date] | [X] regions, key systems working |
| Beta | [Date] | Monetization, progression, content |
| Pre-Launch | [Date] | Full launch content, content buffer |
| Code Freeze | [Date] | Bug fixes only |
| Launch | [Date] | Game live, paid UA begins |

### 12.2 Approval Gates

| Deliverable | Due Date | Approver | Status |
|-------------|----------|----------|--------|
| GDD Approval | [Date] | [Client] | Pending |
| Asset Approval | [Date] | [Client] | Pending |
| Alpha Approval | [Date] | [Client] | Pending |
| Beta Approval | [Date] | [Client] | Pending |
| Launch Approval | [Date] | [Client] | Pending |

### 12.3 Post-Launch Cadence
- **Weekly updates:** Tweaks, bug fixes, minor content
- **Major updates:** Every [X] weeks with new [content type]
- **Tied to:** [Product calendar, events, etc.]

### 12.4 Launch Discovery Model (Explore → Expand)

The RFY ranker runs **explore → expand** phases for new games, so the 28-day measurement window does NOT shut out launches:
- **Explore:** A content update can spike new users from recommendations. Even a small number of players can signal a game is worth considering.
- **Expand:** If that new cohort shows good engagement AND monetization, Roblox recommends the game to more such cohorts.

Implication for milestone planning: early-cohort quality and per-cohort retention across the 28-day window (Day 1 / Day 2–7 / Day 8–28 — see Discovery & Retention KPIs in 2.3) drive distribution growth. Plan update beats around earning and then retaining each cohort.

---

## 13. Content Deliverables

### 13.1 Deliverables Summary

| Category | Launch | Post-Launch | Total |
|----------|--------|-------------|-------|
| World Maps | [X] | [X] | [X] |
| Regions/Zones | [X] | [X] | [X] |
| [Collectibles] | [X] | [X] | [X] |
| Cosmetic Items | [X] | [X] | [X] |
| NPCs | [X] | [X] | [X] |
| Mission/Activity Types | [X] | [X] | [X] |
| UGC Items | [X] | [X] | [X] |

### 13.2 Content Schedule

| Month | Content Drop |
|-------|--------------|
| Launch | [Content list] |
| Month 1 | [Content list] |
| Month 2 | [Content list] |
| Month 3 | [Content list] |

---

## 14. Quick Q&A

*Answer common questions about the game design.*

**Q: [Common question 1]?**
A: [Clear answer]

**Q: [Common question 2]?**
A: [Clear answer]

**Q: [Common question 3]?**
A: [Clear answer]

---

## Appendices

### A. Glossary
| Term | Definition |
|------|------------|
| [Term] | [Definition] |

### B. Reference Links
- [Platform TOS/Guidelines]
- [Brand Guidelines]
- [Technical Requirements]

### C. Change Log
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | [Date] | [Name] | Initial draft |
