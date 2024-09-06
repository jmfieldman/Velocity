#!/bin/sh

# Run dependency magnet on test package
(cd DependencyMagnet && \
  swift run dependency_magnet pull \
    --config Tests/Dependencies/dependencies.yml \
    --workspace-path Tests/.dependency_magnet \
    --output-path Tests/Dependencies
)

(cd DependencyMagnet/Tests && \
  swift run dependency_magnet_test && \
  swift package show-dependencies | grep unspecified --invert-match \
)
