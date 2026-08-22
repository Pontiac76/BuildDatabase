# BuildDatabase - Application Usage and Code Overview

## Audience

This document is intended for a seasoned developer who is new to this codebase and new to Pascal/Lazarus. It explains how the application behaves from a user point of view, how the UI is organized, and which source files/functions are important when porting the tool to another language or database.

The goal is not to teach Pascal. The goal is to explain what the existing program does and where those behaviors live.

---

## High-Level Application Purpose

BuildDatabase is a local desktop inventory application for cataloging retro/PC hardware and complete computer builds.

It manages:

- Individual hardware parts/components.
- Complete system builds.
- Relationships between builds and components.
- QR codes for builds and components.
- Component/build notes and specs.
- Photos attached to builds/components.
- Printable/copyable build summaries.
- Build sheets used to scan/import a whole system inventory.

The application is local-first. The current database is SQLite. Most UI is a Lazarus desktop application, but there is also a small LAN web server used for Android phone photo uploads.

---

## Main User Interface Mental Model

The main window is organized around a tab control.

### Main Tabs

1. **Build List**
   - Shows complete computer builds/systems.
   - Lets the user select a build.
   - Shows build notes/details.
   - Shows build photos and photos from attached components.
   - Shows a copyable build summary/card.

2. **Dynamic component tabs**
   - One tab per hardware category defined in `structure.ini`.
   - Examples: Motherboards, CPUs, Memory Sticks, Video Cards, Hard Drives, Sound Cards, etc.
   - Each tab has a list of components on the left and editable detail fields on the right.
   - Tabs are generated at startup from the configuration file, not all hard-coded in the form designer.

### Menus

The menu system contains normal application commands plus dynamically generated menu entries for component tabs.

Important menus include:

- **File/Image-related items**
  - Load image.
  - Paste image.
  - Phone photo server.
  - Exit.

- **Build List**
  - Build Sheet.
  - Create New Build.
  - Rename Selected Build.
  - Delete Build.
  - Add to Build Manifest.
  - Reset Entire Manifest for Selected Build.
  - Show Only Attached Hardware.
  - Refresh Build List.
  - Export System.
  - Export All Systems.

- **Dynamic component menus**
  - Created from `structure.ini` sections/order.
  - Used for Add/Edit/Delete-type component operations.

---

## Common User Workflows

### 1. Creating a New Build

User flow:

1. Open **Build List** menu.
2. Choose **Create New Build**.
3. Enter/confirm QR code and build title.
4. The app creates a row in `BuildList`.
5. The new build is selected in the Build List.

Important functions:

- `TForm1.mnuAddBuildClick`
- `TForm1.PromptAndValidateQRCodeAndTitle`
- `TForm1.RefreshBuildList`
- `TForm1.lbBuildListClick`

Database table:

- `BuildList`

---

### 2. Selecting a Build

User flow:

1. Click a build in the Build List listbox.
2. The app loads build notes/details.
3. The build summary/card memo updates.
4. The image strip updates.
5. If on a component tab, the component list may refresh to show/sort/filter parts based on the selected build.

Important functions:

- `TForm1.lbBuildListClick`
- `TForm1.LoadBuildDetails`
- `TForm1.PopulateBuildSummary`
- `TForm1.PageControl1Change`
- `TForm1.ReloadImagesOnScreen`

---

### 3. Editing Build Details/Notes

The Build List tab includes a memo/details area. When the memo loses focus, its content is saved.

Important function:

- `TForm1.Memo1Exit`

Database table:

- `BuildList`

---

### 4. Browsing Component Tabs

User flow:

1. User clicks a component tab such as CPUs or Video Cards.
2. The application finds the dynamic listbox for that tab.
3. It loads component rows from the corresponding `Device_*` table.
4. If a build is selected, items attached to the build are sorted to the top or filtered depending on the menu toggle.
5. If no component is selected, detail fields are cleared.

Important functions:

- `TForm1.PageControl1Change`
- `TForm1.LoadDataIntoListBox`
- `TForm1.ClearSpecsPane`
- `TForm1.UpdateBuildAssignmentStatus`

Database tables:

- `Device_Motherboards`
- `Device_CPUs`
- `Device_MemorySticks`
- etc.

The exact table names are built from `structure.ini` category names using `SafeComponentName`.

---

### 5. Selecting and Editing a Component

User flow:

1. User selects a component from a component tab listbox.
2. The app reads the component row from the matching `Device_*` table.
3. Detail fields are populated.
4. User edits fields.
5. When a field loses focus, the changed value is written to SQLite.

