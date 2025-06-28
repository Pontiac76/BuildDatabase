# Labels Clarifications

## App Layers

![image](https://github.com/user-attachments/assets/b114cd65-9e4e-482a-b023-4b0a45ff3b30)

### App Layer: Database
These are issues that deal directly with the Database itself and needs examination.  These issues typically are outside of Pascals control but dealing with the DB itself.

### App Layer: Interactions
These are issues with how the user interacts with the UI, not necessarily what the UI looks like or how it functions or interacts with other aspects of the application.

### App Layer: Logic
These are issues with how the application "thinks" and "acts".  This could tie into either UI or Database interactions.  These issues relate directly to the Pascal source code.

### App Layer: UI
These are issues to how the UI looks and feels and presents itself.  These are issues that deal with the form layouts.  This does not deal with how the user interacts with the software.

## Notes
This does not mean that these different layers can't be assigned to the same issue.

For example, UI and Interactions could be put together to indicate that there is something wrong with how the UI is layed out, and how the user interacts with the application.

Same with Logic and Database.  There may be some kind of logic problem that is affecting how the database is interacted with.

## Bugs
![image](https://github.com/user-attachments/assets/c1ed64bd-326b-4c55-9a97-d2335ffcbae6)

If a bug is entered into the system, a criticality assignment must be tagged to figure out where the priority is.

### Critical: High
Absolutely look at these ones first as this is an IMPACTING type of bug that prevents the software from functioning as REQUIRED or DEFINED.

### Criticality: Low
These are general "annoyances" with the application that doesn't affect use "at the end of the day" functionality.  These are issues where a panel isn't changing color, or, a dropdown doesn't populate correctly.  All the dropdowns (Except the ones that are Read Only) are editable and can still be submitted to the DB, so in this case, it's not an impacting-can't_use-world_ending problem, but should be looked at eventually.
