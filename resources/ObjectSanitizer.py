import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

class OrgContractSanitizer:
    ALWAYS_INCLUDE_FIELDS = {"Id", "Name"}
    LAYOUT_KEY_PREFIX   = "layout"
    PICKLIST_KEY_PREFIX = "picklist"

    def sanitize_org_contract(self, raw: dict) -> dict:
        if not isinstance(raw, dict):
            return {"_error": True, "_errorMessage": "Input must be a dictionary"}
        return {"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "object": "unknown"}


def sanitize_org_contract(raw_input) -> str:
    if isinstance(raw_input, dict):
        raw = raw_input
    else:
        try:
            raw = json.loads(raw_input)
        except json.JSONDecodeError as e:
            return json.dumps({"_error": True, "_errorMessage": f"Invalid JSON input: {e}"}, indent=2)
    sanitizer = OrgContractSanitizer()
    result = sanitizer.sanitize_org_contract(raw)
    return json.dumps(result, indent=2, default=str)
