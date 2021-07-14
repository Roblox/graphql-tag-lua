#!/bin/bash

set -x

echo "Build project"
rojo build test-model.project.json --output model.rbxm
echo "Remove .robloxrc from dev dependencies"
find Packages/Dev -name "*.robloxrc" | xargs rm -f
find Packages/_Index -name "*.robloxrc" | xargs rm -f
echo "Run static analysis"
roblox-cli analyze test-model.project.json
selene --version
selene --config selene.toml src/
echo "Run tests"
roblox-cli run --load.model model.rbxm --run bin/spec.lua --fastFlags.overrides "UseDateTimeType3=true" "EnableLoadModule=true"
