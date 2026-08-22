# Android Photo Intake Companion - Requirements Notes

## Purpose

BuildDatabase is a local desktop inventory tool for cataloging computer hardware, complete builds, build sheets, QR codes, notes, and photos. The recent work added a lightweight phone/web photo intake workflow so an Android phone can quickly send component/build photos into the desktop application without cables, cloud sync, or manual file copying.

This document describes the current workflow and the important requirements for a possible Android app or front-end UI replacement/companion.

## Current Desktop Tool Summary

The desktop application is a Lazarus/FPC application using SQLite as the local database. It manages hardware categories such as motherboards, CPUs, RAM, video cards, hard drives, network cards, sound cards, power supplies, monitors, keyboards, mice, speakers, accessories, and modems.

The application has:

- A **Build List** tab for complete systems/builds.
- Dynamic component tabs for each hardware type defined in `structure.ini`.
- A component detail editor for fields such as QR code, title, class, state, notes, and component-specific specs.
- Photo storage in the SQLite database through the `ComponentImages` table.
- Thumbnail caching for faster browsing.
- A local phone upload server for Android photo intake.
- Build summaries/card text for copying or printing.
- Build sheet support for scanning/importing build hardware lists.

## Current Android/Web Photo Workflow

The desktop app can start a modal **Phone Photo Server**. While this form is open, the main application is locked so the photo target cannot accidentally change.

The server:

- Runs locally on the LAN.
- Listens on port `9088`.
- Shows the LAN URL to open on the Android phone.
- Provides an **Open Browser** button on the desktop, but does not auto-launch the browser.
- Accepts single camera uploads.
- Accepts multiple existing gallery/photo uploads.
- Saves uploaded images directly into the selected target in the database.
- Shows progress/logging during upload.

The intended user workflow is:

1. In the desktop app, select a build or component.
2. Start the phone photo server.
3. Open the shown URL on the Android phone.
4. Take a new photo or select existing photos.
5. Upload them.
6. Close the phone server when finished.
7. Photos appear in the selected build/component image strip.

## Important Behavior Requirements

### Target Locking

When the phone upload session starts, the target build/component should be locked.

This is important because the user may click around in the desktop app or phone uploads may arrive later than expected. Uploaded photos should always go to the item that was selected when the upload session began, not whatever happens to be selected afterward.

### Local/LAN Only

The current design assumes local LAN use only.

Security/tokening/authentication is not currently important for this tool because it is used locally by the owner on a trusted network.

A future Android app should still be simple and local-first unless requirements change.

### Android Only

The expected phone platform is Android. There is no requirement to support iPhone/iOS.

### Modal Desktop Session

The desktop phone server form is modal. This is intentional.

The user should not be able to change the target object while the phone upload session is active.

### Multiple Upload Sources

The phone-side UI should support both:

- Taking a new photo from the camera.
- Selecting one or more existing photos from the gallery/files.

### Upload Feedback

The user should see enough feedback to know uploads are happening and completed.

Current desktop feedback includes:

- Upload progress bar.
- Text log/status messages.
- Upload success/failure messages.

A future front-end should include similar simple feedback.

## Image Storage and Display

Photos are stored in SQLite, not as loose files.

The image table stores original/raw image data and generated thumbnail data. Thumbnail support was added because decoding full images for every thumbnail was too slow.

Important image features:

- Images can belong to a build.
- Images can belong to a component.
- Build image display includes photos directly attached to the build plus photos attached to its components.
- Thumbnail strip rendering prefers cached thumbnails.
- If a thumbnail is missing, the app can fall back to raw image data.
- Missing thumbnails can be regenerated.

## Photo Viewer and Editing Workflow

The desktop app has a photo viewer.

Viewer features:

- Open/view selected photo.
- ESC closes viewer.
- Previous/Next navigation.
- Left/right navigation support.
- Open photo in external editor.
- Import edited photo back into the database.

Editor round-trip behavior:

- Edited files are placed in an `Editing` directory.
- The app watches edited files for timestamp changes.
- After a file stops changing for about 2 seconds, the app can auto-import it.
- The `Editing` directory is cleaned at app startup.

A future Android app may not need this editor workflow, but if it shows images, it should understand that images are database-backed and may have thumbnails.

## Build List and Attached Hardware Filtering

The Build List tab manages complete systems/builds.

Important Build List features:

- Create new build.
- Rename selected build.
- Delete build.
- Add/remove components from a build manifest.
- Reset manifest for a selected build.
- Export build/system data.
- View build photos and component photos.
- Show a copyable build summary.

A new toggle exists:

**Build List → Show Only Attached Hardware**

Behavior:

