# BuildDatabase Current Workflow Risks

## Modeless Build Sheet Synchronization Risks

The Build Sheet is now intended to stay open as a normal/modeless maintenance window. The main form can update behind it while the sheet remains visible.

Known risks to revisit later:

- If component assignments are changed on the main form while the Build Sheet is open, the sheet may not automatically reflect those changes unless the selected build changes or the sheet is manually rebuilt.
- If a component title or QR code is edited on the main form while the Build Sheet is open, visible grid rows may become stale until rebuilt.
- If a component is deleted while shown on the Build Sheet, the sheet may still show the old row until rebuilt.
- If the user edits grid contents and then changes build/model/Show Full Build before clicking Update Sheet or Save Sheet, those unsaved grid edits are discarded by design.
- Save/Update uses visible grid component groups as the replacement scope for build assignments. Hidden groups should be preserved, but any unexpectedly visible stale rows could still affect assignment replacement.
- The temporary Build Sheet `:memory:` SQLite connection should be defensively closed before creating a new one. This is a known cleanup/future fix.

Short-term intent: prioritize faster show-prep workflow over perfect synchronization safety.
