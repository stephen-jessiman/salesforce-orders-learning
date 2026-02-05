# Agentforce Orders Learning (Dev Org)

This repo is an SFDX project you can deploy to a Salesforce **Developer Edition** org to get a small “support + orders” dataset plus a single Case-page “Support 360” LWC example.

You don’t need to run `sf project generate`—just clone this repo and run commands from the repo root.

## Salesforce Setup (if you don’t already have an org)

1) Create a free Developer Edition org: `https://developer.salesforce.com/signup`

2) In your org, confirm Orders are enabled: Setup → **Order Settings** → **Enable Orders**

## Install Salesforce CLI (`sf`)

Pick one:

- Homebrew (macOS): `brew install sf`
- npm: `npm install -g @salesforce/cli`
- Windows (winget): `winget install --id Salesforce.sf`

Verify: `sf --version`

## Quickstart

1) Clone and enter the repo

`git clone https://github.com/stephen-jessiman/salesforce-orders-learning.git`

`cd salesforce-orders-learning`

2) Authenticate to your org and set it as default

`sf org login web --set-default --alias dev`

3) Deploy metadata (custom objects/fields/tabs/permset + Apex/LWC)

`sf project deploy start`

4) (Optional) Assign the permission set if you’re not Sys Admin

`sf org assign permset --name Agentforce_Learning`

## Agentforce Learning Seed Data (Orders + Support)

This repo includes a small “support + orders” dataset (standard objects + a few custom objects) so you can practice Agentforce-style flows like “Where is my order?” and “Start a return”.

Run the seed script (safe to re-run; it won’t duplicate the seed records unless you change the seed “key” values):

`sf apex run --file scripts/apex/seed_agentforce_data.apex`

You can also run full bootstrap in one command:

`bash scripts/setup/init_org.sh <org-alias>`

## Case “Support 360” Example (Apex + LWC)

This repo includes a single example LWC + Apex controller that shows a compact overview of the related Order, latest Shipment, and latest Return directly on a Case record page.

This repo also includes a ready-made Case Lightning Record Page (`FlexiPage:Case_Support_360`) with the component already placed.

To use it, activate the page in your org:

Setup → Object Manager → Case → Lightning Record Pages → open **Case Support 360** → Activation → assign as Org Default or to an App/Profile → Save.

## Smoke Test

- Open the seeded Case: App Launcher → **Cases** → open **“Agentforce: Where is my order?”**
- Confirm the **Support 360** card shows the Order, Shipment, Return, and line items.

## Curated Guides

- `documents/trailhead-agentforce-service-agent-orders-guide.md`
