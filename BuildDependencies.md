# Build Dependencies
## Authors Thought
I hate 'em.  But they're necessary.  I'm attempting to keep it as minimal as possible, and easy to install and get running.

## Image Processing Dependency

This project uses the [Vampyre Imaging Library](https://github.com/galfar/imaginglib) for image loading, resizing, and compression.

(You may have noticed that I have forked it on my own repository, however, my code relies on whatever is in MASTER on the galfar/imaginglib)

Vampyre Imaging Library is licensed under the Mozilla Public License 2.0 (MPL 2.0).

No Vampyre source code is included in this repository. The library is required at build time and can be installed manually by following instructions in their repository.


## 📷 Camera Support: DSPack Dependency

This application includes webcam support using **DSPack for Lazarus**, a Windows-only library that interfaces with DirectShow.

### Dependency Information

- **Library**: DSPack (Lazarus Edition)
- **Source**: [pl_Win_DsPack on Lazarus Package Manager](https://bitbucket.org/avra/ct4laz/downloads/)
- **License**: [Mozilla Public License 1.1 (MPL-1.1)](https://www.mozilla.org/MPL/1.1/)
- **Platform**: Windows only

### Licensing Notes

This project statically links against DSPack. Under MPL 1.1:

- You **may use this library in closed-source or differently licensed applications**.
- If you **modify any DSPack source files**, you must publish those changes (file-level copyleft).
- The rest of your application can remain under your own license.
- A copy of the DSPack source (or a link to it) must be made available if distributing binaries.

No changes have been made to the DSPack source files at this time.

### Installation

To enable camera support:

1. Open Lazarus.
2. Install the `pl_Win_DsPack` package via the **Lazarus Package Manager**.
3. Rebuild the Lazarus IDE when prompted.
4. Ensure `DSPack`, `DSUtil`, and related units are available in your unit scope.

Once installed, the application will be able to enumerate and interface with available video capture devices using DirectShow.