- If no build is selected, component tabs show all hardware.
- If a build is selected and the toggle is off, component tabs show all hardware, with attached items sorted near the top.
- If a build is selected and the toggle is on, component tabs show only hardware attached to the selected build.

When changing to a tab with no selected component, all detail fields should be blank. Stale data from a previously selected item should not remain visible.

## Build Summary / Build Card Output

The Build List screen now has a copyable memo-style build summary instead of dynamically generated group boxes.

This is intended for small printed build cards, possibly credit-card-sized labels.

Current behavior:

- Summary starts with the build name.
- Component labels can use long names or short names.
- Short labels come from `structure.ini` under `[ShortLabels]`.
- Output is fixed-width, pre-wrapped text.
- It intentionally avoids tab-delimited Excel formatting because Excel word wrap disturbed the layout.
- Duplicate identical parts are collapsed using an `(x#)` suffix before wrapping.

Example:

```text
Build Pentium - 233Mhz

CPU   Intel Pentium MMX 233
RAM   Samsung 256MB PC133 (x4)
GPU   S3 Trio64V+
HDD   Quantum Fireball 4.3GB
```

Relevant `structure.ini` settings:

```ini
[ShortLabels]
Motherboards=MB
CPUs=CPU
Memory Sticks=RAM
Video Cards=GPU
Hard Drives=HDD

[CardOutput]
ShortTotalWidth=32
ShortLabelWidth=5
LongTotalWidth=40
LongLabelWidth=14
IncludeBuildName=1
BlankLineAfterBuild=1
UseShortLabels=1
ShowOnlyAttachedHardware=1
```

The selected short/long summary mode persists across restarts.

Runtime preference writes must preserve comments in `structure.ini`.

## Build Sheet Printing

The Build Sheet form has export buttons and now includes a print-friendly HTML export.

The HTML export:

- Writes a temporary HTML file.
- Opens it in the default browser.
- Uses minimal margins for printing.
- Displays a compact table with component, QR code, and description.

The goal is to provide enough writable space on the printed build sheet.

## Possible Android App Goals

If building an Android companion app, the first useful version should focus on photo intake.

Recommended MVP:

1. Let the user enter or discover the desktop server URL.
2. Show the currently selected upload target if the server exposes it.
3. Provide buttons for:
   - Take Photo
   - Pick Photos
   - Upload
4. Show upload progress and result messages.
5. Keep the UI simple and fast.
6. Assume trusted LAN use.

Possible later features:

- Browse builds.
- Browse components attached to a build.
- Show thumbnails from the desktop app/server.
- Upload photos to a selected build/component directly from the phone.
- Scan QR codes and look up hardware.
- Create or edit component titles/notes from the phone.
- Print/share build summaries.

## Front-End/UI Requirements Notes

The phone/web UI should be simple and task-focused.

Important screens/components:

### Connection Screen

- Server URL input.
- Connect/test button.
- Recent server address storage.
- Clear error messages if the desktop server is not running.

### Upload Screen

- Current target display.
- Take Photo button.
- Pick Existing Photos button.
- List of selected files/photos.
- Upload button.
- Upload progress/status.
- Success/failure messages.

### Optional Gallery/Review Screen

- Show uploaded images or thumbnails if supported by the server.
- Allow removing a mistaken image only if the desktop/server supports deletion.

## Non-Goals for Initial Version

The following are not required for the initial Android/front-end companion:

- iOS support.
- Cloud sync.
- User accounts.
- Internet-facing server support.
- Complex authentication.
- Full database management from the phone.
- Replacing the Lazarus desktop application.

## Key Technical Concepts

- Desktop app owns the SQLite database.
- Phone/web UI should act as a client/uploader.
- Photo target should be locked for the upload session.
- Images are stored in the database, not just copied into folders.
- Thumbnails are important for performance.
- `structure.ini` defines hardware categories, labels, card output settings, and UI metadata.

## Current Implementation Files of Interest

For reference in the codebase:

- `frmmain.pas` - main form, build list, component tabs, images, summaries.
- `frmmain.lfm` - main form UI layout.
- `frmphonephotoserver.pas` - LAN phone upload server.
- `frmbuildsheet.pas` - build sheet logic and print HTML export.
- `structure.ini` - component/category definitions and build-card settings.
- `ustreamtodb.pas` - image stream/database helper code.
- `miscfunctions.pas` - shared helpers.

## Practical User Story

As a hardware collector/cataloger, I want to select a computer build or component on my desktop, open a phone upload page on my Android phone, take or select photos, and have those photos automatically attach to the correct item in my local database, so I can document hardware quickly without manually copying files from my phone.

