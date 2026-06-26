"""
AgentJsonParser.py  -  v4
--------------------------
Single-responsibility Python library for all AI reply parsing in the
Copado Robotic Testing agentic pipeline.

v4 CHANGES
----------
ROOT CAUSE FIX: parse_architect_reply() now handles the case where the AI
wraps its step array inside a dict envelope instead of returning a bare array.

Known envelope shapes the AI emits intermittently:
  { "steps": [...] }
  { "test_steps": [...] }
  { "actions": [...] }
  { "plan": [...] }
  { "result": [...] }
  { "data": [...] }

DEEP DIAGNOSTICS: All three high-level parsers (parse_architect_reply,
parse_surgeon_reply, and extract_first_action_from_step) now emit structured
diagnostic log lines at every decision point. This makes future failures
immediately diagnosable from the CRT log without requiring a code change.

Diagnostic log format:
  [AJP] <function> | <stage> | type=<type> | preview=<first 200 chars>

parse_surgeon_reply() also gains the same dict-envelope unwrap logic for
symmetry, since the surgeon can emit the same wrapping pattern.

STRUCTURAL FIX (v4.1): extract_first_action_from_step() guard block was
orphaned after escape_xpath_arg() in the original source. The function
definition is now correctly placed and complete.
"""

import re
import json
import sys
from typing import Any, Dict, List, Optional


# ===========================================================================
# CONSTANTS
# ===========================================================================

_VALID_JSON_ESCAPES = set('"\\\/bfnrtu')

_ARRAY_ENVELOPE_KEYS = [
    'steps',
    'test_steps',
    'actions',
    'plan',
    'result',
    'data',
    'corrected_steps',
]


# ===========================================================================
# INTERNAL DIAGNOSTICS HELPER
# ===========================================================================

def _diag(caller: str, stage: str, value: Any) -> None:
    """
    Emits a structured diagnostic log line to stdout (visible in CRT console).

    Format:
      [AJP] <caller> | <stage> | type=<type> | preview=<first 200 chars>
    """
    type_name = type(value).__name__
    preview   = repr(value)[:200]
    print(
        f"[AJP] {caller} | {stage} | type={type_name} | preview={preview}",
        flush=True,
    )


# ===========================================================================
# LAYER 1 - RAW SANITIZATION
# ===========================================================================

def sanitize_ai_json_reply(raw_text: str) -> str:
    """
    Sanitization pipeline for AI-generated JSON reply strings.

    Steps:
      1. Strip markdown code fences  (```json ... ``` or ``` ... ```)
      2. Flatten ALL backslash-equals variants to bare =  (clean slate)
      3. Remove every \\<char> where <char> is NOT a valid JSON escape
         character. Handles \\', \\!, \\@, and any other AI-injected
         invalid escape by dropping the backslash and keeping the char.

    NOTE: XPath \\= re-injection intentionally does NOT happen here.
    Use escape_xpath_arg() at RF dispatch time instead.

    Returns the sanitized string, ready for json.JSONDecoder().raw_decode().
    """
    text = raw_text.strip()

    # Step 1: Strip markdown fences
    text = re.sub(r'^```(?:json)?\s*', '', text, flags=re.DOTALL)
    text = re.sub(r'\s*```$',          '', text, flags=re.DOTALL)
    text = text.strip()

    # Step 2: Flatten all \\= variants to bare =
    text = text.replace('\\\\=', '=')   # double-backslash-equals first
    text = text.replace('\\=', '=')     # lone backslash-equals second

    # Step 3: Remove all remaining invalid JSON escape sequences
    result = []
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == '\\' and i + 1 < len(text):
            next_ch = text[i + 1]
            if next_ch in _VALID_JSON_ESCAPES:
                result.append(ch)
                result.append(next_ch)
                i += 2
            else:
                # Drop the backslash, keep the character
                result.append(next_ch)
                i += 2
        else:
            result.append(ch)
            i += 1

    return ''.join(result)


def find_json_start(text: str) -> int:
    """
    Returns the index of the first '{' or '[' in the string.
    Raises ValueError if neither is found.
    """
    brace   = text.find('{')
    bracket = text.find('[')
    candidates = [i for i in [brace, bracket] if i > -1]
    if not candidates:
        raise ValueError(
            "Parser Error: No JSON structure found in AI reply. "
            f"Raw text starts with: {text[:200]!r}"
        )
    return min(candidates)


def parse_ai_json_reply(raw_text: str) -> Any:
    """
    Full sanitize-then-parse pipeline.

    Returns the decoded Python object (dict or list).
    Raises ValueError with a clear diagnostic message on failure.
    """
    sanitized    = sanitize_ai_json_reply(raw_text)
    start_idx    = find_json_start(sanitized)
    clean_suffix = sanitized[start_idx:]

    try:
        parsed, _ = json.JSONDecoder().raw_decode(clean_suffix)
        return parsed
    except json.JSONDecodeError as exc:
        char_pos      = exc.pos
        context_start = max(0, char_pos - 60)
        raise ValueError(
            f"Parser Error: JSON decode failed at position {char_pos}. "
            f"Context: ...{clean_suffix[context_start:char_pos + 60]!r}..."
        ) from exc


