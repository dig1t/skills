# Roblox Release Checklists

## Pre-Release Checklist (1-2 Days Before)

### Code Quality
- [ ] All features code-reviewed
- [ ] No `print()` or debug statements in production code
- [ ] All Luau files pass type checking (strict mode is enabled repo-wide via `.luaurc`)
- [ ] Selene linting passes with no errors
- [ ] No known exploits or security vulnerabilities
- [ ] Error handling in place for all RemoteEvents

### Testing
- [ ] Full playthrough completed on PC
- [ ] Full playthrough completed on Mobile
- [ ] Full playthrough completed on Console (Xbox)
- [ ] New features tested with multiple players
- [ ] Edge cases and error states tested
- [ ] Load tested with expected player count
- [ ] Data migration tested (if schema changed)

### Performance
- [ ] MicroProfiler shows no spikes >16ms
- [ ] Memory stable over 30 min session
- [ ] Part count within limits
- [ ] Network traffic within limits
- [ ] StreamingEnabled configured correctly

### Data & Analytics
- [ ] DataStore schema changes are backwards compatible
- [ ] Data migration script ready (if needed)
- [ ] Analytics events firing correctly
- [ ] Dashboards configured for new metrics

### Content
- [ ] All assets uploaded and IDs updated
- [ ] Placeholder content replaced
- [ ] Thumbnails and icons updated
- [ ] Game description updated
- [ ] Social links verified

### First Play Experience (first 60-180s)
First Play Bounce Rate is a Most-Important (negative) RFY ranking signal, measured at under 60s and 61-180s. A weak first 3 minutes hurts Home distribution.
- [ ] Fast load-in / no long initial hang
- [ ] Clear immediate goal or onboarding in the first minute
- [ ] No early dead time before players can act
- [ ] First-session flow checked at both the <60s and 61-180s marks for drop-off

### Discovery Hygiene
Roblox de-prioritizes low-quality metadata in recommendations.
- [ ] Accurate metadata, no irrelevant keywords
- [ ] Original imagery and naming (no repetitive titles or near-clones)
- [ ] No giveaway-/reward-bait phrasing in title, description, or thumbnails

### Monetization
- [ ] GamePass IDs correct for production
- [ ] DevProduct IDs correct for production
- [ ] Prices verified
- [ ] ProcessReceipt handler tested
- [ ] Premium benefits working

### Security
- [ ] All RemoteEvents validate input
- [ ] Rate limiting in place
- [ ] No sensitive data exposed to client
- [ ] Admin commands secured
- [ ] Anti-cheat systems active

---

## Release Day Checklist

### Pre-Deployment (2 hours before)

- [ ] Team aware of release timing
- [ ] Support channels staffed
- [ ] Rollback plan documented
- [ ] Previous stable version noted: `v[X.X.X]`
- [ ] Maintenance notice posted (if needed)

### Deployment

- [ ] Build production version
  ```bash
  rojo build deploy.project.json -o game.rbxl
  ```
- [ ] Publish to Roblox
- [ ] Verify game loads correctly
- [ ] Quick smoke test on all platforms
- [ ] Verify DataStore operations working
- [ ] Check analytics events flowing

### Post-Deployment (First 30 min)

- [ ] Monitor error logs
- [ ] Monitor player count
- [ ] Check social media/Discord for reports
- [ ] Verify monetization working (test purchase)
- [ ] Confirm no exploit reports

### Post-Deployment (First 2 hours)

- [ ] Review crash reports
- [ ] Check retention metrics (Day 1 of the RFY 28-day window)
- [ ] Read PTR and First Play Bounce Rate as the headline click / first-impression metrics
- [ ] Monitor CCU trends
- [ ] Address any critical bugs
- [ ] Gather initial player feedback

---

## Rollback Procedure

### When to Rollback

**Immediate Rollback (within 15 min):**
- Data loss or corruption
- Widespread crashes
- Critical exploit discovered
- Major feature completely broken

**Consider Rollback (within 1 hour):**
- Significant performance degradation
- Major UX issues affecting most players
- Monetization not working

**Hot-fix Instead:**
- Isolated bugs
- Minor issues
- Non-critical exploits (can disable feature)

### Rollback Steps

1. **Confirm decision** with team lead/stakeholders
2. **Announce** in Discord/social if significant
3. **Publish previous version:**
   - Open Roblox Studio
   - File → Open from Roblox → Version History
   - Select last stable version
   - Publish