Important functions:

- `TForm1.ListBoxClick`
- `TForm1.PopulateSpecsPane(DeviceID, TabShortName)`
- `TForm1.ComponentExit`
- `TForm1.cboItemSelected`
- `TForm1.cboPopulateCombo`
- `TForm1.cboPopulateNumeric`

Important implementation detail:

- Detail fields are dynamically created from `structure.ini`.
- Field controls are registered in `GlobalComponentList` so event handlers can map a UI control back to a table/field.

---

### 6. Adding or Removing Components from a Build

User flow:

1. Select a build in Build List.
2. Go to a component tab.
3. Select a component.
4. Use the build assignment UI or menu action to add/remove it from the selected build.
5. The assignment status updates.

Important functions:

- `TForm1.AssignBuildButtonClick`
- `TForm1.HandleBuildComponentAction`
- `TForm1.AddBuildComponent`
- `TForm1.DeleteBuildComponent`
- `TForm1.GetBuildIdForComponent`
- `TForm1.UpdateBuildAssignmentStatus`

Database table:

- `BuildComponents`

Relationship concept:

```text
BuildList.BuildID
    -> BuildComponents.BuildID
BuildComponents.Component
    -> safe component/table name, such as CPUs or MemorySticks
BuildComponents.ComponentID
    -> Device_* table DeviceID
```

---

### 7. Show Only Attached Hardware Toggle

Menu item:

```text
Build List -> Show Only Attached Hardware
```

Behavior:

- No selected build: component tabs show all hardware.
- Selected build + toggle off: component tabs show all hardware, with attached items sorted first.
- Selected build + toggle on: component tabs show only attached hardware.

Important functions:

- `TForm1.mnuShowOnlyAttachedHardwareClick`
- `TForm1.LoadDataIntoListBox`
- `TForm1.PageControl1Change`

Preference storage:

```ini
[CardOutput]
ShowOnlyAttachedHardware=1
```

Important implementation note:

- Runtime writes to `structure.ini` should preserve comments. Use `WriteStructureIniBoolPreserveComments`, not normal `TIniFile.WriteBool`, for these settings.

---

### 8. Adding Photos

Photos can be added several ways:

- Load image from file.
- Paste image from clipboard.
- Upload from Android phone through the phone photo server.

Photos are attached to the currently selected build or component.

Important functions:

- `TForm1.mnuLoadImageClick`
- `TForm1.mnuPasteImageClick`
- `TForm1.ImportImageForComponent`
- `TForm1.SaveStreamToDatabase`
- `TForm1.SavePhonePhotoUpload`
- `TForm1.ReloadImagesOnScreen`

Database table:

- `ComponentImages`

---

### 9. Viewing and Editing Photos

User flow:

1. User clicks or right-clicks a thumbnail.
2. Photo viewer opens.
3. User can navigate previous/next.
4. User can open image in an external editor.
5. Edited image can be imported manually or auto-detected after save.

Important functions:

- `TForm1.ThumbnailClick`
- `TForm1.ViewImageByID`
- `TForm1.LoadPhotoIntoViewer`
- `TForm1.PhotoViewerKeyDown`
- `TForm1.PhotoViewerPrevClick`
- `TForm1.PhotoViewerNextClick`
- `TForm1.PhotoViewerOpenEditorClick`
- `TForm1.PhotoViewerImportEditedClick`
- `TForm1.PhotoViewerMonitorTimer`
- `TForm1.ImportEditedPhotoFile`

Important folders:

- `Editing` - temporary location for editor round-trip files.

---

### 10. Android Phone Photo Upload

User flow:

1. Select a build or component in the desktop app.
2. Start **Phone Photo Server**.
3. The desktop opens a modal server form.
4. User opens the displayed LAN URL on Android.
5. User takes a photo or chooses photos.
6. Photos upload into the selected target.
7. Close the server form when done.

Important files/functions:

- `frmphonephotoserver.pas`
- `ShowPhonePhotoServer`
- `TPhonePhotoServerForm.StartServer`
- `TPhonePhotoServerThread.Execute`
- `TPhonePhotoServerThread.ExtractUploads`
- `TPhonePhotoServerForm.DoUpload`
- `TForm1.mnuPhonePhotoServerClick`
- `TForm1.SavePhonePhotoUpload`

Important behavior:

- The upload target is locked when the modal server starts.
- The server is LAN/local only.
- Android is the intended phone platform.
- The desktop app remains the database owner.

---

