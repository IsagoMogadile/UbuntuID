# UbuntuID — Project Scope

## 1. Project Overview

**UbuntuID** is a final-year university software project and working software prototype that demonstrates a centralised digital-identity and cross-department service-record platform for South African public-sector services.

The platform provides a common digital identity for citizens and allows authorised departmental officials to access and manage **department-specific simulated records** associated with a citizen.

UbuntuID demonstrates competency in:

* Digital identity management
* Authentication and session management
* Role-based access control
* Department-specific authorisation
* Relational database design
* Supabase/PostgreSQL
* Row Level Security (RLS)
* CRUD operations
* Verification workflows
* Document management
* Audit logging
* Notifications
* Responsive Flutter Web development

UbuntuID is a **university prototype** and is not an officially deployed South African Government platform.

It is not affiliated with, endorsed by, or connected to the Department of Home Affairs, SASSA, SARS, SAPS, the Department of Transport, the Department of Human Settlements, the Department of Basic Education, the Department of Higher Education and Training, the Department of Employment and Labour, or any other government entity.

The application's visual identity is an original project design and does not use official government branding or the National Coat of Arms.

---

# 2. Core Purpose

The purpose of UbuntuID is to demonstrate how a central digital identity could allow authorised officials from different departments to securely access and manage information relating to a citizen without giving every department access to the citizen's complete record.

The central principle is:

> **One citizen identity, department-specific access.**

A citizen may visit a government department in person to request a service or make an application. The authorised official searches for the citizen using their South African ID number and, once the citizen has been identified, the official can access only the information and services belonging to their department.

The official can then perform the CRUD operations permitted for that department.

For example:

* A **SASSA official** manages grant information.
* A **Human Settlements official** manages housing, property and title-deed information.
* A **Transport official** manages transport-related records.
* A **SAPS official** manages criminal-clearance information.
* A **Basic Education official** manages school credentials.
* A **DHET official** manages higher-education credentials.
* A **SARS official** manages tax records.
* A **Home Affairs official** manages citizen registration.

The UbuntuID administrator has platform-wide oversight.

---

# 3. System Users

UbuntuID contains four main user categories.

## 3.1 Citizen

The citizen is the person whose identity and departmental records are stored in UbuntuID.

Citizens can:

* Register/login to UbuntuID where a citizen account exists
* Maintain their authentication session
* Reset/recover their password
* View their own identity information
* View authorised credentials
* View their own documents
* View relevant departmental service information
* View notifications
* View verification requests/results relating to them

Citizens do **not** directly perform departmental CRUD operations.

Departmental services are handled by authorised officials.

Citizens also do not upload documents through UbuntuID.

---

## 3.2 Department Official

A department official is an authorised employee/user belonging to a specific department.

Their access is determined by:

```text
department_official
        +
department_id
        ↓
department-specific permissions
```

A department official can:

1. Search for a citizen using their South African ID number.
2. Locate the citizen's central identity record.
3. View the information authorised for their department.
4. Create departmental records.
5. Read departmental records.
6. Update departmental records.
7. Delete departmental records where permitted by business rules.
8. Process departmental services and applications.
9. Participate in verification workflows relevant to their department.

A department official cannot automatically access another department's records.

---

## 3.3 Organisation User

An organisation represents an external organisation, such as an employer or other authorised entity.

An organisation user can:

* Log in
* Search for a citizen using their ID number
* View the limited citizen information permitted by UbuntuID
* Request verification
* View verification requests raised by their organisation
* View verification results

Organisation users cannot:

* Create citizen accounts
* Modify citizen identity records
* Manage departmental records
* Access a citizen's complete record
* Perform departmental CRUD operations

---

## 3.4 UbuntuID Administrator

The UbuntuID administrator oversees the entire UbuntuID platform.

Administrators can:

* View system users
* View department officials
* View organisations
* View departments
* Monitor platform activity
* Manage authorised administrative statuses
* Review flagged records
* Review audit information
* Oversee departmental and organisation accounts
* Perform authorised administrative CRUD operations

The administrator has broader access than departmental officials because their responsibility is **platform-wide administration and oversight**.

---

# 4. Department Scope

UbuntuID supports department-specific services.

Each department has its own responsibility, records and permissions.

## 4.1 Department of Home Affairs

### Responsibility

Home Affairs establishes and manages the citizen's core identity record.

### Main data

```text
citizens
```

### Operations

* Search citizens
* Register new citizens
* Read citizen identity information

