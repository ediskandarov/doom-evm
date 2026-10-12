# Release-preparation evidence

New bounded checks against integrated baseline
`1b728fe3f8307a49f71437d5af75a4935df81492`. See the
[release report](../../docs/release/READINESS.md) for scope, commands, results,
failures and limitations. These records supplement earlier certificates.

- `build.json` / `build.log`: 85-file production compile, unchanged pins/settings.
- `build-warm.json` / `build-warm.log`: successful unchanged cache reuse.
- `package.log`: byte-identical source-bound browser packages.
- `toolchain.json`, `install-toolchain-atomic.log`, `installer-tests.log`: exact
  environment, real pinned reinstall and two focused regression tests.
- `download.log`, `native-resources.log`, `resource-identity.log`, `node.log`:
  authenticated resources, nine-map native resource checks and 153 Node tests.
- `browser-summary.json`: metadata from the successful three-game check;
  21 checks, 20 EVM-to-Canvas comparisons, source/runtime/resource identities,
  receipt and frame hashes. Original full report/journals/screenshots stay local.
- `quickstart.json`: actual Python HTTP responses, MIME/content hashes, Anvil
  arguments, CORS/chain/gas checks and owned runtime cleanup.
- `media.json`: unchanged accepted MP4 hash, README GIF hash and FFmpeg version.
- `audit.json`: protected-baseline blob digest, compiler/source/artifact identity,
  submodule pin, no tracked IWAD/MP4 and local documentation checks.
- `manifest.json`: SHA-256 identities of the committed evidence in this directory.

Failures are retained in `node-missing-assets.log`, `node-missing-native.log`,
`install-toolchain.log` and `historical-runner-failure.json`. The latter preserves
the failed unavailable-profile assertion; it is not a passed browser acceptance.

The compact browser summaries are explicitly derivatives of hash-bound raw local
reports. They omit installation palettes and large receipt lists, and contain no
commercial pixel or IWAD payloads. Screenshots and journal paths identify local
evidence; those files are not promised in a clone. Canvas equality authenticates
display of EVM output, not native framebuffer equality.
