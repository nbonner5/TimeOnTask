# Time on Task branding

The current logo uses a restrained clock/checkmark silhouette with native macOS icon materials. The menu bar uses the original SF Symbol timer/pause indicator to preserve its status behavior.

## Current artwork

- `v2/time-on-task-symbol.png`: transparent foreground generated with the built-in image generation tool.
- `v2/generation-prompt.txt`: exact generation prompt.
- `v2/time-on-task-light.png`: light icon rendered by Apple's Icon Composer command-line tool.
- `v2/time-on-task-dark.png`: dark icon rendered by the same tool.
- `../TimeOnTask/AppIcon.icon`: editable native Icon Composer document, including light/dark fill specializations. Open this document in Icon Composer to refine the material, lighting, and appearance variants.
- `../TimeOnTask/Assets.xcassets/AppIcon.appiconset`: light icon sizes for older macOS releases.
- `../TimeOnTask/Assets.xcassets/BrandIcon.imageset`: transparent mark used with adaptive template tint in the SwiftUI wordmark.

The mark was generated with the built-in image generator, then composed with native Icon Composer fills and materials. Resizing uses macOS `sips`. The wordmark text is rendered natively to remain sharp and adapt to the app's appearance.

## Previous artwork

`time-on-task-icon-master.png`, `brand-icon-v1.png`, and `generation-prompt.txt` preserve the previous icon and prompt. The app no longer references that artwork.
