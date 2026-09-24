import unittest
from argparse import Namespace
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from qc_gate import classify


class Row:
    def __init__(self, library_size, detected_genes, zero_fraction):
        self.library_size = library_size
        self.detected_genes = detected_genes
        self.zero_fraction = zero_fraction


class QCGateTests(unittest.TestCase):
    def setUp(self):
        self.args = Namespace(
            fail_library=5000,
            warn_library=12000,
            fail_genes=50,
            warn_genes=100,
            warn_zero_fraction=0.8,
        )

    def test_pass(self):
        state, _ = classify(Row(20000, 300, 0.1), self.args)
        self.assertEqual(state, "PASS")

    def test_warn(self):
        state, reason = classify(Row(10000, 300, 0.1), self.args)
        self.assertEqual(state, "WARN")
        self.assertIn("library_size", reason)

    def test_fail(self):
        state, reason = classify(Row(1000, 20, 0.9), self.args)
        self.assertEqual(state, "FAIL")
        self.assertIn("library_size", reason)


if __name__ == "__main__":
    unittest.main()
