# Trailhead Service Agent Replication (Orders Case)

This guide applies the Trailhead project flow from:
`https://trailhead.salesforce.com/content/learn/projects/quick-start-build-your-first-agent-with-agentforce/configure-an-agentforce-service-agent`
to this repo's example support case:
`Agentforce: Where is my order?`

## Goal

Recreate the same "build + test + publish" learning flow, but with this project's seeded Orders + Shipment + Return data so the agent can handle real order-support conversations.

## What Already Exists in This DX Project

This repo already provides:

- Custom objects: `Shipment__c`, `Return__c`, `Return_Line__c`
- Case custom fields for support context (question, urgency, sentiment, preferred resolution)
- Seed data script: `scripts/apex/seed_agentforce_data.apex`
- Example case subject: `Agentforce: Where is my order?`
- Case Support 360 component + flexipage for agent-assist context

## Portable Seed Identifiers (Use These, Not Salesforce Record IDs)

When validating data across orgs, do not use Salesforce-generated IDs (they differ in every org).
Use these stable keys from the seed script:

- Case Subject: `Agentforce: Where is my order?`
- Order PO Number: `AF-SEED-ORDER-0001`
- Shipment Tracking Numbers: `1ZAFSEED0001`, `1ZAFSEED0002`
- Return RMA Number: `RMA-AF-0001`
- Account Name: `Agentforce Demo Account`

## Org Initialization (for New Developers)

From repo root:

```bash
sf org login web --set-default --alias agentforce-learning
sf project deploy start
sf org assign permset --name Agentforce_Learning
sf apex run --file scripts/apex/seed_agentforce_data.apex
```

Or use the helper script in this repo:

```bash
bash scripts/setup/init_org.sh agentforce-learning
```

## Trailhead Step Mapping to This Project

1. Enable and open Agentforce setup in your org.
2. Create a new service agent.
3. Add focused instructions for order support.
4. Add the five standard actions used in the Trailhead unit:
   - `Identify Record by Name`
   - `Get Record Details`
   - `Get Related Records`
   - `Create Case`
   - `Update Case`
5. Test in Builder with seeded-case prompts.
6. Activate and publish.
7. Route entry points (site/chat/widget/flow) to this agent.

## Recommended Agent Definition for This Repo

### Agent

- Label: `AF Service Agent - Orders`
- Role: Service/support agent for order status and return help

### Topic

- Topic label: `Order Support`
- Scope: order status, shipment delays, and return requests

### Topic Instructions (starter set)

1. Confirm you are helping with order support, shipment status, or return questions.
2. Identify the customer/account before returning sensitive details.
3. Use related records to gather order, shipment, and return context before replying.
4. If shipment status is `Exception`, explain the delay clearly and share latest tracking update.
5. If customer asks for a return, summarize eligibility and next action, then create or update a case.
6. Keep replies concise and include tracking numbers and ETA when available.

## Action Configuration Notes

Use these objects first:

- `Case`
- `Order`
- `Shipment__c`
- `Return__c`
- `Return_Line__c`
- `Contact`
- `Account`

Suggested mapping:

- `Identify Record by Name`: resolve `Contact` or `Account`
- `Get Record Details`: fetch `Case`, `Order`, `Shipment__c`, `Return__c`
- `Get Related Records`: pull `Shipment__c` and `Return__c` related to `Order`
- `Create Case`: create follow-up support case when no case exists
- `Update Case`: set priority/status/notes for existing case

## Builder Test Prompts (Use Seeded Data)

Use these prompts in Agent Builder test panel:

1. `Where is my order? I only received part of it.`
2. `Can you check tracking for Agentforce Demo Account?`
3. `One package is delayed. What is the latest update?`
4. `I need to return a damaged item from this order.`
5. `Please update my existing case with this new issue detail: box arrived crushed.`

Expected behavior:

- Agent identifies the right customer context
- Agent retrieves order + shipment status
- Agent handles exception path when shipment is delayed
- Agent can create or update case records using actions

## Publish and Entry Point

After successful tests:

1. Activate/publish the agent deployment.
2. Connect your entry point:
   - Experience Cloud page
   - Embedded service chat
   - Flow handoff from existing support intake

For this learning repo, start with internal testing in Builder first, then wire to a public channel.

## Source Control Guidance

Keep these items in DX source:

- Objects/fields/permissions
- Apex/LWC
- Flows and invocable actions (when you add them)

Important:

- Some Agentforce builder configuration can be org-managed and may not be fully source-tracked in all org setups.
- Keep this document as the runbook for reproducing agent configuration consistently across dev orgs.

## Optional Next Features (Ask Before Enabling)

Use these only if you want to extend beyond the base Trailhead replication:

1. Add a custom invocable action to summarize case + order + shipment in one call.
2. Add a flow action to auto-open a return request record when customer intent is "start return".
3. Add guardrails for sensitive account data disclosure before customer identity is confirmed.
4. Add escalation logic to hand off to a human when shipment exception age exceeds a threshold.

## Detailed Build Steps (Click-by-Click)

Use this section when you want exact execution steps instead of a high-level checklist.

