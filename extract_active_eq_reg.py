import winreg
import struct
import os

OUTPUT_EQ_PRESETS_DIR = "graphic-eqs (active)"

MM_DEVICES_PATH = r"SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
# Standard PKEYs (usually common)
PKEY_Device_FriendlyName = "{b3f8fa53-0004-438e-9003-51a46e139bfc},6"
PKEY_DeviceInterface_FriendlyName = "{a45c254e-df1c-4efd-8020-67d146a850e0},2"

# Standard frequencies for 10-band EQ Realtek HD Audio
DEFAULT_FREQUENCIES = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]


def get_reg_value(key_path, value_name):
    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE, key_path, 0, winreg.KEY_READ
        ) as key:
            value, _ = winreg.QueryValueEx(key, value_name)
            return value
    except Exception:
        return None


def decode_graphic_eq(blob):
    if not blob or len(blob) < 48:
        return None
    # 48 bytes: 8 bytes header + 10 * 4 bytes int32 gains
    payload = blob[8:48]
    gains = struct.unpack("<10i", payload)

    # We assume 10 bands for now. If size is different, we can adjust.
    eq_parts = []
    for i, g_raw in enumerate(gains):
        freq = (
            DEFAULT_FREQUENCIES[i] if i < len(DEFAULT_FREQUENCIES) else f"Band{i + 1}"
        )
        gain = g_raw / 100.0
        gain_str = str(int(gain)) if gain == int(gain) else f"{gain:.1f}"
        eq_parts.append(f"{freq} {gain_str}")

    return f"GraphicEQ: {'; '.join(eq_parts)}"


def dump_all_eq_presets_dynamic():
    output_dir = OUTPUT_EQ_PRESETS_DIR
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    found_any = False

    render_key = winreg.OpenKey(
        winreg.HKEY_LOCAL_MACHINE, MM_DEVICES_PATH, 0, winreg.KEY_READ
    )

    print("Extracting all FxProperties for GraphicEQ blobs...")
    for i in range(winreg.QueryInfoKey(render_key)[0]):
        device_guid = winreg.EnumKey(render_key, i)
        device_path = f"{MM_DEVICES_PATH}\\{device_guid}"

        audio_name = get_reg_value(
            f"{device_path}\\Properties", PKEY_Device_FriendlyName
        )
        endpoint_name = get_reg_value(
            f"{device_path}\\Properties", PKEY_DeviceInterface_FriendlyName
        )

        # Discover FX blobs
        fx_path = f"{device_path}\\FxProperties"
        fx_key: winreg.HKEY
        try:
            fx_key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE, fx_path, 0, winreg.KEY_READ
            )
        except FileNotFoundError:
            continue

        for j in range(winreg.QueryInfoKey(fx_key)[1]):
            name, value, _ = winreg.EnumValue(fx_key, j)
            if not (isinstance(value, bytes) and len(value) == 48):
                continue
            # It's a 48-byte blob, likely GraphicEQ
            eq_str = decode_graphic_eq(value)
            if not eq_str:
                continue

            if audio_name is None and endpoint_name is None:
                display_base = f"{device_guid}"
            elif audio_name is None:
                display_base = f"{endpoint_name} ({device_guid})"
            elif endpoint_name is None:
                display_base = f"{audio_name} ({device_guid})"
            else:
                display_base = f"{audio_name} ({endpoint_name}) {device_guid}"

            illegal_chars = '<>:"/\\|?*'
            safe_base = "".join(
                [c if c not in illegal_chars else "_" for c in display_base]
            )

            # Use property index as suffix
            fx_idx = name.split(",")[-1] if "," in name else "0"
            filename = f"{safe_base}_{fx_idx}.txt"
            file_path = os.path.join(output_dir, filename)

            with open(file_path, "w") as f:
                f.write(eq_str + "\n")
            print(f"  + Extracted: {filename}")
            found_any = True

    if not found_any:
        print("No matching 48-byte GraphicEQ blobs found.")


if __name__ == "__main__":
    dump_all_eq_presets_dynamic()