4. **Verify** rollback successful
5. **Communicate** to players
6. **Post-mortem** scheduled within 24 hours

### Rollback Message Template

```
🔧 Temporary Rollback

We've temporarily rolled back to the previous version while we fix an issue with [brief description].

Your progress is safe!

We expect to re-release within [timeframe].

Thank you for your patience!
```

---

## Post-Release Checklist (Day 1)

### Monitoring
- [ ] Check error rates vs baseline
- [ ] Review Day 1 retention (first period of the RFY 28-day window)
- [ ] Check average session length
- [ ] Review revenue vs projections
- [ ] Monitor CCU peaks
- [ ] Check new signals in Creator Analytics → Acquisition → Home Recommendations (PTR, First Play Bounce Rate, retention/spend by window)

### Community
- [ ] Respond to bug reports
- [ ] Acknowledge feedback
- [ ] Update known issues list
- [ ] Thank community for support

### Documentation
- [ ] Update version number
- [ ] Document known issues
- [ ] Record release metrics
- [ ] Note lessons learned

---

## Post-Release Checklist (Week 1)

### Metrics Review

The RFY ranker measures retention-style signals across a 28-day window, reported as three periods: Day 1, Day 2-7, and Day 8-28. Track each signal across all three to mirror how Home/RFY evaluates the launch. Note Playtime Per User is capped at 60 minutes per user/game/day in the ranker — aim for several solid retained sessions across the month, not one-off marathon sessions.

| Metric | Day 1 | Day 2-7 | Day 8-28 | Status |
|--------|-------|---------|----------|--------|
| Playtime Per User | [X] min | [X] min | [X] min | ✅/❌ |
| Play Days Per User | [X] | [X] | [X] | ✅/❌ |
| Qualified Play Sessions Per User | [X] | [X] | [X] | ✅/❌ |
| Intentional Co-Play Days Per User | [X] | [X] | [X] | ✅/❌ |
| Spend Days Per User | [X] | [X] | [X] | ✅/❌ |
| Robux Spent Per User | [X] | [X] | [X] | ✅/❌ |

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Revenue | $[X] | $[X] | ✅/❌ |
| ARPDAU | $[X] | $[X] | ✅/❌ |

### Bug Triage
- [ ] All P0 bugs fixed
- [ ] P1 bugs prioritized for next sprint
- [ ] Bug trends analyzed

### Balance Review
- [ ] Economy metrics reviewed
- [ ] Progression pacing checked
- [ ] Player feedback on difficulty
- [ ] Hotfix balance changes if needed

### Retrospective
- [ ] What went well?
- [ ] What could improve?
- [ ] Action items for next release

---

## Major Update Checklist (Additional Items)

### Communication (2 weeks before)
- [ ] Announcement post drafted
- [ ] Teaser content created
- [ ] Influencer/creator outreach
- [ ] Social media posts scheduled

### Communication (1 week before)
- [ ] Trailer/video ready
- [ ] Detailed patch notes written
- [ ] FAQ prepared
- [ ] Support team briefed

### Communication (Day of)
- [ ] Announcement posted
- [ ] Social media blitz
- [ ] Patch notes published
- [ ] Discord announcement

### Marketing (First week)
- [ ] Sponsored ads running
- [ ] Influencer content going live
- [ ] Community events active
- [ ] Giveaways/promotions running

> RFY ranking counts ONLY users who organically joined from the Recommended For You sort on Home. Engagement/spend from ads, friends, search, curation, or social feeds retrieval (gets the game *considered*) but does NOT count toward rank. Paid/influencer pushes drive consideration; they cannot buy ranking.

### Discovery (RFY explore → expand)
A content update can spike new users from recommendations (explore); if that cohort shows good engagement AND monetization, Roblox expands distribution to more similar cohorts (expand).
- [ ] Update timed and instrumented to retain each new cohort, not just spike day-one CCU
- [ ] Day 1 / Day 2-7 / Day 8-28 cohort quality monitored (see RFY 28-day window)

---

## Event/Seasonal Update Checklist

### Planning (4+ weeks before)
- [ ] Event concept approved
- [ ] Content scope defined
- [ ] Art/audio requirements listed
- [ ] Monetization opportunities identified
- [ ] Start/end dates locked

### Development (2-4 weeks before)
- [ ] Event features implemented
- [ ] Event content created
- [ ] Limited-time items priced
- [ ] Event analytics added

