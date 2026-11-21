---
name: craft-translations
description: Translates Craft CMS and Craft plugin control panel strings (static message translations in `translations/<lang>/<category>.php`) and keeps terms consistent with Craft's own translations. Use when adding or changing translatable strings, translating a plugin or module into other languages, fixing or standardizing a translated term, or reviewing translation quality.
license: MIT
compatibility: Craft CMS 4, 5, and 6, and their plugins and modules. The check script needs PHP with the intl and mbstring extensions, which Craft requires anyway.
---

# Translating Craft strings

Craft and its plugins translate control panel strings with PHP message files: one file per language and message category, mapping each English source string to its translation. Translate strings in the same change that adds or edits them, so they ship translated.

## Where strings live

- **Craft CMS 4 and 5, and their plugins:** `src/translations/<lang>/<category>.php`. Craft CMS 6 keeps its own files in `resources/translations/`. Craft 6 plugins load `lang/<lang>/<category>.php` from the package root first and fall back to `src/translations/`.
- **Category:** `app` for Craft CMS, and the plugin handle for a plugin, such as `commerce`. Use `site` for text that site admins enter, such as section names, feed names, or a plugin name they configure: `Craft::t('site', $name)`, `|t('site')`.
- **Keys** are the English source strings. The `en/<category>.php` file lists them, usually mapping each to itself. Never change a key in a translation file; change the English string in code and in `en/` instead.
- A plugin can use Craft's existing `app` strings, but never adds to or edits the `app` category. Its own strings go in its own category.
- `app` strings differ by Craft version. A string can be in Craft 5's `app.php` and gone from Craft 6's. Check `app` strings against the `en/app.php` of the Craft version each branch targets.

## Auditing the code

The check script only reads translation files. Before translating a plugin, list every translatable call in its code with its category and key, and confirm each key is in that category's `en/` file:

- PHP `Craft::t()`, Craft 6 `t()` (its category defaults to `app`), and `I18N::prep()` (job descriptions).
- Twig `|t()` and `{{ 'Message'|t('category') }}`.
- JS `Craft.t()`. Craft 5 takes `Craft.t(category, message, params)`; Craft 6 takes `t(message, params, category)` and defaults to `app`. In Craft 5, JS strings must also be registered under the same category, with `registerTranslations()` in PHP or `{% do view.registerTranslations('category', [...]) %}` in Twig. Confirm a JS file is still loaded before fixing its calls.

Catch calls that pass the category positionally and calls split across lines; a regex keyed on `category:` misses them. Things to fix:

- A string in the `app` category that isn't in Craft's `en/app.php` never translates. Move it to the plugin's category. The same goes for a misspelled or foreign category, such as another plugin's handle.
- Keys built at runtime, such as `Craft::t('plugin', ucfirst($status))`, are invisible to anyone reading the code. Write a literal call per value, or at least add every possible value to `en/` and note which object each describes, since gender agreement can differ by object.
- Default values a plugin stores, such as a default slot name, should be translated through the plugin category when they're created.
- Hardcoded UI text that isn't wrapped in a translation call.

### Reusing Craft's strings

About a third of a typical plugin's strings (Settings, Enabled, Title, …) already exist in Craft's `app.php`. Compare each literal string in the plugin with Craft's `en/app.php` and use the `app` category for exact matches, and prefer an existing key over a near duplicate (`Open in a new tab` over `Open in new tab?`, `Actions for {name}` over `Actions for {channel}`). Reuse a string only when it means the same thing: Craft's "Duplicate" is a verb, so a plugin's "Duplicate" status keeps its own key.

## Languages

Translate into every language folder except `en`. For `en-GB`, copy the English text and change American spellings to British ones (licence, colour, authorise).

Leave out a string you can't translate rather than adding it with English text. Every entry counts as translated, and Craft falls back to the English text for a missing key.

Some languages need more than the language name suggests:

- **pt** is European Portuguese: utilizador, ficheiro, guardar. Craft's file still has some Brazilian leftovers (usuário, arquivo, Salvar); don't copy those.
- **de-CH** isn't de with Swiss spelling. It uses informal "du", «…» quotes, and ss for ß, while de uses formal "Sie" and „…“.
- **th** has no trailing Latin full stops.
- **fr** puts a non-breaking space before `: ! ? »`.

## Finding the strings to translate

Run the check script on the translations folder. With `--missing`, it lists each language's untranslated keys, per category:

```sh
php scripts/check.php src/translations --missing
```

Skip raw translation keys that aren't UI text, such as `updater/Index` or `account_activation_body`.

