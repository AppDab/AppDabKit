# AppDabServices

Use AppDabServices to access App Store Connect through shared service protocols and models.

## Overview

The module separates service contracts from their live implementations. Supply an account provider to ``LiveServices`` or implement ``ServiceProviding`` to inject alternate services.

## Topics

### Creating services

- ``LiveServices``
- ``ServiceProviding``
- ``StoredAccountProvider``

### Requests and results

- ``PaginationRequest``
- ``PaginationMetadata``
- ``ServiceError``
