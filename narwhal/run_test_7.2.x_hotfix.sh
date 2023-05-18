#!/bin/bash

# shellcheck disable=SC2086,SC2068
./run_release_builder.sh -e NARWHAL_DEBUG=1 -e NARWHAL_OUTPUT=hotfix -e NARWHAL_HOTFIX_TESTING_TAG=test-fix-pack-new-builder -e NARWHAL_HOTFIX_TESTING_SHA=768f6f3952d147585dfc647a75adaa150fad08a6 ${@}