Before translating, read how each string is used (`git grep -n "<source text>"`). Many strings are fragments, column labels, statuses, or screen-reader announcements, and the right translation depends on context:

- A one-word status needs the meaning the code gives it. Read the enum or state machine: a webhook's "Requested" status means "being sent", not "asked for".
- A string compared against imported data, such as `yes`, `on`, or `live` matched in a lowercased CSV value, isn't a label. Translate it as the single lowercase word a data file in that language would contain, with a plain apostrophe.
- Strings inserted into other sentences, such as Laravel validation attribute names in "The :attribute field is required.", need lowercase noun phrases that read naturally in that slot (capitalized nouns in German).

## Choosing terms

Translations across the Craft ecosystem should use the same words for the same things, so a plugin's screens read like Craft's own.

- **Start from Craft's terms.** For Craft concepts (Entry, Asset, Element, Section, Field, Handle, Slug, Draft, Site, Global Set, Control Panel, and so on), use the term Craft's own `app.php` uses in that language: `vendor/craftcms/cms/src/translations/<lang>/app.php` in a project or plugin. Match its register (formal or informal). For a Commerce plugin, use Commerce's `commerce.php` too.
- **Know what the concept is.** [references/glossary.md](references/glossary.md) defines each Craft and Commerce concept, what it's easily confused with, and the words Craft's translations settled on. For example, an Asset is a file in a volume, not a financial asset, and a Global Set holds content, not settings. Read the entries for the terms you're translating before choosing words, and check its per-language list before copying a term, since an older copy of Craft can still have a term that's since been fixed.
- **Decide by meaning, not by frequency.** The most common translation in a file isn't necessarily right. If a term is misleading, fix it in every string that uses it rather than spreading it further.
- **Check for clashes** with other terms in the same file, and with Craft's `app.php` and Commerce's `commerce.php`, since a plugin's strings appear next to theirs. A word that already means something else there is wrong even when it's a fair translation on its own. For example, nl "Bericht" is Message, tr "Genel" is General, and he יוצר is Creator, so none of them work for Entry, Global, or Author. Run `check.php --clashes` to list translations that several different English keys share.
- **A plugin term that shares an English word with a Craft concept needs its own term** when it means something else: Feed Me's "Passkey" is a token in a URL, not a WebAuthn sign-in key, and a webhook event's "Subject" isn't an email subject.
- **Check glossaries** when unsure, such as the WordPress locale glossaries at translate.wordpress.org, or the localized docs of the service a plugin integrates (Stripe, Shopify, CKEditor). Flag terms you couldn't confirm, so a native speaker can review them.
- **Product and system names,** such as "Apple News" or `{system}`, stay Latin and uninflected. In languages with case endings, rephrase around the name (hu "az Apple News szolgáltatásban") rather than suffixing it; tr suffixes go after an apostrophe, as Craft writes “URL’si”.
- **Lightswitch values and literals:** reuse the language's "ON Label"/"OFF Label" words for On and Off. Keep `true` and `false` as literals when the user types or configures the value, and translate them otherwise.

## Quotes and apostrophes

Use typographic quotation marks and apostrophes, never straight `"` or `'`, in translations and in English source strings alike. Straight ones stay only where they're literal: code (`{{ entry.title }}`), HTML attributes, values a user types or a data file contains, and inch or foot marks.

Use each language's quotation marks. When a string you're editing has another style, change it to this one.

| Quotation marks | Languages |
|---|---|
| “…” | ar, cy, da, en-GB, es, he, id, it, ko, nl, pt, th, tr, zh |
| „…“ | cs, de, hr, is, sk |
| „…” | hu, pl |
| «…» | de-CH, el, fa, fr, fr-CA, ky, nb, nn, ru, uk |
| ”…” | sv |
| 「…」 | ja |

fr and fr-CA put a non-breaking space (U+00A0) inside « … ». Wrap code, such as `{slug}` in a tip about path variables, in the same backticks as the source rather than quoting it.

Apostrophes:

- Use ’ (U+2019) in every language, including fr (l’entrée), it, nl, tr (URL’si), and uk, where the apostrophe is a letter (ім’я).
- he writes acronyms with gershayim ״ (דוא״ל, מע״מ) and abbreviations with geresh ׳ (מקס׳).
- Never use ‘ (U+2018) as an apostrophe.

In ICU, a straight `'` directly before `{` or `}` starts a quoted section, so the placeholder prints literally. ’ never does.

Don't add invisible bidi marks (RLM, LRM) to ar, he, or fa unless a rendered string shows the wrong order, and say so in the pull request.

