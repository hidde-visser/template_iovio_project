# ExplorationSessionLibrary.py
import json
import os
import re
from datetime import datetime, timezone
from robot.api.deco import keyword


class ExplorationSessionLibrary:
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'

    def __init__(self):
        self._session: dict = {}
        self._session_file_path: str = ''
        self._element_index: dict = {}
        self._coverage_sets: dict = {}

    @keyword("Load Exploration Session")
    def load_exploration_session(self, session_file_path: str) -> dict:
        if not os.path.exists(session_file_path):
            raise FileNotFoundError(f"Session file not found: {session_file_path}")
        with open(session_file_path, 'r', encoding='utf-8') as f:
            self._session = json.load(f)
        self._session_file_path = session_file_path
        return self._session

    @keyword("Create Exploration Session")
    def create_exploration_session(self, object_name: str, start_state: str, session_file_path: str = None) -> dict:
        if not session_file_path:
            output_dir = os.environ.get('ROBOT_OUTPUT_DIR', os.getcwd())
            session_file_path = os.path.join(output_dir, f"exploration_{object_name.lower()}.json")
        self._session_file_path = session_file_path
        self._session = {'exploration_session': {'object_name': object_name, 'start_state': start_state, 'states': {}}}
        return self._session

    @keyword("Save Exploration Session")
    def save_exploration_session(self) -> None:
        with open(self._session_file_path, 'w', encoding='utf-8') as f:
            json.dump(self._session, f, indent=4)
