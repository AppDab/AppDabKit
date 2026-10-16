# AppDabAutomation

Use AppDabAutomation to discover and execute typed actions over App Store Connect services.

## Overview

Actions expose input and output types, JSON schemas, summaries, and a safety classification. ``Executor`` runs actions through an ``AutomationDataProviding`` implementation. The standard registry is available through ``AutomationRegistry/standard``.

## Topics

### Executing actions

- ``Executor``
- ``AutomationAction``
- ``AutomationRequest``
- ``AutomationRegistry``
- ``AutomationActionCatalog``

### Safety and results

- ``AutomationExecutionSafety``
- ``GuardedAutomationAction``
- ``AutomationMutationPlan``
- ``AutomationMutationReceipt``
