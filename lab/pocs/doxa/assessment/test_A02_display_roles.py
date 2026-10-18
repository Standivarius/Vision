"""A02 display topology must support 3 or 4 screens, not invent missing roles."""
import unittest
from A02_display_roles import roles


def monitor(left,primary=False,width=1920):
    return {"primary":primary,
            "bounds":{"left":left,"top":0,"right":left+width,"bottom":1080},
            "gdi_name":str(left)}


class Roles(unittest.TestCase):
    def test_three_screens(self):
        topo=roles([monitor(3840),monitor(0,True),monitor(1920)])
        self.assertEqual(topo["CENTRE"]["bounds"]["left"],1920)
        self.assertEqual(topo["RIGHT"]["bounds"]["left"],3840)
        self.assertNotIn("LEFT",topo)

    def test_four_screens(self):
        topo=roles([monitor(0,True),monitor(-1920),monitor(1920),monitor(3840)])
        self.assertEqual(topo["LEFT"]["bounds"]["left"],-1920)
        self.assertEqual(topo["CENTRE"]["bounds"]["left"],1920)
        self.assertEqual(topo["RIGHT"]["bounds"]["left"],3840)

    def test_two_screens_unqualified(self):
        self.assertFalse(roles([monitor(0,True),monitor(1920)]))

    def test_extra_monitors_unqualified(self):
        self.assertFalse(roles([monitor(0,True)]+[monitor(x) for x in (-1920,1920,3840,5760)]))

    def test_duplicate_primary_unqualified(self):
        self.assertFalse(roles([monitor(0,True),monitor(1920,True),monitor(3840)]))

    def test_bad_bounds_unqualified(self):
        self.assertFalse(roles([monitor(0,True),monitor(1920),monitor(3840,width=0)]))


if __name__=="__main__":
    unittest.main()
