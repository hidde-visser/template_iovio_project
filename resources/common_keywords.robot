*** Settings ***
Documentation                   Example resource file with custom keywords. NOTE: Some keywords below may need
...                             minor changes to work in different instances.
Library                         QForce
Library                         String
Library                         DateTime
Library                         OperatingSystem

*** Variables ***
${browser}                      chrome

*** Keywords ***
Setup Browser
    [Arguments]                 ${url}=about:blank          ${browser}=chrome
    Set Library Search Order    QWeb                        QForce
    Open Browser                ${url}                      ${browser}
    SetConfig                   LineBreak                   ${EMPTY}                    #\ue000
    SetConfig                   DefaultTimeout              30s                         #sometimes salesforce is slow
    Evaluate                    random.seed()               random                      # initialize random generator
    SetConfig                   Delay                       0.3                         # adds a delay of 0.3 between keywords. This is helpful in cloud with limited resources.

End suite
    Close All Browsers

Login
    [Documentation]             Authenticates to a Salesforce instance using the JWT Bearer Token flow
    ...                         and opens a UI session via JwtLogin, bypassing the standard login screen.
    ...
    ...                         Internally calls JwtAuthenticate with the connected app's consumer key,
    ...                         the Salesforce username, and the RSA private key in PEM format.
    ...                         Once the access token is obtained, JwtLogin is called to bootstrap
    ...                         the browser session using the frontdoor.jsp mechanism.
    ...
    ...                         *Prerequisites:*
    ...                         - ${client_id} must contain the Consumer Key from the Salesforce
    ...                           External Client App (OAuth Settings tab).
    ...                         - ${username} must be the Salesforce username of the automation user.
    ...                         - ${server_key} must contain the RSA private key in PEM format,
    ...                           matching the certificate uploaded to the External Client App.
    ...                           Store this value as a sensitive/secret variable in CRT.
    ...                         - The automation user must be pre-authorized via a Permission Set
    ...                           assigned to the External Client App (Admin approved users).
    ...                         - A browser must already be open before calling this keyword
    ...                           (e.g., via OpenBrowser).
    ...
    ...                         *Authentication Flow:*
    ...                         1. JwtAuthenticate signs a JWT token using ${server_key} and
    ...                            exchanges it for a Salesforce access token.
    ...                         2. JwtLogin uses that token to open an authenticated UI session
    ...                            in the already-open browser window.
    ...
    ...                         *Connected App Setup Summary:*
    ...                         - Generate an RSA key pair (openssl genrsa / openssl req).
    ...                         - Create an External Client App in Salesforce Setup with
    ...                           "Enable JWT Bearer Token Flow" checked.
    ...                         - Upload the public certificate (server.crt) to the app.
    ...                         - Set Permitted Users to "Admin approved users are pre-authorized".
    ...                         - Assign the relevant Permission Set to the automation user.
    ...                         - Copy the Consumer Key into ${client_id}.
    ...
    ...                         *Example:*
    ...                         | Login |
    ...
    ...                         *See Also:* JwtAuthenticate, JwtLogin, ClientAuthenticate
    JwtAuthenticate    ${client_id}    ${username}    ${server_key}
    JwtLogin

Setup
    GoTo                        ${login_url}lightning/setup/SetupOneHome/home

Sales Home
    [Documentation]             Navigate to homepage, login if needed
    Login
    LaunchApp                   Sales
    GoTo                        ${login_url}/lightning/page/home
    VerifyText                  Home    tag=span

Login As
    [Documentation]             Login As different persona. User needs to be logged into Salesforce with Admin rights
    ...                         before calling this keyword to change persona.
    ...                         Example:
    ...                         LoginAs                     Chatter Expert
    [Arguments]                 ${persona}
    ClickText                   Setup
    ClickText                   Setup for current app
    SwitchWindow                NEW
    TypeText                    Search Setup                ${persona}                  delay=2
    ClickText                   User                        anchor=${persona}           delay=5                     # wait for list to populate, then click
    VerifyText                  Freeze                      timeout=45                  # this is slow, needs longer timeout
    ClickText                   Login                       anchor=Freeze               delay=1

Global search and select type
    [Documentation]             searching and navigating to name with specific type
    [Arguments]                 ${name}                     ${type}
    ClickText                   Search...
    # ClickElement              //button[contains(@aria-label,'Search')]
    TypeText                    Search...                   ${name}
    ClickElement                //span[@title\='${name}']/ancestor::div[@class\='instant-results-list']//span[text()\='${type}']

Delete Record By Name
    [Documentation]             Generic keyword to delete any Salesforce object record by its Name field
    ...                         via the REST API. Queries the record ID using SOQL, deletes the record,
    ...                         and verifies it no longer exists.
    ...
    ...                         *Arguments:*
    ...                         - ${sobject}      : Salesforce API object name (e.g. Campaign, Account, Lead)
    ...                         - ${record_name}  : The Name field value of the record to delete
    ...
    ...                         *Prerequisites:*
    ...                         - JWT authentication must already be established before calling this keyword.
    ...
    ...                         *Example:*
    ...                         | Delete Record By Name | Campaign | My Test Campaign |
    ...                         | Delete Record By Name | Account  | Acme Corp        |
    ...                         | Delete Record By Name | Lead     | John Doe         |
    [Arguments]                 ${sobject}                  ${record_name}
    # Step 1: Query the record ID by Name using SOQL
    ${results}=                 QueryRecords
    ...                         SELECT Id FROM ${sobject} WHERE Name \= '${record_name}' LIMIT 1
    ${record_id}=               Set Variable                ${results}[records][0][Id]
    Log                         Deleting ${sobject} record: ${record_name} (ID: ${record_id})
    # Step 2: Delete the record via REST API
    Delete Record               ${sobject}                  ${record_id}
    # Step 3: Verify the record no longer exists
    ${verify}=                  QueryRecords
    ...                         SELECT Id FROM ${sobject} WHERE Id \= '${record_id}' LIMIT 1
    Should Be Equal As Integers    ${verify}[totalSize]     0
    Log                         Successfully deleted ${sobject}: ${record_name}