# ===========================================================================
# LAYER 2 - CONTENT LIST UNWRAPPING
# ===========================================================================

def unwrap_content_list(content: List[Dict]) -> str:
    """
    Extracts the raw JSON text string from a Copado API content list.

    Priority order:
      1. First item whose 'artifact' key is not None  (structured JSON block)
      2. First item whose 'text' value starts with '[' or '{'

    Raises ValueError if no JSON-bearing block is found.
    """
    if not isinstance(content, list):
        raise ValueError(
            f"unwrap_content_list expected a list, got {type(content).__name__}."
        )

    # Pass 1: prefer the artifact-bearing block
    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get('artifact') is not None:
            text = item.get('text', '')
            if isinstance(text, str):
                return text

    # Pass 2: fall back to first block that looks like JSON
    for item in content:
        if not isinstance(item, dict):
            continue
        text_val = item.get('text', '')
        if isinstance(text_val, str):
            stripped = text_val.strip()
            if stripped.startswith('[') or stripped.startswith('{'):
                return text_val

    raise ValueError(
        "Parser Error: No JSON-bearing content block found in content list. "
        f"Received {len(content)} item(s)."
    )


# ===========================================================================
# LAYER 2.5 - UNIVERSAL CONTENT RESOLVER
# ===========================================================================

def resolve_content_to_raw_text(content) -> str:
    """
    Universal resolver that collapses any Copado API content shape into
    a raw JSON string ready for parse_ai_json_reply().

    Accepted input shapes:
      str   -> used directly
      list  -> routed through unwrap_content_list()
      dict  -> drills into 'content' key and recurses once
    """
    if content is None:
        raise ValueError(
            "resolve_content_to_raw_text: received None. "
            "The API returned no content for the last message."
        )

    if isinstance(content, str):
        return content

    if isinstance(content, list):
        return unwrap_content_list(content)

    if isinstance(content, dict):
        inner = content.get('content')
        if inner is None:
            raise ValueError(
                "resolve_content_to_raw_text: dict input has no 'content' key. "
                f"Keys present: {list(content.keys())}"
            )
        return resolve_content_to_raw_text(inner)

    raise ValueError(
        f"resolve_content_to_raw_text: unrecognised content type "
        f"'{type(content).__name__}'. Expected str, list, or dict."
    )


# ===========================================================================
# LAYER 2.6 - DICT ENVELOPE UNWRAPPER
# ===========================================================================

def _unwrap_array_envelope(parsed_dict: dict, caller: str) -> list:
    """
    Inspects a parsed dict for a value that is a non-empty list and
    promotes it to the return value.

    Checks _ARRAY_ENVELOPE_KEYS in priority order first, then falls back
    to scanning all values for the first non-empty list found.
    """
    _diag(caller, 'dict-envelope-detected', parsed_dict)

    # Priority pass: check known envelope keys first
    for key in _ARRAY_ENVELOPE_KEYS:
        value = parsed_dict.get(key)
        if isinstance(value, list) and len(value) > 0:
            print(
                f"[AJP] {caller} | dict-envelope-unwrapped | "
                f"key='{key}' | items={len(value)}",
                flush=True,
            )
            return value

    # Fallback pass: scan all values for the first non-empty list
    for key, value in parsed_dict.items():
        if isinstance(value, list) and len(value) > 0:
            print(
                f"[AJP] {caller} | dict-envelope-unwrapped-fallback | "
                f"key='{key}' | items={len(value)}",
                flush=True,
            )
            return value

    raise ValueError(
        f"{caller}: AI returned a dict instead of a bare array, and no "
        f"list value could be found inside it. "
        f"Dict keys present: {list(parsed_dict.keys())}. "
        f"Add the correct key to _ARRAY_ENVELOPE_KEYS in AgentJsonParser.py."
    )


# ===========================================================================
# LAYER 3 - HIGH-LEVEL PAYLOAD PARSERS
# ===========================================================================

def parse_architect_reply(content) -> List[Dict]:
    """
    Full pipeline for the architect's reply.

    Accepts any content shape (list, str, or dict) via
    resolve_content_to_raw_text(), then sanitizes and parses the bare
    JSON array that the architect emits.

    v4: Handles dict-envelope wrapping transparently.

    Returns
    -------
    list
        A list of step dicts, each with keys: intent, is_risky,
        confidence_score, strategies.
    """
    _diag('parse_architect_reply', 'input', content)

    raw_text = resolve_content_to_raw_text(content)
    _diag('parse_architect_reply', 'raw_text', raw_text)

    parsed = parse_ai_json_reply(raw_text)
    _diag('parse_architect_reply', 'parsed', parsed)

    if isinstance(parsed, list):
        print(
            f"[AJP] parse_architect_reply | success | items={len(parsed)}",
            flush=True,
        )
        return parsed

    if isinstance(parsed, dict):
        return _unwrap_array_envelope(parsed, 'parse_architect_reply')

    raise ValueError(
        f"parse_architect_reply: Expected a JSON array or a dict envelope "
        f"containing an array. Got {type(parsed).__name__}. "
        f"Raw text preview: {raw_text[:300]!r}"
    )


