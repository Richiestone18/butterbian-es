# Tools v6: how the translation is generated (and how to make the next one)

The v6 generator lives INSIDE the package (`~/Documentos/butterbian-es`), which
is self-contained: the butterdwm clone and the staging are in `work/`.

## For a new butterdwm version

A single command from the package root:

```sh
bash tools/regenerate.sh --new <commit>
```

Options:

- `--new <commit>`   commit/tag/branch of butterdwm to translate (required)
- `--base <commit>`  commit of the previous version; by default it is read from
                     the current `manifest.txt`
- `--repo <url|path>` clone to use; by default
                     `https://codeberg.org/justaguylinux/butterdwm.git`
- `--package`        also regenerate `payload/`, `manifest.txt` and `shortcuts.tsv`
- `--no-tests`       do not run `test-v6.sh` when done

What it does (4 steps, each an independent script in `tools/`):

1. **`dict_v6.py`** — ACCUMULATED English→Spanish dictionary. It aligns the
   current payload with its base commit (`--base`), extracts pairs (phrase,
   context), MERGES them into `tools/dictionary.tsv` (persistent: it grows on
   every regeneration, so phrases that reappear or move between files stay
   covered) and applies the full dictionary to the new butterdwm →
   `work/v6/suckless`. Pending items and conflicts are reported in
   `work/v6-report.json`.
2. **`build_v6.py`** — applies three lists with REGEX ANCHORS (tolerant to
   upstream reformats):
   - `REVERT`: texts that are data and stay in English;
   - `T`: translations of the new stuff the dictionary did not cover;
   - `P`: functional fixes (battery, clock, calendar, power menu...).
   - Validation: outside the patches only text inside quotes may change
     (golden rule: geometry intact). Check the final `PROBLEMS` list.
3. **`keybinds_v6.py`** — `keybinds.conf` descriptions (reading `shortcuts.tsv`,
   the single source), automatic labels of `scripts/keybinds` and section names
   in `KeybindsPane.qml`.
4. **`scripts_v6.py`** — script notices and menus.

And then:

5. **`package_v6.py --version v6`** (run by `--package`) — writes `payload/`,
   `manifest.txt` and `shortcuts.tsv`.
6. **`test-v6.sh <package> <English suckless> [<expected v6>]`** — 6 tests on a
   temporary copy (--check, apply, idempotence, --restore, user edits, another
   version); with `MIX=~/.config/suckless` and `EXPECTED_V6` it adds the test 7
   of a mixed machine.

## When regenerating

1. Review the build's `PROBLEMS` (translations not applied, patches that did
   not align, changes outside quotes).
2. Review in context every new text the program may use as data (comparisons,
   commands, fields) and add what is missing to `REVERT` or to `T`/`P` with a
   regex anchor.
3. Verify the output stays faithful to the previous one: against the same base
   commit, `regenerate.sh --new a511dab --base a511dab` must reproduce the
   payload byte by byte (the regression test).
4. Test on a real machine and check the bar log:
   `qs log -p ~/.config/suckless/quickshell | grep -iE 'error|warn'`.
5. The accumulated dictionary (`dictionary.tsv`) is not edited by hand; if a
   payload translation was wrong, fix it in the payload and regenerate (the
   merge detects the change and reports a conflict).
