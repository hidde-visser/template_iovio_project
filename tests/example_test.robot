*** Settings ***
Documentation          Self-Healing Library - plug-and-play demo.
...
...                    This test shows the customer exactly what the integration looks like.
...                    The ONLY change from a standard test is the single Library import
...                    on line 10. Everything else is written exactly as it would be without
...                    self-healing. No keyword changes. No structural changes.
...
...                    When any wrapped actionable keyword fails, the surgeon fires once,
...                    proposes a corrected step, executes it, and logs a WARN-level notice
...                    in the report. If the corrected step also fails, the test fails
...                    cleanly with full error context.

Resource               ../resources/common_keywords.robot
Library                RequestsLibrary
Library                QForce
Library                XML
Resource               ../resources/GeminiHelp.robot
Library                ../resources/ObjectSanitizer.py
Library                ../resources/DomParserLibrary.py
Library                ../resources/ExplorationSessionLibrary.py
Library                ../resources/SelfHealingLibrary.py
Resource               ../resources/selfhealing.robot
Suite Setup            Initialize Salesforce Session


*** Test Cases ***
BasicText
    [Documentation]    Standard Salesforce test. Self-healing is invisible to the author.
    ...                If any actionable keyword drifts (locator change, timing issue),
    ...                the surgeon corrects it automatically and logs a WARN in the report.
    SelfHeal           True
    
    ClickText    Campaigns
    ClickText    New
    UseModal    On
    TypeText     Campaign Name*   Test new Campaign
    PickList    Type    Webinar
    PickList    Status    Planning
