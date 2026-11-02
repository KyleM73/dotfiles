---
name: refcheck
description: Verify every citation in Kyle's papers repo (~/projects/papers) exists online with the correct title, authors, year, venue, and DOI. Use whenever references are added or edited, before any submission or Overleaf push, when asked to check/verify/audit citations or the bibliography, and whenever a .bib file changes. Zero tolerance - every entry must end VERIFIED or be flagged to Kyle.
---

# refcheck: zero-tolerance citation verification

Kyle has **zero tolerance for incorrect citations**. RSS and other venues
desk-reject papers with hallucinated references. Every entry in every `.bib`
in the papers repo must be confirmed against a real online record. Anything
wrong or unconfirmed gets flagged to Kyle **immediately**.

## 1. Run the automated pass (covers every citation in the repo)

```bash
cd ~/projects/papers
./km refs check            # all tracked .bib files; ~10-15 min cold, fast when cached
# narrower: ./km refs check --bib works/<slug>/paper/references.bib
#           ./km refs check --key key1,key2      --fresh  (ignore cache)
```

It reads every tracked `.bib`. From template sample bibs listed in
`tools/refcheck-exclude.txt`, it only checks entries that are actually cited.
It queries Crossref (DOI and search), arXiv (id and title), and OpenAlex,
and writes `build/refcheck/report.md` plus `report.json`.

Verdicts: `VERIFIED`, `CHECK` (found, but the author list, venue, or year
off by one needs a look), `MISMATCH` (found, but the title, first author,
year, or DOI is wrong), `NOT_FOUND`. The report also lists **UNDEFINED**
keys (cited but no bib entry) and **INLINE `\bibitem`** references
(never auto-verified).

## 2. Resolve every non-VERIFIED item yourself, online

Don't stop at the script. For each `MISMATCH`, `NOT_FOUND`, `CHECK`,
`UNDEFINED`, and inline `\bibitem`:

1. Search for the work: WebSearch with the exact title in quotes, then
   WebFetch the best hits. Use arXiv abs pages, the publisher (IEEE Xplore,
   ACM DL, Springer, PMLR, OpenReview, RSS proceedings at
   roboticsproceedings.org), DBLP, and Google Scholar.
2. Confirm **title, full author list in order, year, venue, and DOI/arXiv
   id** against the authoritative page. A published version beats an arXiv
   preprint.
3. Record the evidence (URL) for each conclusion.

Common false alarms: workshop papers and theses that aren't indexed (confirm
on the workshop site or the PDF in the repo), software or datasets
(`@misc`/`@software`, confirm the URL resolves), year off by one between
arXiv and the proceedings (cite the version actually used). These still need
evidence. They just aren't errors.

## 3. Report to Kyle immediately, before anything else

Lead with the problems, in a table:

| key | file(s) | problem | what the source says | evidence |
|---|---|---|---|---|

Then: counts by verdict, and which documents cite each bad entry
(active/synced papers first, especially anything with a deadline).

## 4. Fixes

- Never invent, guess, or "complete" an entry from memory. Every field must
  come from the source you fetched.
- Propose each correction (old → new, with the URL) and apply it only after
  Kyle confirms. Bib entries are references, so agents may edit them, but
  only to match a verified source.
- After a fix: update the copy in every `.bib` that has the key
  (`./km bib dups` lists them), keep `bib/references.bib` in sync, and rerun
  `./km refs check --key <key>` until it is VERIFIED.
- Never edit paper prose (AGENTS.md rule 1). If a citation needs to change
  in the text (wrong key, citing a retracted work), tell Kyle.
- No agent attribution anywhere in the repo, including commit messages
  (AGENTS.md rule 2).
