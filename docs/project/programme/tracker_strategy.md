# Programme tracking strategy

**Reviewed:** 2026-09-29

## Decision principle

The Git repository remains the canonical programme source of truth. The tracker is an execution view, not the only copy of scope, status, dependencies or acceptance criteria.

This matters because work must remain accessible from Dell, ASUS and future agent sessions even if a SaaS integration or local service is unavailable.

## Preferred option: Linear Free, if owner wants the Linear workflow

Current Linear Free limits are sufficient to start this programme:

- $0;
- unlimited members;
- 2 teams;
- 250 issues;
- projects, cycles and initiatives;
- API and webhook access.

Recommended structure:

- one team: `Visual / Doxa`;
- use **Projects**, not separate Linear teams, for the programme streams;
- copy stable IDs from `work_breakdown.md` into issue titles/descriptions;
- keep project documents linked back to `docs/project/programme/`.

Suggested Linear Projects:

1. Visual - Two-screen Product
2. Doxa - Installer & Hardware Enablement
3. Doxa - Four-screen Workspace
4. Quality, Release & Support
5. Ask Visual / Assistance
6. Competitive & Commercial Research

Do not buy Linear Basic yet merely to start. The current Free issue/team limits are adequate for the initial backlog. Basic becomes relevant if the programme needs more than 250 active/history issues or more team-level separation. Linear currently advertises Basic at $10/user/month when billed yearly, with unlimited issues and up to 5 teams.

### Current integration state

The repository bridge contains Linear tools, but they currently report:

`Linear integration is disabled: LINEAR_API_KEY is not configured in .env`

To enable agent access, create a personal Linear API key with only the permissions/team scope required, then configure the bridge secret locally. Never commit the key to the repository.

Official references:

- https://linear.app/pricing
- https://linear.app/docs/api-and-webhooks

## Strong fallback: GitHub Projects

GitHub is already the code/release host for Visual, so this requires no additional project-management service.

GitHub Projects supports:

- repository issues and pull requests;
- table, board and roadmap views;
- custom fields such as Stream, Phase, Priority, Hardware Gate and Status;
- iterations and date fields;
- automation around issue/PR state.

Recommended structure:

- one Project: `Visual / Doxa Programme`;
- issues remain in the Visual repository;
- create views filtered by the stable work-item prefix (`VIS-`, `INS-`, `D4-`, etc.) or a custom Stream field.

Advantages here are zero new subscription, natural code/PR linkage, and cross-desktop availability. The main disadvantage versus Linear is product-planning UX/preference rather than missing core tracking capability.

Official references:

- https://github.com/pricing
- https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects

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
2. **Preferred execution UI:** create a Linear Free workspace/team if the owner prefers Linear's UX; no paid subscription is required initially.
3. **Fallback with no extra service:** use GitHub Projects immediately.
4. **Do not build a local-only tracker on one development laptop.** If self-hosting is desired later, host centrally.

This keeps the programme tool-portable: moving from Linear to GitHub/Plane later does not require reconstructing the plan from a proprietary tracker database.
