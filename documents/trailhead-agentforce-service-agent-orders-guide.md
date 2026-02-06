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
- Agentforce action Flows (autolaunched, deploy-ready):
  - `Get_Customer_Details` — look up Contact by email
  - `Get_Order_By_PO_Number` — look up Order by PO number
  - `Get_Shipments_For_Order` — get all Shipment__c for an Order
  - `Get_Return_Details` — get all Return__c for an Order
  - `Create_Support_Case` — create a Case linked to a Contact

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

Permission set model:

- `Agentforce_Learning`: developer/human learning access for this repo objects and fields.
- `Agentforce_Agent_Runtime`: least-privilege runtime access for the Agent User created in Agent Builder.

The `sf project deploy start` command deploys everything including the Flows. After deploy, the flows are Active and ready to wire as Agent Actions in Agent Builder.

## Trailhead Step Mapping to This Project

1. Enable and open Agentforce setup in your org.
2. Create a new service agent.
3. Add focused instructions for order support.
4. Create custom Flow-based actions (do NOT use standard catalog actions — they return mock/incorrect data without configuration):
   - `Get Customer Details` — Flow: query Contact by email
   - `Get Order By PO Number` — Flow: query Order by PoNumber
   - `Get Shipments For Order` — Flow: query Shipment__c by Order lookup
   - `Get Return Details` — Flow: query Return__c by Order or RMA number
   - `Create Support Case` — Flow: create Case with contact, subject, description
5. Add each Flow as an Agent Action with configured inputs/outputs.
6. Update topic instructions to reference each action by name.
7. Test in Builder with seeded-case prompts.
8. Activate and publish.
9. Route entry points (site/chat/widget/flow) to this agent.

**Important lesson learned:** Standard catalog actions (e.g. `Identify Customer By Email`, `Get Orders By Contact`) returned mock/wrong data when used without configuration. The Trailhead approach creates purpose-built Flows for each action so the agent queries real org data.

## Recommended Agent Definition for This Repo

### Agent

- Label: `AF Service Agent - Orders`
- Role: Service/support agent for order status and return help

### Topic

- Topic label: `Order Support`
- Scope: order status, shipment delays, and return requests

### Topic Instructions (action-aware)

1. If the customer is not known, identify them by one of these paths:
   - Ask for their email address and run 'Get Customer Details', OR
   - If they provide a PO number, run 'Get Order By PO Number' first and use the account/contact context from the order to confirm identity.
   Either path is acceptable. Do not require email if the customer has already provided a PO number.
2. If the customer asks about an order, ask for their PO number (if not already provided) and run 'Get Order By PO Number' to retrieve the order. If they don't know the PO number, use context from 'Get Customer Details' to help.
3. To check shipment status, run 'Get Shipments For Order' using the Order ID from 'Get Order By PO Number'. Report all tracking numbers and delivery statuses.
4. If a shipment has Delivery Status 'Exception', explain the delay clearly, share the Exception Reason and the Last Tracking Update datetime.
5. If the customer asks about a return, run 'Get Return Details' to retrieve the return record. Share the RMA number, status, and reason.
6. If the customer needs to open a support case, run 'Create Support Case' with their Contact ID, a clear subject, and description summarizing the issue.
7. Keep replies concise. Always include tracking numbers, ETAs, and RMA numbers when available.
8. Treat order status, shipment delay, return requests, and case updates as in-scope. These are operational support requests.

## Custom Action Configuration (Flow-Based)

Each action is a purpose-built Autolaunched Flow exposed as an Agent Action. Do NOT use standard catalog actions — they return mock/incorrect data without proper configuration.

### Why only our flows appear in the action picker

Agent Builder only lists flows that meet **all** of these criteria:

1. **Flow type: Autolaunched (No Trigger)** — `processType=AutoLaunchedFlow`. Screen Flows, Record-Triggered Flows, Scheduled Flows, and Platform Event flows are excluded because the agent cannot interact with a UI or wait for a trigger.
2. **Status: Active** — inactive or draft flows are excluded.
3. **Has input and/or output variables** — variables with `isInput=true` or `isOutput=true`. This is what makes the flow callable with parameters and able to return data.

