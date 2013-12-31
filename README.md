Stages
======

This is a wrapper macro that supplies:

1. simple name-based memoization (note: not @memoize)
2. invocation of stage functions is asynchronous
3. the wrapper defines two versions of the function:
    1. a version that takes inputs as they are declared
    2. a version that takes wraps inputs remote references and where prior to calling the original version, we wait for the inputs

Scripts using stages would ideally run in something like an ijulia
notebook.  Currently, ijulia notebooks don't handle magics, but
eventually, when they do, we can clean up/manage checkpoints via
filesystem commands.

Note: Ipython checkpoints provide script versioning but they don't
checkpoint execution.

Execution Contexts
==================

This i

Memoization Log
===============
