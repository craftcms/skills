# Settled terminology

Decisions made while reviewing Craft CMS's own translations. Craft's current `app.php` files are the source of truth; this list explains the choices that weren't obvious.

## General

- **Keyboard key names** (Alt, Control, Command, Option, Shift, Return, Enter, Escape, Tab, …) stay in English, as printed on the physical key.
- **"The Quick Brown Fox"** is placeholder text (a sample entry title in card previews), like lorem ipsum. A native pangram or a literal translation is fine; a person's name isn't.
- **"Live"** as an entry status means the entry is enabled and its post date has passed. In "live element" and "live changes" strings, it means the current canonical version, as opposed to a draft. Keep both distinct from "Active" and "Published".
- **"Feed"** in Craft CMS is the RSS Feed dashboard widget, so news or RSS translations are right there. A plugin that uses "feed" for something else, such as Feed Me's data imports, needs its own term.
- **"Passkey"** is a WebAuthn sign-in key. Don't translate it as "password".
- **OAuth and API strings:** "Scopes" are OAuth scopes, "Personal" means a personal access token, "App" is a scope category, and "Extend" is the verb (extensibility). "It…" on the consent screen refers to the client app.

## Craft 6

- **Content "Release"** (the 6.x Releases feature) means a release as in "ship". Use one term per language, distinct from the queue-job "release" (let go of a job), from "publish", and from "Edition". Current terms: de/nl/sv Release, fr lancement, es lanzamiento, pt lançamento, it rilascio, da udgivelse, nb utgivelse, pl wydanie, cs vydání, sk vydanie, ru Релиз, uk Реліз, el Κυκλοφορία, is Útgáfa, hu Kiadás, tr Sürüm, ja リリース, ko 릴리스, zh 发行版, fa ریلیز, th รีลีส, he גרסה, ar الإصدار.
- **"Bridged index" / "Bridged screen"** are dev-mode badges for legacy Craft 5-era screens rendered inside the Craft 6 control panel. Translate them as "legacy index/screen", not with a bridge metaphor.

## Terms by language

Terms that replaced misleading ones. Use them, and don't reintroduce the old ones.

- **ar:** Parent الأب (الأصل is Asset).
- **cs:** Entry "Záznam" (not "Zadávané údaje"). Tag "Tag", tags "tagy" (štítek is Label).
- **da:** Slug "Slug" (not "Snegl"), Handle "Handle" (not "Kodetagget"), Site "Site" ("Side" is Page), Feed "Feed" ("Tilføre" is a verb), Disabled "Deaktiveret".
- **fa:** Passkey کلید عبور (رمز عبور is Password).
- **fr:** Slug "Slug"; Handle "Identificateur". **fr-CA:** search indexes "index de recherche" (not "répertoires").
- **he:** Entry רשומה (not כניסה), Author מחבר (יוצר is Creator), License רישיון, Field Layout פריסת שדות.
- **hr:** Live status "Dostupno" ("Objavljeno" is Published, "Aktivno" is Active).
- **hu:** Asset "Médiafájl", Assets "Médiafájlok" ("Eszköz" is Tool).
- **is:** Disabled "Óvirkt" ("Öryrkjar" means disabled people), Entry "Færsla" ("Inngangur" means introduction), Element "Þáttur" ("Frumefni" is a chemical element), Slug "Slóðarheiti" ("Snigill" is a snail), Feed "Straumur" ("Fæða" is food), Category Group "Flokkahópur", logs "annálar" ("Sjá annála" for "See logs").
- **it:** Field Layout "Layout dei campi" (not "Struttura del campo").
- **ja:** Author 投稿者 (作成者 is Creator).
- **ko:** Author 작성자 (not 저자, a book's author).
- **nb/nn:** Slug "Slug" (not "Lenke", which is Link), Handle "Handle" (not "Kodeord", a password).
- **nl:** Entry "Vermelding", entry type "vermeldingstype" ("Bericht" is Message, "Inhoud" is Content, "Invoer" is Input). Post Date "Publicatiedatum". A draft is "concept".
- **pl:** Entry "Wpis" (not "Pozycja"), Tag "Tag" to match "Grupa tagów".
- **pt:** Parent "Pai" ("Parente" means a relative).
- **ru:** Slug "Ярлык" (not "Поле динамичных данных"). **uk:** Slug "Частина посилання" (not "Поле змінюваних даних").
- **sk:** Tag "Značka", Tag Group "Skupina značiek"; Label stays "Štítok".
- **sv:** Handle "Handle" ("Hantera" is the verb).
- **tr:** Global Set "Global küme" ("Genel" is General and Public; "Genel Etiket Kümesi" meant global tag set), Parent "Üst öge", Entry "Kayıt" ("Giriş" is Login), Asset "Dosya".
- **zh:** Slug 别名 (not 链接), Global Set 全局集 (全局设置 is Global Settings).

## "New {type}"

Several languages translate "New {type}" with a select that gives Craft's built-in types their full phrase and falls back to a neutral "new element" phrase, such as de "Neues Element ({type})", fr "Nouvel élément ({type})", es "Nuevo elemento ({type})", pl "Nowy element ({type})", da "Nyt element ({type})", nb "Nytt element ({type})", el "Νέο στοιχείο ({type})", is "Nýr þáttur ({type})", ar عنصر جديد ({type}). Plugin element types get the fallback, so give a plugin's own "New …" strings their own correctly inflected keys only when the fallback reads badly.

## Not yet confirmed

Native speakers haven't checked these: hr "Dostupno", nl "Vermelding", is "Slóðarheiti" and "annálar", and tr "Dosya" (WordPress uses "Ortam" for media). Raise doubts rather than reverting them silently.
