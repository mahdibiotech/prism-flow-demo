import json
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from validate_metadata import validate


class MetadataValidationTests(unittest.TestCase):
    def test_demo_metadata_passes(self):
        root = Path(__file__).resolve().parents[1]
        result = validate(root / "config/samples.tsv", root / "config/patients.tsv", "demo")
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["sample_count"], 8)
        self.assertEqual(result["modalities"], ["bulk_rnaseq"])

    def test_duplicate_sample_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            samples = tmp / "samples.tsv"
            patients = tmp / "patients.tsv"
            patients.write_text("patient_id\nP1\n", encoding="utf-8")
            samples.write_text(
                "sample_id\tpatient_id\tcondition\tmodality\tsample_type\tfastq_r1\tfastq_r2\n"
                "S1\tP1\tnormal\tbulk_rnaseq\tx\t\t\n"
                "S1\tP1\ttumor\tbulk_rnaseq\tx\t\t\n",
                encoding="utf-8",
            )
            result = validate(samples, patients, "demo")
            self.assertEqual(result["status"], "FAIL")
            self.assertTrue(any("Duplicate sample_id" in x for x in result["errors"]))


if __name__ == "__main__":
    unittest.main()
