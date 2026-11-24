## Summary
<!-- Briefly describe which language was added or which sections of the Russian manual were corrected. -->

## Contribution Type
- [ ] New manual language
- [ ] Corrections to the Russian manual (`docs/i18n/target_ru/manual_ru_RU.properties`)

## Commands Run
<!-- Confirm or paste the exact CLI commands you executed: -->
```bash
typst-xlatory --config docs/docs.yaml --import
typst compile --root docs docs/out_<lang>/manual.typ pdf/manual_<lang>.pdf
```

## Verification Checklist
- [ ] This PR covers only one language or a focused set of Russian corrections (no unrelated code refactoring).
- [ ] `docs/docs.yaml` has been updated (if adding a new language).
- [ ] `typst-xlatory --config docs/docs.yaml --import` was executed and the regenerated `docs/out_<lang>/` files are included in this PR.
- [ ] The reconstructed `.typ` files compile cleanly with `typst compile --root docs ...` without errors.
- [ ] No compiled `.pdf` files (or the `pdf/` directory) are included in the commit.
- [ ] I visually inspected the resulting PDF for layout, line breaks, and character rendering.

## Screenshots / Notes (optional)
<!-- If you fixed layout-sensitive wording or noticed any edge cases, feel free to share details or a screenshot here. -->
