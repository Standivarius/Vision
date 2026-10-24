# BCS low-vision discussion brief

## Meeting objective

The objective is not to obtain a feature wish list and not primarily to sell Visual.

The objective is to determine whether Doxa plus Visual addresses a recurring workplace barrier that BCS already sees, and to identify the smallest configuration worth testing with real users.

## Opening context

A useful way to frame the discussion is:

> We started with Doxa as a compact multi-display workstation. While looking at low-vision use, we became interested in a particular problem with magnification: enlargement helps people see detail, but increasingly removes surrounding context. The user then spends time panning, finding the pointer or caret, changing zoom, and moving between the detail they need and the wider information needed to understand the task.
>
> We have started building Visual to explore whether a multi-display workstation can separate those functions instead of forcing one screen to do everything.

Then show the working pointer/caret behaviour.

## What we already know and therefore do not need to ask at a basic level

UK workplace assessments already consider the effect of the person's condition on their actual job, workplace barriers, the environment, specialist equipment and access technology, training, and adjustments. Recommendations are expected to meet the person's need in a cost-effective way.

Therefore the useful BCS knowledge is not a generic explanation of workplace assessment. It is their accumulated experience of where existing magnification arrangements succeed or fail in real jobs.

## Conversation flow

### 1. Start with real work

Ask Ben and Oliver to think of actual low-vision cases they have assessed.

Rather than asking which features people want, explore a few representative tasks:

- writing or replying to email;
- working in Word or a browser form;
- Excel or other dense tabular work;
- reading one source while entering information somewhere else;
- comparing two documents or systems;
- Teams or other communication alongside the main task;
- moving repeatedly between keyboard and mouse.

The central question is:

> Where does the person lose context, lose their place, or spend effort managing the magnifier instead of doing the work?

### 2. Understand who may benefit â€” and who may not

Useful distinctions include:

- people who need high magnification but retain enough field of view to use more than one physical display;
- people whose main problem is loss of context at higher zoom;
- people doing cross-reference or data-entry tasks;
- users who frequently transition between typing and pointer navigation.

Also probe the opposite case:

> Which low-vision users would you expect to find several displays tiring, confusing or actively unhelpful?

This establishes the boundary of the product instead of assuming every low-vision user benefits.

### 3. Show what Visual already does

Demonstrate pointer following, then type and show attention return to the caret.

Ask:

> Does this correspond to a real problem you see?

Do not ask whether they 'like' the feature.

### 4. Introduce Context + Detail

Explain the proposed model:

- one screen preserves the whole context;
- one screen carries magnified Detail;
- the context screen shows exactly which region appears enlarged on the Detail display.

Then ask them to think about actual users and tasks for which that separation would or would not help.

### 5. Introduce Reference as a hypothesis

The third Doxa screen could hold information that should remain stable while the person works elsewhere.

The useful question is:

> In the work you see, what information do people repeatedly have to return to or keep visible while working somewhere else?

This may identify stronger use cases than merely adding another magnified display.

### 6. Configuration and training

This is an important product-design question.

Ask:

> When assistive technology is installed today, how much configuration do users realistically change themselves after the assessor or trainer leaves?

And:

> Which controls do users actually understand and use, and which settings tend to create support problems?

We need to know whether Visual should expose many independent controls or whether an assessor should configure a simple preset and leave the user with only a few obvious choices.

### 7. Ask for the reasons not to recommend it

One of the most valuable questions is:

> What would make you decide not to recommend Doxa plus Visual to somebody who uses magnification?

Possible answers could involve head movement, restricted field of view, cognitive load, desk space, training, speech requirements, application compatibility, or insufficient advantage over an existing solution.

Do not defend the concept immediately. These objections define the product boundary.

## What answers are most valuable

The strongest result is not general enthusiasm.

The useful result sounds like:

> We regularly see this particular type of user doing these kinds of tasks. Their existing magnification arrangement causes these recurring problems. Context plus Detail, or Detail plus Reference, appears worth testing. These two or three behaviours would need to work. We know suitable users with whom this could be evaluated.

That gives us:

- a user profile;
- a real task;
- a recognised barrier;
- a minimum feature set;
- and a route to user validation.

## What to avoid in the meeting

Avoid spending much time on:

- detailed tracking algorithms;
- GPU/capture architecture;
- installer/cloud/AI details;
- a long ZoomText-versus-SuperNova feature comparison;
- hypothetical settings that do not correspond to a recognised task;
- presenting the three Doxa screen roles as already decided.

The important discussion is the user's work and attention, not our implementation.

## Desired end point

Try to leave the discussion with four things:

1. One or two user types for whom the idea is plausible.
2. Two or three workplace tasks where current magnification creates identifiable friction.
3. The smallest Visual configuration BCS believes is worth testing.
4. A path to one or a few real-user observations or trials.

If those four things emerge, the meeting has done what we need.

## Doxa dual-workspace concept to challenge

Present this as a hypothesis, not a finished feature:

- left Doxa screen: stable Workspace A;
- centre Doxa screen: shared magnified Detail view;
- right Doxa screen: stable Workspace B;
- laptop: simple organiser for which windows occupy Left and Right;
- source workspace shows a locator/highlight that corresponds exactly to the centre Detail view;
- Detail should follow intentional activity (pointer/text cursor/focus), not every incidental mouse boundary crossing.

Primary question for Ben and Oliver:

> Would preserving two stable application contexts while one central screen supplies readable magnified Detail solve a recurring workplace problem for the low-vision users you assess?

Probe especially for who would benefit, who would be overwhelmed by three external screens, whether one shared Detail surface is enough, and whether automatic switching or explicit switching would be preferable.

Canonical concept document: `docs/project/foundation/doxa_dual_workspace_shared_detail_concept.md`.