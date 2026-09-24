# Containers

`prism-flow.def` is an Apptainer/Singularity definition for the orchestration environment.

For a validated production release, tool-level containers should be built immutably and referenced by digest rather than relying only on mutable package channels. The workflow currently uses pinned Conda environments for readability and portability.