Most default org flows are Record-Triggered or Screen Flows without exposed input/output variables, so they don't qualify.

### Action 1: Get Customer Details

- **Flow:** `Get_Customer_Details`
- **Flow logic:** Query `Contact` WHERE `Email = :email`. Return first match.
- **Agent Action Instructions:** "Look up a customer's Contact record using their email address. Always run this action first before any other actions to identify the customer."
- **Loading text:** "Looking up your account..."

| Parameter | Direction | Require Input | Collect from user | Show in conversation | Instructions |
|-----------|-----------|---------------|-------------------|----------------------|--------------|
| `email` | Input | checked | checked | — | "The customer's email address. Ask the customer for their email if not already provided." |
| `contact` | Output | — | — | checked | "The customer's Contact record including name, email, and account details." |

- **Why:** The agent must identify the customer before accessing any account-specific data.

### Action 2: Get Order By PO Number

- **Flow:** `Get_Order_By_PO_Number`
- **Flow logic:** Query `Order` WHERE `PoNumber = :poNumber`. Return first match.
- **Agent Action Instructions:** "Retrieve an order using the PO number. Run this after identifying the customer with 'Get Customer Details'. Use the PO number provided by the customer."
- **Loading text:** "Looking up your order..."

| Parameter | Direction | Require Input | Collect from user | Show in conversation | Instructions |
|-----------|-----------|---------------|-------------------|----------------------|--------------|
| `poNumber` | Input | checked | checked | — | "The order's PO number (e.g. AF-SEED-ORDER-0001). Ask the customer for their order or PO number if not already provided." |
| `orderRecord` | Output | — | — | checked | "The Order record including status, effective date, and account." |

- **Why:** Lets the agent look up order details using the customer-facing PO number.

### Action 3: Get Shipments For Order

- **Flow:** `Get_Shipments_For_Order`
- **Flow logic:** Query `Shipment__c` WHERE `Order__c = :orderId`. Return all matches.
- **Agent Action Instructions:** "Retrieve all shipments for an order. Run this after 'Get Order By PO Number' to check tracking and delivery status. Use the Order ID from the order record, not the PO number."
- **Loading text:** "Checking shipment status..."

| Parameter | Direction | Require Input | Collect from user | Show in conversation | Instructions |
|-----------|-----------|---------------|-------------------|----------------------|--------------|
| `orderId` | Input | checked | unchecked | — | "The Salesforce Order record ID from the 'Get Order By PO Number' action. This must be an ID, not the PO number." |
| `shipments` | Output | — | — | checked | "List of Shipment records including tracking number, carrier, delivery status, ETA, and exception details." |

- **Why:** Returns all shipments for the order so the agent can report tracking, status, and exceptions.

### Action 4: Get Return Details

- **Flow:** `Get_Return_Details`
- **Flow logic:** Query `Return__c` WHERE `Order__c = :orderId`. Return all matches.
- **Agent Action Instructions:** "Retrieve all returns for an order. Run this when the customer asks about a return, refund, or RMA. Use the Order ID from the order record."
- **Loading text:** "Checking return status..."

| Parameter | Direction | Require Input | Collect from user | Show in conversation | Instructions |
|-----------|-----------|---------------|-------------------|----------------------|--------------|
| `orderId` | Input | checked | unchecked | — | "The Salesforce Order record ID from the 'Get Order By PO Number' action. This must be an ID, not the PO number." |
| `returns` | Output | — | — | checked | "List of Return records including RMA number, status, reason, and refund amount." |

- **Why:** Lets the agent check return status, RMA number, and reason for a given order.

### Action 5: Create Support Case

- **Flow:** `Create_Support_Case`
- **Flow logic:** Create a `Case` record with ContactId, Subject, Description, and Origin='Agentforce'. Then fetch the created record back to return as output.
- **Agent Action Instructions:** "Create a new support case for the customer. Run this when the customer needs to report an issue, request help, or escalate a problem. Always identify the customer first with 'Get Customer Details'."
- **Loading text:** "Creating your support case..."

