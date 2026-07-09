# Success Patterns: What Makes Games Win on Roblox (February 2026)

Analysis of top-performing games and the patterns that drive their success.

## The Viral Formula

### Pattern 1: The "Just One More" Loop

**Games:** Fish It! (900K CCU), Bee Swarm Simulator (165K CCU), Sol's RNG

**How it works:**
- Each action takes 5-30 seconds
- Random reward creates anticipation
- Reward leads directly to next action
- Progression is always visible

**Implementation:**
```
Action (5-30 sec) → Random Reward → Satisfaction → Next Action
         ↑                                              |
         └──────────────────────────────────────────────┘
```

**Key Metrics:**
- Average session: 30-60 minutes
- Like ratio: 90%+
- High retention

### Pattern 2: The Social Playground

**Games:** Brookhaven RP (69B visits), Adopt Me! (40B), Dress to Impress (57B)

**How it works:**
- Open-world sandbox environment
- Avatar/identity customization
- Property ownership
- Player-driven content

**Implementation:**
- Give players tools to create scenarios
- Let them express identity through customization
- Provide spaces for interaction
- Minimal rules, maximum freedom

**Key Metrics:**
- Massive concurrent players (500K-1M+)
- Long session times
- High word-of-mouth

### Pattern 3: The Meme Moment Factory

**Games:** Steal a Brainrot (20M+ peak CCU), Escape Tsunami For Brainrots (678K CCU)

**How it works:**
- Creates shareable/funny moments
- References current internet culture (TikTok memes)
- Simple to understand, chaotic to play
- Low barrier to viral clips
- Admin abuse events drive insane CCU spikes

**Implementation:**
- Embrace chaos/physics comedy
- Reference trending memes quickly
- Make clips easy to capture
- Encourage ridiculous outcomes
- Schedule "admin abuse" events for massive spikes

**Key Metrics:**
- Explosive growth (20M+ CCU peaks)
- Very high visit counts (56B+)
- Lower but acceptable retention
- Short shelf life -- plan updates accordingly

### Pattern 4: The Progression Mountain

**Games:** Blox Fruits (53B visits), Anime Vanguards, The Forge (300K CCU)

**How it works:**
- Deep progression systems
- Always something to work toward
- Clear power growth
- Collection/completion drive

**Implementation:**
- Multiple progression tracks
- Visible power increases
- Rare/legendary items to chase
- Regular content additions
- Trading economy for endgame

**Key Metrics:**
- Very high session times (20-35 min)
- Strong retention
- High monetization

### Pattern 5: The Competitive Arena

**Games:** RIVALS (207K CCU, 95% likes), Blade Ball, Jujutsu Shenanigans

**How it works:**
- Skill-based gameplay
- Clear win/loss outcomes
- Ranking/ladder systems
- Spectator appeal and clip potential

**Implementation:**
- Tight, responsive controls
- Fair matchmaking
- Visible skill expression
- Replay/highlight potential
- Simple core mechanic, high skill ceiling

**Key Metrics:**
- High like ratio (94%+)
- Consistent player base
- eSports potential (Roblox Twitch Rivals $300K prize pool)

### Pattern 6: The AFK Economy (NEW - 2025)

**Games:** Grow a Garden (22.3M peak CCU, 21.2B visits), Fish It! (900K CCU)

**How it works:**
- Plant/cast/set up → Wait (AFK) → Harvest → Trade
- Passive earning while offline
- Random mutations/rare outcomes create excitement
- Trading creates community and retention
- Admin chaos events drive viral spikes

**Implementation:**
- Design for check-in play (plant, come back later)
- Random weather/mutation systems
- Robust trading UI
- Scheduled admin events for CCU spikes
- Social spaces around the idle mechanic

**Key Metrics:**
- Record-breaking CCU (22.3M, surpassed Fortnite)
- Very high visit counts
- Strong D7 retention through trading
- Admin events = massive viral moments

---

## The Home Recommendation Algorithm (Updated 2026)

**Important:** the older "QPTR is the single algorithm" framing is obsolete. Roblox's algorithm has evolved significantly through 2025–2026. This model reflects the **June 15 2026 RFY update** (28-day measurement window, PTR + First Play Bounce Rate). Use this current model when ideating. Rolled out 2026-06-15; webinar 2026-06-17 11am PST; docs https://create.roblox.com/docs/discovery; 2-min overview https://youtu.be/K7jsk3bzmvE.

