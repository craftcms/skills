---
name: craft-translations
description: Translates Craft CMS and Craft plugin control panel strings (static message translations in `translations/<lang>/<category>.php`) and keeps terms consistent with Craft's own translations. Use when adding or changing translatable strings, translating a plugin or module into other languages, fixing or standardizing a translated term, or reviewing translation quality.
license: MIT
compatibility: Craft CMS 4, 5, and 6, and their plugins and modules. The check script needs PHP with the intl and mbstring extensions, which Craft requires anyway.
---

# Translating Craft strings

Craft and its plugins translate control panel strings with PHP message files: one file per language and message category, mapping each English source string to its translation. Translate strings in the same change that adds or edits them, so they ship translated.

## Where strings live

- **Craft CMS 4 and 5, and plugins:** `src/translations/<lang>/<category>.php`. Craft CMS 6 moves its own files to `resources/translations/`.
- **Category:** `app` for Craft CMS, and the plugin handle for a plugin, such as `commerce`. Code reads them with `Craft::t('category', 'Message')` (`t()` in Craft 6) and Twig's `|t('category')` filter.
- **Keys** are the English source strings. The `en/<category>.php` file lists them, usually mapping each to itself. Never change a key in a translation file; change the English string in code and in `en/` instead.
- A plugin can use Craft's existing `app` strings, but never adds to or edits the `app` category. Its own strings go in its own category.

## Languages

Translate into every language folder except `en`. For `en-GB`, copy the English text and change American spellings to British ones (licence, colour, authorise).

Leave out a string you can't translate rather than adding it with English text. Every entry counts as translated, and Craft falls back to the English text for a missing key.

## Finding the strings to translate

Run the check script on the translations folder. With `--missing`, it lists each language's untranslated keys, per category:

```sh
php scripts/check.php src/translations --missing
```

Skip raw translation keys that aren't UI text, such as `updater/Index` or `account_activation_body`.

Before translating, read how each string is used (`git grep -n "<source text>"`). Many strings are fragments, column labels, or screen-reader announcements, and the right translation depends on context.

## Choosing terms

Translations across the Craft ecosystem should use the same words for the same things, so a plugin's screens read like Craft's own.

- **Start from Craft's terms.** For Craft concepts (Entry, Asset, Element, Section, Field, Handle, Slug, Draft, Site, Global Set, Control Panel, and so on), use the term Craft's own `app.php` uses in that language: `vendor/craftcms/cms/src/translations/<lang>/app.php` in a project or plugin. Match its register (formal or informal) and quote style too. [references/terminology.md](references/terminology.md) lists settled decisions.
- **Know what the concept is.** [references/glossary.md](references/glossary.md) defines each Craft and Commerce concept and what it's easily confused with. For example, an Asset is a file in a volume, not a financial asset, and a Global Set holds content, not settings. Read the entries for the terms you're translating before choosing words.
- **Decide by meaning, not by frequency.** The most common translation in a file isn't necessarily right. If a term is misleading, fix it in every string that uses it rather than spreading it further.
- **Check for clashes** with other terms in the same file. A word that already means something else there is wrong even when it's a fair translation on its own. For example, nl "Bericht" is Message, tr "Genel" is General, and he יוצר is Creator, so none of them work for Entry, Global, or Author.
- **Check glossaries** when unsure, such as the WordPress locale glossaries at translate.wordpress.org. Flag terms you couldn't confirm, so a native speaker can review them.
- **Product and system names** in placeholders such as `{system}` or `{client}` are plain names. Don't hyphenate them onto nouns or inflect them.

## Placeholders and ICU

Messages use ICU MessageFormat.

- Keep every placeholder exactly as written.
- Plural and select translations must keep the source's selectors (`=1`, `other`, and so on). You can add the language's own plural categories (`one`, `few`, `many`), but don't remove the source's.
- Select keys are matched exactly and can't contain spaces, so a multi-word value always falls through to `other`.

### `{type}` and other placeholders whose gender, case, or number is unknown

Placeholders such as `{type}`, `{item}`, and actor names often need words that agree with them.

`{type}` gets an element type's name, already translated in the current language. Which form depends on the call: usually the lowercase singular (`lowerDisplayName()`, such as "entry"), but also the lowercase plural (`pluralLowerDisplayName()`), the plural display name (such as "Users" on the New Users chart), or the singular display name (in fallback element titles). Read the calls before writing a select. Plugin element types pass their own names, so a translation can't list every value.