## Placeholders and ICU

Messages use ICU MessageFormat.

- Keep every placeholder exactly as written.
- Plural and select translations must keep the source's selectors (`=1`, `other`, and so on). You can add the language's own plural categories (`one`, `few`, `many`), but don't remove the source's, and never leave one empty: `one {}` also catches numbers like French 0 or Russian 21, which then print nothing.
- Write the whole phrase inside each plural branch, so `=1` reads naturally ("Every day", not "Every 1 day"), and use `=2` in ar and he, or `two` in cy, where the language has a dual.
- Select keys are matched exactly and can't contain spaces, so a multi-word value always falls through to `other`.
- A placeholder that receives a nominative value, such as `{duration}` from `humanDuration()` ("3 Tage, 2 Stunden"), breaks after a preposition that governs another case. Use a label form: "Erstellt vor: {duration}".
- In source strings, prefer one message with placeholders and ICU plurals over concatenated fragments, which can't be reordered in languages with a different word order.

### `{type}` and other placeholders whose gender, case, or number is unknown

Placeholders such as `{type}`, `{targetTypeSingular}`, `{item}`, and actor names often need words that agree with them. Read what each one receives before choosing a form.

`{type}` usually gets an element type's name, already translated in the current language. Which form depends on the call: usually the lowercase singular (`lowerDisplayName()`, such as "entry"), but also the lowercase plural (`pluralLowerDisplayName()`), the plural display name (such as "Users" on the New Users chart), or the singular display name (in fallback element titles). Plugin element types pass their own names, so a translation can't list every value. Sometimes `{type}` isn't an element type at all: an entry type's own name ("Quote") is a proper name ("entries of type {type}"), and Commerce passes inventory level labels such as Available or Reserved.

- Give each common type its full phrase in a select, keyed on the translated names, and fall back to a neutral phrase that works for any noun: `{type, select, Eintrag{Neuer Eintrag} Benutzer{Neuer Benutzer} Asset{Neues Asset} Kategorie{Neue Kategorie} other{Neues Element ({type})}}`. Don't select only the agreeing word and append `{type}`, as in `{type, select, Eintrag{Neuer} other{Neue}} {type}`: every type you didn't list gets the wrong form.
- A neutral phrase on its own ("the element {type}", "this element ({type})", "zatwierdził(a)") is fine when a select isn't practical. Articles, demonstratives, adjectives, and case endings next to the placeholder are the usual bugs: es "El {type}" gives "El entrada", de "diesen {type}" gives "diesen Lizenz".
- Changing a language's word for a noun can silently break selects that match it. When you rename a term, search the file for selects on the old word. The check script warns about select keys that aren't a translation in that language. If the placeholder receives a raw value, such as an API enum (`day`, `month`), the keys stay that value; ignore the warning.
- Test each select with PHP's `MessageFormatter` for every value it can receive, including one it doesn't list:

  ```php
  $f = new MessageFormatter('de', $translation);
  foreach (['Eintrag', 'Asset', 'Benutzer', 'Kategorie', 'Digitalprodukt'] as $type) {
      echo $f->format(['type' => $type]), "\n";
  }
  ```

### In code

Craft's `{type}` strings ("Create {type}", "Are you sure you want to delete this {type}?") are already translated, so a plugin can pass its element type's name instead of adding "Create widget": `Craft::t('app', 'Create {type}', ['type' => MyElement::lowerDisplayName()])`. Capitalize the result in code (`StringHelper::upperCaseFirst()`, `mb_ucfirst()` in Craft 6) when the string starts a label. Before switching, run `MessageFormatter` on each language's translation with the plugin's own translated noun. Where a translation agrees only with Craft's nouns, keep the plugin's own key.

## File format

- Add each key in the same position as in `en/<category>.php`, and escape `'` as `\'`.
- When editing many files, replace whole `'key' => 'value',` lines with a script that fails if a key or line isn't found, so nothing changes silently.
- When building files from a list of values, compare each file's keys with `en` (`array_keys($t) === array_keys(array_intersect_key($en, $t))` keeps the order) and spot-check pairs: a value shifted onto its neighbour's key passes every other check.
- When a string is removed from `en/`, remove it from every language file too.
- Run `php -l` on each file you edit.
- Mark every translation file except the English source as generated in `.gitattributes`, so pull request diffs collapse them. Use one wildcard with an `en` override rather than per-language patterns, which miss languages:

  ```gitattributes
  /src/translations/*/my-plugin.php linguist-generated=true
  /src/translations/en/my-plugin.php -linguist-generated
  ```

  A Craft 6 plugin uses `/lang/` instead.