**Headline change for ideators:** the RFY ranker now measures across a **28-day window** (up from 7 days), rewarding long-term retention and monetization across the first month — keeping players coming back, bringing friends, and spending over time, not just hooking the first session or first week.

### Two-stage pipeline

1. **Retrieval** — narrows millions of games to thousands. Uses signals from *all* players regardless of acquisition source (organic, ads, editorial features). Ads and curation can push your game into retrieval consideration.
2. **Ranking** — decides what each user sees on Home and in what order. Uses signals **only from players who discovered the game organically on Home**. Ad-acquired user behavior is explicitly excluded from ranking. You cannot buy your way up the ranker.

### Signals the ranker uses (multiple, dynamically weighted)

As of the June 15 2026 update, Roblox now publishes the **relative importance** ordering of signals (Most Important vs Important) to guide creators. It still does NOT publish exact numeric weights or thresholds, and **the algorithm uses dynamic per-user personalized weighting**, not a single global formula.

Retention-style signals are now measured across the **28-day window** and reported as three separate averages — **Day 1**, **Day 2–7**, and **Day 8–28** — applied to playtime, play days, qualified play sessions, intentional co-play days, spend days, and Robux spent.

**MOST IMPORTANT:**

- **Play Through Rate (PTR)** — the rate at which users play your game after seeing it in the RFY sort. The headline click-quality metric (replaces the retired QPTR).
- **First Play Bounce Rate** (NEGATIVE signal) — the rate at which users leave after a short play session, measured at **under 60s** and **61–180s**. First-impression quality is now judged separately from deeper session quality — design a strong, fast first play to keep this low.
- **Play Days Per User** — average number of unique days users engage with your game; tracked as Day 1, Day 2–7, and Day 8–28 averages.
- **Playtime Per User** — average time users spend in your game; **capped at 60 minutes per user, per game, per day**, so one player's marathon session can't dominate the signal.

**IMPORTANT:**

- **Intentional Co-Play Days Per User** — average unique days users come back to play your game WITH FRIENDS (Day 1 / Day 2–7 / Day 8–28).
- **Qualified Play Sessions Per User** — average qualified play sessions per user who clicked and played through recommendations (filters accidental clicks).
- **Spend Days Per User** — average unique days users spend Robux in your game.
- **Robux Spent Per User** — average Robux users spend (in-experience IAP only — Rewarded Video ad revenue does NOT feed the ranker).

All ranking signals count **only users who organically joined from the RFY sort on Home**.

### Critical framing for game ideation

Stop chasing absolute thresholds (e.g., "7 minutes of playtime"). Roblox itself says **5 minutes of engagement could be a bounce in a deep game or peak success in a casual one**. What matters:

- **Genre-relative outliers** — does your game underperform a signal *that's relevant to your genre*? A deep-play game with low repeat sessions is fine. A casual game with low repeat sessions is a problem.
- **Like ratio** still matters as a quality signal but is one input among many, not the algorithm.
- **Device stability and first-minute retention** still matter, but as inputs to broader signals (PTR, First Play Bounce Rate), not as direct ranking levers.

### Discovery surfaces (not just RFY)

When ideating, consider how the concept intersects with each Home sort:

- **Recommended For You (RFY)** — primary personalized ranker. Ads now blend into this sort (Mar 2026); the separate Sponsored sort is gone.
- **Standout Games** (replaced Today's Picks, Mar 2026) — *curated* by Roblox curation team for novel games (new mechanics, distinctive visuals, underrepresented genres). **Submit via the Curation team's nomination form.** As of Apr 2026, this sort primarily features **video previews** — an authentic gameplay video on the experience details page is now table stakes for Standout consideration.
- **Continue** — recently-played. Where ad-acquired users land (which is why RFY impressions drop after a successful ad — it's a graduation indicator, not failure).
- **Avatar sort** (Apr 2026) — UGC-focused, not directly relevant to game concepts.

### Optimization strategy (revised)

1. **Build for genre-relative excellence**, not absolute thresholds. The new 28-day signals surface in **Creator Analytics → Acquisition → Home Recommendations** (rolling out soon after the 2026-06-15 announcement).
2. **Design for novelty if you want curation.** Standout Games requires meaningful novelty. If your concept is a clone of a top performer, accept that you'll compete on RFY ranker signals alone.
3. **Build for deep, long-term retention, not just first session.** The 28-day window (live June 15 2026) plus a low First Play Bounce Rate and strong Day 8–28 retention reward this now — the goal is retaining each cohort across the full first month.
4. **Capture authentic gameplay video** for the experience details page — required for Standout, expanding to other sorts.
5. **Don't conflate ad-driven and organic metrics.** Ads feed retrieval, not ranking. Plan retention loops that work for *organic* players, since they're the ones whose behavior moves your rank.
6. Mobile stability still matters but is now one of many device/context inputs in the per-user dynamic weighting.
7. **New games aren't shut out by the 28-day window.** The ranker runs **explore → expand**: a content update can spike new users from recommendations (explore); if that cohort shows good engagement AND monetization, Roblox recommends the game to more such cohorts (expand). Early cohort quality drives expansion, and the 28-day window rewards retaining each cohort you earn — so even a small number of players can signal a game is worth considering.
8. **Reaffirm discovery best practices:** accurate metadata with no irrelevant keywords, no giveaway/monetary-reward bait (giveaway-implying metadata is de-prioritized), unique original imagery/naming (avoid repetitive titles/images and near-clones), and add your own spin to existing trends.

---

## Case Studies

### Case Study 1: Grow a Garden (2025 -- Record Breaker)

**Launch:** March 26, 2025
**Current Stats:** 21.2B visits, peaked at 22.3M CCU (all-time Roblox record)
**Peak Timeline:** 5M (May) → 16M (June) → 21.3M → 22.3M (August)

**Why It Worked:**
1. **AFK + Trading formula:** Plant, wait, harvest, trade. Zero skill barrier.
2. **Random mutations:** Weather events mutate crops into rare variants. Gambling psychology.
3. **Trading economy:** Rare plants become social currency. Players return to trade.
4. **Admin abuse events:** Scheduled developer chaos events drove 22.3M CCU peak.
5. **Simple concept:** Anyone can understand "grow plants" in 3 seconds.

**Lessons:**
- Idle mechanics + trading = massive engagement
- Admin events are the new marketing hack
- Surpassed Fortnite's CCU record with a plant growing game
- Simple > complex for maximum audience

### Case Study 2: Fish It! (2024-2025 -- Session King)

**Launch:** October 2024
**Current Stats:** 900K+ CCU, 3.5B visits, 59 min average session

**Why It Worked:**
1. **Satisfying loop:** Cast, wait, catch, repeat
2. **Deep collection:** Hundreds of fish + rod upgrades
3. **AFK-friendly:** Can fish while doing other things
4. **Boss battles:** Adds excitement to calm gameplay
5. **Private islands:** Social + personal space

**Lessons:**
- 59-minute average session = exceptional engagement
- AFK compatibility extends sessions massively
- Collection depth drives "just one more" retention

### Case Study 3: 99 Nights in the Forest (2025 -- Horror Innovation)

**Launch:** March 2025
**Current Stats:** 900K+ CCU, 23B visits, 91% likes

**Why It Worked:**
1. **Atmospheric horror:** Tension beats jump scares
2. **Survival crafting:** Resource gathering + campfire upgrades
3. **Escalating nights:** Each night harder than the last
4. **Social survival:** Multiplayer cooperation
5. **Zone unlocking:** Campfire upgrades unlock new areas

**Lessons:**
- Horror + survival + crafting = powerful combination
- Atmospheric design creates viral content
- 900K+ CCU proves horror isn't niche

### Case Study 4: The Forge (2025 -- Genre Fusion)

**Launch:** 2025
**Current Stats:** 300K+ CCU

**Why It Worked:**
1. **Genre fusion:** Tycoon crafting + battle arena (NEW combination)
2. **Dual gameplay:** Build phase satisfaction + combat phase excitement
3. **Seasonal events:** Regular content drops
4. **Natural monetization:** Both crafting and cosmetic purchases

**Lessons:**
- Genre fusion creates new market categories
- First movers in new fusions capture audience
- Tycoon + combat is a proven new pattern

### Case Study 5: Blade Ball (2023-2024 -- The Formula)

**Launch:** 2023
**Peak Stats:** 350K+ CCU

**Why It Worked:**
1. **One-button mechanic:** Parry at the right time. Anyone can understand.
2. **FFA elimination:** Last one standing. No teams needed.
3. **Escalating speed:** Ball gets faster each deflect. Natural tension curve.
4. **Clip factory:** Clutch parries at max speed = viral content.
5. **Deep cosmetics:** Swords, abilities, auras, trails.

**Lessons:**
- Simple mechanic + high skill ceiling = mass appeal
- Sport reimagination is a viable genre
- Spectator-friendly gameplay drives creator content
- Cosmetic-only monetization sustains goodwill

---

## Success Metrics Benchmarks (Updated Feb 2026)

### Launch Week Targets
| Metric | Poor | Average | Good | Excellent |
|--------|------|---------|------|-----------|
| Like Ratio | <70% | 70-80% | 80-90% | 90%+ |
| Avg Session | <5 min | 5-10 min | 10-20 min | 20+ min |
| D1 Retention | <10% | 10-20% | 20-30% | 30%+ |
| FTUE Completion | <40% | 40-60% | 60-80% | 80%+ |

### Month 1 Targets
| Metric | Poor | Average | Good | Excellent |
|--------|------|---------|------|-----------|
| D7 Retention | <5% | 5-10% | 10-20% | 20%+ |
| CCU Peak | <100 | 100-1K | 1K-10K | 10K+ |
| Revenue | $0 | $1-100 | $100-1K | $1K+ |
| Payer Conversion | <1% | 1-3% | 3-5% | 5%+ |

### Established Game (6+ months)
| Metric | Poor | Average | Good | Excellent |
|--------|------|---------|------|-----------|
| D30 Retention | <2% | 2-5% | 5-10% | 10%+ |
| Monthly Revenue | <$100 | $100-1K | $1K-10K | $10K+ |
| CCU/Visits Ratio | <0.01% | 0.01-0.1% | 0.1-1% | 1%+ |

### Record-Setting Benchmarks (2025-2026)
| Achievement | Game | Number |
|-------------|------|--------|
| Highest CCU ever | Grow a Garden | 22.3M |
| Highest visits (1 year) | Steal a Brainrot | 56B+ |
| Highest like ratio (top 10) | Bee Swarm Simulator | 96% |
| Longest avg session (top 10) | Pet Simulator 99 | 130 min |

---

## Anti-Patterns (What NOT to Do)

### 1. The Clone Trap
- Copying exactly without innovation
- No differentiation from original
- Players and creators call it out immediately

### 2. The Feature Creep
- Adding features before core is solid
- Bloated, confusing game that never ships
- Kill the feature, ship the core

### 3. The Pay-to-Win Death Spiral
- Aggressive monetization early
- Negative reviews tank discovery algorithm
- "Ethical monetization" is now a competitive advantage

### 4. The Update Drought
- Shipping and abandoning
- Competition fills vacuum within weeks
- LiveOps is mandatory, not optional

### 5. The Wrong Platform
- Ignoring mobile (60%+ of users)
- Building for PC-level graphics
- Not testing on low-spec devices
- Asia-Pacific = 60% of users on budget phones

### 6. The Localization Gap
- English-only in a 144M DAU global platform
- Missing Indonesia (+700% growth), LATAM (30M DAUs)
- Multilingual support = 2x session times

---

## The Update Cadence Formula

### For New Games (Months 1-3)
- **Weekly:** Bug fixes, balance tweaks
- **Bi-weekly:** New content (items, areas, characters)
- **Monthly:** Major feature additions
- **As-needed:** Admin abuse events for CCU spikes

### For Established Games (Months 4+)
- **Weekly:** Minor updates, rotating events
- **Monthly:** Content drops, seasonal items
- **Quarterly:** Major updates/seasons
- **Annually:** Anniversary celebrations

### Event Calendar
- **Holidays:** Halloween, Christmas, Easter, Valentine's, Summer
- **Platform events:** Roblox-wide events, Twitch Rivals
- **Game anniversaries:** Celebration events
- **Trend windows:** Capitalize on external trends quickly
- **Admin events:** Schedule chaos events for CCU spikes (proven at 22M+)
