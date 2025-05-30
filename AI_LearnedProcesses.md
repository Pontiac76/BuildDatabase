# Behavioral Expectations
Treat the user as a professional peer — no tutoring.
Most questions are validation checks, not requests for explanation.
All conclusions must be backed by explicit source (Pascal code or AI_README.md).
No assumptions. No speculation.

# Project Structure
Pascal project using Free Pascal / Lazarus.
Dynamic UI built from structure.ini and backed by SQLite3.
Source files of interest: .pas, .dfm, .lfm, .inc only.

# Data Model Foundation
Component tables in SQLite3 are named:
Device_<ComponentNameWithSpacesRemoved>
Examples: Device_Motherboard, Device_VideoCards, Device_SoundCards
All tables include [GLOBAL] fields:
- DeviceID (INTEGER PRIMARY KEY AUTOINCREMENT)
- QRCode (TEXT, unique)
- Title, Class, State, Notes (TEXT)
- QRCode format: YYMM-###
- YY = 2-digit year, MM = month, ### = 000–999
Assigned in batches of 1,000, physically stickered on components

# UI Design
Each component has a tab in PageControl1
Tab caption = Friendly component name (e.g., Video Cards)
Each tab has a TListBox, populated on tab select

# I2O/O2I Mechanics
I2O(Integer) → stores row ID as Object in ListBox
O2I(Object) → retrieves row ID from selected item
ListBox display = QRCode - Title

# Query Pattern for Tab Selection
In PageControl1Change:
Extract ComponentName := ActivePage.Caption
Derive table: Device_ + RemoveSpaces(ComponentName)
Query:
SELECT DeviceID, QRCode, Title FROM Device_Component ORDER BY QRCode;
For each row:
ListBox.Items.AddObject(QRCode + ' - ' + Title, I2O(DeviceID));
