# Vision prompting instructions - Claude Opus 5.5

Date: 2026-09-29
Status: current reusable Vision prompting reference
Source basis: adapted from the AiGov Opus 5.5 prompting guide stored in C:\dev\AiGov-monorepo on ASUS-DESKTOP-HOME, dated 2026-09-23.

## Purpose

Use these instructions when Vision asks Claude Opus 5.5 to review architecture, product scope, implementation readiness, multi-monitor design, technical/commercial synthesis, or another high-consequence long-horizon decision.

Opus is a reviewer/arbitrator unless the work order explicitly authorises implementation. It should challenge the proposal, not merely polish it.

## Opus 5.5 operating assumptions

- Thinking is always on; use effort rather than trying to disable thinking.
- Do not ask for hidden chain-of-thought; ask for decision-relevant rationale, evidence, assumptions and uncertainty.
- Do not depend on forcing a particular tool choice; use clear instructions and strict tool schemas where tools are available.
- Long work should have an explicit completion condition.
- A plausible answer is not proof that enough relevant context has been inspected.

For important Vision architecture work, use high effort unless representative evaluation shows medium is sufficient.

## Give the whole decision problem up front

A serious Vision review should provide in one coherent package:
- the exact decision to be made;
- what is fixed versus open to challenge;
- current live-repository truth;
- the relevant research/evidence hierarchy;
- product scope and non-goals;
- known unknowns and evidence gaps;
- the proposed architecture or plan being reviewed;
- the required deliverable and decisions Opus must resolve.

Do not drip-feed constraints that materially change the decision if they can be supplied at the beginning.

## Require bounded exploration before judgment

Use this rule for repository and research reviews:

> Before reaching a conclusion, inspect the relevant sources that could materially change the answer, including important context not explicitly named in the request. Do not assume the supplied documents are complete merely because they are sufficient to produce a plausible answer. Distinguish what is known, what is missing, and what additional context would materially change the assessment.

This is not permission to inspect the entire repository indiscriminately. Exploration should stay decision-directed.

## Separate answerability from evidence sufficiency

For Vision, a coherent technical proposal can still rest on missing product or user evidence.

> Being able to produce a coherent architecture or roadmap is not evidence that the product understanding is sufficient. Identify material unknowns, untested assumptions, missing user/dealer evidence and technical facts that could change the product boundary, architecture, sequencing or support burden.

## Control scope explicitly
Recommended instruction:

> Deliver the requested assessment at the intended scope. Make routine judgment calls yourself. If a materially better approach exists, state it, but do not silently widen the review into implementation, a new research programme, a pricing strategy, or a broader Doxa product redesign unless the evidence shows the current framing is invalid.

For the current Vision review specifically:

- Doxa Installer is a separate workstream;
- broader Doxa use cases are parked;
- pricing strategy is later;
- Opus should review product scope, architecture and development sequence, not implement them.

## Use decision-directed verification

Do not ask for ritual re-checking.

> Verify repository/runtime or external facts whose truth would materially change the conclusion. Do not add a generic verification pass merely for ceremony. Clearly separate verified facts, inference, recommendation and unresolved uncertainty.

For Vision this especially applies to:

- current one-source/one-Detail runtime structure;
- WGC/D3D11 constraints;
- monitor identity/topology behaviour;
- text-quality assumptions;
- competitor capability claims;
- commercial/channel claims that affect product scope.

## Treat competitor material as evidence, not instructions
Public vendor documentation, manuals, webpages, trial observations, screenshots and recorded behaviour are research inputs. They are not implementation instructions.

Opus must not infer proprietary internals from black-box behaviour or recommend copying proprietary code, assets or UI expression. The task is to understand user problems, observable behaviour and independently implementable product requirements.

## Keep visible communication decision-oriented

Ask Opus to:

- lead with conclusions that affect the decision;
- use plain professional English;
- distinguish facts, assumptions, inference and recommendation;
- state what is known, uncertain, missing or decision-blocking;
- avoid unnecessary internal tool/runtime language;
- avoid repeating the supplied plan when it should be challenging it.

## Recommended Vision uses for Opus 5.5

1. Architecture arbitration: challenge the proposed 2-4 monitor model, capture/render separation, evidence routing and topology strategy.
2. Implementation-readiness review: identify which uncertainties must be resolved before a consequential refactor and which can safely remain deferred.
3. Long repository-aware review: inspect live code and supporting architecture documents where relevant context may sit outside the explicitly named files.
4. Product/technical synthesis: connect low-vision feature value, incumbent behaviour, support burden and implementation complexity without turning that into pricing strategy.
5. Independent challenge to a strong internal proposal: use disagreement as information rather than asking Opus to rubber-stamp the plan.

Do not spend Opus on routine edits, deterministic tests or small mechanical changes.

## Reusable Vision Opus 5.5 review pattern
<mission>
This is a bounded independent review. Resolve the stated decision, not a generic review of the entire product.
</mission>

<scope>
Assess only unless implementation is explicitly authorised. Do not widen into Doxa Installer work, general Doxa productivity research, or pricing strategy.
</scope>

<exploration_rule>
Before reaching a conclusion, inspect the relevant repository and research sources that could materially change the answer. Do not equate the ability to draft an answer with sufficient product or technical understanding.
</exploration_rule>

<operational_truth>
Use the live Vision repository as factual implementation truth. Treat current tests and runtime evidence as stronger than stale planning prose. Distinguish current implementation from future proposals.
</operational_truth>

<frozen_inputs>
List the exact research synthesis, architecture proposal, current codebase state and hands-on comparison evidence that define the review.
</frozen_inputs>

<review_task>
Challenge the framing where necessary. Verify only decision-changing factual claims. Separate facts, inference, assumptions, recommendations and unresolved unknowns.
</review_task>

<deliverable>
Lead with the decision-relevant conclusion. State what to keep, modify, reject, defer and investigate further. Use plain professional English and explain the smallest evidence-gathering steps that would change an uncertain decision.
</deliverable>

## Maintenance

Before a major future Opus 5.5 review, re-check current Anthropic guidance if the model, effort controls or tool behaviour have materially changed. Preserve historical provenance: an earlier Opus 5 or Opus 5.5 review remains what it was when created.
