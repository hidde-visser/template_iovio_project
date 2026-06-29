*** Settings ***
Documentation          Template test script for the project
Resource               ../resources/common_keywords.robot
Library                RequestsLibrary
Library                QForce
Library                XML
Suite Setup            Setup Browser
Test Setup             Sales Home


*** Test Cases ***
Example Test
    [Documentation]    Standard Salesforce test. Self-healing is invisible to the author.
    ...                If any actionable keyword drifts (locator change, timing issue),
    ...                the surgeon corrects it automatically and logs a WARN in the report.
    ClickText          Campaigns
    ClickText          New
    UseModal           On
    TypeText           Campaign Name*              Test new Campaign
    PickList           Type                        Webinar
    PickList           Status                      Planned
    ClickText          Save                        partial_match=False
    VerifyText         Campaign "Test new Campaign" was created.
    ClickText          Details
    VerifyField        Campaign Name               Test new Campaign
    [Teardown]         Delete Record via API       Campaign               Test new Campaign