### 11. Build Summary / Build Card

The Build List screen includes a memo used to create copyable/printable build-card text.

User-facing features:

- Short labels button.
- Long labels button.
- Copy button.
- Fixed-width output.
- Duplicate identical parts collapsed with `(x#)`.

Important functions:

- `TForm1.SetupBuildSummaryPane`
- `TForm1.BuildSummaryUseShortLabels`
- `TForm1.SetBuildSummaryUseShortLabels`
- `TForm1.BuildComponentLabel`
- `TForm1.PopulateBuildSummary`
- `TForm1.btnBuildSummaryShortClick`
- `TForm1.btnBuildSummaryLongClick`
- `TForm1.btnBuildSummaryCopyClick`

Configuration:

```ini
[ShortLabels]
Memory Sticks=RAM
Video Cards=GPU
Hard Drives=HDD

[CardOutput]
ShortTotalWidth=32
ShortLabelWidth=5
LongTotalWidth=40
LongLabelWidth=14
UseShortLabels=1
```

---

### 12. Build Sheet Workflow

The Build Sheet is a separate modal form used to scan or enter an entire system manifest.

User flow:

1. Open **Build List -> Build Sheet**.
2. Choose or define a build sheet model.
3. The model controls how many rows of each component type should appear.
4. User enters/scans build QR and component QRs/titles into a grid.
5. The app validates QR codes and enables Save when valid.
6. Saving creates/updates the build and component records.
7. It also recreates the build/component relationships.

Important file:

- `frmbuildsheet.pas`

Important functions:

- `TBuildSheet.RepopulateForm`
- `TBuildSheet.RegenSheetModels`
- `TBuildSheet.CreateComponentCounters`
- `TBuildSheet.cboBuildSheetModelChange`
- `TBuildSheet.StringGrid1SetEditText`
- `TBuildSheet.CheckSheet`
- `TBuildSheet.LoadSheet`
- `TBuildSheet.SaveSheet`
- `TBuildSheet.btnSaveSheetClick`
- `TBuildSheet.btnSaveModelClick`
- `TBuildSheet.btnPrintHTMLClick`

Important tables:

- `BuildSheets`
- `BuildSheetLists`
- `BuildList`
- `BuildComponents`
- `Device_*`

---

## Source File Guide

### `BuildDatabase.lpr`

The Lazarus program entry point.

Responsibilities:

- Starts the application.
- Includes the main forms/units.
- Creates the main form.

Porting note:

- This is equivalent to app bootstrap/startup code in other frameworks.

---

### `frmmain.pas` / `frmmain.lfm`

Main application form and most application behavior.

`frmmain.lfm` contains form layout and design-time controls. `frmmain.pas` contains event handlers and business/UI logic.

Major responsibilities:

- Build List UI.
- Dynamic component tab creation.
- Dynamic component field creation.
- Component list loading.
- Component editing.
- Build/component assignment.
- Image import, display, thumbnail handling.
- Photo viewer/editor round-trip.
- Build summary/card generation.
- Menu creation and menu event handling.

Most important functions:

- `FormCreate` - initializes runtime UI, menus, tabs, image viewer state, build list.
- `GenerateMenuSystem` - builds dynamic component menus from `structure.ini`.
- `CreateTab` - creates a component tab for a hardware category.
- `AddGlobalFieldsToFrame` - creates editable fields for a component tab from config/database metadata.
- `PageControl1Change` - refreshes active tab UI/data when switching tabs.
- `LoadDataIntoListBox` - loads component list rows for a tab.
- `ListBoxClick` - reacts to component selection.
- `PopulateSpecsPane` - loads component record values into fields.
- `ComponentExit` - saves edited field values.
- `RefreshBuildList` - reloads the build list.
- `lbBuildListClick` - central selected-build change handler.
- `LoadBuildDetails` - loads build notes/details.
- `AddBuildComponent` / `DeleteBuildComponent` - modify build-component relationships.
- `ReloadImagesOnScreen` - redraws thumbnail strip.
- `ImportImageForComponent` - imports images into `ComponentImages`.
- `SavePhonePhotoUpload` - saves phone-uploaded photos.
- `PopulateBuildSummary` - generates fixed-width build-card text.

Porting note:

- A future rewrite should probably separate this file into smaller modules: routing/controller logic, database repository, image service, build service, component service, and UI view models.

---

### `frmbuildsheet.pas` / `frmbuildsheet.lfm`

Build Sheet modal form.

Major responsibilities:

- Defines reusable build sheet models.
- Creates a grid for scanning/entering build and component QR/title data.
- Validates QR codes.
- Loads existing build/component info when QR codes are recognized.
- Saves a complete sheet into the database.
- Exports/copies build sheet data.
- Generates print-friendly HTML.

Important functions:

- `RepopulateForm` - sets up the build sheet form.
- `RegenSheetModels` - loads model list from database.
- `CreateComponentCounters` - creates controls for component counts per model.
- `NewSheetDB` - creates temporary in-memory worksheet table.
- `SaveSheet` - saves grid content into the temporary worksheet table.
- `CheckSheet` - validates/normalizes worksheet content.
- `LoadSheet` - loads temporary worksheet results back into the grid.
- `btnSaveSheetClick` - writes build/component data to main database.
- `StringGrid1SetEditText` - reacts as the user edits/scans grid cells.
- `ApplicationProperties1Idle` - enables/disables save based on validity.
- `btnPrintHTMLClick` - creates browser-printable HTML.

---

### `frmphonephotoserver.pas`

Modal LAN upload server for Android photo intake.

Major responsibilities:

- Finds LAN IPv4 address.
- Starts/stops a simple Winsock HTTP server thread.
- Serves an HTML upload form.
- Accepts multipart uploads.
- Reports progress/logs to the modal form.
- Calls back into the main form to save uploaded photos.

Important classes/functions:

- `TPhonePhotoServerThread` - background server thread.
- `TPhonePhotoServerThread.Execute` - accepts connections and handles requests.
- `TPhonePhotoServerThread.ReadRequest` - reads HTTP request data.
- `TPhonePhotoServerThread.ExtractUploads` - parses uploaded file data.
- `TPhonePhotoServerForm` - modal UI form.
- `ShowPhonePhotoServer` - public entry point used by the main form.

Porting note:

- In a rewrite, this could become a small HTTP API endpoint or be replaced by a native Android client talking to an API.

---

### `databasemanager.pas`

Database schema manager.

Major responsibilities:

- Creates required tables.
- Reads `structure.ini` to determine component table schemas.
- Merges global fields with component-specific fields.
- Adds fields/tables as needed.
- Handles SQLite schema migration-style operations.

Important functions:

- `DefineBuildList` - ensures `BuildList` exists.
- `DefineBuildComponents` - ensures relationship table exists.
- `DefineComponentImages` - ensures photo table exists.
- `DefineDevices` - creates/updates `Device_*` tables from `structure.ini`.
- `GetMergedFieldDefinitions` - combines `[GLOBAL]` fields with component-specific fields.
- `BuildCreateTableStatement` - creates SQL table definition.
- `AddFieldToTable` - adds missing fields.
- `StartSchemaEditForTable` / `GenerateInsertStatement` / `ExecuteSQLSteps` - heavier schema-edit helpers.

Porting note:

- The current schema is config-driven. A rewrite needs to decide whether to keep this dynamic model or replace it with a fixed schema plus metadata tables.

---

### `structure.ini`

Configuration file that drives much of the app.

Responsibilities:

- Defines global fields common to all components.
- Defines component categories and menu/tab order.
- Defines component-specific fields.
- Defines combo box choices.
- Defines UI captions/grouping metadata.
- Defines short labels for build-card output.
- Stores some simple runtime preferences.

Important sections:

- `[GLOBAL]` - fields included in every component table.
- `[ORDER]` - component categories and ordering.
- `[ShortLabels]` - compact names for build summary/card output.
- `[CardOutput]` - build-card formatting and preference settings.
- `[CPUs]`, `[Motherboards]`, etc. - per-component fields.

Example field definition:

```ini
RAMSlots=integer default 0;Fastest Slot Count|RAM Information
```

Conceptually this means:

- Database field: `RAMSlots`
- Type/default: `integer default 0`
- UI caption: `Fastest Slot Count`
- UI group: `RAM Information`

Porting note:

- This file is both configuration and documentation. Do not blindly rewrite it with an INI writer that strips comments.

---

### `simplesqlite3.pas`

Small SQLite helper wrapper.

Important functions:

- `OpenDB`
- `CloseDB`
- `NewQuery`
- `EndQuery`
- `TableExists`
- `BuildExists`

Porting note:

- This is a thin database utility layer. In a rewrite, this would likely become repository/database context helper code.

---

### `ustreamtodb.pas`

Binary stream to/from database helper.

Responsibilities:

- Compress streams with zlib.
- Decompress streams.
- Save streams into BLOB fields.
- Read BLOB fields back into streams.