| Parameter | Direction | Require Input | Collect from user | Show in conversation | Instructions |
|-----------|-----------|---------------|-------------------|----------------------|--------------|
| `contactId` | Input | checked | unchecked | — | "The Contact record ID from the 'Get Customer Details' action. This must be an ID." |
| `caseSubject` | Input | checked | checked | — | "A short summary of the customer's issue for the case subject line." |
| `caseDescription` | Input | checked | checked | — | "A detailed description of the customer's issue including any relevant order or shipment details discussed." |
| `caseRecord` | Output | — | — | checked | "The created Case record including the case number." |

- **Why:** Lets the agent create a real support case when the customer needs one.

### Configuration pattern summary

- **Collect from user: checked** — for inputs the agent should ask the customer for (email, PO number, case subject/description).
- **Collect from user: unchecked** — for inputs the agent chains from previous action outputs (orderId, contactId). The agent should never ask the customer for a Salesforce record ID.

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

## Topic Routing Troubleshooting (If You Get "Off Topic")

Symptom:

- The agent responds with an off-topic deflection even for valid order-support prompts.
- The agent responds with a security/refusal message such as "reverse engineering" and denies normal order requests.

Most common cause:

- Topic classifier confidence is too low for `Order Support`, so a default off-topic topic wins routing.
- A safety/off-topic instruction set is winning routing and treating operational order questions as policy probing.

Fix sequence:

1. Open the `Order Support` topic and add clear trigger examples (sample utterances), such as:
   - `Where is my order AF-SEED-ORDER-0001?`
   - `My order is delayed.`
   - `I only received part of my order.`
   - `I need to return a damaged item from my order.`
   - `Please update my case about my order issue.`
2. In `Order Support` instructions, explicitly state:
   - "Treat order status, shipment delay, return requests, and case updates as in-scope."
3. Review other active topics:
   - Remove or disable conflicting generic topics if possible.
   - Keep off-topic behavior as fallback only.
4. If you see "reverse engineering" refusal text:
   - Open all active non-order topics and search their instructions for `reverse engineering`, `system instructions`, `function`, or blanket denial language.
   - Disable that topic for this learning run, or narrow its scope so it only triggers on genuine prompt-injection attempts.
5. In `Order Support`, add an explicit boundary:
   - "Requests about order status, case updates, delays, and returns are operational support requests, not reverse-engineering requests."
6. Save and retest with the seeded prompts.
7. Use natural customer phrasing in tests. Avoid prompts that instruct internal tool usage
   (for example, "identify customer by email, then get order..."), which can be classified as
   system/tool probing in some org configurations.

Validation target:

- Order-related prompts should route to `Order Support` before any off-topic fallback topic.

## Grounding Troubleshooting (If Response Is "UNGROUNDED")

Symptom:

- Agent gives a generic response and trace flags `UNGROUNDED`.
- No useful action call appears in function history.

Most common causes:

1. Topic routed correctly, but no action was selected.
2. Action selected but failed due missing required inputs.
3. Action selected but failed due agent-user permissions.

Fix sequence:

1. Use a forced, explicit prompt to encourage action selection:
   - `Identify customer by email alex.customer@example.com, then get order by order number AF-SEED-ORDER-0001, and summarize the order.`
2. Open trace/function history and confirm:
   - Which action was attempted first.
   - Whether the call succeeded or failed.
   - Exact error text if failed.
3. If no action was called:
   - Add an instruction to `Order Support`: "For order requests, call available order actions before responding."
4. If action failed on required inputs:
   - Update topic instructions to gather required inputs in order (email first, then order number).
5. If action failed on permissions:
   - Grant agent user access to required objects/fields and retry.
   - Minimum for this loop: read on `Contact` + `Order`, create/edit/read on `Case` + `CaseComment`.
   - Assign permission set `Agentforce_Agent_Runtime` to the Agent User.
   - In source-managed permission sets, prefer object-level permissions for these standard objects; avoid adding required/non-permissionable standard fields (can cause deploy failures).

Validation target:

- At least one order action executes successfully before response generation.

## Data Sources vs Actions (Important)

Use this rule during setup:

- Data sources = retrieval grounding (knowledge/docs/datasets)
- Actions = live record operations and workflow execution