1. Prepare org data and confirm seed records.
   - Run: `bash scripts/setup/init_org.sh <org-alias>`
   - Open App Launcher -> Cases.
   - Confirm case subject: `Agentforce: Where is my order?`
   - Learning checkpoint: the agent needs realistic data context, or action testing is misleading.
2. Open Agentforce Builder.
   - Setup -> search for `Agentforce`.
   - Open Agent Builder (or Service Agent setup entry, depending on org UI version).
   - Learning checkpoint: builder is where prompt policy (instructions) and tool policy (actions) meet.
3. Create a new service agent.
   - Click New Agent.
   - Type: Service agent.
   - Name: `AF Service Agent - Orders`.
   - Save.
   - Learning checkpoint: the agent record is your runtime container for topics, actions, and deployment.
4. Add topic and instruction policy.
   - Add topic `Order Support`.
   - Paste or adapt the instructions from the "Topic Instructions (starter set)" section above.
   - Keep scope narrow: order status, shipment exceptions, return support.
   - Learning checkpoint: instructions are guardrails, not just prose; they shape action-selection behavior.
5. Add the five Trailhead actions.
   - Add `Identify Record by Name`.
   - Add `Get Record Details`.
   - Add `Get Related Records`.
   - Add `Create Case`.
   - Add `Update Case`.
   - If object scoping is available, prioritize: `Case`, `Order`, `Shipment__c`, `Return__c`, `Return_Line__c`, `Contact`, `Account`.
   - Learning checkpoint: actions define capability. Without the right action set, the model can only answer generically.
6. Run builder tests against seeded order scenario.
   - Test prompt: `Where is my order? I only received part of it.`
   - Validate the agent can surface both tracking numbers (`1ZAFSEED0001`, `1ZAFSEED0002`) and identify the exception path.
   - Test prompt: `One package is delayed. What is the latest update?`
   - Validate it reports `Delivery_Status__c = Exception` and `Exception_Reason__c = Carrier_Delay`.
   - Test prompt: `I need to return a damaged item from this order.`
   - Validate it can reference existing return `RMA-AF-0001` or create/update case as needed.
   - Learning checkpoint: good tests include normal path + exception path + workflow update path.
7. Publish and deploy.
   - Activate/publish the agent deployment.
   - Keep initial channel internal (builder test or internal service channel) before external rollout.
   - Learning checkpoint: publish controls runtime availability; deployment without test evidence creates support risk.
8. Optional channel routing.
   - Connect to Experience Cloud, chat, or flow entry points.
   - Start with low-risk routing, then expand.
   - Learning checkpoint: channel integration is separate from agent quality; test both layers independently.

## Debrief Template (Use After Each Test Session)

Add notes after each working session:

1. What prompt did we test?
2. Which action(s) should have been called?
3. Which action(s) were actually called?
4. Did the response match seeded data exactly?
5. What instruction change would improve reliability?

## AI Session Prompt (Live Coaching Loop)

Use this prompt in a new AI coding/chat session to recreate the same guided learning loop with any developer.

```text
You are my live coach for implementing Agentforce service agent setup in this Salesforce DX project.

Context:
- Project context: I am already in the repository root.
- Primary scenario: Case subject "Agentforce: Where is my order?"
- Seeded records include:
  - Order PoNumber: AF-SEED-ORDER-0001
  - Shipments: 1ZAFSEED0001 (Shipped), 1ZAFSEED0002 (Exception / Carrier_Delay)
  - Return: RMA-AF-0001
- Reference guide to keep updated as we learn:
  documents/trailhead-agentforce-service-agent-orders-guide.md

How I want you to run the session:
1. Work as a live loop, one step at a time.
2. For each step, provide:
   - The exact thing I should do in Salesforce UI.
   - Why this step matters (what system behavior it controls).
   - What success looks like.
   - One quick validation check.
3. Stop after each step and ask me for results before moving on.
4. If my result is wrong or unclear, diagnose and give a targeted fix before continuing.
5. Keep the flow practical, not theoretical.

Quality bar:
- Focus on understanding, not checklist completion.
- Tie every action to one of these layers:
  - agent policy (instructions/topic)
  - capability (actions/tools)
  - orchestration (runtime choice of tools)
  - deployment/routing
- Use the seeded order case for examples and test prompts.
- Never use Salesforce record IDs in instructions or validation; use stable seed identifiers only.

Documentation behavior:
- When I ask a good question or we discover a better instruction, update the guide file directly.
- Add new notes under "Session Clarifications (Living Section)" with date and concise rationale.
- If we improve repeatability, update "Detailed Build Steps (Click-by-Click)".

Start now with Step 1: confirm org/data readiness and explain why this prevents false confidence in agent tests.
```

Tips for use:

1. Paste the prompt exactly, then respond with your real UI output after each step.
2. Ask follow-up "why" questions whenever behavior seems non-obvious.
3. At the end of each session, ask the AI to summarize what changed in the guide and why.

## Session Clarifications (Living Section)

Use this section to capture questions and decisions so the document improves over time.

- 2026-02-05: Added detailed click-by-click steps because high-level checklists were not enough for learning transfer.
- 2026-02-05: Replaced absolute local filesystem paths with project-root-relative references to keep instructions portable for all developers.
- 2026-02-05: Added a strict rule to use stable seed identifiers (case subject, PO number, tracking number, RMA) instead of Salesforce record IDs.
