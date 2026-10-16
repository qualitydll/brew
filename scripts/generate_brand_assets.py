from __future__ import annotations

from io import BytesIO
from pathlib import Path
import zipfile

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "brewicon.png"
ICON_ARCHIVE = ROOT / "Brew_Icons_Windows_Android.zip"
ASSET_DIR = ROOT / "assets" / "images"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
WINDOWS_ICON = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def fit(image: Image.Image, size: int, safe_fraction: float = 0.78) -> Image.Image:
    source = image.convert("RGBA")
    safe_size = max(1, int(size * safe_fraction))
    fitted = ImageOps.contain(source, (safe_size, safe_size), method=Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return canvas


def _score(name: str, size: tuple[int, int], target: int | None = None) -> tuple[int, int, int]:
    lower = name.lower()
    path_score = 0
    if "android" in lower or "mipmap" in lower:
        path_score += 30
    if "launcher" in lower or "app_icon" in lower:
        path_score += 20
    if "windows" in lower or "win32" in lower:
        path_score += 25
    if "logo" in lower or "main" in lower or "512" in lower or "1024" in lower:
        path_score += 15
    if "preview" in lower or "mockup" in lower or "screenshot" in lower:
        path_score -= 100
    area = size[0] * size[1]
    exact = 1 if target is not None and size == (target, target) else 0
    return (exact, path_score, area)


def load_archive():
    images = []
    if not ICON_ARCHIVE.is_file():
        print("Brand icon ZIP not present; using the repository source logo.")
        return images
    with zipfile.ZipFile(ICON_ARCHIVE) as archive:
        for info in archive.infolist():
            if info.is_dir() or Path(info.filename).suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp", ".ico"}:
                continue
            try:
                raw = archive.read(info.filename)
                with Image.open(BytesIO(raw)) as image:
                    image.load()
                    images.append((info.filename, raw, image.copy().convert("RGBA"), image.size))
            except Exception as exc:
                print(f"Skipping unreadable icon {info.filename}: {exc}")
    print("Icon ZIP images:")
    for name, _, _, size in images:
        print(f"  {name} — {size[0]}x{size[1]}")
    return images


def best_source(images: list[tuple], fallback: Image.Image) -> Image.Image:
    pngs = [item for item in images if Path(item[0]).suffix.lower() != ".ico"]
    if not pngs:
        return fallback.convert("RGBA")
    square = [item for item in pngs if item[3][0] == item[3][1]]
    candidates = square or pngs
    selected = max(
        candidates,
        key=lambda item: (item[3][0] * item[3][1], _score(item[0], item[3])[1]),
    )
    print(f"Primary app artwork: {selected[0]} ({selected[3][0]}x{selected[3][1]})")
    return selected[2]


def exact_size_source(images: list[tuple], size: int) -> Image.Image | None:
    pngs = [
        item for item in images
        if Path(item[0]).suffix.lower() != ".ico" and item[3] == (size, size)
    ]
    if not pngs:
        return None
    return max(pngs, key=lambda item: _score(item[0], item[3], size))[2]


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Brand image not found: {SOURCE}")

    images = load_archive()
    with Image.open(SOURCE) as original:
        original.load()
        source = best_source(images, original)

    # Downsample app artwork so oversized source files do not inflate decoded
    # Flutter image memory. The uploaded archive remains untouched in git.
    app_art = fit(source, 512, 0.94)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    app_art.save(ASSET_DIR / "brew_logo.png", format="PNG", optimize=True)
    app_art.save(ROOT / "brewicon.png", format="PNG", optimize=True)

    android_nodpi = ANDROID_RES / "drawable-nodpi"
    android_nodpi.mkdir(parents=True, exist_ok=True)
    app_art.save(android_nodpi / "brewicon.png", format="PNG", optimize=True)

    foreground_dir = ANDROID_RES / "drawable"
    foreground_dir.mkdir(parents=True, exist_ok=True)
    fit(source, 432, 0.68).save(
        foreground_dir / "ic_brew_foreground_image.png", format="PNG", optimize=True
    )

    for folder, size in ANDROID_SIZES.items():
        target_dir = ANDROID_RES / folder
        target_dir.mkdir(parents=True, exist_ok=True)
        exact = exact_size_source(images, size)
        icon = exact if exact is not None else fit(source, size, 0.70)
        icon.save(target_dir / "ic_launcher.png", format="PNG", optimize=True)
        print(f"Android icon {folder}: {size}x{size} ({'from ZIP' if exact is not None else 'resized from source'})")

    WINDOWS_ICON.parent.mkdir(parents=True, exist_ok=True)
    windows_icos = [item for item in images if Path(item[0]).suffix.lower() == ".ico"]
    if windows_icos:
        selected_ico = max(
            windows_icos,
            key=lambda item: (
                1 if "windows" in item[0].lower() or "win" in item[0].lower() else 0,
                item[3][0] * item[3][1],
            ),
        )
        WINDOWS_ICON.write_bytes(selected_ico[1])
        print(f"Windows EXE icon: {selected_ico[0]} (copied unchanged)")
    else:
        fit(source, 256, 0.78).convert("RGB").save(
            WINDOWS_ICON,
            format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
        )
        print("Windows EXE icon: generated multi-size ICO from supplied artwork")

    print("Generated optimized Brew assets; VPN/core files were not modified.")


if __name__ == "__main__":
    main()
