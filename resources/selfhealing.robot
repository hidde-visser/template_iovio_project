*** Settings ***
Documentation                   Self-Healing Library - plug-and-play resource.
...
...                             Drop this single Resource import into any test suite.
...                             Set Suite Setup to "Initialize Salesforce Session".
...                             Every wrapped actionable keyword will automatically
...                             self-heal on failure using the Copado AI surgeon.
...
...                             Orchestration cycle (fires once per failed keyword):
...                             1. Start / reuse HTTP session (done at Suite Setup)
...                             2. Reuse existing dialogue thread (done at Suite Setup)
...                             3. Capture screenshot + DOM snapshot
...                             4. Send multimodal message to surgeon
...                             5. Parse reply and execute corrected step

Library                         QForce
Library                         RequestsLibrary
Library                         DomParserLibrary.py
Library                         AgentJsonParser.py
Resource                        GeminiHelp.robot

*** Variables ***
# IMPORTANT: Please read the readme.txt to understand needed variables and how to handle them!!
${BROWSER}                      chrome
${SELF_HEALING_ENABLED}    False

*** Keywords ***

Initialize Salesforce Session
    [Documentation]             One-time suite setup.
    ...                         1. Opens the browser and logs in to Salesforce.
    ...                         2. Creates the persistent HTTP session to the Copado AI gateway.
    ...                         3. Creates a fresh dialogue thread for this suite run.
    ...                         4. Waits until the AI worker container is fully provisioned.
    ...
    ...                         All subsequent calls to Run With Healing reuse the same
    ...                         session and thread, so context accumulates across steps.
    # ── Step 1: Browser + Salesforce login ───────────────────────────────────
    ${token}=                   JwtAuthenticate             ${client_id}              ${username}                 ${server_key}
    ${instanceUrl}=             Get Instance Url
    Set Suite Variable          ${SUITE_TOKEN}              ${token}
    Set Suite Variable          ${SUITE_INSTANCE_URL}       ${instanceUrl}
    Set Library Search Order    QForce                      QWeb
    Open Browser                about:blank                 ${BROWSER}
    SetConfig                   LineBreak                   ${EMPTY}                    #\ue000
    Evaluate                    random.seed()               random                      # initialize random generator
    SetConfig                   DefaultTimeout              10s                         #sometimes salesforce is slow
    # adds a delay of 0.3 between keywords.
    # This is helpful in cloud with limited resources.
    SetConfig                   Delay                       0.1
    JwtLogin
    ${CLEAN_API_KEY}=           String.Strip String         ${CopadoAIApi}
    ${CLEAN_ORG}=               String.Strip String         ${ORG_ID}
    ${CLEAN_WSPACE}=            String.Strip String         ${WORKSPACE_ID}
    Set Suite Variable          ${CLEAN_API_KEY}            ${CLEAN_API_KEY}
    Set Suite Variable          ${CLEAN_ORG}                ${CLEAN_ORG}
    Set Suite Variable          ${CLEAN_WSPACE}             ${CLEAN_WSPACE}
    SelfHeal           ${SELF_HEALING_ENABLED} 
    # ── Step 2: Persistent HTTP session to Copado AI gateway ─────────────────
    # The session alias "CopadoSession" is expected by GeminiHelp keywords.
    ${headers}=                 Create Dictionary
    ...                         accept=application/json
    ...                         X-Authorization=${CLEAN_API_KEY}
    ...                         X-Workspace-Id=${CLEAN_WSPACE}
    ...                         x-client=ai_platform_ui

    # Persistent session auto-forwards session identity traits matching the browser archetype
    Create Session              alias=CopadoSession         url=https://copadogpt-api.robotic.copado.com            headers=${headers}


    # ══════════════════════════════════════════════════════════════════════════════
    # WRAPPED KEYWORD FAMILIES
    # All keywords below are drop-in replacements for their QForce equivalents.
    # The test author uses them exactly as they would use QForce keywords.
    # ══════════════════════════════════════════════════════════════════════════════

    # --- CLICK FAMILY ---

ClickText
    [Arguments]    @{args}    &{kwargs}
    Run With Healing    ClickText    @{args}    &{kwargs}

ClickItem
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickItem                   @{args}    &{kwargs}

ClickElement
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickElement                @{args}    &{kwargs}

ClickCheckbox
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickCheckbox               @{args}    &{kwargs}

ClickCell
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickCell                   @{args}    &{kwargs}

ClickFieldValue
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickFieldValue             @{args}    &{kwargs}

