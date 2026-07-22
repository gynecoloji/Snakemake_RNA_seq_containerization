"""Validate config/config.yaml against the JSON schema and sanity-check samples.csv."""
import csv
import pathlib

import yaml
from jsonschema import Draft7Validator

ROOT = pathlib.Path(__file__).resolve().parent.parent


def test_schema_is_valid():
    schema = yaml.safe_load((ROOT / "workflow/schemas/config.schema.yaml").read_text())
    Draft7Validator.check_schema(schema)


def test_config_matches_schema():
    schema = yaml.safe_load((ROOT / "workflow/schemas/config.schema.yaml").read_text())
    config = yaml.safe_load((ROOT / "config/config.yaml").read_text())
    Draft7Validator(schema).validate(config)


def test_samples_sheet_has_sample_id():
    rows = list(csv.DictReader((ROOT / "config/samples.csv").open()))
    assert rows, "samples.csv has no data rows"
    assert "sample_id" in rows[0], "samples.csv is missing the sample_id column"
    assert all(r["sample_id"].strip() for r in rows), "empty sample_id found"
