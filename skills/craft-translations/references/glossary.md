# Craft concepts

What the Craft terms in control panel strings mean, condensed from the Craft glossary. Use it to pick a translation that names the right thing. The notes after a dash say what a term is easily confused with.

## Content

- **Element:** the core unit of content. Entries, assets, categories, tags, global sets, users, and addresses are all elements. Translate it as a generic "item" or "element", not a chemical or HTML element.
- **Element type:** a kind of element, such as entries or assets. Plugins add their own, such as Commerce's products and orders.
- **Entry:** the most flexible content container, usually belonging to a section, or nested in a Matrix or CKEditor field. A piece of content, like a post or record. Not an entrance, a login, or a journal entry in the accounting sense.
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
- **Global set:** an element holding content used across a site, such as a footer or contact details. It holds content, not settings or global configuration.
- **User:** a person with an account. **Admin** is a user with unrestricted access. A **user group** is a role that collects permissions.
- **Author:** a user attached to an entry as its author. New entries get the current user. Not the creator of a file or the owner of a record.
- **Address:** an element storing a location, belonging to a user or another element.
- **Nested element:** an element owned by another element, such as the entries in a Matrix field or a user's addresses. The owning element is its **owner**.
- **Relation:** a link between elements, made with a relational field such as Entries or Assets.
- **Content:** the text, options, and media users add to elements.

## Drafts and statuses

- **Canonical:** the main version of an element, as opposed to its drafts and revisions.
- **Draft:** unpublished edits to an element, which can be applied to it later. A **provisional draft** holds unsaved changes visible only to the person editing.
- **Revision:** a saved copy of an element's earlier state, which can be viewed or restored. Not a review.
- **Status:** an element's state, such as Live, Pending, Expired, or Disabled, built from whether it's enabled and, for entries, its post and expiry dates.
- **Enabled:** the main status switch for an element. Disabled elements aren't shown on the site. A software "on/off" sense, not a disability sense.
- **Live:** published and visible right now. In "live element" strings, the current published version rather than a draft.
- **Trash:** soft-deleted elements, which can be restored until garbage collection removes them. **Soft delete** marks something as deleted without removing it yet.
- **Propagation:** how an element and its field values are created and kept in sync across sites. Not advertising or plant propagation.

## Fields and layouts

- **Field:** a custom field added to a field layout, such as a Plain Text or Assets field. Not a field of land or a sports field.
- **Field type:** the kind of field, which sets its input and stored value, such as Plain Text, Dropdown, Lightswitch, or Matrix.
- **Field layout:** the tabs, fields, and conditions that make up an element's edit form.
- **Matrix:** a field that manages a set of nested entries. Keep the product name; it isn't a mathematical matrix.
- **Lightswitch:** a field with an on/off toggle.
- **Handle:** a stable, machine-readable name (letters and numbers) for a field, section, entry type, and so on, used in templates. Not a door handle, and not the verb "to handle".
- **Slug:** the human-readable, URL-friendly part of a URI that identifies a piece of content. Not the animal, and not a whole link.
- **Condition:** one rule in a condition builder. A **condition builder** combines rules to filter elements or decide when a field or tab shows.
- **Generated field:** a field whose value is computed from a template instead of edited.

## Sites and localization

- **Site:** one of a project's sites, often one per language or brand. A project can have many. **Site group:** a set of sites.
- **Project:** a single Craft installation.
- **Translation:** content managed per site or language, or interface text passed through `Craft::t()`.

## Control panel

- **Control panel:** Craft's administration interface, where users sign in to manage content and settings. Not a hardware control panel.
- **Dashboard:** each user's customizable start screen, made of **widgets**.
- **Element index:** a table or grid of elements, with **sources** in its sidebar. A source is a predefined set of elements, such as one section's entries.
- **Live Preview:** previewing an element's changes side by side while editing. A **preview target** is a page the element can be previewed on.
- **Settings:** the screens where admins configure sections, fields, sites, and so on. They're read-only when admin changes aren't allowed.
- **Utility:** a back-office page, such as Caches or Queue Manager.
- **Queue:** background tasks waiting to run. Each one is a **job**. A job that's "released" is let go of, not published.
- **Permission:** a capability granted to a user directly or through a user group.
- **User preference:** a user's own settings, such as language and accessibility options.
- **Project config:** Craft's record of a project's schema and settings, kept in files and applied to other environments.
- **Edition:** a product tier, such as Solo, Team, or Pro. Not a book edition or an edit.
- **License:** the terms under which a project uses Craft or a plugin.
- **Plugin:** an extension to Craft. **Plugin Store:** where plugins are found and licensed.
- **Logs:** records of what happened during requests, including warnings and errors.
- **Deprecation warning:** a notice that code uses something scheduled for removal.

## Craft Commerce

- **Product:** an element that holds one or more **variants**. A **product type** defines its fields, variants, and URLs.
- **Variant:** a specific purchasable version of a product, with its own price, SKU, and dimensions.
- **Purchasable:** anything that can be added to a cart. Variants and donations are built in, and plugins add others.
- **Donation:** a purchasable whose amount the customer chooses.
- **Order:** an element for a completed purchase. Before checkout, the same element is a **cart**.
- **Line item:** one purchasable in a cart or order, with its quantity and options.
- **Customer:** a user with Commerce information such as orders, addresses, and payment sources.
- **Adjuster:** part of order totaling that applies discounts, tax, and shipping as **adjustments**.
- **Discount:** an adjuster that applies special pricing. **Sale** is the older promotion feature that catalog pricing replaced.
- **Catalog pricing:** the system that works out each variant's price from pricing rules.