ClickTableCell
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickTableCell              @{args}    &{kwargs}

ClickTree
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickTree                   @{args}    &{kwargs}

ClickCoordinates
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ClickCoordinates            @{args}    &{kwargs}

RightClick
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            RightClick                  @{args}    &{kwargs}

    # --- TYPE FAMILY ---

TypeText
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            TypeText                    @{args}    &{kwargs}

TypeSecret
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            TypeSecret                  @{args}    &{kwargs}

TypeAlert
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            TypeAlert                   @{args}    &{kwargs}

TypeTable
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            TypeTable                   @{args}    &{kwargs}

TypeTexts
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            TypeTexts                   @{args}    &{kwargs}

WriteText
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            WriteText                   @{args}    &{kwargs}

    # --- SELECTION FAMILY ---

DropDown
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            DropDown                    @{args}    &{kwargs}

PickList
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            PickList                    @{args}    &{kwargs}

MultiPickList
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            MultiPickList               @{args}    &{kwargs}

ComboBox
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ComboBox                    @{args}    &{kwargs}

    # --- INTERACTION FAMILY ---

DragDrop
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            DragDrop                    @{args}    &{kwargs}

UploadFile
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            UploadFile                  @{args}    &{kwargs}

    # --- SCROLL FAMILY ---

Scroll
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            Scroll                      @{args}    &{kwargs}

ScrollTo
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ScrollTo                    @{args}    &{kwargs}

ScrollText
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ScrollText                  @{args}    &{kwargs}

ScrollList
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            ScrollList                  @{args}    &{kwargs}

    # --- HOVER FAMILY ---

HoverText
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            HoverText                   @{args}    &{kwargs}

HoverItem
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            HoverItem                   @{args}    &{kwargs}

HoverElement
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            HoverElement                @{args}    &{kwargs}

    # --- MOUSE FAMILY ---

MouseDown
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            MouseDown                   @{args}    &{kwargs}

MouseUp
    [Arguments]                 @{args}    &{kwargs}
    Run With Healing            MouseUp                     @{args}    &{kwargs}


# ── Fallback Keyword: Execute Next Healing Strategy ───────────────────────────
# Call this when a healed step appeared to pass but caused a bad state downstream.
# It picks up the next unused strategy from the suite-level list and runs it.
Execute Next Healing Strategy
    [Documentation]             Executes the next available surgeon strategy from the suite-level
    ...                         remaining strategies list.
    ...                         Advances the suite-level index each call.
    ...                         Logs a warning when no strategies remain instead of failing.
    ${has_remaining}=    Evaluate    isinstance($HEALING_REMAINING_STRATEGIES, list) and len($HEALING_REMAINING_STRATEGIES) > 0

    IF    not ${has_remaining}
        Log To Console          [SelfHealing Fallback] No remaining strategies registered. Nothing to execute.
        RETURN
    END

    ${count}=                   Evaluate                    len($HEALING_REMAINING_STRATEGIES)
    ${idx}=                     Set Variable                ${HEALING_REMAINING_IDX}

    IF    ${idx} >= ${count}
        Log To Console          [SelfHealing Fallback] No more strategies remaining for '${HEALING_REMAINING_KW}'. All ${count} fallback(s) exhausted.
        RETURN
    END

    ${strategy}=                Set Variable                ${HEALING_REMAINING_STRATEGIES[${idx}]}

    ${action}=                  Evaluate                    AgentJsonParser.extract_first_action_from_step({'strategies': [$strategy]})
    ${action_is_none}=          Evaluate                    $action is None
    IF                          ${action_is_none}
        Log To Console          [SelfHealing Fallback] Strategy at index ${idx} yielded no valid action. Skipping.
        ${next_idx}=            Evaluate                    $idx + 1
        Set Suite Variable      ${HEALING_REMAINING_IDX}    ${next_idx}
        RETURN
    END

    ${corrected_kw}=            Get From Dictionary         ${action}                   keyword
    ${corrected_args}=          Get From Dictionary         ${action}                   args
    ${corrected_kwargs}=        Get From Dictionary         ${action}                   kwargs
    ${corrected_kwargs}=        Sanitize Kwargs             ${corrected_kwargs}

    ${safe_args}=               Create List
    FOR                         ${arg}                      IN                          @{corrected_args}
        ${is_str}=              Evaluate                    isinstance($arg, str)
        IF                      ${is_str}
            ${arg}=             Evaluate                    AgentJsonParser.escape_xpath_arg($arg)
        END
        Append To List          ${safe_args}                ${arg}
    END

    Log To Console              [SelfHealing Fallback] Executing next strategy [${idx}]: ${corrected_kw} args\=${safe_args}

    ${status}    ${fb_message}=    Run Keyword And Ignore Error    ${corrected_kw}    @{safe_args}    &{corrected_kwargs}

    ${next_idx}=                Evaluate                    $idx + 1
    Set Suite Variable          ${HEALING_REMAINING_IDX}    ${next_idx}

    IF    '${status}' == 'PASS'
        Log To Console          [SelfHealing Fallback] Strategy [${idx}] passed: ${corrected_kw} ${safe_args}
    ELSE
        Log To Console          [SelfHealing Fallback] Strategy [${idx}] failed: ${fb_message}. Call again for next strategy.
    END


