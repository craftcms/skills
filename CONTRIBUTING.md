# Contributing

This repository holds [Agent Skills](https://github.com/agentskills/agentskills) for helping developers work with Craft CMS and Craft Commerce.

## Structure

Each skill lives in its own directory under `skills/`:

```text
skills/
└── <skill-name>/
    ├── SKILL.md       # Required: metadata and instructions
    ├── scripts/      # Optional: executable helpers
    ├── references/   # Optional: supporting documentation
    └── assets/       # Optional: templates and other resources
```

## Adding a skill

To have an agent help you draft, test, and refine a skill, install Anthropic's [`skill-creator`](https://www.skills.sh/anthropics/skills/skill-creator):

```sh
npx skills add https://github.com/anthropics/skills --skill skill-creator
```

To write one by hand:

1. Create `skills/<skill-name>/SKILL.md`.
2. Start it with YAML frontmatter containing `name`, `description`, and `license: MIT`. The `name` must match the directory name, be 1–64 characters, and contain only lowercase letters, numbers, and single hyphens (no leading or trailing hyphens). The `description` must be 1–1024 characters and explain what the skill does and when to use it.
3. Write a focused workflow with examples, edge cases, and validation steps. State any applicable Craft CMS or Commerce versions and prerequisites.
4. Add supporting files only as needed, linking to them using paths relative to `SKILL.md`. Leave out optional directories the skill doesn't use.

Follow the [Agent Skills specification](https://agentskills.io/specification). If you have the upstream [`skills-ref`](https://github.com/agentskills/agentskills/tree/main/skills-ref) validator installed, run:

```sh
skills-ref validate skills/<skill-name>
```
