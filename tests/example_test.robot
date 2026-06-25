*** Settings ***
Suite Setup            Setup Browser
Suite Teardown         End suite
Test Setup             Sales Home
Library                QForce
Resource               ../resources/common_keywords.robot

*** Test Cases ***

example test
    [Documentation]    This is an example test on how it should look like
    [Tags]             REGRESSION                  SMOKE
    LaunchApp          Sales