- Give each common type its full phrase in a select, keyed on the translated names, and fall back to a neutral phrase that works for any noun: `{type, select, Eintrag{Neuer Eintrag} Benutzer{Neuer Benutzer} Asset{Neues Asset} Kategorie{Neue Kategorie} other{Neues Element ({type})}}`. Don't select only the agreeing word and append `{type}`, as in `{type, select, Eintrag{Neuer} other{Neue}} {type}`: every type you didn't list gets the wrong form.
- A neutral phrase on its own ("this element ({type})", "zatwierdził(a)") is fine when a select isn't practical.
- Changing a language's word for a noun can silently break selects that match it. When you rename a term, search the file for selects on the old word. The check script warns about select keys that aren't a translation in that language.
- Test each select with PHP's `MessageFormatter` for every value it can receive, including one it doesn't list:

  ```php
  $f = new MessageFormatter('de', $translation);
  foreach (['Eintrag', 'Asset', 'Benutzer', 'Kategorie', 'Digitalprodukt'] as $type) {
      echo $f->format(['type' => $type]), "\n";
  }
  ```

### In code

Prefer Craft's existing `{type}` strings to new strings that hardcode an element type, such as `Craft::t('app', 'Create {type}', ['type' => MyElement::lowerDisplayName()])` rather than a new "Create widget" key. They're already translated into every language, and their translations already handle agreement. Capitalize the result in code (`StringHelper::upperCaseFirst()`, `mb_ucfirst()` in Craft 6) when the string starts a label.

## File format

- Add each key in the same position as in `en/<category>.php`, and escape `'` as `\'`.
- When editing many files, replace whole `'key' => 'value',` lines with a script that fails if a key or line isn't found, so nothing changes silently.
- When a string is removed from `en/`, remove it from every language file too.
- Run `php -l` on each file you edit.
- Mark every translation file except the English source as generated in `.gitattributes`, so pull request diffs collapse them. Use one wildcard with an `en` override rather than per-language patterns, which miss languages:

  ```gitattributes
  /src/translations/*/*.php linguist-generated=true
  /src/translations/en/*.php -linguist-generated
  ```

## Translating many languages

Split the work across parallel workers by language family (de/de-CH, fr/fr-CA, es/pt/it, da/nb/nn/sv, pl/cs/sk, ru/uk, ar/he/fa, ja/zh, ko/th, …). Give each worker the keys, the terminology to follow, and the files it owns, and tell it to edit only its own languages' files.

## Verifying

Run the check script without `--missing`. For each category, it reports keys that aren't in the English file, messages that aren't valid ICU, and placeholders a translation dropped, and exits with 1 when it finds any. It also warns about select keys that aren't a translation anywhere in that language's folder, such as an English `draft` branch in a language whose `{type}` values are translated. Warnings don't change the exit code, because a plugin's select can match names from Craft's own `app.php`. Test selects with `MessageFormatter` too.

## Craft's own repositories

Craft CMS, Commerce, and other first-party plugins use [craftcms/translation-sync](https://github.com/craftcms/translation-sync) to keep translations the same across their branches. If the repo has `.github/workflows/translation-sync.yml`:

- The `translations` branch holds a catalog with one folder per language. Its `translation-sync.yml` lists each synced branch with its translations folder, and optionally languages to leave out of that branch (`exclude_languages`).
- The sync runs daily, after each push to `translations`, and by hand. It copies translations edited on a branch into the catalog, removes catalog keys that no branch's English file has anymore, and opens or updates a `t9n/<branch>` pull request for each branch that differs from the catalog.
- A key has one translation per language on every branch, and the most recent edit wins. Translate a string once, on the branch your pull request targets, and let the sync carry it to the other branches.
- To fix an existing term on every branch at once, edit the catalog on the `translations` branch directly.
- After merging a pull request that changes translation files, run the sync: `gh workflow run translation-sync.yml -R craftcms/<repo> --ref translations`.
- If a pull request conflicts with a merged `t9n/<branch>` pull request in translation files, keep the target branch's translations and reapply the pull request's own key additions and removals.
- The catalog has no `en/` folder. To check it, copy it to a temporary folder with a branch's English file in `en/`. Because the catalog holds every branch's keys, save the script's output before editing and diff it afterward. "No new findings" is the bar, not exit 0.