For this guide's seeded order-support loop, actions are the priority and Data Cloud is not required.
If your org blocks data sources because Data Cloud is not enabled, continue without data sources.

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
   - Paste or adapt the instructions from the "Topic Instructions (action-aware)" section above.
   - Remove default Salesforce topic instructions if they conflict with this focused order-support policy.
   - Keep scope narrow: order status, shipment exceptions, return support.
   - Learning checkpoint: instructions are guardrails, not just prose; they shape action-selection behavior.
5. Deploy and wire custom Flow-based actions.
   - The five Agentforce Flows are pre-built in this repo under `force-app/main/default/flows/`. They are deployed as part of `sf project deploy start`.
   - Do NOT use standard catalog actions — they return mock/incorrect data without configuration.
   - After deploy, verify Flows are Active: Setup -> Flows -> search for "Get Customer" — you should see all five.
   - Wire each Flow as an Agent Action in Agent Builder:
     a. Open your agent in Agent Builder.
     b. In the `Order Support` topic, go to Actions.
     c. Remove any standard catalog actions you added previously.
     d. Click **New** -> Type: **Flow** -> select each flow one at a time:
        - `Get Customer Details`: Input `email` -> Require Input: checked. Output `contact` -> Show in conversation: checked.
        - `Get Order By PO Number`: Input `poNumber` -> Require Input: checked. Output `orderRecord` -> Show in conversation: checked.
        - `Get Shipments For Order`: Input `orderId` -> Require Input: checked. Output `shipments` -> Show in conversation: checked.
        - `Get Return Details`: Input `orderId` -> Require Input: checked. Output `returns` -> Show in conversation: checked.
        - `Create Support Case`: Inputs `contactId`, `caseSubject`, `caseDescription` -> all Require Input: checked. Output `caseRecord` -> Show in conversation: checked.
   - Learning checkpoint: actions define capability. Custom flows query real org data. The "Require Input" and "Show in conversation" flags control what the agent must collect and what it can relay back.

### Understanding the Flow pattern (for learning)

   Each flow follows the same simple pattern. For example, `Get_Customer_Details`:

   ```
   Start -> Get Records (Contact WHERE Email = {!email}) -> Assignment ({!contact} = result)
   ```

   - **Input variable** (`email`): marked `isInput=true` so Agent Builder can pass data in.
   - **Get Records element**: queries the real org database with a filter.
   - **Output variable** (`contact`): marked `isOutput=true` so the agent receives the result.

   If you need to add new actions in future (e.g. for a new object), follow this same three-step pattern: input variable -> Get/Create Records -> output variable assignment.
6. Assign runtime permissions to Agent User.
   - Setup -> Permission Sets -> `Agentforce_Agent_Runtime` -> Manage Assignments -> assign `EinsteinServiceAgent User` (or your created Agent User).
   - Learning checkpoint: action execution uses Agent User permissions, not admin permissions.
7. Run builder tests against seeded order scenario.
   - Test prompt: `Where is my order? I only received part of it.`
   - Validate the agent can surface both tracking numbers (`1ZAFSEED0001`, `1ZAFSEED0002`) and identify the exception path.
   - Test prompt: `One package is delayed. What is the latest update?`
   - Validate it reports `Delivery_Status__c = Exception` and `Exception_Reason__c = Carrier_Delay`.
   - Test prompt: `I need to return a damaged item from this order.`
   - Validate it can reference existing return `RMA-AF-0001` or create/update case as needed.
   - Learning checkpoint: good tests include normal path + exception path + workflow update path.
8. Publish and deploy.
   - Activate/publish the agent deployment.
   - Keep initial channel internal (builder test or internal service channel) before external rollout.
   - Learning checkpoint: publish controls runtime availability; deployment without test evidence creates support risk.
9. Optional channel routing.
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
  - Customer email: alex.customer@example.com
- Reference guide (read this first):
  documents/trailhead-agentforce-service-agent-orders-guide.md
- Session log from previous working session:
  documents/live-loop-session-log-2026-02-06.md

Prerequisites already handled by this repo:
- Custom objects, fields, and permissions are in DX source.
- 5 Autolaunched Flows for agent actions are in force-app/main/default/flows/.
- Seed data script is at scripts/apex/seed_agentforce_data.apex.
- All of these deploy via `sf project deploy start`.