Home Affairs is intentionally restricted compared with other departments.

The primary responsibility of the Home Affairs official is to **create/register the citizen identity record** used by the rest of UbuntuID.

Home Affairs cannot manage SASSA, housing, tax, education, transport or other departmental records.

---

# 5. SASSA

## Responsibility

SASSA manages simulated social-grant information.

### Main records

```text
sassa_grant_types
sassa_grant_applications
sassa_grant_details
sassa_grant_payments
dependents
```

### Operations

Authorised SASSA officials can:

* Create grant records
* View grant records
* Update grant records
* Delete records where authorised
* Manage grant applications
* Manage grant details
* Manage payment information
* Manage dependent information
* Process relevant grant-related services

Citizens do not submit SASSA applications directly through the UbuntuID citizen interface.

---

# 6. Department of Human Settlements

## Responsibility

Human Settlements manages simulated housing and property information.

### Main records

```text
housing_programmes
housing_applications
housing_beneficiaries
properties
title_deeds
```

### Operations

Authorised Human Settlements officials can:

* Create housing applications
* Read housing applications
* Update housing applications
* Delete housing records where authorised
* Create and manage beneficiaries
* Create property records
* Update property information
* Create title-deed records
* Update title-deed information
* View property/title-deed information
* Process housing-related services

The property relationship is managed through housing beneficiaries rather than requiring a direct citizen reference on every property record.

---

# 7. South African Revenue Service (SARS)

## Responsibility

SARS manages simulated tax and tax-compliance information.

### Main records

```text
tax_records
```

### Operations

Authorised SARS officials can:

* Create tax records
* Read tax records
* Update tax records
* Delete records where authorised
* Manage simulated compliance information
* Process tax-related verification requests

No real SARS information is retrieved.

---

# 8. South African Police Service (SAPS)

## Responsibility

SAPS manages simulated criminal-clearance information.

### Main records

```text
criminal_clearance_records
```

### Operations

Authorised SAPS officials can:

* Search for citizens
* Create criminal-clearance records
* Read clearance records
* Update clearance records
* Delete records where authorised
* Process criminal-clearance-related verification requests

The criminal-clearance table must be confirmed against the live database before final deployment/demo because its existence and exact columns have not yet been fully verified.

---

# 9. Department of Basic Education

## Responsibility

Basic Education manages simulated school-level education credentials.

### Main records

```text
credential_types
credentials
```

Credentials issued by Basic Education represent school-level qualifications.

The proposed `nqf_level` field allows education credentials to distinguish NQF levels.

### Operations

Authorised Basic Education officials can:

* Create school credentials
* Read credentials
* Update credentials
* Delete credentials where authorised
* Verify school qualifications
* Process Basic Education verification requests

---

# 10. Department of Higher Education and Training

## Responsibility

DHET manages simulated post-school and tertiary education credentials.

### Main records

```text
credential_types
credentials
```

DHET credentials are intended to represent post-school qualifications, generally covering NQF levels 5–9.

### Operations

Authorised DHET officials can:

* Create higher-education credentials
* Read credentials
* Update credentials
* Delete credentials where authorised
* Verify tertiary qualifications
* Process higher-education verification requests

Basic Education and Higher Education are treated as separate departments and are not merged.

---

# 11. Department of Employment and Labour

## Responsibility

Employment and Labour manages simulated employment and labour-related information.

### Potential information

* Employment status
* Unemployment-related information
* Labour-related records
* Employment verification information

### Operations

Authorised officials can:

* Create employment/labour records
* Read records
* Update records
* Delete records where authorised
* Process employment-related verification

UbuntuID does not operate as a full recruitment platform.

---

# 12. Department of Transport

## Responsibility

The Department of Transport manages simulated transport-related citizen records.

### Potential records

```text
transport_records
driving_licences
vehicle_records
permits
traffic_records
```

These records represent simulated data within the UbuntuID database.

### Operations

Authorised Transport officials can:

* Create transport records
* Read transport records
* Update transport records
* Delete records where authorised
* Manage simulated driving-licence information
* Manage vehicle information
* Manage permits
* Manage relevant traffic/transport records
* Process transport-related verification requests

The exact Transport tables should be aligned with the final live database schema before implementation.

---

# 13. Department-Specific Access

A major requirement of UbuntuID is that officials do not receive unrestricted access to all citizen information.

For example:

### SASSA official

Can access:

