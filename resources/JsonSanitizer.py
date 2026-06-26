"""
JsonSanitizer.py  —  shim (do not edit logic here)
----------------------------------------------------
This file exists solely for backward compatibility.
All logic has been consolidated into AgentJsonParser.py.

Any .robot file that imports 'Library  JsonSanitizer.py' will continue
to work without modification. When you are ready to cut over, replace
the Library import with 'Library  AgentJsonParser.py' and delete this file.
"""

from AgentJsonParser import (   # noqa: F401  (re-export everything)
    sanitize_ai_json_reply,
    find_json_start,
    parse_ai_json_reply,
    escape_xpath_arg,
)
