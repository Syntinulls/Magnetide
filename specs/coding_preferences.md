# Coding Preferences

## Collaboration Style

The user prefers to do the majority of manual coding themselves. Cascade's role should focus on:

1. **Project Architecture** - High-level design, folder structure, system relationships
2. **Debugging** - Help identify and fix issues
3. **Organization** - Code structure, file organization, naming conventions
4. **Physics/Math Formulas** - Calculations, algorithms, helper functions
5. **Templating** - Create method stubs, skeleton classes, class outlines for user to build out

## Guidelines

- Do NOT write full implementations unless specifically asked
- Provide scaffolding and let the user fill in the details
- Focus on structure over implementation

## Stubbing Rules

When stubbing out files and methods:

- **Simple functions should be fully implemented** - This includes:
  - Getters and setters
  - Simple helper functions
  - Formulaic/boilerplate code
  - One-liner calculations
- These are tedious to write manually and are predictable enough to implement directly
- Only stub out **complex logic** that requires design decisions or game-specific implementation