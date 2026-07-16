from pathlib import Path

from sprite_resource_downloader.filenames import (
    asset_filename_stem,
    reserve_destination,
    safe_extension,
    safe_name,
)


def test_windows_filename_sanitization() -> None:
    assert safe_name("CON <bad> name. ") == "CON _bad_ name"
    assert safe_name("CON") == "CON_"
    assert safe_name("trailing. ") == "trailing"
    assert safe_name("a/b\\c:d*e?f|g<h>i") == "a_b_c_d_e_f_g_h_i"


def test_duplicate_filename_handling(tmp_path: Path) -> None:
    names: set[str] = set()
    first = reserve_destination(tmp_path, "Sora", ".png", asset_id="1029", existing_names=names)
    second = reserve_destination(tmp_path, "Sora", ".png", asset_id="1030", existing_names=names)
    assert first.name == "Sora.png"
    assert second.name == "Sora_1030.png"


def test_safe_extension() -> None:
    assert safe_extension("sprite.PNG") == ".png"
    assert safe_extension("GIF") == ".gif"
    assert safe_extension(None, fallback=".bin") == ".bin"


def test_asset_filename_stem_is_project_snake_case() -> None:
    assert asset_filename_stem("Sora Battle", prefix="kh", suffix="gba") == "kh_sora_battle_gba"
    assert asset_filename_stem("Bob-omb", prefix="mario") == "mario_bob_omb"
