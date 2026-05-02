# Architecture Constraints

## Non-Negotiable Rules
1. Do not modify any managed package asset from Summit Events.
2. All new FIU functionality must be delivered via FIU-owned metadata and code.
3. Discovery may use Prod. All implementation and deployment must target Partial UAT only.
4. Maintain upgrade compatibility with future Summit package versions.

## Allowed Building Blocks
- FIU custom Apex classes
- FIU custom LWCs
- FIU custom tabs and Lightning app
- FIU-owned Flexipages / App pages / Record pages where appropriate
- FIU custom objects / fields / custom metadata / custom labels
- Flows owned by FIU
- Permission sets and permission set groups owned by FIU
- Wrapper service classes that read/write Summit objects via supported object/field access

## Disallowed Changes
- Editing managed package Apex
- Editing managed package LWCs/VF/components directly
- Altering managed package metadata in ways that block package upgrades
- Relying on unsupported hacks against package internals

## Summit Model Assumptions to Respect
- Parent Event exists first
- One or more Event Instances belong to that Event
- Instance-level settings can diverge via overrides
- Operational behavior often depends on values at both levels

## Data/Automation Safety Expectations
- All custom logic must be bulk-safe
- Follow org sharing/FLS expectations where appropriate
- Avoid duplicate creation when cloning or syncing
- Guard against accidental live operational side effects in Prod discovery

## Build/Deployment Rules for Codex
- Read and inspect from Prod
- Build, test, and deploy only in Partial UAT
- Use source-driven changes where possible
- Prefer additive changes
- Document assumptions when exact business rules are discovered from metadata
