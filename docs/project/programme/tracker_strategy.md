# Programme tracking strategy

**Reviewed:** 2026-09-29

## Decision principle

The Git repository remains the canonical programme source of truth. The tracker is an execution view, not the only copy of scope, status, dependencies or acceptance criteria.

This matters because work must remain accessible from Dell, ASUS and future agent sessions even if a SaaS integration or local service is unavailable.

## Selected execution tracker: GitHub Projects

GitHub Projects is selected for this programme.

Reasons:

- GitHub is already required for the Visual repository, releases and release automation;
- one owner plus a small number of coding/research agents does not justify an additional project-management service;
- issues can link directly to commits, pull requests, releases and repository documentation;
- table, board and roadmap views plus custom fields are sufficient for the current programme;
- it is available from Dell, ASUS and remote/agent sessions without hosting another service.

Recommended structure:

- one GitHub Project: `Visual / Doxa Programme`;
- repository issues carry the stable IDs from `work_breakdown.md` in their titles, e.g. `[VIS-001] ...`;
- use custom fields for `Stream`, `Phase`, `Priority`, `Hardware Gate` and `Status` if useful;
- create filtered views for Visual, Installer/Hardware, Four-screen Doxa, Ask Visual, Quality/Release, Low-vision Research and Broader Doxa Research;
- issue descriptions should link back to `docs/project/programme/` and preserve the canonical completion criteria.

The Git repository remains authoritative. GitHub Projects is the execution/status surface.

Official references:

- https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects
- https://github.com/pricing

## Alternative retained only if needs change: Linear

Linear Free remains technically adequate for the current issue count, but it is no longer the selected tool. There is no reason to add another SaaS dependency while GitHub Projects meets the programme needs.

The existing repository bridge also reports that its Linear integration is disabled because `LINEAR_API_KEY` is not configured. No action is required unless the programme later chooses to revisit Linear.
## Open-source / self-hosted alternative: Plane

Plane is the strongest lightweight open-source alternative considered for this programme. Its cloud Free plan provides projects/work items, cycles/modules, views, intake, estimates and project pages. It can also be self-hosted with Docker; current documentation gives a starting requirement around 2 CPU cores and 4 GB RAM.

However, **do not self-host the programme tracker only on Dell or only on ASUS**. Whichever laptop is off would make the tracker unavailable to the other machine and to remote/agent sessions.

If Plane is chosen for independence from Linear/GitHub, use either:

- Plane Cloud Free; or
- a centrally reachable always-on host/VPS/NAS with backups.

Official references:

- https://plane.so/pricing
- https://developers.plane.so/self-hosting/methods/docker-compose

## Heavier open-source alternative: OpenProject

OpenProject Community is free/open source and supports unlimited users/projects when self-hosted. It is credible for a larger organisation, but it introduces more server/operations overhead than this programme currently needs.

Use it only if stronger traditional project-management/governance features justify running and maintaining a central service.

Official references:

- https://www.openproject.org/community-edition/
- https://www.openproject.org/docs/installation-and-operations/

## Recommendation

1. **Canonical:** keep the inventory, roadmap, work IDs and handover in Git (`docs/project/programme/`).
2. **Execution UI:** use one GitHub Project, `Visual / Doxa Programme`, backed by repository issues carrying the stable work IDs.
3. **No additional subscription is needed.**
4. **Do not build a local-only tracker on one development laptop.**

This gives the next chat/agent a simple operating model: read the programme docs, pick or create the matching GitHub issue, do the work in the repository, and update both issue status and canonical evidence when the work is complete.