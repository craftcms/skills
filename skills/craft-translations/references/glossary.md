# Craft terms

What the Craft terms in control panel strings mean, and the words Craft's own translations settled on for them. Use it to pick a translation that names the right thing and matches Craft. Craft's current `app.php` files are the source of truth for each language; this file explains the choices that weren't obvious and lists terms that replaced misleading ones. Don't reintroduce the old ones.

## Content

- **Element:** the core unit of content. Entries, assets, categories, tags, global sets, users, and addresses are all elements. Translate it as a generic "item" or "element", not a chemical or HTML element.
- **Element type:** a kind of element, such as entries or assets. Plugins add their own, such as Commerce's products and orders.
- **Entry:** the most flexible content container, usually belonging to a section, or nested in a Matrix or CKEditor field. A piece of content, like a post or record. Not an entrance, a login, or a journal entry in the accounting sense. Some languages use their word for "article" (it "Articolo", nb/nn "Artikkel"), so a plugin that also talks about articles, such as a news or SEO plugin, needs a different word for its own articles.
- **Entry type:** a content type that defines an entry's fields. Sections, Matrix fields, and CKEditor fields choose which entry types they allow.
- **Section:** a container for entries that sets their entry types, sites, and URLs. There are three section types:
  - **Channel:** a flat list of entries, always ordered by a property such as date. Not a TV or sales channel.
  - **Structure:** entries in an ordered tree. An entry's **Parent** is the entry above it in the tree, not a relative or a parent company.
  - **Single:** a section with exactly one entry, such as a homepage. Not "unmarried" or "one-way".
- **Asset:** an element that tracks one file in a volume, such as an image or PDF. Not a financial asset. Media or file terms work.
- **Volume:** where assets are organized, with nested folders. Each volume uses a **filesystem**, the storage behind it (a local disk or a cloud bucket).
- **Uploader:** the user who uploaded an asset, or last replaced its file.
- **Transform:** a resized or optimized version of an image, defined by name or in templates.
- **Category:** an element for hierarchical taxonomies, organized in **category groups**.
- **Tag:** an element for flat, unordered keywords, organized in **tag groups**. Not a label, an HTML tag, or a version tag.
- **Global set:** an element holding content used across a site, such as a footer or contact details. It holds content, not settings or global configuration. "Global" must not reuse the language's word for General.
- **User:** a person with an account. **Admin** is a user with unrestricted access. A **user group** is a role that collects permissions.
- **Author:** a user attached to an entry as its author. New entries get the current user. Not the creator of a file or the owner of a record.
- **Address:** an element storing a location, belonging to a user or another element.
- **Nested element:** an element owned by another element, such as the entries in a Matrix field or a user's addresses. The owning element is its **owner**.
- **Relation:** a link between elements, made with a relational field such as Entries or Assets.
- **Content:** the text, options, and media users add to elements.

## Drafts and statuses

- **Canonical:** the main version of an element, as opposed to its drafts and revisions.
- **Draft:** unpublished edits to an element, which can be applied to it later. A **provisional draft** holds unsaved changes visible only to the person editing (an auto-saved, temporary draft).
- **Revision:** a saved copy of an element's earlier state, which can be viewed or restored. Keep it distinct from Version, Review, Edit, Change, and Fix. Current terms include de/de-CH Revision, pl Wersja, ar النسخة المحفوظة, he גרסה שמורה, fa نگارش, th ฉบับแก้ไข, ko 개정, hu revízió, is vistuð útgáfa.
- **Status:** an element's state, such as Live, Pending, Expired, or Disabled, built from whether it's enabled and, for entries, its post and expiry dates.
- **Enabled:** the main status switch for an element. Disabled elements aren't shown on the site. A software "on/off" sense, not a disability sense.
- **Live:** as an entry status, the entry is enabled and its post date has passed. In "live element" and "live changes" strings, the current canonical version rather than a draft. Keep both distinct from Active, Enabled, and Published, and don't use "real-time" or "fresh". Current terms: de/de-CH/nb/da/nl Live, fr En ligne, fr-CA En direct, es En Vivo, it/pt/pl/sk Online, ru/ky Онлайн, uk Наживо, el Ζωντανό, cs V provozu, hr Dostupno, hu Éles, is Í loftinu, sv Direkt, nn Direkte, tr Canlı, id Tayang, th ออนไลน์, fa آنلاین, ko 라이브, zh 已上线, ja ライブ, ar مباشر, he חי. A payment gateway's **live mode** (live versus test keys) is a different concept; don't reuse these there. **Live Preview** is a separate concept too: keep cms's own term for it, even where that reads as "real-time".
- **Trash:** soft-deleted elements, which can be restored until garbage collection removes them. **Soft delete** marks something as deleted without removing it yet.
- **Propagation:** how an element and its field values are created and kept in sync across sites. Not advertising or plant propagation.