Important functions:

- `CompressZlib`
- `DecompressZlib`
- `StreamToDB`
- `DbToStream`

Used heavily by image storage.

---

### `miscfunctions.pas`

General utility functions.

Important functions:

- `SafeComponentName` - converts display/category names into safe component/table identifiers.
- `FindAnyComponent` - recursive component lookup.
- `ValidateQRCode` - validates QR code format.
- `ListObject` - gets selected listbox item object as integer ID.
- `I2O` / `O2I` - converts integer IDs to/from TObject storage for listbox items.
- `ResizeImageMax` - image resize helper.
- `CalcCRC32Hex` - CRC helper.

Important Pascal/Lazarus pattern:

- Lazarus listboxes can store an object pointer alongside display text. This code stores integer IDs by casting them to objects using `I2O`, then recovers them with `O2I`.

---

### `framecomponentmanager.pas` / `.lfm`

Frame used inside dynamically created component tabs.

Responsibilities:

- Provides reusable UI structure for a component tab.
- Hosts component details/editor controls.

Porting note:

- Think of this as a reusable component detail panel/view.

---

### `componentdetails.pas` / `.lfm`

Older/supporting component details UI.

Some functionality appears to have shifted toward dynamic frames and `frmmain.pas`. Review before porting, but do not assume this is the primary current component editor.

---

### `tabgrouping.pas` / `.lfm`

Supporting UI/grouping unit related to tab/group layout.

This is less central than `frmmain.pas`, `structure.ini`, and `databasemanager.pas`, but may contain older or supporting layout behavior.

---

## Database Concepts

### Main Tables

#### `BuildList`

Represents complete systems/builds.

Typical fields:

- `BuildID`
- `BuildQR`
- `BuildName`
- Notes/details fields depending on schema version.

#### `BuildComponents`

Join table between builds and hardware components.

Typical fields:

- `BuildID`
- `Component`
- `ComponentID`

#### `Device_*`

One table per component category.

Examples:

- `Device_CPUs`
- `Device_Motherboards`
- `Device_MemorySticks`
- `Device_VideoCards`

Fields are based on `[GLOBAL]` plus that component's section in `structure.ini`.

#### `ComponentImages`

Stores photos/images.

Important concepts:

- `ComponentType` tells whether the image belongs to a build or hardware category.
- `ComponentID` points to the owning build/component ID.
- Raw image data is stored as a BLOB.
- Thumbnail data is also stored as a BLOB for faster UI rendering.

#### `BuildSheets` / `BuildSheetLists`

Used by the Build Sheet model system.

---

## Important UI/Data Patterns

### Config-Driven UI

Much of the UI is not statically designed. It is generated from `structure.ini`.

At startup:

1. The app reads `[ORDER]`.
2. It creates menus for component categories.
3. It creates tabs for component categories.
4. It creates fields based on `[GLOBAL]` and each category section.

This makes the app flexible but couples UI generation to config parsing.

---

### Safe Names vs Friendly Names

The user sees friendly names:

```text
Memory Sticks
Video Cards
Hard Drives
```

The code/database often uses safe names:

```text
MemorySticks
VideoCards
HardDrives
```

The important helper is:

```pascal
SafeComponentName(...)
```

A rewrite should preserve this concept or replace it with explicit IDs/slugs.

---

### Listbox Item Objects Store IDs

A common Lazarus pattern in this app:

```text
ListBox.Items[x] = display text
ListBox.Items.Objects[x] = database ID stored as object pointer
```

Helpers:

- `I2O(integer)`
- `O2I(TObject)`
- `ListObject(lb)`

In a web/mobile rewrite this maps naturally to list item view models containing both `label` and `id`.

---

### Detail Fields Save on Exit

Most component edits are saved when a field loses focus.

This is different from a Save button workflow.

In a rewrite, decide whether to keep auto-save or move to explicit Save/Cancel.

---

### Images Are Database-Owned

Images are not simply file paths. The database owns the image data.

A rewrite should decide whether to:

- Keep images as database BLOBs.
- Move images to object/file storage and keep metadata in database.
- Generate thumbnails in a background job/service.

---

## Suggested Rewrite/Porting Architecture

If converting to another language/framework, consider separating current responsibilities into these modules:

### Domain Models

- Build
- ComponentCategory
- Component
- BuildComponentAssignment
- ComponentImage
- BuildSheet
- BuildSheetModel

### Services

- BuildService
- ComponentService
- AssignmentService
- ImageService
- ThumbnailService
- BuildSummaryService
- BuildSheetService
- PhoneUploadService/API
- ConfigurationService