### Pre-Launch (1 week before)
- [ ] Event tested end-to-end
- [ ] Timers verified (time zones!)
- [ ] Announcement content ready
- [ ] Emergency disable switches in place

### During Event
- [ ] Daily metrics monitoring
- [ ] Player feedback collection
- [ ] Hotfix issues immediately
- [ ] Social media engagement
- [ ] Watch the RFY explore → expand effect: seasonal content can spike new cohorts (explore); retain them well across Day 1 / Day 2-7 / Day 8-28 so Roblox expands distribution to more similar cohorts

### Event End
- [ ] Event disabled on time
- [ ] Exclusive items properly locked
- [ ] Post-event analytics reviewed
- [ ] Learnings documented

---

## Hotfix Checklist

### Assessment
- [ ] Issue severity confirmed (P0 = hotfix worthy)
- [ ] Root cause identified
- [ ] Fix verified in development
- [ ] Regression risk assessed

### Fast-Track Testing
- [ ] Fix tested on target platform
- [ ] Related features smoke tested
- [ ] No new issues introduced
- [ ] Data integrity verified

### Deployment
- [ ] Hotfix deployed
- [ ] Issue confirmed resolved
- [ ] Community informed (if public issue)
- [ ] Incident documented

---

## Version Numbering

### Semantic Versioning for Roblox

```
MAJOR.MINOR.PATCH

Examples:
1.0.0 - Initial launch
1.0.1 - Bug fix
1.1.0 - New content update
1.2.0 - Feature update
2.0.0 - Major overhaul/rebrand
```

### Version Management

**In Code:**
```lua
-- Shared/Config/Version.luau
return {
    major = 1,
    minor = 2,
    patch = 3,
    display = "1.2.3",
}
```

**In Game:**
- Show version in settings menu
- Log version on player join
- Include in bug reports

---

## Incident Response

### Severity Levels

| Level | Definition | Response Time | Examples |
|-------|------------|---------------|----------|
| SEV-1 | Game unplayable | Immediate | Crashes, data loss |
| SEV-2 | Major feature broken | <1 hour | Shop broken, exploits |
| SEV-3 | Significant issue | <4 hours | UI bugs, balance issues |
| SEV-4 | Minor issue | Next sprint | Typos, minor visual bugs |

### Incident Template

```markdown
# Incident: [Brief Description]

## Status: 🔴 Active / 🟡 Monitoring / 🟢 Resolved

## Timeline
- [Time] - Issue reported
- [Time] - Investigation started
- [Time] - Root cause identified
- [Time] - Fix deployed
- [Time] - Issue resolved

## Impact
- Affected players: [Estimate]
- Duration: [Time]
- Data loss: Yes/No

## Root Cause
[Description of what went wrong]

## Resolution
[What was done to fix it]

## Prevention
[What will prevent this in the future]

## Action Items
- [ ] [Action] - @owner
```

---

## Communication Templates

### Update Announcement
```
🎉 [Update Name] is LIVE!

[2-3 sentence summary of what's new]

✨ New Features:
• [Feature 1]
• [Feature 2]

🐛 Bug Fixes:
• [Fix 1]
• [Fix 2]

Full patch notes: [link]

Thank you for playing! ❤️
```

### Known Issues
```
⚠️ Known Issues

We're aware of the following issues and working on fixes:

• [Issue 1] - [Status/ETA]
• [Issue 2] - [Status/ETA]

Workarounds:
• [Issue 1]: [Workaround if any]

We'll update this list as issues are resolved.
```

### Maintenance Notice
```
🔧 Scheduled Maintenance

[Game Name] will be offline for maintenance:
📅 [Date]
🕐 [Time] - [Time] ([Timezone])

What to expect:
• [What's being done]
• Estimated downtime: [Duration]

Your progress is safe!
```

---

## Discovery Reference

RFY (Recommended For You) signal guidance in this checklist reflects the algorithm update rolled out 2026-06-15, which expanded the ranking measurement window from 7 days to 28 days (reported as Day 1 / Day 2-7 / Day 8-28) and replaced QPTR with Play Through Rate (PTR) + First Play Bounce Rate as the headline metrics.

- Webinar: 2026-06-17 11am PST
- Docs: https://create.roblox.com/docs/discovery
- Overview video: https://youtu.be/K7jsk3bzmvE