## Fields and layouts

- **Field:** a custom field added to a field layout, such as a Plain Text or Assets field. Not a field of land or a sports field.
- **Field type:** the kind of field, which sets its input and stored value, such as Plain Text, Dropdown, Lightswitch, or Matrix.
- **Field layout:** the tabs, fields, and conditions that make up an element's edit form.
- **Matrix:** a field that manages a set of nested entries. Keep the product name; it isn't a mathematical matrix.
- **Lightswitch:** a field with an on/off toggle.
- **Option:** one choice in a Dropdown, Checkboxes, or similar field, or a product option. Keep it distinct from Settings.
- **Handle:** a stable, machine-readable name (letters and numbers) for a field, section, entry type, and so on, used in templates. Not a door handle, and not the verb "to handle".
- **Slug:** the human-readable, URL-friendly part of a URI that identifies a piece of content. Not the animal, and not a whole link.
- **Condition:** one rule in a condition builder. A **condition builder** combines rules to filter elements or decide when a field or tab shows.
- **Generated field:** a field whose value is computed from a template instead of edited.
- **Time:** in field and picker strings, a time of day, not a duration. **Created at** and **Updated at** label dates, so avoid "at" forms that read as a clock time.

## Sites and localization

- **Site:** one of a project's sites, often one per language or brand. A project can have many. **Site group:** a set of sites.
- **Project:** a single Craft installation.
- **Translation:** content managed per site or language, or interface text passed through `Craft::t()`.

## Control panel

- **Control panel:** Craft's administration interface, where users sign in to manage content and settings. Not a hardware control panel.
- **Dashboard:** each user's customizable start screen, made of **widgets**. The **Feed** widget shows an RSS feed, so news or RSS translations are right in Craft CMS. A plugin that uses "feed" for something else, such as Feed Me's data imports, needs its own term.
- **Element index:** a table or grid of elements, with **sources** in its sidebar. A source is a predefined set of elements, such as one section's entries.
- **Live Preview:** previewing an element's changes side by side while editing. A **preview target** is a page the element can be previewed on.
- **Settings:** the screens where admins configure sections, fields, sites, and so on. They're read-only when admin changes aren't allowed.
- **Utility:** a back-office page, such as Caches or Queue Manager.
- **Queue:** background tasks waiting to run. Each one is a **job**. A job that's "released" is let go of, not published.
- **Permission:** a capability granted to a user directly or through a user group.
- **User preferences:** a user's own settings, such as language and accessibility options. Not properties or attributes.
- **Passkey:** a WebAuthn sign-in key. Not a password.
- **OAuth and API strings:** "Scopes" are OAuth scopes, "Personal" means a personal access token, "App" is a scope category, and "Extend" is the verb (extensibility). "It…" on the consent screen refers to the client app.
- **Project config:** Craft's record of a project's schema and settings, kept in files and applied to other environments.
- **Edition:** a product tier, such as Solo, Team, or Pro. Not a book edition or an edit.
- **License:** the terms under which a project uses Craft or a plugin.
- **Plugin:** an extension to Craft. **Plugin Store:** where plugins are found and licensed.
- **Logs:** records of what happened during requests, including warnings and errors. Not the word for Save.
- **Deprecation warning:** a notice that code uses something scheduled for removal.
- **Keyboard key names** (Alt, Control, Command, Option, Shift, Return, Enter, Escape, Tab, …) stay in English, as printed on the physical key.
- **"The Quick Brown Fox"** is placeholder text (a sample entry title in card previews), like lorem ipsum. A native pangram or a literal translation is fine; a person's name isn't.

## Craft 6

- **Release:** a content release (the Releases feature), as in "ship". Use one term per language, distinct from the queue-job "release" (let go of a job), from "publish", and from "Edition". Current terms: de/nl/sv Release, fr lancement, es lanzamiento, pt lançamento, it rilascio, da udgivelse, nb utgivelse, pl wydanie, cs vydání, sk vydanie, ru Релиз, uk Реліз, el Κυκλοφορία, is Útgáfa, hu Kiadás, tr Sürüm, ja リリース, ko 릴리스, zh 发行版, fa ریلیز, th รีลีส, he גרסה, ar الإصدار.
- **Embeddings:** AI vector embeddings used for search. Not oEmbed **embeds** (embedded media), which plugins should call "embedded content". Also keep embeds distinct from **nested** entries (da "indlejret", sv "inbäddade").
- **"Bridged index" / "Bridged screen":** dev-mode badges for legacy Craft 5-era screens rendered inside the Craft 6 control panel. Translate them as "legacy index/screen", not with a bridge metaphor.

