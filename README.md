# Craft CMS Skills

[Agent Skills](https://github.com/agentskills/agentskills) for helping developers work with Craft CMS and Craft Commerce.

## Skills

| Skill | Description |
| --- | --- |
| [`craft-6-plugin-upgrade`](skills/craft-6-plugin-upgrade/SKILL.md) | Walks a developer and their agent through upgrading a Craft 5 (Yii 2) plugin or module to Craft 6 (Laravel) in stages, from running on 6.x with the Yii 2 adapter to native Laravel code. Craft 6 is in alpha, so the bundled docs snapshot may lag behind. |

## Structure

Each skill lives in its own directory under `skills/`:

```text
skills/
└── example-skill/
    ├── SKILL.md       # Required: metadata and instructions
    ├── scripts/      # Optional: executable helpers
    ├── references/   # Optional: supporting documentation
    └── assets/       # Optional: templates and other resources
```

[`example-skill`](skills/example-skill/SKILL.md) is a template for contributors, not an implemented Craft CMS or Commerce skill.

## Adding a skill

1. Copy `skills/example-skill/` to `skills/<skill-name>/`.
2. Update the YAML frontmatter in `SKILL.md`. The `name` must match the directory name, be 1–64 characters, and contain only lowercase letters, numbers, and single hyphens (no leading or trailing hyphens). The `description` must be 1–1024 characters and explain what the skill does and when to use it.
3. Replace the placeholder instructions with a focused workflow, examples, and validation steps. State any applicable Craft CMS or Commerce versions and prerequisites.
4. Add supporting files only as needed, linking to them using paths relative to `SKILL.md`. Remove unused optional directories and `.gitkeep` placeholders when adding files.

Follow the [Agent Skills specification](https://agentskills.io/specification). If you have the upstream [`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref) validator installed, run:

```sh
skills-ref validate skills/<skill-name>
```
