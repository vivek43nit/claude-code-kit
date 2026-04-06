# Contributing to claude-code-kit

Thank you for contributing! This project is a shared baseline for Claude Code
configuration — quality and clarity matter more than quantity.

## Types of Contributions

| Type | Welcome? | Notes |
|------|----------|-------|
| Bug fixes in hooks or install.sh | Yes | Include a failing test case |
| New language guidelines | Yes | Follow the template below |
| New universal guideline | Discuss first | Open an issue before writing |
| Changes to base.md | Discuss first | Affects every project |
| CI template improvements | Yes | Test in a real repo first |
| Typo / clarity fixes | Yes | No issue needed |

## Before You Start

For anything beyond a typo fix, open a GitHub Issue first:
- Describe the problem or gap you see
- Wait for maintainer acknowledgement before opening a PR
- This prevents duplicate work and wasted effort

## Development Setup

```bash
git clone https://github.com/<your-fork>/claude-code-kit
cd claude-code-kit
# No dependencies — pure bash + markdown
```

Run the test suite:

```bash
bash .claude/hooks/test-detect-languages.sh
bash .claude/hooks/test-security-scan.sh
```

All tests must pass before submitting a PR.

## Adding a New Language

1. Create `guidelines/<lang>.md` following this structure:

```markdown
# <Language> Guidelines

**Style guide:** [link to official style guide]

## Style
[Key style rules — max 10 bullet points]

## Types / Type Safety
[Static typing conventions]

## TDD in <Language>
[Test framework, naming convention, example test]

## Error Handling
[Error handling idiom for this language]

## Tooling
[Linter, formatter, test runner]
```

2. Add detection logic to `.claude/hooks/detect-languages.sh`:

```bash
# <Language>
if manifest_exists "<manifest-file>" || has_files "*.<ext>"; then
    DETECTED+=("<lang>")
fi
```

3. Add a test case to `.claude/hooks/test-detect-languages.sh`:

```bash
run_test "detects <Language> via <manifest>" "$(
    dir=$(mktemp -d)
    touch "$dir/<manifest-file>"
    bash "$SCRIPT" "$dir" >/dev/null 2>&1
    grep -c "<lang>" "$dir/guidelines/active.md"
)" "1"
```

4. Add CI lint/test step in `ci/github/quality-gates.yml` and `ci/gitlab/quality-gates.yml` for the new language.

5. Run all tests — they must pass.

## Pull Request Process

1. Fork the repo and create a branch: `feat/<short-desc>` or `fix/<short-desc>`
2. Make your changes following the conventions above
3. Run both test scripts — all tests must pass
4. Open a PR with:
   - A clear title following [Conventional Commits](https://www.conventionalcommits.org/) format
   - A description explaining *why* (not just what changed)
   - A link to the issue it resolves (e.g. `Closes #42`)
5. A maintainer will review within 5 business days
6. Address review comments — we aim for 1 review round
7. Maintainer merges once approved

## PR Checklist

- [ ] Tests pass (`bash .claude/hooks/test-detect-languages.sh && bash .claude/hooks/test-security-scan.sh`)
- [ ] New language: detection + guideline file + test case + CI step all added together
- [ ] No hardcoded secrets or credentials
- [ ] Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`)
- [ ] PR description explains *why*, links to the issue

## Code of Conduct

Be respectful. Critique ideas, not people. This is a blameless, collaborative project.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
