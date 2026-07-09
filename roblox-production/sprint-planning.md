# Sprint Planning for Roblox Development

## Sprint Framework

### Recommended Sprint Length

| Team Size | Sprint Length | Rationale |
|-----------|---------------|-----------|
| 1-3 people | 1 week | Fast iteration, quick feedback |
| 4-8 people | 2 weeks | Balance of planning and execution |
| 9+ people | 2 weeks | Coordination overhead needs structure |

### Sprint Cadence

```
Monday (Day 1)
├── Sprint Planning (1-2 hours)
├── Task breakdown
└── Begin development

Daily
├── Standup (15 min async or sync)
└── Development work

Mid-Sprint (Day 3-4)
├── Check-in on blockers
├── Adjust scope if needed
└── Playtest current build

End of Sprint (Day 5 or 10)
├── Sprint Review/Demo (30-60 min)
├── Retrospective (30 min)
└── Deploy to staging/production
```

## Task Categories

### Task Types for Roblox Projects

| Type | Label | Example |
|------|-------|---------|
| Feature | `[FEAT]` | Implement trading system |
| Bug | `[BUG]` | Fix coin duplication exploit |
| Polish | `[POLISH]` | Add screen shake on hit |
| Performance | `[PERF]` | Optimize pet rendering |
| Infrastructure | `[INFRA]` | Set up analytics pipeline |
| Art | `[ART]` | Create Zone 2 environment |
| Audio | `[AUDIO]` | Add combat SFX |
| Design | `[DESIGN]` | Balance weapon stats |
| QA | `[QA]` | Test mobile controls |

### Priority Levels

| Priority | Label | Definition | SLA |
|----------|-------|------------|-----|
| P0 | Critical | Game-breaking, exploit, data loss | Same day |
| P1 | High | Major feature blocker, significant UX issue | This sprint |
| P2 | Medium | Important but not blocking | Next sprint |
| P3 | Low | Nice to have, minor improvement | Backlog |

### Effort Estimation

**T-Shirt Sizing:**
| Size | Hours | Story Points | Example |
|------|-------|--------------|---------|
| XS | 1-2 | 1 | Fix typo, tweak value |
| S | 2-4 | 2 | Add simple UI element |
| M | 4-8 | 3 | New basic feature |
| L | 8-16 | 5 | Complex system |
| XL | 16-32 | 8 | Major new feature |
| XXL | 32+ | 13 | Epic (break down) |

**Rule:** If a task is XL or larger, break it down into smaller tasks.

## Sprint Planning Process

### 1. Backlog Grooming (Before Sprint)

**Checklist:**
- [ ] All items have clear descriptions
- [ ] Acceptance criteria defined
- [ ] Priority assigned
- [ ] Effort estimated
- [ ] Dependencies identified
- [ ] Items are ordered by priority

### 2. Sprint Goal

Every sprint needs ONE clear goal that answers: "What will be true at the end of this sprint?"

**Good Sprint Goals:**
- "Players can complete the core loop from start to first purchase"
- "Zone 2 is playable with all enemies and rewards"
- "Trading system is live and secure"

**Bad Sprint Goals:**
- "Make progress on features" (too vague)
- "Finish the game" (too big)
- "Fix bugs and add trading and new zone" (too many things)

### 3. Capacity Planning

**Calculate Team Capacity:**
```
Available Hours = Team Members × Work Days × Hours/Day × Focus Factor

Example:
3 developers × 5 days × 6 hours × 0.8 (meetings, etc.) = 72 hours

With buffer for unknowns:
Planned Work = 72 × 0.8 = ~58 hours of tasks
```

**Focus Factor Adjustments:**
| Situation | Factor |
|-----------|--------|
| Normal sprint | 0.8 |
| New team/project | 0.6 |
| Crunch (avoid) | 0.9 |
| Holidays/PTO | Subtract days |

### 4. Sprint Backlog Creation

**Selection Process:**
1. Start with sprint goal
2. Pull P0s first (non-negotiable)
3. Pull tasks that support sprint goal
4. Fill remaining capacity with P1s/P2s
5. Leave 20% buffer for unknowns

**Template:**
```markdown
## Sprint [X]: [Goal]
Duration: [Start Date] - [End Date]
Capacity: [X] hours

### Must Have (P0)
- [ ] [FEAT] Task 1 (M, 5h) @developer
- [ ] [BUG] Task 2 (S, 2h) @developer

### Should Have (P1)
- [ ] [FEAT] Task 3 (L, 12h) @developer
- [ ] [POLISH] Task 4 (S, 3h) @developer

### Nice to Have (P2)
- [ ] [PERF] Task 5 (M, 6h) @developer

### Stretch Goals
- [ ] [FEAT] Task 6 (M, 8h) @developer

Total Planned: [X] hours / [X] capacity
```

## Daily Standups

### Async Standup Template (Discord/Slack)

```markdown
**Yesterday:** [What I completed]
**Today:** [What I'm working on]
**Blockers:** [None / Describe blocker]
**Mood:** 🟢🟡🔴
```

### Standup Rules

1. **Timebox:** 15 minutes max
2. **Not a status report:** Focus on blockers
3. **Follow up offline:** Don't solve problems in standup
4. **Everyone participates:** No spectators

### Blocker Escalation

| Blocker Type | Action | Owner |
|--------------|--------|-------|
| Technical | Pair programming session | Tech lead |
| Resource | Prioritization discussion | Producer |
| External | Escalate to stakeholder | Producer |
| Knowledge | Documentation/training | Team |

