# Visual Assistant knowledge layer

This directory is the curated/read-only knowledge boundary for the optional cloud-backed `Ask Visual` fallback.

## Why it exists

Muse should be able to interpret:

1. the user's question;
2. Visual's minimal structured runtime state;
3. authoritative current Visual implementation evidence; and
4. familiar ZoomText, SuperNova and Windows Magnifier terminology.

It must **not** receive arbitrary repository access, credentials, screenshots, document contents or unrelated user files.

## Evidence precedence

For answers about current Visual behavior, evidence is ranked as follows:

1. **Current Visual source mirror / current Visual docs** - authoritative for what Visual presently implements.
2. **Official incumbent documentation** - authoritative only for the named incumbent product (ZoomText, SuperNova, Windows Magnifier).
3. **Project migration research** - interpretation and design rationale only; it must not override current source or official incumbent documentation.

The Worker states these precedence rules in every model request.

## Curated incumbent knowledge

`incumbent_knowledge.json` contains short, paraphrased, source-attributed entries based on public official material. It deliberately does not copy full third-party manuals.

Current official sources include:

- Freedom Scientific / Vispero ZoomText User Guide and Getting Started material;
- Dolphin SuperNova manuals, Learning Zone and transition terminology material;
- Microsoft Windows Magnifier support documentation;
- the project's own mental-model/migration research as a clearly lower-authority interpretation source.

Each entry records its public source URL and source role.

## Read-only Visual source mirror

`source-mirror/` is generated from an explicit allowlist in `build-knowledge.ps1`. It contains only Visual runtime/help/tracking/settings files useful for answering product questions. It excludes cloud credentials, environment files, setup secrets and unrelated repository material.

The mirror is not used by the Visual executable. The cloud model cannot write to it. The Worker bundles it as retrieval chunks and sends only a small set of relevant excerpts for each question.

The manifest records a SHA-256 hash for every mirrored file plus an aggregate source-tree digest.

Generate/update:

```powershell
.\support\doxa-cloud\visual-assistant-knowledge\build-knowledge.ps1
```

Check that the mirror still matches the canonical source files:

```powershell
.\support\doxa-cloud\visual-assistant-knowledge\build-knowledge.ps1 -Check
```

A source change to an allowlisted file makes `-Check` fail until the mirror is deliberately regenerated.

## Retrieval

The generated `../visual-assistant-worker/worker.js` contains the curated evidence and source-mirror chunks. The Worker performs deterministic lexical/synonym retrieval locally before calling Dify. Typical requests send at most seven chunks and roughly 12 KB of retrieved evidence rather than the full mirror.

This gives Muse enough implementation context to explain current behavior while keeping repository exposure bounded and auditable.

## Updating incumbent material

When an incumbent product changes:

1. verify the change against an official source;
2. update the relevant paraphrased entry in `incumbent_knowledge.json`;
3. retain the public source URL and date note;
4. regenerate the bundle;
5. test at least one migration query for the changed concept.

Do not paste whole commercial manuals or proprietary assets into this directory.