### Repositories/Data Access

- BuildRepository
- ComponentRepository
- CategoryMetadataRepository
- ImageRepository
- BuildSheetRepository

### UI/View Models

- BuildListView
- ComponentTabView
- ComponentDetailEditor
- ImageStrip/Gallery
- BuildSummaryCard
- BuildSheetEditor
- PhoneUploadScreen

---

## Recommended Reading Order for the Code

For understanding behavior, read in this order:

1. `structure.ini`
   - Understand categories, fields, and labels.
2. `frmmain.lfm`
   - See the static main form controls.
3. `frmmain.pas`
   - Start with `FormCreate`, `GenerateMenuSystem`, `CreateTab`, `PageControl1Change`.
4. `databasemanager.pas`
   - Understand schema generation.
5. `frmbuildsheet.pas`
   - Understand build sheet scanning/import workflow.
6. `frmphonephotoserver.pas`
   - Understand phone photo upload.
7. `ustreamtodb.pas`
   - Understand image/blob storage.
8. `miscfunctions.pas`
   - Understand naming, QR validation, and ID helper conventions.

---

## Key Pascal/Lazarus Concepts Seen in This Code

### `.pas` and `.lfm`

- `.pas` contains Pascal code.
- `.lfm` contains Lazarus form layout/resource data.

Together they define a form or frame.

### Event Handlers

Functions like these are UI event handlers:

```pascal
procedure TForm1.lbBuildListClick(Sender: TObject);
procedure TForm1.PageControl1Change(Sender: TObject);
procedure TForm1.ComponentExit(Sender: TObject);
```

They are equivalent to click/change/blur handlers in web or desktop UI frameworks.

### `TSQLQuery`

Database query object. Common pattern:

```pascal
q := NewQuery(S3DB);
try
  q.SQL.Text := 'select ...';
  q.ParamByName('id').AsInteger := SomeID;
  q.Open;
  ...
finally
  EndQuery(q);
end;
```

### `TStringList`

Used everywhere as a flexible list of strings, key/value map, or object registry.

### Dynamic Controls

Controls can be created at runtime:

```pascal
Edit := TEdit.Create(Frame2.CompDetails);
Edit.Parent := Frame2.CompDetails;
Edit.Name := ...;
Edit.OnExit := @ComponentExit;
```

This is how component-specific editor fields are built.

---

## Known Design Considerations for Rewrite

### Current Strengths

- Very flexible component/category schema.
- Local-first database.
- Practical QR/build sheet workflows.
- Photos are integrated directly into build/component records.
- Android upload workflow is simple and fast.
- Build summaries are printable/copyable.

### Current Complexity

- `frmmain.pas` contains too many responsibilities.
- UI, database, and business logic are tightly coupled.
- Schema is dynamic and INI-driven.
- Some older/retired code paths still exist.
- Auto-save-on-exit behavior may be surprising in a modern UI.
- Images as database BLOBs may or may not be ideal for a new implementation.

### Rewrite Choices to Make Early

- Keep SQLite or move to another database?
- Keep dynamic categories/fields or define fixed schema?
- Keep BLOB image storage or switch to file/object storage?
- Keep desktop as the database owner or create a client/server API?
- Keep QR code formats exactly compatible?
- Keep auto-save edits or use explicit Save buttons?
- Keep build sheet model workflow as-is or redesign it?

---

## Glossary

### Build

A complete computer/system, such as a retro PC build.

### Component

A hardware item, such as a CPU, RAM stick, video card, hard drive, etc.

### Component Category

The type/class of component, such as CPUs or Motherboards.

### Build Manifest

The list of components assigned to a selected build.

### Build Sheet

A scan/input worksheet for creating or updating a build and its attached components.

### QR Code

A string used to identify builds and components. The app validates QR formats before saving/importing.

### Safe Component Name

A sanitized name used for table/control names, derived from friendly category names.

### Thumbnail

A smaller cached image used for fast rendering in image strips.

---

## Summary for a Future Front-End Rewrite

The application is primarily an inventory manager with these core screens:

1. Build list and build detail screen.
2. Component category list/detail screens.
3. Build-component assignment workflow.
4. Image gallery/upload/viewer workflow.
5. Build sheet scanning/import workflow.
6. Printable build summary/card workflow.

The most important behavior to preserve is the relationship between builds, components, QR codes, and photos. The current UI is desktop/Lazarus-specific, but the underlying user goals translate well into a modern web/mobile application.
