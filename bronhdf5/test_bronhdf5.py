"""
    test_bronhdf5.py
    Contains simple tests which verify that the read_bron2 function either succeeds
    or raises the correct error.
    For the write_gmw_to_bron2 function the only checks are that it succeeds
    and that the read-functions can read the result without a problem.

    In particular, the data values are not verified.

""" 
import unittest
import h5py
import bronhdf5
import os


class TestRWMethods(unittest.TestCase):
    def tearDown(self):
        try:
            os.remove("binaries/tmp2.bron2")
        except FileNotFoundError:
            pass
        try:
            os.remove("binaries/tmp1.bron2")
        except FileNotFoundError:
            pass

    def test_no_version(self):
        with self.assertRaises(KeyError):
            with h5py.File(
                "binaries/No_version Testdata_Overijssel CB 3 juli 2020_v3xi.bron2", "r"
            ) as f:
                bronhdf5.read_bron2_to_gmws(f)

    def test_wrong_version(self):
        with self.assertRaises(NotImplementedError):
            with h5py.File(
                "binaries/Wrong_version Testdata_Overijssel CB 3 juli 2020_v3xi.bron2",
                "r",
            ) as f:
                bronhdf5.read_bron2_to_gmws(f)

    def test_rw_gmws(self):
        # The actual test.
        with h5py.File(
            "binaries/Testdata_Overijssel CB 3 juli 2020_v3xi.bron2", "r"
        ) as f:
            gmw1 = bronhdf5.read_bron2_to_gmws(f)
        with h5py.File("binaries/tmp1.bron2", "w") as f:
            bronhdf5.write_gmws_to_bron2(f, gmw1)
        with h5py.File("binaries/tmp1.bron2", "r") as f:
            gmw2 = bronhdf5.read_bron2_to_gmws(f)
        with h5py.File("binaries/tmp2.bron2", "w") as f:
            bronhdf5.write_gmws_to_bron2(f, gmw2)
        assert True


if __name__ == "__main__":
    unittest.main()
