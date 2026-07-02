![SQL Server](https://img.shields.io/badge/SQL_Server-2019+-red)
![CDC](https://img.shields.io/badge/Feature-CDC-blue)
![Availability Groups](https://img.shields.io/badge/HA-Availability_Groups-green)

# SQL Server CDC with Availability Groups

## Overview

Change Data Capture (CDC) is not fully Availability Group aware out of the box.

When CDC is enabled on a database participating in an Availability Group (AG), SQL Server creates CDC Capture and Cleanup SQL Agent jobs on the primary replica. During an AG failover, these jobs do not automatically transition to the new primary replica.

Without additional configuration, CDC processing stops after failover and change data is no longer captured.

This repository provides a method for making CDC operational across Availability Group failovers by:

- Replicating CDC metadata to secondary replicas
- Creating CDC Agent jobs on all replicas
- Synchronizing CDC configuration
- Automatically enabling CDC jobs only on the current primary replica

---

## The Problem

CDC relies on:

- SQL Agent jobs
- MSDB metadata
- Local server objects

Availability Groups replicate user databases, but they do **not** replicate SQL Agent jobs or MSDB CDC metadata.

After a failover:

1. A secondary becomes primary
2. CDC jobs do not exist or are disabled
3. CDC capture stops
4. Applications depending on CDC experience data gaps

---

## Solution Architecture

The solution implements:

| Component | Purpose |
|------------|-----------|
| CDC Job Schedules | Ensure jobs remain runnable after failover |
| MSDB CDC Metadata Table | Stores CDC job configuration |
| CDC Jobs on Every Replica | Makes jobs available locally |
| Metadata Synchronization | Synchronizes CDC configuration |
| AG Role Detection Job | Enables jobs on primary and disables them on secondary |

### Expected Behavior

Primary Replica:

- CDC Capture Job Enabled
- CDC Cleanup Job Enabled

Secondary Replica:

- CDC Capture Job Disabled
- CDC Cleanup Job Disabled

After failover:

- Former primary disables CDC jobs
- New primary enables CDC jobs
- CDC continues processing automatically

---

## Prerequisites

This guide assumes:

- SQL Server Availability Group already exists
- CDC is already enabled
- SQL Agent is running on all replicas
- Sufficient permissions exist to create jobs and objects in MSDB

---

# Step 1 - Add a Persistent Schedule to CDC Jobs

By default CDC jobs use startup behavior that may not restart correctly following an Availability Group failover.

Create an additional schedule that executes every five minutes.

Script:

```sql
-- See scripts/01_Add_CDC_Schedules.sql
```

---

# Step 2 - Create CDC Metadata Objects on Secondary Replicas

CDC stores job metadata in MSDB.

Create the supporting table and view on all secondary replicas.

Script:

```sql
-- See scripts/02_Create_CDC_Metadata.sql
```

---

# Step 3 - Create CDC Jobs on Every Replica

Script the CDC Capture and Cleanup jobs from the primary replica and deploy them to all secondary replicas.

### Important

Replace server-specific references in the scripts before deployment.

A quick method is:

1. Script jobs from primary
2. Connect to secondary
3. Perform find and replace on server name
4. Execute script

---

# Step 4 - Synchronize CDC Metadata

Generate INSERT statements from the primary replica and execute them on each secondary replica.

This keeps CDC metadata aligned across all nodes.

Scripts:

```sql
-- See scripts/03_Populate_CDC_Metadata.sql
```

After the inserts complete, synchronize job IDs:

```sql
-- See scripts/04_Sync_CDC_JobIds.sql
```

---

# Step 5 - Create CDC Job State Controller

A SQL Agent job runs every five minutes and determines whether the local replica currently owns the primary role.

If the replica is primary:

- Enable CDC Capture Job
- Enable CDC Cleanup Job

If the replica is secondary:

- Disable CDC Capture Job
- Disable CDC Cleanup Job

Script:

```sql
-- See scripts/05_AG_CDC_Job_Controller.sql
```

---

# Validation

Perform an Availability Group failover and verify:

```sql
SELECT
    sys.fn_hadr_is_primary_replica('YourDatabase');
```

Confirm:

- CDC jobs are enabled on the new primary
- CDC jobs are disabled on former primary
- CDC capture continues normally

---

# Benefits

✅ Automatic CDC recovery after failover

✅ No manual intervention

✅ Works with existing Availability Groups

✅ Prevents duplicate CDC processing

✅ Keeps CDC operational during role transitions

---

# Notes

This implementation was designed for environments with a single Availability Group. Environments containing multiple AGs may require additional logic for role detection.

Always test failover behavior in a non-production environment before deployment.
