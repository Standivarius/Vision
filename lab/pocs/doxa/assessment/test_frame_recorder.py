"""PNG encoder self-check, no desktop capture or user data."""
import struct
import unittest
import zlib

from frame_recorder import png_from_bgra


class FrameEncodingTests(unittest.TestCase):
    def test_bgra_png_roundtrip_pixels(self):
        # 2 pixels: blue channel only then bright red in BGRA form
        src = bytes((255, 0, 0, 255, 0, 0, 255, 255))
        png = png_from_bgra(src, 2, 1)
        self.assertTrue(png.startswith(b"\x89PNG\r\n\x1a\n"))
        off = 8
        idat = b""
        sizes = None
        while off < len(png):
            length = struct.unpack_from("!I", png, off)[0]
            tag = png[off + 4:off + 8]
            chunk = png[off + 8:off + 8 + length]
            crc = struct.unpack_from("!I", png, off + 8 + length)[0]
            self.assertEqual(zlib.crc32(tag + chunk) & 0xffffffff, crc)
            if tag == b"IHDR":
                sizes = struct.unpack_from("!II", chunk)
            if tag == b"IDAT":
                idat += chunk
            off += 12 + length
        self.assertEqual(sizes, (2, 1))
        self.assertEqual(zlib.decompress(idat), bytes((0, 0, 0, 255, 255, 0, 0)))


if __name__ == "__main__":
    unittest.main()