## Translating many languages

Split the work across parallel workers by language family (de/de-CH, fr/fr-CA, es/pt/it, da/nb/nn/sv, pl/cs/sk, ru/uk, ar/he/fa, ja/zh, ko/th, …). Give each worker the keys, how each is used, the terminology to follow, and the files it owns, and tell it to edit only its own languages' files. Then review each language for clashes and agreement before merging.

## Verifying

Run the check script without `--missing`. For each category, it reports keys that aren't in the English file, messages that aren't valid ICU, and placeholders a translation dropped, and exits with 1 when it finds any. It also warns about:

- select keys that aren't a translation anywhere in that language's folder, such as an English `draft` branch in a language whose `{type}` values are translated;
- plurals that lost the source's explicit selectors, such as `=1`;
- empty plural category branches, such as `one {}`;
- ‘ used as an apostrophe;
- straight quotes or apostrophes outside code spans, HTML tags, and inch or foot marks. Ignore it for literal values, such as a word matched against imported data.

Warnings don't change the exit code, because a plugin's select can match names from Craft's own `app.php`. Add `--clashes` to list translations shared by keys with different English text; most are harmless variants ("Add Group" and "Add a group"), but it's how you find one word used for two concepts. Test selects with `MessageFormatter` too.

## Craft's own repositories

Craft CMS, Commerce, and other first-party plugins use [craftcms/translation-sync](https://github.com/craftcms/translation-sync) to keep translations the same across their branches. If the repo has `.github/workflows/translation-sync.yml`:

- The `translations` branch holds a catalog with one folder per language. Its `translation-sync.yml` lists each synced branch with its translations folder, and optionally languages to leave out of a branch (`exclude_languages`). That's how to add new languages on a release branch first; remove the exclusion once the release branch merges up.
- The sync runs daily, after each push to `translations`, and by hand. It copies translations edited on a branch in the last 90 days into the catalog, removes catalog keys that no branch's English file has anymore, and opens or updates a `t9n/<branch>` pull request for each branch that differs from the catalog.
- A key has one translation per language on every branch, and the most recent edit wins. Translate a string once, on the branch your pull request targets, and let the sync carry it to the other branches.
- To fix an existing term on every branch at once, edit the catalog on the `translations` branch directly. If the sync committed to the catalog since you started, reapply your values by key onto the latest `translations` (replace whole lines, and fail if an old value changed upstream) rather than rebasing.
- After merging a pull request that changes translation files, run the sync: `gh workflow run translation-sync.yml -R craftcms/<repo> --ref translations`.
- If a pull request conflicts with a merged `t9n/<branch>` pull request in translation files, keep the target branch's translations and reapply the pull request's own key additions and removals.
- The catalog has no `en/` folder. To check it, copy it to a temporary folder and merge every synced branch's English file into one `en/<category>.php`, so keys from other branches aren't reported. Save the script's output before editing and diff it afterward. "No new findings" is the bar, not exit 0.

### Adding the sync to a repository

- Every synced branch needs its `en/<category>.php` before the workflow reaches `translations`. A sync against a branch with no source file removes that branch's keys from the catalog, and a sync while a pull request adding `en` keys is still open removes those keys and opens a duplicate `t9n/` pull request. Push the catalog without the workflow, merge the branch pull requests, then add the workflow.
- The daily schedule runs from the default branch. If that's the older branch, merge the newer branch's pull request first.
- If a plugin had only `en` files, `bootstrap` builds an empty catalog; copy the new language files into it in the same change.
- Preview the first sync before pushing anything: push the pull request branches (under the real branch names) and the catalog to a local bare repo, clone it, and run `sync --fetch --dry-run`, then `sync --no-pr`, and commit the catalog in the sync's own output. It orders keys its own way, so a hand-built catalog gets rewritten on the first sync. Alternatively, point refs at unmerged branches with `git update-ref refs/remotes/pr/<branch> <pr-branch>` and pass `--remote=pr`. Set `git config user.email` to the action's bot identity first, or your own commits count as branch edits. Each branch should report "up to date".
- `sync --dry-run` fails on a new orphan `translations` branch until it has a commit.
- A Craft 6 branch whose translation pull request merges more than 90 days after `bootstrap` loses its branch-only strings unless you run `bootstrap` again.
- Match the repo's Prettier config when adding `translation-sync.yml`: a repo with `singleQuote: true` wants the README example's single quotes, and one without it wants double quotes, including on the cron line.
