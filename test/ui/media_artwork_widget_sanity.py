#!/usr/bin/env python3
"""Sanity checks for activity artwork-only Text widget dispatch."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
activity = (ROOT / "src/qml/components/entities/activity/deviceclass/Activity.qml").read_text()
artwork = (ROOT / "src/qml/components/entities/activity/MediaArtworkWidget.qml").read_text()
qrc = (ROOT / "resources/qrc/main.qrc").read_text()
docs = (ROOT / "docs/inline-media-artwork.md").read_text()

for text in (
    "function mediaArtworkEntityId(widgetText)",
    'EntityController.getIdsByType("media_player")',
    'full === needle || tail === needle',
    "needle.length >= 3",
    "tail.indexOf(needle) === 0",
    "if (exact.length === 1)",
    "if (exact.length > 1) return",
    "if (prefixMatches.length === 1)",
    "if (prefixMatches.length > 1) return",
    "needle.indexOf(\".media_player.\")",
    'const artworkPlayerId = activityBase.mediaArtworkEntityId(widgetText);',
    '"qrc:/components/entities/activity/MediaArtworkWidget.qml"',
    '"entityId": artworkPlayerId',
):
    assert text in activity, f"Missing artwork Text dispatch contract: {text}"

assert activity.index('if (widgetKind === "MB")') < activity.index("const artworkPlayerId")
assert activity.index('if (["KB", "KEYBOARD"') < activity.index("const artworkPlayerId")
assert activity.index('item.text.trim().toLowerCase().indexOf("rtsp://")') < activity.index("const artworkPlayerId")
assert activity.index("const artworkPlayerId") < activity.index('case "icon":')

assert '<file alias="components/entities/activity/MediaArtworkWidget.qml">' in qrc
assert "property string entityId:" in artwork
assert "EntityController.get(entityId)" in artwork
assert "EntityController.load(entityId)" in artwork
assert "onEntityLoaded(success, loadedId)" in artwork
assert "entityObj.mediaImage" in artwork
assert "aspectFit: !Config.fillMediaArtwork" in artwork
assert "visible: !artwork.url || artwork.failed" in artwork
assert "anchors.fill: parent" in artwork and "clip: true" in artwork
assert "Popup {" not in artwork and "MouseArea {" not in artwork
assert "HapticMouseArea {" not in artwork

def resolve(text: str, known: list[str]) -> str:
    """Exercise the intended matching cases against representative IDs."""
    import re
    s = text.strip()
    if not re.fullmatch(r"[a-zA-Z0-9_.:-]+", s):
        return ""
    needle = s.lower()
    exact = [i for i in known if i.lower() == needle or i.rsplit(".", 1)[-1].lower() == needle]
    if len(exact) != 0:
        return exact[0] if len(exact) == 1 else ""
    if len(needle) >= 3 and "." not in needle:
        prefix = [i for i in known if i.rsplit(".", 1)[-1].lower().startswith(needle)]
        if prefix:
            return prefix[0] if len(prefix) == 1 else ""
    if ".media_player." in needle or needle.startswith("media_player."):
        return s
    return ""

ps5 = "ps5_connect_driver.main.media_player.ps5_10_1_1_30"
others = ["music_assistant.main.media_player.music"]
for name in (ps5, "ps5_10_1_1_30", "ps5"):
    assert resolve(name, [ps5] + others) == ps5
for ordinary in ("KB", "MB", "MB;ps5", "rtsp://camera", "Netflix", "Living Room"):
    assert resolve(ordinary, [ps5] + others) == ""
assert resolve("ps5", [ps5, "other.main.media_player.ps5_10_1_1_31"]) == ""
assert resolve("ps5_10_1_1_30", [ps5, "other.main.media_player.ps5_10_1_1_31"]) == ps5
assert "ps5_10_1_1_30" in docs and "ps5" in docs
print("Media artwork Text-widget dispatch and compatibility checks passed.")
