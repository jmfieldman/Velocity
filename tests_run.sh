#!/bin/sh

# Run dependency magnet on test package
swift run dependency_magnet pull \
  --config Tests/Dependencies/dependencies.yml \
  --workspace-path Tests/.dependency_magnet \
  --output-path Tests/Dependencies

(cd Tests && \
  swift run dependency_magnet_test && \
  swift package show-dependencies | grep unspecified --invert-match \
  )