## Craft Commerce

- **Product:** an element that holds one or more **variants**. A **product type** defines its fields, variants, and URLs.
- **Variant:** a specific purchasable version of a product, with its own price, SKU, and dimensions.
- **Purchasable:** anything that can be added to a cart. Variants and donations are built in, and plugins add others.
- **Donation:** a purchasable whose amount the customer chooses.
- **Order:** an element for a completed purchase. Before checkout, the same element is a **cart**. Not Craft's sort order: nl Bestelling, not Volgorde.
- **Line item:** one purchasable in a cart or order, with its quantity and options.
- **Customer:** a user with Commerce information such as orders, addresses, and payment sources.
- **Adjuster:** part of order totaling that applies discounts, tax, and shipping as **adjustments**.
- **Discount:** an adjuster that applies special pricing. **Sale** is the older promotion feature that catalog pricing replaced; keep it distinct from Discount. **Promotion** is a price promotion, not advertising. **Promotable** means sales and discounts may apply to the item. The **sale price** is the effective selling price, not necessarily discounted.
- **Catalog pricing:** the system that works out each variant's price from pricing rules.
- **Capture:** collecting funds from an authorized payment. Not a screenshot or "catch". **Authorize** (the verb) and **Authorization** (the noun) may need different words.
- **Gateway:** a payment gateway, not incoming payments.
- **Inventory levels:** On Hand, Available, Committed, Reserved, Safety (safety stock, not security), Incoming, Damaged, and Quality Control are distinct, and each needs its own word.
- **Origin:** both a transfer's origin and an order's origin (Web or Control panel). Not a departure or exit.
- **Attention:** the ATTN line of an address, not a warning.
- **Tax category:** a category of taxable goods, not an income tax bracket. A **taxable subject** is what a tax rate is calculated on, not a taxable person.
- **Invoice** (Stripe and other payment plugins): a bill, not a tax invoice. Invoice statuses Void and Canceled need different words, and Open is a status, not the verb.

## Terms by language

