*** Settings ***
Documentation          Template test script for the project
Resource               ../resources/common_keywords.robot
Library                RequestsLibrary
Library                QForce
Library                XML
Suite Setup            Setup Browser
Test Setup             Sales Home


*** Test Cases ***
Example Test - Create Campaign Via UI
    [Documentation]    Standard Salesforce test. Self-healing is invisible to the author.
    ...                If any actionable keyword drifts (locator change, timing issue),
    ...                the surgeon corrects it automatically and logs a WARN in the report.
    LaunchApp          Campaigns
    ClickText          New
    UseModal           On
    TypeText           Campaign Name*              Test new Campaign
    PickList           Type                        Webinar
    PickList           Status                      Planned
    ClickText          Save                        partial_match=False
    VerifyText         Campaign "Test new Campaign" was created.
    ClickText          Details
    VerifyField        Campaign Name               Test new Campaign
    [Teardown]         Delete Record via API       Campaign                   Test new Campaign

Example Test - Modify Campaign Via UI
    [Documentation]    Verifies that an existing Campaign record can be modified via the Salesforce UI.
    ...
    ...                A Campaign record is created via the REST API as a precondition, then the test
    ...                navigates to the record through the Campaigns app, opens the Details tab,
    ...                and edits the Campaign Name, Type, and Status fields using the inline edit
    ...                controls. After saving, all three fields are verified to reflect the updated
    ...                values. The record is deleted via the REST API in the teardown step.
    ...
    ...                *Preconditions:*
    ...                - JWT authentication must already be established (handled by Suite Setup).
    ...                - The Campaigns app must be accessible to the automation user.
    ...                - The Campaign record "My Test Campaign" must not already exist in the org.
    ...
    ...                *Test Steps:*
    ...                1. Create a Campaign record via API with Name="My Test Campaign" and Status="Planning".
    ...                2. Launch the Campaigns app via LaunchApp.
    ...                3. Navigate to the Campaign record by clicking its name.
    ...                4. Open the Details tab to expose inline-editable fields.
    ...                5. Click "Edit Campaign Name" to activate the inline edit mode.
    ...                6. Update the Campaign Name field to "My Modify Test Campaign".
    ...                7. Select "Trade Show" from the Type picklist.
    ...                8. Select "Planned" from the Status picklist.
    ...                9. Save the record.
    ...                10. Verify Campaign Name, Type, and Status reflect the updated values.
    ...
    ...                *Expected Results:*
    ...                - Campaign Name is displayed as "My Modify Test Campaign".
    ...                - Type is displayed as "Trade Show".
    ...                - Status is displayed as "Planned".
    ...
    ...                *Teardown:*
    ...                - The modified Campaign record "My Modify Test Campaign" is deleted via the REST API.
    ${campaign_id}=    Create Record Via API
    ...                Campaign
    ...                Name=My Test Campaign
    ...                Status=Planning
    Log                Campaign created with ID: ${campaign_id}
    LaunchApp          Campaigns
    ClickText          My Test Campaign
    ClickText          Details
    ClickText          Edit Campaign Name
    TypeText           Campaign Name               My Modify Test Campaign
    PickList           Type                        Trade Show
    PickList           Status                      Planned
    ClickText          Save                        partial_match=False
    VerifyField        Campaign Name               My Modify Test Campaign
    VerifyField        Type                        Trade Show
    VerifyField        Status                      Planned
    [Teardown]         Delete Record Via API       Campaign                   My Modify Test Campaign
