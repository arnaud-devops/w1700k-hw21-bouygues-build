# Upstream provenance

This package is vendored from:

- repository: `https://github.com/gSpotx2f/luci-app-log`
- commit: `69226866b51f90c35390dfe57875d56d337d8b56`
- package: `luci-app-log-viewer` version `1.5.0-r2`
- license: MIT, preserved in `LICENSE`

Only the package build files are included. Screenshots, development examples
and other repository-only material are intentionally omitted.

Upstream `1.5.0-r3` is deliberately not selected: it disables
`htmlEntities()` escaping while the log table still renders content through
`insertAdjacentHTML()`. This pinned revision keeps log-message escaping.