- **ar:** Parent الأب (الأصل is Asset), Class الصنف (الفئة is Category).
- **cs:** Entry "Záznam" (not "Zadávané údaje"). Tag "Tag", tags "tagy" (štítek is Label). Asset "soubor" (not "Prostředek"/"Objekty").
- **cy:** Field Limit "Terfyn Maes".
- **da:** Slug "Slug" (not "Snegl"), Handle "Handle" (not "Kodetagget"), Site "Site" ("Side" is Page), Feed "Feed" ("Tilføre" is a verb), Disabled "Deaktiveret", Options "Valgmuligheder" ("Indstillinger" is Settings).
- **de/de-CH:** Global Set "globales Set", Options "Optionen" ("Einstellungen" is Settings), Tax Category "Steuerkategorie" ("Steuerklasse" is an income tax bracket). Actions "Aktionen" is right for actions; Commerce's Sale needs a different word.
- **el:** Global Set "Καθολικό σύνολο", Globals Καθολικ- ("Γενικά" is General).
- **es:** ID "ID", Settings "Ajustes" ("Opciones" is Options). Commerce Adjustments "ajustes de precio", since "Ajustes" is Settings.
- **fa:** Passkey کلید عبور (رمز عبور is Password), Load بارگذاری (not لود).
- **fr:** Slug "Slug"; Handle "Identificateur". **fr-CA:** search indexes "index de recherche" (not "répertoires").
- **he:** Entry רשומה (not כניסה), Author מחבר (יוצר is Creator), License רישיון, Field Layout פריסת שדות, Draft טיוטה (not טיוטא), Hostname שם המארח.
- **hu:** Asset "Médiafájl", Assets "Médiafájlok" ("Eszköz" is Tool). Actions "Műveletek" ("Akciók" reads as promotions), Global Set "globális készlet", Globals "Globális adatok".
- **is:** Disabled "Óvirkt" ("Öryrkjar" means disabled people), Entry "Færsla" ("Inngangur" means introduction), Element "Þáttur" ("Frumefni" is a chemical element), Slug "Slóðarheiti" ("Snigill" is a snail), Feed "Straumur" ("Fæða" is food), Category Group "Flokkahópur", logs "annálar" ("Sjá annála" for "See logs"), Site "Vefur" ("Síða" is Page), Handle "Kerfisheiti" ("auðkenni" is ID), Global "víðvær" ("Almennt" is General), Characters "Stafir".
- **it:** Field Layout "Layout dei campi" (not "Struttura del campo"), Parent "Genitore" ("Principale" is Primary), UID "UID" (not "ID utente").
- **ja:** Author 投稿者 (作成者 is Creator), Global Set グローバルセット (グローバル設定 is Global Settings).
- **ko:** Author 작성자 (not 저자, a book's author), Post Date 게시 날짜, Notes 메모 (주의 is caution), Item 아이템 (항목 is Entry).
- **ky:** Trashed "Таштандыда" ("Себет" is Cart).
- **nb/nn:** Slug "Slug" (not "Lenke", which is Link), Handle "Handle" (not "Kodeord", a password).
- **nl:** Entry "Item", entries "items", entry type "itemtype". "Item" is neuter: "het item", "dit item", "een nieuw item". Not "Vermelding" (a mention or listing, rejected by Dutch users in [cms#21099](https://github.com/craftcms/cms/discussions/21099)), "Bericht" (Message), "Inhoud" (Content) or "Invoer" (Input). Post Date "Publicatiedatum". A draft is "concept". Handle "Handle" ("Ingang" is an entrance), Preferences "Voorkeuren" ("Eigenschappen" is Properties), Globals "Globale inhoud", Global Set "globale set" ("Algemeen" is General).
- **pl:** Entry "Wpis" (not "Pozycja"), Tag "Tag" to match "Grupa tagów", Revision "Wersja" (not "Zmiana").
- **pt:** European Portuguese. Parent "Pai" ("Parente" means a relative), Asset "Recurso", Time (of day) "Hora" ("Tempo" is a duration).
- **ru:** Slug "Ярлык" (not "Поле динамичных данных"), Tag "Тег" ("Метка" is Label). **uk:** Slug "Частина посилання" (not "Поле змінюваних даних").
- **sk:** Tag "Značka", Tag Group "Skupina značiek"; Label stays "Štítok". Asset "súbor". Labels use sentence case.
- **sv:** Handle "Handle" ("Hantera" is the verb; "handtag" is a door handle), Asset "Mediefil" ("Tillgång" is a financial asset), Entry Type "Inläggstyp".
- **th:** Author ผู้เขียน (ผู้สร้าง is close to Creator), logs บันทึกระบบ (บันทึก is Save), Global ส่วนกลาง (ทั่วโลก is worldwide), Landscape/Portrait แนวนอน/แนวตั้ง.
- **tr:** Global Set "Global küme" ("Genel" is General and Public; "Genel Etiket Kümesi" meant global tag set), Parent "Üst öge", Entry "Kayıt" ("Giriş" is Login), Asset "Dosya", Type "Tür", Email "E-posta", Create "Oluştur", Time (of day) "Saat" ("Süre" is a duration).
- **zh:** Slug 别名 (not 链接), Global Set 全局集 (全局设置 is Global Settings), Parent 父级 (not 根源), Active 已激活 (活动 is Event), Pending 待处理 (待定 means "to be decided"; 暂停 is Paused), "press" 按 for key shortcuts (单击 is a click), Invoice 账单 (发票 is a tax invoice).

## "{type}" strings

Most `{type}` sentences in Craft's translations either select over Craft's built-in type names with a neutral fallback or use a neutral phrase such as "this element ({type})". "New {type}" selects fall back to phrases such as de "Neues Element ({type})", fr "Nouvel élément ({type})", es "Nuevo elemento ({type})", pl "Nowy element ({type})", da "Nyt element ({type})", nb "Nytt element ({type})", el "Νέο στοιχείο ({type})", is "Nýr þáttur ({type})", ar عنصر جديد ({type}). Plugin element types get the fallback, so give a plugin's own "New …" strings their own correctly inflected keys only when the fallback reads badly.

Craft 5 releases before [cms#21126](https://github.com/craftcms/cms/pull/21126) format strings registered for JS with a `Craft.formatMessage()` that cuts each argument at its second comma. Plugins can run on those releases, so their JS strings still have to work with it. A plugin's JS string can't nest a typed argument such as `{type, select, …}` or `{num, number}` inside a plural or select, or put a comma in an option's text: the delete dialog stopped opening in eight languages that way ([cms#21100](https://github.com/craftcms/cms/issues/21100)). Use `#` for the count, the neutral "this element ({type})" form instead of a nested select, and rephrase around commas. check.php reports these.

## Not yet confirmed

Native speakers haven't checked these: hr "Dostupno", is "Slóðarheiti", "annálar", "Í loftinu", "Kerfisheiti", "víðvær" and "vistuð útgáfa", tr "Dosya" (WordPress uses "Ortam" for media), he גרסה שמורה, ko 아이템, it "Genitore", sv "Mediefil", cs/sk "soubor"/"súbor" for Asset, pt "Recurso" (also Resources), ky "Таштандыда", and Commerce es Adjustments "ajustes de precio". fr "En ligne" and pl/sk "Online" also translate the system-status toggle "Online", which means the same thing. Raise doubts rather than reverting them silently.
