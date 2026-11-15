"""檢查 APK / AAB 內每個原生程式庫(.so)是否支援 16 KB 記憶體分頁。

用法:python3 export/tools/check_16k.py export/build/doggyknight-debug.apk export/build/doggyknight-release.aab

規則(Google Play,2025-11 起):arm64-v8a 與 x86_64 的 .so,每個 LOAD 區段的對齊(p_align)
至少要 16384。armeabi-v7a(32 位元)的手機一律用 4 KB 分頁,不受這個規定限制。
有任何 64 位元的 .so 不合格時,結束代碼是 1。
"""
import struct
import sys
import zipfile


def load_aligns(data: bytes) -> list:
    if data[:4] != b"\x7fELF":
        return []
    is64 = data[4] == 2
    endian = "<" if data[5] == 1 else ">"
    if is64:
        e_phoff = struct.unpack_from(endian + "Q", data, 0x20)[0]
        e_phentsize, e_phnum = struct.unpack_from(endian + "HH", data, 0x36)
    else:
        e_phoff = struct.unpack_from(endian + "I", data, 0x1C)[0]
        e_phentsize, e_phnum = struct.unpack_from(endian + "HH", data, 0x2A)
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if struct.unpack_from(endian + "I", data, off)[0] != 1:  # PT_LOAD
            continue
        if is64:
            aligns.append(struct.unpack_from(endian + "Q", data, off + 0x30)[0])
        else:
            aligns.append(struct.unpack_from(endian + "I", data, off + 0x1C)[0])
    return aligns


def main(paths: list) -> int:
    bad = 0
    for archive in paths:
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                if not info.filename.endswith(".so"):
                    continue
                aligns = load_aligns(z.read(info.filename))
                low = min(aligns) if aligns else 0
                is64 = "arm64-v8a" in info.filename or "x86_64" in info.filename
                ok = low >= 16384 or not is64
                if not ok:
                    bad += 1
                note = "OK" if low >= 16384 else ("OK (32-bit, 4 KB pages)" if not is64 else "NOT 16 KB")
                print(f"{archive}: {info.filename}: LOAD align {low} -> {note}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
