Homework 09
===========

1. As discussed in class, working with **system calls** can be tricky because
   unlike most normal functions, they can fail.  For each of the following
   scenarios involving `moveit`, identify which **system calls** would fail (if
   any) and described you handled that situation:

    - No arguments passed to `moveit`.

    No system calls would fail for this reason. All that would happen is that no
    files would be created and the user would not have the chance to change any
    names. This program would therefore be completely useless.

    - `$EDITOR` environmental variable is not set.

    No system calls would fail. All that happens is that the editor variable is
    set to a default, which for me is vim. If we did not set this to a default,
    exec would fail because it would be called on nothing.

    - User has run out of processes.

    The fork system call would fail in this case because no new processes could
    be created. I accounted for this by checking if the pid returned from fork
    is less than 0 and returning false if that is the case.

    - `$EDITOR` program is not found.

    The exec system call would fail in this case. Exec will be called with
    something that is not a valid path to a function which will cause it to
    fail. Once again, I just return false to main if this is the case so my
    program knows that something failed.

    - Temporary file is deleted before moving files.

    Fopen would fail in this case. It would try and open a path that no longer
    exists. I checked for this by returning false if !file, which once again
    just tells main that something went wrong and cause it to exit the program.

    - Destination path is not writable.

    Rename would fail in this case because we would no longer have permission to
    edit anything in the file, which is what it is doing. I check if rename is
    less than zero and return false to main if it is, once again signaling that
    something went wrong and exiting the program. Another check we do is
    explicitly make the path writeable so that this does not happen.

2. As described in the project write-up, the **parent** is doing most of the
   work in `timeit` since it `forks`, `times`, and `waits` for the **child**
   (and possibly kills it), while the child simply calls `exec`.  To distribute
   the work more evenly, **Bill** proposes the following change:

    > Have the **child** set an `alarm` that goes off after the specified
    > `timeout`.  In the signal handler for the `alarm`, simply call `exit`, to
    > terminate the **child**.  This way, the **parent** just needs to `wait`
    > and doesn't need to perform a `kill` (since the **child** will terminate
    > itself after the `timeout`).

    Is this a good idea?  Explain why or why not.

    I do not think this is a good idea. The parent would be the one handling the
    signal from the child, since the child is a completely different program
    once we call exec. Therefore, the child no longer has the signal handler.
    The parent process would therefore be the one calling exit, which would exit
    the parent but would do nothing to kill its child. This would leave the
    child process running after its parent has been exited, which is not what
    we want at all. 