## Sprint Review

### Demo Structure (30-60 min)

```
1. Sprint Goal Recap (2 min)
   - What we set out to do

2. Demo (20-40 min)
   - Show working software
   - Let stakeholders play
   - Gather feedback

3. Metrics Review (5 min)
   - Velocity (points completed)
   - Bug count
   - Blockers encountered

4. What's Next (5 min)
   - Preview next sprint
   - Discuss priority changes
```

### Demo Best Practices

- **Show, don't tell:** Let people play the build
- **Use production data:** Not test/debug builds
- **Prepare fallback:** Record video in case of crashes
- **Gather feedback:** Document stakeholder comments
- **Celebrate wins:** Acknowledge team accomplishments

## Retrospective

### Format: Start/Stop/Continue (30 min)

```
START doing:
- [What should we begin doing?]

STOP doing:
- [What isn't working?]

CONTINUE doing:
- [What's working well?]
```

### Other Retrospective Formats

**4 Ls:**
- Liked: What went well?
- Learned: What did we learn?
- Lacked: What was missing?
- Longed for: What do we wish we had?

**Sailboat:**
- Wind (pushing forward): What helped us?
- Anchor (holding back): What slowed us?
- Rocks (risks): What could hurt us?
- Island (goal): Are we heading the right direction?

### Action Items

Every retro should produce 1-3 action items:

```markdown
## Action Items
- [ ] [Action] - Owner: @name - Due: [Date]
- [ ] [Action] - Owner: @name - Due: [Date]
```

## Velocity Tracking

### Velocity Chart

Track points completed per sprint:

| Sprint | Planned | Completed | % |
|--------|---------|-----------|---|
| 1 | 20 | 15 | 75% |
| 2 | 18 | 17 | 94% |
| 3 | 18 | 19 | 106% |
| 4 | 20 | 18 | 90% |

**Average Velocity:** 17.25 points/sprint

### Using Velocity

- **Planning:** Use average velocity for sprint capacity
- **Roadmap:** Estimate feature delivery dates
- **Trends:** Watch for consistent under/over delivery

### Burndown Chart

Track remaining work through sprint:

```
Points
  20 |●
  15 |  ●───●
  10 |        ●───●
   5 |              ●───●
   0 |____________________●
     M   T   W   T   F
```

**Ideal line:** Straight diagonal from start to zero
**Actual line:** Should follow close to ideal

**Warning Signs:**
- Flat line = No progress, blocked
- Upward = Scope creep
- Late spike down = Last-minute rush

## Roblox-Specific Considerations

### Update Cadence

| Update Type | Frequency | Content |
|-------------|-----------|---------|
| Hotfix | As needed | Critical bugs, exploits |
| Minor | Weekly | Bug fixes, balance |
| Content | Bi-weekly | New content, features |
| Major | Monthly | Large features, events |

### Release Windows

**Best Times to Release:**
- Friday afternoon (US) = Weekend traffic
- Avoid Monday mornings (less support staff)
- Before holidays/events for themed content

**Bad Times to Release:**
- Late Friday = Weekend with no support
- Before long weekends
- Same day as major Roblox updates

### Testing Requirements

| Release Type | Testing Required |
|--------------|------------------|
| Hotfix | Smoke test, exploit check |
| Minor | Full regression on affected areas |
| Content | Content verification, balance check |
| Major | Full regression, load testing, mobile/console |

### Sprint Buffer for Roblox

Always reserve time for:
- **Exploit fixes:** 10% buffer
- **Platform issues:** Roblox updates can break things
- **Moderation:** Content review, appeals
- **Community:** Responding to feedback

## Templates

### Sprint Planning Document

```markdown
# Sprint [Number]: [Name]

## Meta
- **Dates:** [Start] - [End]
- **Goal:** [One sentence goal]
- **Team:** [Names]
- **Capacity:** [X] points / [X] hours

## Committed Work

### P0 - Must Ship
| Task | Type | Size | Owner | Status |
|------|------|------|-------|--------|
| [Task] | FEAT | M | @name | ⬜ |

### P1 - Should Ship
| Task | Type | Size | Owner | Status |
|------|------|------|-------|--------|
| [Task] | BUG | S | @name | ⬜ |

### P2 - Stretch
| Task | Type | Size | Owner | Status |
|------|------|------|-------|--------|
| [Task] | POLISH | S | @name | ⬜ |

## Risks
- [Risk 1]: [Mitigation]

## Dependencies
- [Dependency]: [Owner/ETA]

## Notes
- [Any other relevant information]
```

### Weekly Status Report

```markdown
# Week of [Date] - Status Report

## Summary
[2-3 sentence summary]

## Completed This Week
- ✅ [Feature/Task]
- ✅ [Feature/Task]

## In Progress
- 🔄 [Feature/Task] - [X]% complete
- 🔄 [Feature/Task] - [X]% complete

## Blocked
- 🚫 [Task] - Blocked by [reason]

## Next Week
- [ ] [Planned work]
- [ ] [Planned work]

## Metrics
| Metric | This Week | Last Week | Trend |
|--------|-----------|-----------|-------|
| DAU | [X] | [X] | ↑/↓ |
| Revenue | $[X] | $[X] | ↑/↓ |
| Bugs Fixed | [X] | [X] | - |

## Risks & Concerns
- [Any concerns to flag]
```
