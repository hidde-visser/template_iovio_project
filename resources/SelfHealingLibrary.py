import sys
import os

_resources_dir = os.path.dirname(os.path.abspath(__file__))
if _resources_dir not in sys.path:
    sys.path.insert(0, _resources_dir)

from robot.libraries.BuiltIn import BuiltIn
from robot.api import logger


class SelfHealingLibrary:
    """
    Self-healing wrapper for QForce actionable keywords.
    Consolidates all surgeon logic into a single file so CRT cloud
    can load it with zero cross-file dependencies.

    Integration: add ONE line to your test suite Settings block,
    AFTER all other Library/Resource imports:

        Library    ../resources/SelfHealingLibrary.py

    Wrapped families: Click, Type, Selection, Interaction, Scroll, Hover, Mouse.
    Excluded (fail hard by design): Verify*, Get*, Is*, Compare*, SetConfig,
    UseTable, UseList, UseModal, CopadoAI, SwitchWindow, OpenWindow,
    CloseWindow, UseFrame, RefreshPage, GoTo, LaunchApp, NavigateToApp,
    GlobalSearch, PressKey.
    """

    ROBOT_LIBRARY_SCOPE = "GLOBAL"

    # ------------------------------------------------------------------
    # Internal dispatch
    # ------------------------------------------------------------------

    def _run(self, keyword_name, *args):
        builtin = BuiltIn()

        # Step 1: attempt the original keyword
        status, message = builtin.run_keyword_and_ignore_error(
            "QForce." + keyword_name, *args
        )

        if status == "PASS":
            return

        # Step 2: first attempt failed, call the surgeon
        logger.warn(
            "[SelfHealing] First attempt FAILED for '"
            + keyword_name
            + "': "
            + message
            + ". Calling surgeon..."
        )

        # Capture screenshot for surgeon context (non-fatal if it fails)
        try:
            builtin.run_keyword("Log Screenshot")
        except Exception:
            logger.warn("[SelfHealing] Could not capture screenshot before surgeon call.")

        # Call Resolve Step Failure Stable from GeminiHelp.robot
        try:
            surgeon_result = builtin.run_keyword(
                "Resolve Step Failure Stable",
                keyword_name,
                list(args),
                {},
                message,
            )
        except Exception as surgeon_exc:
            raise RuntimeError(
                "[SelfHealing] Surgeon invocation failed for '"
                + keyword_name
                + "'. Original error: "
                + message
                + ". Surgeon error: "
                + str(surgeon_exc)
            )

        if not surgeon_result or not isinstance(surgeon_result, dict):
            raise RuntimeError(
                "[SelfHealing] Surgeon returned no usable repair for '"
                + keyword_name
                + "'. Original error: "
                + message
            )

        corrected_keyword = surgeon_result.get("keyword", keyword_name)
        corrected_args = surgeon_result.get("args", list(args))

        # Step 3: execute the surgeon's corrected step once
        retry_status, retry_message = builtin.run_keyword_and_ignore_error(
            corrected_keyword, *corrected_args
        )

        if retry_status == "PASS":
            logger.warn(
                "[SelfHealing] HEALED: '"
                + keyword_name
                + "' was corrected by the surgeon to '"
                + corrected_keyword
                + "'. Original error: "
                + message
            )
            return

        # Step 4: both attempts failed, raise cleanly
        raise RuntimeError(
            "[SelfHealing] UNRECOVERABLE: '"
            + keyword_name
            + "' failed and the surgeon's corrected step '"
            + corrected_keyword
            + "' also failed. "
            + "Original error: "
            + message
            + ". Surgeon retry error: "
            + retry_message
        )

    # ------------------------------------------------------------------
    # CLICK FAMILY
    # ------------------------------------------------------------------

    def ClickText(self, *args):
        """Self-healing wrapper for QForce ClickText."""
        self._run("ClickText", *args)

    def ClickItem(self, *args):
        """Self-healing wrapper for QForce ClickItem."""
        self._run("ClickItem", *args)

    def ClickElement(self, *args):
        """Self-healing wrapper for QForce ClickElement."""
        self._run("ClickElement", *args)

    def ClickCheckbox(self, *args):
        """Self-healing wrapper for QForce ClickCheckbox."""
        self._run("ClickCheckbox", *args)

    def ClickCell(self, *args):
        """Self-healing wrapper for QForce ClickCell."""
        self._run("ClickCell", *args)

    def ClickFieldValue(self, *args):
        """Self-healing wrapper for QForce ClickFieldValue."""
        self._run("ClickFieldValue", *args)

    def ClickTableCell(self, *args):
        """Self-healing wrapper for QForce ClickTableCell."""
        self._run("ClickTableCell", *args)

    def ClickTree(self, *args):
        """Self-healing wrapper for QForce ClickTree."""
        self._run("ClickTree", *args)

    def ClickCoordinates(self, *args):
        """Self-healing wrapper for QForce ClickCoordinates."""
        self._run("ClickCoordinates", *args)

    def RightClick(self, *args):
        """Self-healing wrapper for QForce RightClick."""
        self._run("RightClick", *args)

    # ------------------------------------------------------------------
    # TYPE FAMILY
    # ------------------------------------------------------------------

    def TypeText(self, *args):
        """Self-healing wrapper for QForce TypeText."""
        self._run("TypeText", *args)

    def TypeSecret(self, *args):
        """Self-healing wrapper for QForce TypeSecret."""
        self._run("TypeSecret", *args)

    def TypeAlert(self, *args):
        """Self-healing wrapper for QForce TypeAlert."""
        self._run("TypeAlert", *args)

    def TypeTable(self, *args):
        """Self-healing wrapper for QForce TypeTable."""
        self._run("TypeTable", *args)

    def TypeTexts(self, *args):
        """Self-healing wrapper for QForce TypeTexts."""
        self._run("TypeTexts", *args)

    def WriteText(self, *args):
        """Self-healing wrapper for QForce WriteText."""
        self._run("WriteText", *args)

    # ------------------------------------------------------------------
    # SELECTION FAMILY
    # ------------------------------------------------------------------

    def DropDown(self, *args):
        """Self-healing wrapper for QForce DropDown."""
        self._run("DropDown", *args)

    def PickList(self, *args):
        """Self-healing wrapper for QForce PickList."""
        self._run("PickList", *args)

    def MultiPickList(self, *args):
        """Self-healing wrapper for QForce MultiPickList."""
        self._run("MultiPickList", *args)

    def ComboBox(self, *args):
        """Self-healing wrapper for QForce ComboBox."""
        self._run("ComboBox", *args)

    # ------------------------------------------------------------------
    # INTERACTION FAMILY
    # ------------------------------------------------------------------

    def DragDrop(self, *args):
        """Self-healing wrapper for QForce DragDrop."""
        self._run("DragDrop", *args)

    def UploadFile(self, *args):
        """Self-healing wrapper for QForce UploadFile."""
        self._run("UploadFile", *args)

    # ------------------------------------------------------------------
    # SCROLL FAMILY
    # ------------------------------------------------------------------

    def Scroll(self, *args):
        """Self-healing wrapper for QForce Scroll."""
        self._run("Scroll", *args)

    def ScrollTo(self, *args):
        """Self-healing wrapper for QForce ScrollTo."""
        self._run("ScrollTo", *args)

    def ScrollText(self, *args):
        """Self-healing wrapper for QForce ScrollText."""
        self._run("ScrollText", *args)

    def ScrollList(self, *args):
        """Self-healing wrapper for QForce ScrollList."""
        self._run("ScrollList", *args)

    # ------------------------------------------------------------------
    # HOVER FAMILY
    # ------------------------------------------------------------------

    def HoverText(self, *args):
        """Self-healing wrapper for QForce HoverText."""
        self._run("HoverText", *args)

    def HoverItem(self, *args):
        """Self-healing wrapper for QForce HoverItem."""
        self._run("HoverItem", *args)

    def HoverElement(self, *args):
        """Self-healing wrapper for QForce HoverElement."""
        self._run("HoverElement", *args)

    # ------------------------------------------------------------------
    # MOUSE FAMILY
    # ------------------------------------------------------------------

    def MouseDown(self, *args):
        """Self-healing wrapper for QForce MouseDown."""
        self._run("MouseDown", *args)

    def MouseUp(self, *args):
        """Self-healing wrapper for QForce MouseUp."""
        self._run("MouseUp", *args)
