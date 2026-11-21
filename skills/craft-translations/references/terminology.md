# Settled terminology

Decisions made while reviewing Craft CMS's own translations. Craft's current `app.php` files are the source of truth; this list explains the choices that weren't obvious.

## General

- **Keyboard key names** (Alt, Control, Command, Option, Shift, Return, Enter, Escape, Tab, …) stay in English, as printed on the physical key.
- **"The Quick Brown Fox"** is placeholder text (a sample entry title in card previews), like lorem ipsum. A native pangram or a literal translation is fine; a person's name isn't.
- **"Live"** in "live element" strings means the current published version, not the Live status.
- **"Feed"** in Craft CMS is the RSS Feed dashboard widget, so news or RSS translations are right there. A plugin that uses "feed" for something else, such as Feed Me's data imports, needs its own term.
- **OAuth and API strings:** "Scopes" are OAuth scopes, "Personal" means a personal access token, "App" is a scope category, and "Extend" is the verb (extensibility). "It…" on the consent screen refers to the client app.

## Craft 6

- **Content "Release"** (the 6.x Releases feature) means a release as in "ship". Use one term per language, distinct from the queue-job "release" (let go of a job), from "publish", and from "Edition". Current terms: de/nl/sv Release, fr lancement, es lanzamiento, pt lançamento, it rilascio, da udgivelse, nb utgivelse, pl wydanie, cs vydání, sk vydanie, ru Релиз, uk Реліз, el Κυκλοφορία, is Útgáfa, hu Kiadás, tr Sürüm, ja リリース, ko 릴리스, zh 发行版, fa ریلیز, th รีลีส, he גרסה, ar الإصدار.
- **"Bridged index" / "Bridged screen"** are dev-mode badges for legacy Craft 5-era screens rendered inside the Craft 6 control panel. Translate them as "legacy index/screen", not with a bridge metaphor.

## Terms by language

Terms that replaced misleading ones. Use them, and don't reintroduce the old ones.

- **ar:** Parent الأب (not الأصل, which also means Asset).
- **cs:** tags "tagy" (štítky is Labels).
- **da:** Slug and Handle have their own terms (not "Snegl" or "Kodetagget").
- **fr:** Slug isn't "Identificateur".
- **he:** Author מחבר (יוצר is Creator); Entry isn't כניסה.
- **hr:** Live "Dostupno" (Objavljeno is Published).
- **is:** Disabled "Óvirkt", Entry "Færsla", Element "Þáttur", Slug "Slóðarheiti", Feed "Straumur", Logs "annála".
- **nb/nn:** Handle isn't "Kodeord" and Slug isn't "Lenke". nn uses the same handle and slug terms as nb.
- **nl:** Entry "vermelding" (Bericht is Message).
- **pt:** Parent "Pai" (not "Parente", which means relative).
- **ru:** Slug "Ярлык". **uk:** Slug "частина посилання".
- **sk:** Tag "Značka"; Label stays "Štítok".
- **sv:** Handle isn't "Hantera" (that's the verb).
- **tr:** Global Set "global küme" (Genel is General/Public), Parent "Üst öge", Entry "Kayıt", Asset "Dosya".
- **zh:** Slug isn't 链接; Global Set 全局集.

Some of these haven't been checked by native speakers yet (hr "Dostupno", nl "vermelding", is Slug and Logs). Raise doubts rather than reverting them silently.
