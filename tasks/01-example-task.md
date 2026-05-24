# 01 — Example task

**Status:** Todo

**Priorita:** v1.0 · **Úsilí:** S · **Dopad:** Low (example)

## Cíl

Tento soubor je příklad / template pro budoucí task. Smaž ho nebo přepiš, jakmile budeš psát první reálný task. Reálný task má konkrétní user-visible feature s jasným „hotovo když" kritériem a buildovatelným artefaktem.

## Kontext

- Struktura task souboru je popsaná v [`tasks/README.md`](README.md).
- Claude command `/task <číslo>` použije tento soubor jako vstup, založí feature branch, implementuje, spustí Codex review na staged diff a označí task jako Done.
- Po dokončení Claude přidá `**Status:** Done — YYYY-MM-DD` na začátek souboru.
- Konvence repozitáře (MVVM, protocol-first, `@Observable`, DI přes `AppDependency`, mocky v `Testing/`, snapshot testy přes `AssertSnapshot`) jsou popsané v `CLAUDE.md`.

## Scope

### 1. Konkrétní akční bod

Každá sub-section by měla být buildable krok — soubor, který se vytvoří, funkce, která se přidá, test, který se napíše.

### 2. Testy

Vyjmenuj konkrétní testy. Unit (KeyboardCore-style) nebo snapshot (KeyboardUI-style). Co se assertuje, jaké edge cases.

### 3. Lokalizace

Pokud feature vkládá uživatelsky-viditelné texty: přidej klíče do `TemplateResources/Resources/en.lproj/Localizable.strings` ve formátu `<feature>.<section>.<key>`. Texty se používají přes typed `L10n.<Feature>.<section>.<key>` (Tuist generuje strukturu automaticky).

## Mimo scope

- Explicit-deny list. Co tento task vědomě **NE**dělá. Bez tohohle bodu „task creep" debaty pokračují donekonečna.

## Hotovo když

- Build prochází (`tuist generate && xcodebuild ... build`).
- Všechny testy green.
- Snapshot testy refreshnuté pokud byla změna view layeru.
- Manuální verify v simulátoru / na zařízení.

## Rizika

- Edge cases, fragile interactions, performance traps, iOS-version specifické chování.

## Reference

- `CLAUDE.md` — projektové konvence
- `Features/Example/` — referenční implementace pro feature framework
- Apple HIG / iOS API docs — pokud se feature dotýká platformy
