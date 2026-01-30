# Roblox Development Skills

Agent skills for professional Roblox game development with Luau.

## Installation

```bash
# Install all skills
npx skills add dig1t/skills

# Or install specific skills
npx skills add dig1t/skills --skill luau-type-expert
npx skills add dig1t/skills --skill luau-best-practices
npx skills add dig1t/skills --skill rojo-pro
```

## Available Skills

### luau-type-expert

Professional Luau type-checking specialist for writing type-safe Roblox code.

**Use when:**
- Writing or reviewing code that needs proper type annotations
- Fixing type errors from luau-lsp or luau-analyze
- Converting untyped Lua/Luau to strictly typed code
- Designing type-safe APIs and data structures
- Understanding generics, unions, intersections, refinements
- Setting up `--!strict` mode compliance

**Includes:**
- Type annotation syntax and patterns
- Generic types and constraints
- Type narrowing/refinements
- Metatable typing patterns
- Common error fixes
- Lint rules reference
- Performance-aware typing

### luau-best-practices

Clean code patterns and production-quality practices for Roblox development.

**Use when:**
- Writing new modules, services, or controllers
- Reviewing code for quality and maintainability
- Setting up project structure
- Implementing error handling
- Managing memory and preventing leaks
- Writing secure server-authoritative code

**Includes:**
- Code style and naming conventions
- Service/Controller patterns
- State machines, object pools, signals
- Error handling with Result types
- Memory management and Maid pattern
- Security best practices and validation
- Rate limiting patterns

### rojo-pro

Expert guidance for Rojo filesystem sync and professional development workflows.

**Use when:**
- Setting up Rojo projects
- Configuring project.json files
- Troubleshooting sync issues
- Multi-environment setups (dev/staging/prod)
- Integrating with Wally and Aftman

**Includes:**
- Project configuration patterns
- File naming conventions
- Wally package management
- CI/CD workflows
- Common troubleshooting solutions

## Compatibility

These skills work with:
- [Claude Code](https://claude.ai/code)
- [Cursor](https://cursor.sh)
- Other agents supporting the skills format

## Links

- [skills.sh](https://skills.sh) - Discover more skills
- [Rojo](https://rojo.space) - Filesystem sync for Roblox
- [Luau](https://luau-lang.org) - Roblox's programming language
