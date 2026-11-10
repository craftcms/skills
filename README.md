# Craft CMS Skills

Skills for AI coding agents working with Craft CMS and Craft Commerce. A skill is a packaged set of instructions, references, and scripts that an agent loads when a task calls for it.

Skills follow the [Agent Skills](https://agentskills.io/) format and can be installed with `npx skills add`.

## Available skills

### commerce-6-gateway-plugin-upgrade

Upgrades a Craft Commerce 5 payment gateway plugin to Commerce 6 as a native Craft 6 plugin. Omnipay is deprecated and isn't ported to Commerce 6, so the gateway calls the provider's API directly.

**Use when:**

- Making a Commerce gateway plugin compatible with Commerce 6
- Removing Omnipay or `craftcms/commerce-omnipay` from a gateway

**Covers:**

- Assessing the gateway with a scan script, and checking the provider's API and SDK are still alive
- The package, plugin class, gateway registration, and keeping saved gateways loadable
- Replacing Omnipay with a small HTTP client, response classes, and amounts in minor units
- Gateway settings with `settingsUi()` and payment forms with `paymentFormUi()`
- Webhooks: verification, locking, idempotency, and recording child transactions
- Tests with faked provider responses, CI, `UPGRADE.md`, and the PR

---

### craft-6-plugin-development

Builds a new Craft 6 (Laravel) plugin step by step, with an Orchestra Testbench workbench inside the plugin repository for manual checks and Pest tests.

**Use when:**

- Creating or scaffolding a new Craft 6 plugin
- Adding features to an existing Craft 6 plugin

**Covers:**

- The Composer package, plugin class, and settings
- Routes, controllers, and control panel pages with the `Ui` builder and Vue/Inertia
- Permissions, migrations, and events
- Field types, widgets, Twig extensions, jobs, and commands
- Testing in the workbench with Pest

---

### craft-6-plugin-upgrade

Upgrades a Craft 5 (Yii 2) plugin or module to Craft 6 (Laravel) in stages: first make it run on 6.x with the Yii 2 adapter, then move each area to native Laravel code and remove the adapter.

**Use when:**

- Making a Craft plugin or module compatible with Craft 6
- Moving plugin code from Yii 2 APIs to Laravel
- Removing a plugin's dependency on `craftcms/yii2-adapter`

**Covers:**

- Assessing the plugin with a scan script and picking an end state (ship on the adapter, or go adapter-free)
- The plugin class, services and dependency injection, events, and registries
- Controllers, requests, auth, element types, fields, widgets, and forms
- Models and validation, database code, templates and Twig, and tests
- Keeping an `UPGRADE.md` for the plugin's users
- A snapshot of the Craft 6.x extension docs

---

### craft-6-project-upgrade

Upgrades a Craft 5 project (site) to Craft 6 in stages: preflight on 5.x, run the `craft6-revamp` tool, install and migrate, fix and verify, then clear deprecations and optionally remove the Yii 2 adapter.

**Use when:**

- Upgrading, migrating, or moving a Craft 5 site to Craft 6
- Checking whether a project and its plugins are ready for Craft 6

**Covers:**

- Preflight checks on Craft 5 and the plugin dependency graph
- Running `craft6-revamp` and installing Craft 6
- Database migrations and verification
- Clearing deprecations and the optional adapter-free path

Craft 6 is still pre-release. When a skill and Craft disagree, the skills trust the installed Craft source first, then the published 6.x docs.

## Installation

Install all skills:

```shell
npx skills add craftcms/skills
```

Or install specific skills:

```shell
npx skills add craftcms/skills --skill craft-6-plugin-development
npx skills add craftcms/skills --skill craft-6-plugin-upgrade
npx skills add craftcms/skills --skill craft-6-project-upgrade
npx skills add craftcms/skills --skill commerce-6-gateway-plugin-upgrade
```

List available skills:

```shell
npx skills add craftcms/skills --list
```

List installed skills:

```shell
npx skills list
```

## Usage

Once a skill is installed, the agent uses it when a task matches. For example:

```
Create a Craft 6 plugin that adds a dashboard widget
```

```
Upgrade this plugin to Craft 6
```

```
Upgrade my Craft 5 site to Craft 6
```

```
Remove the Yii 2 adapter from my plugin
```

```
Upgrade this Commerce gateway plugin to Commerce 6 without Omnipay
```

## Skill structure

Each skill lives in `skills/<skill-name>/` and contains:

- `SKILL.md`: instructions with YAML frontmatter (name, description, compatibility)
- `references/` (optional): detailed guides the agent reads as needed
- `scripts/` (optional): helpers the agent runs, such as scans and checks
- `assets/` (optional): templates and other files

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add or change a skill.

## License

[MIT](LICENSE)