```text
Citizen identity
       +
SASSA records
```

but not:

```text
❌ Title deeds
❌ Tax records
❌ Education records
❌ Criminal-clearance records
```

### Human Settlements official

Can access:

```text
Citizen identity
       +
Housing/property records
```

but not unrelated departmental records.

### Transport official

Can access:

```text
Citizen identity
       +
Transport records
```

The department determines the official's authorised data scope.

---

# 14. Citizen Service Workflow

UbuntuID follows an **in-person departmental service model**.

The general workflow is:

```text
Citizen visits department
        ↓
Official logs into UbuntuID
        ↓
Official searches citizen by SA ID
        ↓
Citizen identity is located
        ↓
System identifies official's department
        ↓
Only authorised departmental information is displayed
        ↓
Official performs required service
        ↓
Official creates/reads/updates/deletes
departmental records as authorised
        ↓
Changes are recorded
        ↓
Audit information is generated
```

This allows the same citizen identity to be used across multiple departments while maintaining departmental boundaries.

---

# 15. Verification Workflow

Organisations can request verification of citizen information.

The workflow is:

```text
Organisation
     ↓
Search citizen by ID
     ↓
Limited citizen information displayed
     ↓
Verification request created
     ↓
Relevant department receives request
     ↓
Department official reviews relevant information
     ↓
Official records verification result
     ↓
Organisation receives result
     ↓
Audit trail maintained
```

Verification is department-specific.

For example, a qualification verification can be directed to the appropriate education department rather than exposing unrelated citizen information.

---

# 16. Credentials

Credentials are linked to citizens through:

```text
credential_types
        ↓
credentials
        ↓
citizens
```

Credential types are associated with an issuing department.

This allows UbuntuID to determine which department is responsible for a credential.

For example:

```text
Basic Education
    ↓
School credential
    ↓
NQF 4

DHET
    ↓
Post-school credential
    ↓
NQF 5–9
```

The `nqf_level` field is an additive schema change and must be applied and verified against the live database.

---

# 17. Document Management

UbuntuID supports document viewing through Supabase Storage.

Documents are associated with citizens.

The intended model is:

```text
documents
     ↓
citizen
     ↓
Supabase Storage
```

Access is restricted according to the citizen and authorised reviewer/department context.

### Out of scope

Citizens do not upload documents through UbuntuID.

UbuntuID acts as a **view and management surface for records that already exist within the simulated system**, rather than a public document-submission platform.

---

# 18. Notifications

UbuntuID includes notifications for relevant user activity, including verification-related events.

Notifications are associated with:

* Citizens
* Verification requests

Notification read state is intended to persist in the database.

The database read-state implementation is currently pending application of the relevant SQL changes.

---

# 19. Audit Logging

Important system actions should be auditable.

UbuntuID includes:

```text
audit_logs
```

Audit records are intended to be generated through database triggers rather than relying entirely on the client application.

This provides a record of important actions such as departmental changes and verification activity.

The audit-trigger SQL is currently proposed and must be applied and tested against the live database.

---

# 20. Flagged Records

UbuntuID includes:

```text
flagged_records
```

Flagged records allow potentially problematic or suspicious records to be escalated for administrator review.

A flagged record may reference:

* Citizens
* Credentials
* Verification results
* An assigned UbuntuID administrator

Administrators can review and manage these records as part of platform oversight.

---

# 21. Authentication

Authentication is handled through **Supabase Auth**.

The system supports:

* Registration
* Login
* Logout
* Password recovery
* Session persistence
* Authentication state management

The Flutter client uses the public Supabase **anon key**.

A Supabase service-role key must never be embedded in the Flutter application.

---

# 22. Authorisation and RLS

Row Level Security is the primary database security boundary.

The intended model is:

```text
Flutter Web
     ↓
Supabase anon key
     ↓
PostgreSQL
     ↓
RLS
     ↓
Authorised records only
```

Departmental access is determined by the authenticated user's relationship to their department.

The system should enforce:

```text
Citizen
→ Own authorised records

Organisation
→ Limited citizen information + own verification requests

Department Official
→ Citizen information + records belonging to their department

Administrator
→ Platform-wide authorised access
```

The RLS policies must be applied before the system can be considered fully operational.

---

# 23. Database Model

The central identity model is:

```text
auth.users
    │
    ├── citizens
    ├── department_officials
    ├── organisation_users
    └── ubuntuid_administrators
```

Department officials are linked to:

```text
department_officials
        ↓
departments
```

This relationship determines their departmental permissions.

The database contains records for:

* Citizens
* Departments
* Organisations
* Department officials
* Organisation users
* Administrators
* Credentials
* Documents
* Verification
* SASSA
* Human Settlements
* SARS
* SAPS
* Education
* Employment/Labour
* Transport
* Notifications
* Audit logs
* Flagged records

---

# 24. What UbuntuID Is Not

UbuntuID is not intended to replace existing government systems.

It does not:

* Connect to real Home Affairs systems
* Connect to real SASSA systems
* Connect to real SARS systems
* Connect to real SAPS systems
* Connect to real Human Settlements systems
* Connect to real Transport systems
* Connect to real education department systems
* Connect to real Employment and Labour systems
* Process real government applications
* Store real citizen government records
* Replace existing government databases
* Provide citizens with online access to government application processes

All departmental information is simulated for demonstration purposes.

---

# 25. Simulated Data

All government-service information used in UbuntuID is simulated.

This includes:

* Citizen information
* Grant information
* Housing information
* Title deeds
* Tax records
* Criminal-clearance information
* Education credentials
* Employment information
* Transport information
* Verification records

No real citizen information or real government records are required for the prototype.

---

# 26. Architecture

UbuntuID follows the architecture:

```text
Flutter Web UI
       ↓
Riverpod Providers
       ↓
Repository / Service Layer
       ↓
Supabase
       ↓
PostgreSQL + RLS
       ↓
Supabase Storage
```

The repository layer separates the frontend from the database implementation.

This means that, in a hypothetical future implementation, an individual repository could be adapted to communicate with an external government API without requiring the Flutter UI to be completely redesigned.

Such integrations are **future work and are not implemented as part of this project**.

---

# 27. Security Principles

UbuntuID follows these principles:

1. **Least privilege** — users should only access information necessary for their role.
2. **Departmental isolation** — department officials should only access records belonging to their department.
3. **Database-enforced security** — RLS is the security boundary rather than relying solely on Flutter code.
4. **No service-role key in the client**.
5. **Auditability** — important operations should be recorded.
6. **Simulated data** — no real government data is required.
7. **Separation of responsibilities** — departments manage their own services while UbuntuID administrators oversee the platform.

---

# 28. Current Known Limitations

The project currently has several implementation limitations.

### Supabase access

The Supabase MCP connection was unavailable for most of the development session.

Therefore, some recent schema assumptions still require live verification.

### RLS

The RLS policies have been prepared but are currently **proposed rather than fully applied**.

Until they are applied:

* Some queries may return zero rows.
* Organisation citizen searches may fail.
* Verification requests may fail.
* Verification approval/rejection may fail.
* Administrative status changes may fail.

### Schema verification

The following areas require confirmation against the live database:

* `organisation_users.organisation_id`
* `department_officials.department_id`
* Exact department names
* Contact/email columns
* `criminal_clearance_records`
* `credential_types.nqf_level`
* Transport-related tables
* Employment/Labour-related tables

### Testing

Pure application logic has been tested, but full repository/database testing against production-equivalent RLS has not yet been completed.

---

# 29. Scope Boundaries

The project prioritises:

### In scope

* Digital identity
* Authentication
* Role resolutionq
* Department-specific access
* Departmental CRUD
* Citizen search
* Departmental service records
* Verification workflows
* Documents
* Notifications
* Audit logging
* Flagged records
* Administrator oversight
* Responsive Flutter Web interface
* Supabase/PostgreSQL
* RLS

### Out of scope

* Real government API integration
* Real government databases
* Real citizen data
* Online citizen applications
* Citizen document uploads
* Replacement of government systems
* Real financial transactions
* Real grant payments
* Real property/title-deed transactions
* Real tax transactions
* Real criminal-clearance processing
* Real driving-licence processing

---

# 30. Overall Project Objective

The overall objective of UbuntuID is to demonstrate a secure, centralised digital-identity platform in which:

> **A citizen has one central identity, departments manage their own authorised service information, organisations can request controlled verification, and an UbuntuID administrator can oversee the entire platform.**

The project demonstrates how authentication, relational data modelling, departmental CRUD operations, role-based access control, Row Level Security, verification workflows, document management, auditing and a responsive frontend can work together in a realistic software architecture.

UbuntuID is therefore best understood as a **digital identity and cross-department information-management and verification prototype**, rather than a replacement for existing South African government systems.