What still needs to be done in Salesforce UI (not source-controllable):
1. Create a new service agent (Agent Builder -> New Agent -> Service Agent).
2. Add topic "Order Support" with the action-aware instructions from the guide.
3. Wire each of the 5 deployed flows as Agent Actions (New Action -> Type: Flow).
   - Configure inputs, outputs, action instructions, and loading text per the guide's "Custom Action Configuration" section.
   - Key pattern: "Require Input" + "Collect from user" for customer-provided values (email, PO number); "Require Input" only for chained values (orderId, contactId).
4. Assign permission set `Agentforce_Agent_Runtime` to the Agent User (Setup -> Permission Sets).
5. Test in Builder, then activate and publish.

Important lessons from previous sessions (avoid repeating these mistakes):
- Do NOT use standard catalog actions (e.g. Identify Customer By Email, Get Orders By Contact). They return mock/wrong data. Always use the custom flows from this repo.
- Agent runs as EinsteinServiceAgent User, not admin. Without the runtime permission set, actions fail silently.
- Topic instructions must reference action names explicitly for reliable action selection.
- Standard field FLS in permission sets causes deploy failures — use object-level permissions for standard objects.
- recordCreates in flows stores only the ID. To return a created record, add a Get Records element after the create.

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

Start now with Step 1: confirm org/data readiness (run sf project deploy start and seed data script), then explain why this prevents false confidence in agent tests.
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
- 2026-02-05: Clarified that data sources are optional retrieval context and this loop should continue without Data Cloud by focusing on actions.
- 2026-02-05: During topic setup, default Salesforce instructions were removed to keep policy narrowly scoped to the order-support use case.
- 2026-02-05: Action catalog can be large; guide now explicitly instructs using search to add only the five target actions for this loop.
- 2026-02-05: Some orgs do not expose Trailhead generic record actions; added an equivalent action mapping using `Identify Customer By Email`, order lookup actions, `Create Case`, and `Add Case Comment`.
- 2026-02-05: Added troubleshooting for topic misrouting where valid order prompts are classified as off-topic; fix is stronger `Order Support` utterances and reduced topic conflicts.
- 2026-02-05: Added troubleshooting for `UNGROUNDED` responses to require trace verification of actual action execution before trusting outputs.
- 2026-02-05: Added explicit agent-user permission requirements after action failures showed missing access to `Contact`/`Order`/`Case`.
- 2026-02-05: Removed standard-field FLS entries that caused deploy errors on required/non-permissionable fields; kept object-level access for standard objects.
- 2026-02-05: In some orgs, imperative "call this action" test phrasing can trigger safety/off-topic behavior; use natural end-user prompts for routing tests.
- 2026-02-05: Split permissions into two sets: `Agentforce_Learning` for developers and `Agentforce_Agent_Runtime` for the runtime Agent User (least privilege).
- 2026-02-06: Added `Shipment__c`, `Return__c`, `Return_Line__c` read access + all custom field FLS to `Agentforce_Agent_Runtime` — agent could not read shipment/return data without this.
- 2026-02-06: Replaced standard catalog action approach with custom Flow-based actions. Standard actions (`Identify Customer By Email`, `Get Orders By Contact`, etc.) returned mock/wrong data. Trailhead pattern is to build purpose-built Flows for each action.
- 2026-02-06: Rewrote topic instructions to be action-aware — each instruction references a specific action by name, matching the Trailhead pattern for reliable action selection.
- 2026-02-06: Added 5 deployable Autolaunched Flows to repo (`force-app/main/default/flows/`). Trailhead's sample org had flows pre-built; our repo now does too. Developers deploy once, then wire as Agent Actions in Builder.
- 2026-02-06: Added "Understanding the Flow pattern" section so developers can create new actions following the same input -> query -> output template.
- 2026-02-06: Added full Agent Action configuration for all 5 actions: action instructions, loading text, input/output instructions, Collect from user, Require Input, and Show in conversation flags.
- 2026-02-06: Documented why only Autolaunched Flows with input/output variables appear in the Agent Builder action picker — Screen Flows, Record-Triggered Flows, and flows without exposed variables are excluded.