SelfHeal
    [Documentation]             Master switch for the self-healing pipeline.
    ...                         Sets a suite-level boolean that Run With Healing checks.
    [Arguments]                 ${enabled}

    ${normalized}=              Convert To Lowercase        ${enabled}
    IF                          '${normalized}' == 'true'
        Set Suite Variable      ${SELF_HEALING_ENABLED}     ${True}
        Log To Console          [SelfHeal] Self-healing ENABLED for this suite.
    ELSE IF                     '${normalized}' == 'false'
        Set Suite Variable      ${SELF_HEALING_ENABLED}     ${False}
        Log To Console          [SelfHeal] Self-healing DISABLED for this suite. Running in pass-through mode.
    ELSE
        Fail                    [SelfHeal] Invalid value '${enabled}'. Expected 'true' or 'false' (case-insensitive).
    END


Run With Healing 
    [Documentation]             Internal dispatcher used by every wrapped keyword.
    ...                         Attempt 1: runs the QForce keyword normally.
    ...                         On failure: engaging Resolve Step Failure Stable (GeminiHelp.robot)
    ...                         to execute a multi-strategy heal operation via the AI surgeon.
    [Arguments]                 ${kw}                       @{args}    &{kwargs}
    ${healing_active}=          Get Variable Value          ${SELF_HEALING_ENABLED}     ${True}

    IF                          not ${healing_active}
        # Pass-through mode: run directly, fail hard on error.
        ${status}    ${message}=    Run Keyword And Ignore Error    QForce.${kw}    @{args}    &{kwargs}
        IF    '${status}' == 'PASS'
            RETURN
        ELSE
            Fail    ${message}
        END
    END

    # ── Attempt 1: normal execution ──────────────────────────────────────────
    ${status}    ${message}=    Run Keyword And Ignore Error    QForce.${kw}    @{args}    &{kwargs}
    IF                          '${status}' == 'PASS'
        RETURN
    END

    Log To Console                         '${kw}' FAILED: ${message}. Activating surgeon...

    Create Dialogue Thread Stable                           test

    # ── Step 3: Capture visual and structural artifacts ───────────────────────
    ${screenshot_path}=         LogScreenshot               fullpage=False
    ${dom_json_path}=           Capture Page Elements

    # ── Step 4: Build a minimal step dict for Resolve Step Failure Stable ────
    ${action_dict}=             Create Dictionary
    ...                         keyword=${kw}
    ...                         args=${args}
    ...                         kwargs=${kwargs}

    ${strategy_sequence}=       Create List                 ${action_dict}
    ${strategies_list}=         Create List                 ${strategy_sequence}

    ${failed_step}=             Create Dictionary
    ...                         intent=Self-healing: ${kw} ${args}
    ...                         strategies=${strategies_list}
    ...                         is_risky=${False}

    # Empty remaining steps and history for the plug-and-play context.
    @{empty_remaining}=         Create List
    ${empty_history_json}=      Set Variable                []

    # ── Step 5: Call Resolve Step Failure Stable ──────────────────────────────
    ${ai_reply}=                Resolve Step Failure Stable
    ...                         test
    ...                         ${failed_step}
    ...                         ${message}
    ...                         ${empty_remaining}
    ...                         ${dom_json_path}
    ...                         ${screenshot_path}
    ...                         ${empty_history_json}
    ...                         Self-healing single keyword: ${kw}
    ...                         failure_mode=HARD_KEYWORD_ERROR

    # ── Step 6: Parse surgeon reply ───────────────────────────────────────────
    ${surgeon_payload}=         Extract Surgeon JSON Reply                              ${ai_reply}

    # Check for business-logic escalation.
    ${escalate}=                Get From Dictionary         ${surgeon_payload}          escalate                    default=${False}
    IF                          ${escalate}
        ${reason}=              Get From Dictionary         ${surgeon_payload}          escalation_reason           default=No reason provided
        Fail                    [SelfHealing] Surgeon escalated: ${reason}. Original error: ${message}
    END

    # ── Step 7: Extract ALL strategies and loop until one passes ─────────────
    ${raw_corrected}=           Get From Dictionary         ${surgeon_payload}          corrected_steps             default=${NONE}
    ${corrected_is_none}=       Evaluate                    $raw_corrected is None
    IF                          ${corrected_is_none}
        Fail                    [SelfHealing] Surgeon returned no corrected_steps for '${kw}'. Original error: ${message}
    END
    ${corrected_is_list}=       Evaluate                    isinstance($raw_corrected, list) and len($raw_corrected) > 0
    IF                          not ${corrected_is_list}
        Fail                    [SelfHealing] Surgeon corrected_steps is empty or not a list for '${kw}'. Original error: ${message}
    END

    ${first_step}=              Set Variable                ${raw_corrected[0]}

    # Pull the full strategies list from the first step.
    ${strategies}=              Get From Dictionary         ${first_step}               strategies                  default=${NONE}
    ${has_strategies}=          Evaluate                    isinstance($strategies, list) and len($strategies) > 0
    IF                          not ${has_strategies}
        Fail                    [SelfHealing] No strategies found in surgeon corrected_steps for '${kw}'. Original error: ${message}
    END

    # ── Step 8: Loop every strategy until one passes ──────────────────────
    ${healed}=                  Set Variable                ${False}
    ${last_message}=            Set Variable                ${message}
    ${remaining_strategies}=    Create List
    SetConfig                   DefaultTimeout              4s

    FOR                         ${strategy}                 IN                          @{strategies}
        # Initial retry in case of a timing issue
        ${status}    ${message}=    Run Keyword And Ignore Error    QForce.${kw}    @{args}    &{kwargs}
        IF    '${status}' == 'PASS'
            Log To Console      [SelfHealing] Timing retry succeeded for '${kw}'.
            Log To Console      Consider adding an IsText step with a timeout before this keyword to avoid future failures.
            ${healed}=          Set Variable                ${True}
            BREAK
        END
        # Each strategy is a list of action dicts.
        ${action}=              Evaluate                    AgentJsonParser.extract_first_action_from_step({'strategies': [$strategy]})
        ${action_is_none}=      Evaluate                    $action is None
        IF                      ${action_is_none}
            CONTINUE
        END

        ${corrected_kw}=        Get From Dictionary         ${action}                   keyword
        ${corrected_args}=      Get From Dictionary         ${action}                   args
        ${corrected_kwargs}=    Get From Dictionary         ${action}                   kwargs
        ${corrected_kwargs}=    Sanitize Kwargs             ${corrected_kwargs}

        ${safe_args}=           Create List
        FOR                     ${arg}                      IN                          @{corrected_args}
            ${is_str}=          Evaluate                    isinstance($arg, str)
            IF                  ${is_str}
                ${arg}=         Evaluate                    AgentJsonParser.escape_xpath_arg($arg)
            END
            Append To List      ${safe_args}                ${arg}
        END

        Log To Console          [SelfHealing] Trying strategy: ${corrected_kw} args\=${safe_args}

        ${status2}    ${last_message}=    Run Keyword And Ignore Error    Qforce.${corrected_kw}    @{safe_args}    &{corrected_kwargs}

        IF    '${status2}' == 'PASS'
            ${args_str}=        Convert To String           ${safe_args}
            ${kwargs_str}=      Convert To String           ${corrected_kwargs}
            Log To Console      HEALED: '${kw}' corrected to: ${corrected_kw} ${args_str} ${kwargs_str}
            Log To Console      Original error: ${message}
            # Store remaining strategies (everything after this one) for the fallback keyword.
            ${current_idx}=     Evaluate                    $strategies.index($strategy)
            ${remaining_strategies}=    Evaluate            $strategies[$current_idx + 1:]
            Set Suite Variable  ${HEALING_REMAINING_STRATEGIES}         ${remaining_strategies}
            Set Suite Variable  ${HEALING_REMAINING_KW}              ${kw}
            Set Suite Variable  ${HEALING_REMAINING_IDX}                0
            ${healed}=          Set Variable                ${True}
            BREAK
        END
    END
    SetConfig                   DefaultTimeout              10s

    IF    not ${healed}
        Fail                    [SelfHealing] All ${strategies.__len__()} strategies exhausted for '${kw}'. Last error: ${last_message}
    END