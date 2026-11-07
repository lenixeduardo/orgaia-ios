# CI investigation: Foteka Share Extension installer

On 7 November 2026, the iOS Simulator unit test host failed before running XCTest:

```
extensionDictionary must be set in placeholder attributes for an app extension placeholder
```

## Confirmed cause

The source `ShareExtension/Info.plist` included the `NSExtension` dictionary. However, the compiled
`OrgaIAShare.appex/Info.plist` did **not** contain this dictionary (confirmed by
`plutil -p` and `PlistBuddy` in CI run 42335383396).

The original XcodeGen `project.yml` contained:

```yaml
info:
  path: ShareExtension/Info.plist
```

XcodeGen regenerates any `info.path` on every project generation. With no `info.properties`, it
silently overwrote the manually curated extension configuration. The same behavior applies to
`entitlements.path` and can remove App Group entitlements.

## Fix

- Removed generated `info:` and `entitlements:` entries for the app and Share target.
- Added explicit `INFOPLIST_FILE` and `CODE_SIGN_ENTITLEMENTS` build settings.
- Preserved the checked-in `Info.plist` and entitlements as the authoritative sources.
- Added CI assertions immediately after `xcodegen generate` and after `xcodebuild build` to ensure
  the bundled Share Extension still has `NSExtension` and the App Group file is intact.
- Do not remove the Share Extension just to make the simulator tests pass.

Related documentation: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md

Status: remediation committed; pass/fail of Xcode simulator installation must be confirmed by
the subsequent Actions run.
