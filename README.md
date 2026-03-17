# moment

A macOS command-line tool that shows your calendar events and reminders for the next 7 days.

```
Sunday 15 Mar 2026
  All day  Public Holiday

Monday 16 Mar 2026
> 9:00 am  Standup [Join]
  10:00 am Team sync [Join]
  2:30 pm  Doctor appointment
  5:00 pm  Pick up kids [reminder]

Wednesday 18 Mar 2026
  All day  Jane Smith's Birthday 🎈
  11:00 am Design review [Join] [Map]

↑/↓/j/k navigate   Enter complete   d delete   n new   u undo   r redo   q quit
```

Entries are grouped by day. Events show [Join] and [Map] links where available. Reminders can be marked complete with Enter, deleted with d, added with n, and undone with u. The display updates automatically when your calendar or reminders change.

## Installation

```
brew tap notahat/moment
brew install moment --formula
```

## Usage

```
moment
```

## Development

Requires Xcode 16 or later.

```
swift build
swift test
swift run
```
