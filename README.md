# Premise

A training tracker that is needed by pet owners to bridge the gap between the last Trainer visit and the next. Further, after the last Trainer visit, this tool can be used to manage ongoing owner training.

# Intended Buyer

1. Trainers who then direct guardians to download the app
2. Guardian who wants to use it

## What it Doesn’t Do

- Create a Training Plan
- No prescribed Training Plan
- No promises. No Guarantees
- Doesn’t teach the Guardian how to train. That’s the Trainers job.

## What it Does Do

- Gives Guardians rewards for making progress
- Enables guardians to track Training Sessions
- Enables guardians to track more than one pet
- Enables guardians to share training results
- Enables guardians to store video recording or photos of their or a pet
- Enables guardians to read Trainer-delivered notes
- Enables Trainers to deliver training plans to guardians

# Use Cases

## Guardian

### First Time Use

- Create an account
- Visit Home Screen

### Saving References

- articles
- YouTube videos
- Document
- Videos & Photos
    - Associated Notes
    - Date stamp

### Share Account (Grant Access) …to Trainer

- Permissions
    - Read, Write, Comment

### Log a Training Session

- Log a *Training Record*

### Create a Pet

- Create a *Pet Record*

## Trainer

### CRUD a Guardian

- Guardian Record
- Create/Read/Update/Delete a Guardian

### Create a Training Plan for a Guardian

- Design a Training Record

### Share Training Plan with a Guardian

- with one or more guardians

### View Guardians

- View a selectable list of Guardians

### Select Guardian

- from the **View Guardians** result

### View Guardian

- View *Guardian Record*
- View *Pet Records*
- View *Training Plan* records
- View *Training* records

### Link/Unlink Guardians

- Two Guardian for one or more pets

### Comment on a Training (Record)

- Ideally in Confluence-style but …

### Add Material to Guardian Materials

- URL
- Photo
- Note
- etc.

## Habit Hound App

- Analyze Training Records and suggest what?

# Features

## CRUD a Training Plan

- Used by both trainers and guardians
- User can add up to 5 user-defined properties (Table Columns)
- For one Guardian
- For all Guardians
- TBD

## Attach Training Plan to Pet

- If created separately of course

## CRUD a Training Record

- Only Guardians can do this
- For a Pet

## CRUD a Material Record

- Only Guardians can do this

## CRUD a Behavior Record

- For a Pet

## CRUD a Pet Record

- Only Guardians can do this

## CRUD a Guardian Record

- Not delete of course
- Only Guardians can do this

## Link Guardian Records

- Husband and Wife scenario
- Only Trainers can do this
- Maybe v2 Guardians could do this

# Database

## Material Record

**Table Properties**

- image
- video
- notes
- url
- etc

## Behavior Record

**Table Properties**

- Behavior
    - Enumerated list
- DateTime
- Trigger
- Notes

## Pet Record

**Table Properties**

- **Status History**
- **Pet name**
- **Photo**

## Guardian Record

**Table Properties**

- traditional person properties
- Client start - when the Guardian became a client
- Client end - when the Guardian stopped being a client
- Client History - start and end history
- notes

## Training Record

**Table Properties**

- **Pet Name**
- **DateTime**
- **Share**
- **Status**
    - red - not getting it
    - orange - occasional success
    - yellow - half way there
    - green - Success
- **What’s Next** - What the guardian should do next
- **Three D**’s.
    - Distance - Owner editable
        - Arm’s length
        - 6 feet
        - 12 feet
        - 20 feet
        - 20+ feet
    - Distraction - Owner editable
        - None
        - Any
    - Duration - Owner editable
        - instant
        - 5 seconds
        - 5+ seconds
- **Notes**