def parse_surgeon_reply(content) -> Dict:
    """
    Full pipeline for the surgeon's reply.

    Accepts any content shape (list, str, or dict) via
    resolve_content_to_raw_text(), then sanitizes and parses the
    surgeon's JSON dict.

    Guarantees the returned dict always has the three expected keys,
    using safe defaults so callers never need to guard against KeyError.

    Returns
    -------
    dict with keys:
        escalate        : bool  - whether the surgeon is escalating
        recovery_steps  : list  - steps to run before corrected_steps
        corrected_steps : list  - replacement steps for the failed intent
    """
    _diag('parse_surgeon_reply', 'input', content)

    raw_text = resolve_content_to_raw_text(content)
    _diag('parse_surgeon_reply', 'raw_text', raw_text)

    parsed = parse_ai_json_reply(raw_text)
    _diag('parse_surgeon_reply', 'parsed', parsed)

    # Recovery path: surgeon returned a bare array instead of a dict.
    # Treat the array as corrected_steps with no escalation or recovery.
    if isinstance(parsed, list):
        print(
            f"[AJP] parse_surgeon_reply | bare-array-promoted | items={len(parsed)}",
            flush=True,
        )
        return {
            'escalate':        False,
            'recovery_steps':  [],
            'corrected_steps': parsed,
        }

    if not isinstance(parsed, dict):
        raise ValueError(
            f"parse_surgeon_reply: Expected a JSON object. Got {type(parsed).__name__}. "
            f"Raw text preview: {raw_text[:300]!r}"
        )

    print(
        f"[AJP] parse_surgeon_reply | success | keys={list(parsed.keys())}",
        flush=True,
    )

    return {
        'escalate':        parsed.get('escalate',        False),
        'recovery_steps':  parsed.get('recovery_steps',  []),
        'corrected_steps': parsed.get('corrected_steps', []),
        # Preserve any extra keys the surgeon may add (e.g. root_cause_analysis)
        **{k: v for k, v in parsed.items()
           if k not in ('escalate', 'recovery_steps', 'corrected_steps')},
    }


# ===========================================================================
# LAYER 4 - XPATH DISPATCH HELPER
# ===========================================================================

def escape_xpath_arg(arg: str) -> str:
    """
    Re-injects \\= into an XPath argument string for Robot Framework.

    Call this at DISPATCH TIME only, never during JSON parsing.
    Only transforms strings that start with 'xpath='.

    Example
    -------
    Input  (from parsed JSON):  "xpath=//input[@id='abc']"
    Output (for RF execution):  "xpath=//input[@id\\='abc']"
    """
    if not isinstance(arg, str) or not arg.startswith('xpath='):
        return arg

    prefix       = 'xpath='
    body         = arg[len(prefix):]
    escaped_body = re.sub(r'(?<!\\)=', r'\\=', body)
    return prefix + escaped_body


# ===========================================================================
# LAYER 5 - STEP-LEVEL HELPERS
# ===========================================================================

def extract_first_action_from_step(step: Any) -> Optional[Dict]:
    """
    Drills into a normalised step dict and returns the first action object
    from the first strategy sequence.

    Returns None on any malformed input so callers can guard safely
    without raising exceptions.

    Parameters
    ----------
    step : any
        A normalised step dict, expected shape:
        {
            'intent': str,
            'strategies': [ [ {'keyword': ..., 'args': ..., 'kwargs': ...} ] ]
        }

    Returns
    -------
    dict or None
        The first action dict, or None if the step is malformed.
    """
    _diag('extract_first_action_from_step', 'input', step)

    # Guard: step must be a dict
    if not isinstance(step, dict):
        print(
            "[AJP] extract_first_action_from_step | step-not-dict | returning None",
            flush=True,
        )
        return None

    strategies = step.get('strategies')
    if not isinstance(strategies, list) or len(strategies) == 0:
        print(
            "[AJP] extract_first_action_from_step | no-strategies | returning None",
            flush=True,
        )
        return None

    first_strategy = strategies[0]
    if not isinstance(first_strategy, list) or len(first_strategy) == 0:
        print(
            "[AJP] extract_first_action_from_step | empty-first-strategy | returning None",
            flush=True,
        )
        return None

    first_action = first_strategy[0]

    # Guard: action must be a dict with at least a 'keyword' key
    if not isinstance(first_action, dict) or 'keyword' not in first_action:
        print(
            "[AJP] extract_first_action_from_step | action-invalid | returning None",
            flush=True,
        )
        return None

    result = {
        'keyword': first_action['keyword'],
        'args':    first_action.get('args')   or [],
        'kwargs':  first_action.get('kwargs') or {},
    }

    _diag('extract_first_action_from_step', 'result', result)
    return result
