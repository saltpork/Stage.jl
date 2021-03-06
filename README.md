Stages
======

<img align=right src="https://travis-ci.org/saltpork/Stage.jl.svg?branch=master" alt="Build Status"/>

This is a wrapper macro that supplies:

1. simple name-based memoization/checkpointing (note: not @memoize)
2. injected logger and ckpts arguments
3. invocation of stage functions is asynchronous via `@spawn`
4. results are returned as remote ref of tuple (result, logger-output)

Scripts using stages would ideally run in something like an ijulia
notebook.  Currently, ijulia notebooks don't handle magics, but
eventually, when they do, we can clean up/manage checkpoints via
filesystem commands.

Note: Ipython checkpoints provide script versioning but they don't
checkpoint execution.

News
----

11/1 -- Last 0.3 version tagged

11/1 -- Initial port to 0.4 passing

7/27 -- ported to 0.6

