# Project Brief

## Project Name
FIU Events Extension Layer for Summit Events

## Target Org for Build
Partial UAT sandbox

## Source of Truth for Discovery
Production org

## Summary
FIU uses the Summit Events managed package as its event management solution. The package offers substantial capability but exposes users to a clunky object-driven setup model that requires too much architectural knowledge. As a result, users frequently omit critical values, create the wrong record type of thing conceptually, misconfigure reminders or payments, and end up with event instances that do not behave properly.

The solution is not to alter the managed package. The solution is to create an FIU-owned UX and service layer that sits alongside it.

## Business Outcome
The FIU user should be able to:
- understand whether they need a new Event, a clone, or another Instance
- create a valid event setup without knowing package architecture
- avoid missing required operational fields
- review attendee lists more naturally
- export attendees to CSV
- update attendance more naturally after an event
- understand when payment, reminders, email, website visibility, and Opportunity creation are enabled or at risk

## Key Product Principle
Start from the Event, then guide the user down to the first or next Instance.

## MVP Positioning
Phase 1 focuses on guided creation, clone, add-instance, and operational visibility.
Phase 2 addresses more complex OGI and advanced Summit feature needs.
