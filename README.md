# RankWatch

A WoW TBC Classic addon that highlights action bar buttons when they contain a lower rank spell than what you've learned.

![Interface: 20504](https://img.shields.io/badge/Interface-20504-blue) ![TBC Classic](https://img.shields.io/badge/TBC-Classic-yellow)

## Why?

You just trained a new rank of Frostbolt. You drag it to your bar... or did you? Maybe you grabbed Rank 1 by mistake. Maybe you forgot to update your bars after visiting the trainer. RankWatch puts an orange border around any spell that isn't your highest learned rank.

## Installation

1. Download and extract to `World of Warcraft/_anniversary_/Interface/AddOns/RankWatch`
2. Restart WoW or `/reload`

## Usage

The addon works automatically. Any action button with a lower-rank spell gets an orange border.

### Commands

| Command | Description |
|---------|-------------|
| `/rw` | Force rescan of spellbook and action bars |
| `/rw list` | Print all outdated spells to chat |
| `/rw ignore <spell>` | Ignore a spell (for intentional downranking) |
| `/rw unignore <spell>` | Stop ignoring a spell |
| `/rw ignored` | Show ignored spells |

### Examples

```
/rw list
```
```
RankWatch: Holy Light is Rank 1 (max is Rank 4)
RankWatch: Found 1 outdated spell(s) on your action bars.
```

```
/rw ignore Healing Touch
```
Healers often downrank for mana efficiency. This tells RankWatch to stop warning you about that spell.

```
/rw unignore Healing Touch
```
Changed your mind? Start warning again.

## What it detects

- All spell ranks on all action bars (main bar, bottom bars, side bars, stance bars)
- Updates automatically when you learn new spells or change your bars

## What it ignores

- Macros (can't reliably detect the spell)
- Items, mounts, professions
- Spells without ranks

## Downranking

TBC healers frequently use lower rank heals for mana efficiency. Use `/rw ignore <spell>` to whitelist these. Your preferences are saved between sessions.

## Supported bars

- Main Action Bar
- Bottom Left/Right Bars
- Right Side Bars 1 & 2
- Stance/Form/Stealth bars (Warrior, Druid, Rogue)

## Troubleshooting

**Border not showing?**
Try `/rw` to force a rescan.

**Wrong spell flagged?**
Use `/rw list` to see exactly what's detected. If you're intentionally downranking, use `/rw ignore`.
