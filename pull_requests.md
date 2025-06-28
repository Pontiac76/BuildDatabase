# Rules about Pull Requests

## Forms (LFM files)
Unless you're adding components to the form at design time, don't include the LFM file.  These changes are typically moving forms around the screen, or changing the size of the form to fit your screen, or whatever the case may be.  Before including the LFM, look at a diff of what is being changed.  If it's just positioning don't include as part of your commit.  If it's adding components, prior to the submit, change the forms position to 0,0 so that it'll show up at home position.

### Exceptions
- Of course, if you're adding/deleting components to the form, then do include the LFMs
- If for whatever reason the order of components get changed, such as parent to child relations, do include
- If you're creating a brand new LFM, then yes, absolutely that'll need to be included
- Component name changes


### What shouldn't be submitted
- Form position changes only

# How to check
I personally setup VSC to open the folder where this source code lives.  I then do my branching and code views through it.  I do no editing in VSC for this code, and I ignore the errors VSC reports (Because it's not trained on include directories, etc) but I'll view its diff view with ease.
