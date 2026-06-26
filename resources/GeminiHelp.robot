*** Settings ***
Library                         RequestsLibrary
Library                         Collections
Library                         String
Library                         DateTime
Library                         OperatingSystem
Library                         QWeb
Library                         QForce
Library                         String
Library                         DateTime
Library                         ../resources/DomParserLibrary.py
Library                         ../resources/ObjectSanitizer.py
#Resource                        ../resources/MetadataRetrieval.robot
Library                         ../resources/ExplorationSessionLibrary.py
Library                         JsonSanitizer.py

*** Variables ***
@{ALL_PROPOSED_STEPS}           # A: Every step the AI has suggested so far
@{EXECUTION_HISTORY_PASSED}     # B: Steps that technically executed without throwing a CRT error
@{EXECUTION_HISTORY_FAILED}     # C: Steps that threw an error
@{GOLDEN_PATH_SCRIPT}           # D: The final, optimized sequence to be saved as the real asset

*** Keywords *** 
    #########EXPERIMENTAL###########
Send Multimodal Message To Agent Stable
    [Arguments]                 ${target_assistant_id}      ${text_prompt}              ${screenshot_path}          ${max_attempts}=16          ${poll_interval}=15s

    ${absolute_path}=           Normalize Path              ${screenshot_path}
    Should Exist                ${absolute_path}

    # 1. Convert image to base64 string
    ${file_bytes}=              OperatingSystem.Get Binary File                         ${absolute_path}
    ${base64_str}=              Evaluate                    base64.b64encode($file_bytes).decode('utf-8')           modules=base64
    ${raw_data_uri}=            Set Variable                data:image/png;base64,${base64_str}

    # 2. Downsize via gateway utility
    ${resize_payload}=          Create Dictionary           image_url=${raw_data_uri}
    ${resize_res}=              POST On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/image
    ...                         json=${resize_payload}
    ...                         expected_status=200

    ${resized_data_uri}=        Set Variable                ${resize_res.json()['image_url']}
    Log To Console              ⚡ Screenshot optimized and downsized by gateway utility.

    # STEP 3: Structure individual content parts
    ${text_part}=               Create Dictionary           type=text                   text=${text_prompt}
    ${image_url_obj}=           Create Dictionary           url=${resized_data_uri}

    # FIX: Change type from 'image_url' to 'image' to match the strict model literal
    ${image_part}=              Create Dictionary           type=image                  image_url=${image_url_obj}

    # Combine elements into a unified content array
    ${multimodal_prompt}=       Create List                 ${text_part}                ${image_part}

    # Wrap the list inside a valid ChatMessage dictionary structure
    ${chat_message}=            Create Dictionary           role=user                   content=${multimodal_prompt}

    # 4. Build final payload using the wrapped chat_message object
    ${msg_uuid}=                Evaluate                    str(uuid.uuid4())           modules=uuid
    ${message_payload}=         Create Dictionary
    ...                         request_id=${msg_uuid}
    ...                         prompt=${chat_message}
    ...                         assistantId=test

    # 5. Send payload inside your 403-safe heartbeat loop
    FOR                         ${attempt}                  IN RANGE                    1                           ${max_attempts} + 1
        Log To Console          📤 [Attempt ${attempt}/${max_attempts}] Sending multimodal payload to dialogue ${DIALOGUE_ID}...

        ${response}=            POST On Session
        ...                     alias=CopadoSession
        ...                     url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}/messages?ngsw-bypass=true
        ...                     json=${message_payload}
        ...                     expected_status=any
        ...                     timeout=90

        ${http_status}=         Set Variable                ${response.status_code}

        IF                      ${http_status} == 200
            Log To Console      ✅ Multimodal message successfully accepted by the gateway!
            RETURN
        END

        IF                      ${http_status} == 403
            IF                  ${attempt} == ${max_attempts}
                Fail            TIMEOUT: Dialogue thread remained locked on all attempts.
            END
            Log To Console      ↳ Ingestion indexing active (HTTP 403). Retrying in ${poll_interval}...
            Sleep               ${poll_interval}
            CONTINUE
        END

        Fail                    SEND MESSAGE FAILED: Unexpected HTTP ${http_status}. Body: ${response.text}
    END
Embed Screenshot To Dialogue Stable
    [Documentation]             Reads a local screenshot file, converts it into a
    ...                         Base64 Data URI string, and POSTs it directly to the
    ...                         image microservice endpoint.
    [Arguments]                 ${screenshot_path}

    ${absolute_path}=           Normalize Path              ${screenshot_path}
    Should Exist                ${absolute_path}

    # 1. Read the raw visual image bytes from disk
    ${file_bytes}=              OperatingSystem.Get Binary File                         ${absolute_path}

    # 2. Leverage Python's encoding module to translate the binary grid into a clean text string
    ${base64_str}=              Evaluate                    base64.b64encode($file_bytes).decode('utf-8')           modules=base64

    # 3. Construct the exact Data URI scheme required by the Copado API contract
    ${data_uri}=                Set Variable                data:image/png;base64,${base64_str}

    # 4. Wrap the data string into a clean JSON payload dictionary
    ${image_payload}=           Create Dictionary           image_url=${data_uri}

    Log To Console              📤 Transmodulating image binary to text. Sending frame payload...

    # 5. Execute the transaction against the dedicated image pipeline
    ${response}=                POST On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/image
    ...                         json=${image_payload}
    ...                         expected_status=200
    ...                         timeout=60

    Log To Console              ✅ Screenshot successfully integrated into active conversation channel.
    RETURN                      ${response.json()}
Initialize Copado AI Session Stable
    [Documentation]             Strips variables and creates a persistent network session pool
    ...                         configured with browser-mimicking headers to prevent routing blocks.
    ${CLEAN_API_KEY}=           String.Strip String         RsXATKf3Qrrthmu8p4jWTFKaXMF4XFlHTg6BrqnkyvElVFzVm9Gd
    ${CLEAN_ORG}=               String.Strip String         47405
    ${CLEAN_WSPACE}=            String.Strip String         91c3bc10-96c7-4a1b-87c4-5751b54bede6
    Set Suite Variable          ${CLEAN_API_KEY}            ${CLEAN_API_KEY}
    Set Suite Variable          ${CLEAN_ORG}                ${CLEAN_ORG}
    Set Suite Variable          ${CLEAN_WSPACE}             ${CLEAN_WSPACE}

    ${headers}=                 Create Dictionary
    ...                         accept=application/json
    ...                         X-Authorization=${CLEAN_API_KEY}
    ...                         X-Workspace-Id=${CLEAN_WSPACE}
    ...                         x-client=ai_platform_ui

    # Persistent session auto-forwards session identity traits matching the browser archetype
    Create Session              alias=CopadoSession         url=https://copadogpt-api.robotic.copado.com            headers=${headers}
    Log To Console              Persistent stable request session initialized with UI routing context.


Create Dialogue Thread Stable
    [Documentation]             Creates a new AI dialogue thread with a dynamically generated name.
    [Arguments]                 ${target_assistant_id}

    ${timestamp}=               DateTime.Get Current Date                               result_format=%m/%d/%Y %I:%M:%S%p
    ${timestamp}=               String.Convert To Lower Case                            ${timestamp}
    ${dialogue_name}=           Set Variable                Test Creation ${timestamp}
    Log To Console              Creating stable dialogue: ${dialogue_name}

    ${dialogue_payload}=        Create Dictionary
    ...                         name=${dialogue_name}
    ...                         workspaceId=${CLEAN_WSPACE}
    ...                         assistantId=${target_assistant_id}

    ${create_dial_res}=         POST On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/dialogues?ngsw-bypass=true
    ...                         json=${dialogue_payload}
    ...                         expected_status=201
    ...                         timeout=90

    ${dialogue_data}=           Set Variable                ${create_dial_res.json()}
    ${DIALOGUE_ID}=             Set Variable                ${dialogue_data['id']}
    Set Suite Variable          ${DIALOGUE_ID}              ${DIALOGUE_ID}
    Log To Console              Dialogue created stably with ID: ${DIALOGUE_ID}


Attach Document To Dialogue Stable
    [Documentation]             Uploads a local file using the stable persistent session configuration.
    [Arguments]                 ${file_path}

    ${absolute_path}=           Normalize Path              ${file_path}
    Should Exist                ${absolute_path}

    ${file_name}=               Fetch From Right            ${absolute_path}            /
    ${file_handle}=             Evaluate                    open($absolute_path, 'rb')
    ${file_tuple}=              Create List                 ${file_name}                ${file_handle}              application/octet-stream
    ${file_obj}=                Create Dictionary           file=${file_tuple}

    ${upload_headers}=          Create Dictionary           accept=application/json

    # Added the angular service worker parameter discovered in browser network inspections
    ${upload_res}=              POST On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}/documents?ngsw-bypass=true
    ...                         headers=${upload_headers}
    ...                         files=${file_obj}
    ...                         expected_status=201
    ...                         timeout=90

    Log To Console              Document stably attached to RAG context: ${file_name}
    RETURN                      ${file_name}


Send Message To Agent Stable
    [Documentation]             Posts a prompt message to the assistant, gracefully absorbing
    ...                         the long 403 database locks caused by heavy document indexing loops.
    [Arguments]                 ${target_assistant_id}      ${prompt}                   ${max_attempts}=16          ${poll_interval}=15s

    ${msg_uuid}=                Evaluate                    str(uuid.uuid4())           modules=uuid
    Log To Console              Sending message with request ID: ${msg_uuid}

    # ${message_payload}=         Create Dictionary
    # ...                         request_id=${msg_uuid}
    # ...                         prompt=${prompt}
    # ...                         assistantId=${target_assistant_id}

    ${message_payload}=         Create Dictionary
    ...                         request_id=${msg_uuid}
    ...                         prompt=${prompt}
    ...                         assistantId=test

    FOR                         ${attempt}                  IN RANGE                    1                           ${max_attempts} + 1
        Log To Console          📤 [Attempt ${attempt}/${max_attempts}] Dispatching prompt payload to dialogue ${DIALOGUE_ID}...

        ${response}=            POST On Session
        ...                     alias=CopadoSession
        ...                     url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}/messages?ngsw-bypass=true
        ...                     json=${message_payload}
        ...                     expected_status=any
        ...                     timeout=90

        ${http_status}=         Set Variable                ${response.status_code}

        # 200 OK means the background indexing lock has officially been released!
        IF                      ${http_status} == 200
            Log To Console      ✅ Gateway lock released! Message successfully accepted on attempt ${attempt}.
            RETURN
        END

        # 403 means the vector engine is still chewing through the heavy HTML layout structure
        # IF                      ${http_status} == 403
        #     IF                  ${attempt} == ${max_attempts}
        #         Fail            TIMEOUT: AI Gateway dialogue thread remained locked via 403 for over 4 minutes.
        #     END
        #     Log To Console      ↳ Background indexing still active (HTTP 403). Holding line for ${poll_interval}...
        #     Sleep               ${poll_interval}
        #     CONTINUE
        # END
        IF                      ${http_status} == 403
    IF                  ${attempt} == ${max_attempts}
        Fail            TIMEOUT: AI Gateway dialogue thread remained locked via 403 for over 4 minutes.
    END
    # Log the full response body so we can diagnose the actual error
     Log To Console      ↳ [403 DIAGNOSTIC] Response URL: ${response.url}
    Log To Console      ↳ [403 DIAGNOSTIC] Response Body: ${response.text}
    Log To Console      ↳ [403 DIAGNOSTIC] Response Headers: ${response.headers}
    Log To Console      ↳ [403 DIAGNOSTIC] Request URL: ${response.request.url}
    Log To Console      ↳ [403 DIAGNOSTIC] Request Headers: ${response.request.headers}
    Log To Console      ↳ [403 DIAGNOSTIC] Request Body: ${response.request.body}
    Log To Console      ↳ [403 DIAGNOSTIC] Elapsed Time: ${response.elapsed}
    Log To Console      ↳ Holding line for ${poll_interval} before retry...
    Sleep               ${poll_interval}
    CONTINUE
    END


        Fail                    SEND MESSAGE FAILED: Unexpected HTTP ${http_status} received from gateway. Body: ${response.text}
    END

TEST Send Message To Agent Stable
    [Documentation]             Posts a prompt message to the assistant, gracefully absorbing
    ...                         the long 403 database locks caused by heavy document indexing loops.
    [Arguments]                 ${target_assistant_id}      ${prompt}                   ${max_attempts}=16          ${poll_interval}=15s

    ${msg_uuid}=                Evaluate                    str(uuid.uuid4())           modules=uuid
    Log To Console              Sending message with request ID: ${msg_uuid}

    ${message_payload}=         Create Dictionary
    ...                         request_id=${msg_uuid}
    ...                         prompt=${prompt}
    ...                         assistantId=test

    FOR                         ${attempt}                  IN RANGE                    1                           ${max_attempts} + 1
        Log To Console          📤 [Attempt ${attempt}/${max_attempts}] Dispatching prompt payload to dialogue ${DIALOGUE_ID}...

        ${response}=            POST On Session
        ...                     alias=CopadoSession
        ...                     url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}/messages?ngsw-bypass=true
        ...                     json=${message_payload}
        ...                     expected_status=any
        ...                     timeout=90

        ${http_status}=         Set Variable                ${response.status_code}

        # 200 OK means the background indexing lock has officially been released!
        IF                      ${http_status} == 200
            Log To Console      ✅ Gateway lock released! Message successfully accepted on attempt ${attempt}.
            RETURN
        END

        # 403 means the vector engine is still chewing through the heavy HTML layout structure
        # IF                      ${http_status} == 403
        #     IF                  ${attempt} == ${max_attempts}
        #         Fail            TIMEOUT: AI Gateway dialogue thread remained locked via 403 for over 4 minutes.
        #     END
        #     Log To Console      ↳ Background indexing still active (HTTP 403). Holding line for ${poll_interval}...
        #     Sleep               ${poll_interval}
        #     CONTINUE
        # END
        IF                      ${http_status} == 403
    IF                  ${attempt} == ${max_attempts}
        Fail            TIMEOUT: AI Gateway dialogue thread remained locked via 403 for over 4 minutes.
    END
    # Log the full response body so we can diagnose the actual error
     Log To Console      ↳ [403 DIAGNOSTIC] Response URL: ${response.url}
    Log To Console      ↳ [403 DIAGNOSTIC] Response Body: ${response.text}
    Log To Console      ↳ [403 DIAGNOSTIC] Response Headers: ${response.headers}
    Log To Console      ↳ [403 DIAGNOSTIC] Request URL: ${response.request.url}
    Log To Console      ↳ [403 DIAGNOSTIC] Request Headers: ${response.request.headers}
    Log To Console      ↳ [403 DIAGNOSTIC] Request Body: ${response.request.body}
    Log To Console      ↳ [403 DIAGNOSTIC] Elapsed Time: ${response.elapsed}
    Log To Console      ↳ Holding line for ${poll_interval} before retry...
    Sleep               ${poll_interval}
    CONTINUE
    END


        Fail                    SEND MESSAGE FAILED: Unexpected HTTP ${http_status} received from gateway. Body: ${response.text}
    END

Read Dialogue With Messages Stable
    [Arguments]                 ${target_dialogue_id}
    Log To Console              Reading dialogue with ID: ${target_dialogue_id}

    ${read_dial_res}=           GET On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/dialogues/${target_dialogue_id}?ngsw-bypass=true
    ...                         expected_status=200
    ...                         timeout=90

    ${dialogue_data}=           Set Variable                ${read_dial_res.json()}

    ${DIALOGUE_ID}=             Set Variable                ${dialogue_data['id']}
    ${DIALOGUE_NAME}=           Set Variable                ${dialogue_data['name']}
    ${DIALOGUE_MESSAGES}=       Set Variable                ${dialogue_data['messages']}
    ${DIALOGUE_MSG_COUNT}=      Set Variable                ${dialogue_data['message_count']}

    Set Suite Variable          ${DIALOGUE_ID}              ${DIALOGUE_ID}
    Set Suite Variable          ${DIALOGUE_NAME}            ${DIALOGUE_NAME}
    Set Suite Variable          ${DIALOGUE_MESSAGES}        ${DIALOGUE_MESSAGES}
    Set Suite Variable          ${DIALOGUE_MSG_COUNT}       ${DIALOGUE_MSG_COUNT}

    Log To Console              Dialogue context '${DIALOGUE_NAME}' retrieved with ${DIALOGUE_MSG_COUNT} message(s).
    [Return]                    ${dialogue_data}


Retrieve Agent Reply Stable
    [Documentation]             Waits for the streaming connection data frame to settle,
    ...                         then fetches the full thread history using the stable session alias.
    

    ${history_res}=             GET On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}?ngsw-bypass=true
    ...                         expected_status=200
    ...                         timeout=90

    ${history_json}=            Set Variable                ${history_res.json()}
    ${all_messages}=            Set Variable                ${history_json['messages']}
    ${last_message}=            Set Variable                ${all_messages[-1]}
    ${ai_final_reply}=          Set Variable                ${last_message['content']}

    Log To Console              Compiled AI Agent Answer Received.
    RETURN                      ${ai_final_reply}


Verify Document Is Ready Stable
    [Documentation]             Polls the agent session backend to bridge the worker container provisioning gap.
    ...                         Blocks execution if the worker returns a 404 (provisioning) or an active indexing state.
    [Arguments]                 ${file_name}
    Log To Console              ⏳ Waiting for AI agent worker instance to initialize and assign container...

    FOR                         ${attempt}                  IN RANGE                    1                           16
        ${session_res}=         GET On Session
        ...                     alias=CopadoSession
        ...                     url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}/agent-session
        ...                     expected_status=any
        ...                     timeout=30

        ${status_code}=         Set Variable                ${session_res.status_code}

        # Scenario A: Container is still booting up (The 404 your log caught)
        IF                      ${status_code} == 404
            Log To Console      ↳ [Attempt ${attempt}/15] Worker container not allocated yet (HTTP 404). Waiting for cloud provisioning...
            Sleep               5s
            CONTINUE
        END

        # Scenario B: Container is online, verify it has finished ingestion indexing
        IF                      ${status_code} == 200
            ${session_data}=    Set Variable                ${session_res.json()}
            ${worker_status}=                               Get From Dictionary         ${session_data}             status                      default=ready

            Log To Console      ↳ [Attempt ${attempt}/15] Worker container online! Status flag: '${worker_status}'

            IF                  '${worker_status}' != 'processing' and '${worker_status}' != 'indexing'
                Log To Console                              ✅ Agent worker is initialized, allocated, and idle. Proceeding safely to message.
                RETURN          ${session_data}
            END
        END

        Sleep                   5s
    END
    Fail                        TIMEOUT: AI Gateway failed to provision an active worker container within 75 seconds.




Normalize Strategies
    [Documentation]             Accepts any shape the AI may emit for the "strategies" value
    ...                         and returns a clean list-of-lists (action sequences).
    ...
    ...                         Handled permutations:
    ...                         1. None / missing           -> empty list (step routes to surgeon)
    ...                         2. A bare dict (action)     -> [[dict]]
    ...                         3. A bare dict (step)       -> unwrap its inner strategies
    ...                         4. A flat list of dicts     -> [[d] for d in list]
    ...                         5. A proper list of lists                               -> used as-is
    ...                         6. A mixed list             -> each element normalised individually
    ...                         7. Anything else            -> empty list (logged, step routes to surgeon)
    ...
    ...                         FIX: The AI occasionally nests a full step-level dict (containing
    ...                         "intent" and "strategies") inside another step's strategies array.
    ...                         When a dict element contains an "intent" key it is a step object,
    ...                         not an action. Its inner strategies are extracted and flattened in.
    ...
    ...                         SAFETY: This keyword never modifies string values, casing, or arg
    ...                         contents. It only restructures the container shape.
    [Arguments]                 ${raw_strategies}

    # Guard: None or non-iterable
    ${is_none}=                 Evaluate                    $raw_strategies is None
    IF                          ${is_none}
        Log To Console          ⚠️ strategies is None. Routing step to surgeon.
        RETURN                  ${EMPTY LIST}
    END

    ${is_dict}=                 Evaluate                    isinstance($raw_strategies, dict)
    IF                          ${is_dict}
    # Check if this dict is actually a step object (has "intent") rather than an action.
        ${is_step_obj}=         Run Keyword And Return Status
        ...                     Dictionary Should Contain Key                           ${raw_strategies}           intent
        IF                      ${is_step_obj}
        # It is a misplaced step dict. Unwrap its inner strategies recursively.
            Log To Console      ⚠️ strategies value is a step-level dict. Unwrapping inner strategies.
            ${inner}=           Get From Dictionary         ${raw_strategies}           strategies                  default=${NONE}
            RETURN              Normalize Strategies        ${inner}
        END
        # Bare action dict -> wrap into a one-sequence, one-action list-of-lists
        ${action_seq}=          Create List                 ${raw_strategies}
        ${result}=              Create List                 ${action_seq}
        RETURN                  ${result}
    END

    ${is_list}=                 Evaluate                    isinstance($raw_strategies, list)
    IF                          not ${is_list}
        Log To Console          ⚠️ strategies is an unexpected type: ${raw_strategies}. Routing step to surgeon.
        RETURN                  ${EMPTY LIST}
    END

    # It is a list. Normalise each element individually.
    ${result}=                  Create List
    FOR                         ${element}                  IN                          @{raw_strategies}
        ${elem_is_list}=        Evaluate                    isinstance($element, list)
        ${elem_is_dict}=        Evaluate                    isinstance($element, dict)

        IF                      ${elem_is_list}
        # Already a proper action sequence. Use as-is.
            Append To List      ${result}                   ${element}
        ELSE IF                 ${elem_is_dict}
        # Check if this dict element is a misplaced step object.
            ${elem_is_step}=    Run Keyword And Return Status
            ...                 Dictionary Should Contain Key                           ${element}                  intent
            IF                  ${elem_is_step}
            # Misplaced step object inside the list. Unwrap its inner strategies.
                Log To Console                              ⚠️ Element in strategies list is a step-level dict. Unwrapping inner strategies.
                ${inner}=       Get From Dictionary         ${element}                  strategies                  default=${NONE}
                ${unwrapped}=                               Normalize Strategies        ${inner}
                FOR             ${seq}                      IN                          @{unwrapped}
                    Append To List                          ${result}                   ${seq}
                END
            ELSE
            # Regular action dict. Strip surgeon metadata keys, keep only the action contract.
                ${has_kw}=      Run Keyword And Return Status
                ...             Dictionary Should Contain Key                           ${element}                  keyword
                IF              ${has_kw}
                    ${clean_action}=                        Create Dictionary
                    ...         keyword=${element.get('keyword', 'unknown')}
                    ...         args=${element.get('args', [])}
                    ...         kwargs=${element.get('kwargs', {})}
                    ${action_seq}=                          Create List                 ${clean_action}
                    Append To List                          ${result}                   ${action_seq}
                ELSE
                    Log To Console                          ⚠️ Skipping dict element with no "keyword" or "intent": ${element}
                END
            END
        ELSE
            Log To Console      ⚠️ Skipping unrecognised strategy element: ${element}
        END
    END

    RETURN                      ${result}


Normalize Action
    [Documentation]             Accepts a single action object and returns a clean, safe dict.
    ...
    ...                         Handles:
    ...                         - Not a dict at all         -> returns ${NONE} (caller must skip)
    ...                         - Missing "keyword" field                               -> returns ${NONE} (caller must skip)
    ...                         - args is None              -> replaced with empty list
    ...                         - kwargs is None or not a dict -> replaced with empty dict
    ...
    ...                         FIX: Log To Console does NOT accept a stream/level argument.
    ...                         The previous call used WARN as a 4th positional arg, which RF
    ...                         tried to interpret as the 'stream' parameter and crashed with
    ...                         ValueError. The message and action are now concatenated into a
    ...                         single string argument.
    [Arguments]                 ${raw_action}

    ${is_dict}=                 Evaluate                    isinstance($raw_action, dict)
    IF                          not ${is_dict}
        Log To Console          ⚠️ Action is not a dict (got: ${raw_action}). Skipping.
        RETURN                  ${NONE}
    END

    # Validate required "keyword" field
    ${has_keyword}=             Run Keyword And Return Status
    ...                         Dictionary Should Contain Key                           ${raw_action}               keyword
    IF                          not ${has_keyword}
    # FIX: Single concatenated string — no 4th positional arg that RF misreads as 'stream'.
        Log To Console          ⚠️ Action is missing required "keyword" field. Skipping: ${raw_action}
        RETURN                  ${NONE}
    END

    # Safely extract args, defaulting None -> empty list
    ${raw_args}=                Get From Dictionary         ${raw_action}               args                        default=${NONE}
    ${args_is_none}=            Evaluate                    $raw_args is None
    IF                          ${args_is_none}
        ${clean_args}=          Create List
    ELSE
        ${clean_args}=          Set Variable                ${raw_args}
    END

    # Safely extract kwargs, defaulting None or non-dict -> empty dict
    ${raw_kwargs}=              Get From Dictionary         ${raw_action}               kwargs                      default=${NONE}
    ${kwargs_is_none}=          Evaluate                    $raw_kwargs is None
    IF                          ${kwargs_is_none}
        ${clean_kwargs}=        Create Dictionary
    ELSE
        ${kwargs_is_dict}=      Evaluate                    isinstance($raw_kwargs, dict)
        IF                      not ${kwargs_is_dict}
            ${clean_kwargs}=    Create Dictionary
        ELSE
            ${clean_kwargs}=    Set Variable                ${raw_kwargs}
        END
    END

    # Build the clean action dict preserving all original values exactly
    ${clean_action}=            Create Dictionary
    ...                         keyword=${raw_action}[keyword]
    ...                         args=${clean_args}
    ...                         kwargs=${clean_kwargs}

    RETURN                      ${clean_action}


Normalize Step
    [Documentation]             Accepts a single step object from either the architect or the surgeon
    ...                         and returns a clean, safe step dict.
    ...
    ...                         Handles:
    ...                         - Not a dict at all         -> returns ${NONE} (caller must skip)
    ...                         - Missing "intent" field    -> returns ${NONE} (caller must skip)
    ...                         - Missing "strategies" field                            -> treated as empty list
    ...                         - is_risky missing          -> defaults to False
    ...
    ...                         This is the fix for the re-injection bug: surgeon corrected_steps are
    ...                         passed through this keyword before being assigned to ${active_steps},
    ...                         ensuring the execution loop always receives a predictable shape regardless
    ...                         of whether the steps came from the architect or the surgeon.
    [Arguments]                 ${raw_step}

    ${is_dict}=                 Evaluate                    isinstance($raw_step, dict)
    IF                          not ${is_dict}
        Log To Console          ⚠️                          Step is not a dict (got: ${raw_step}). Skipping.
        RETURN                  ${NONE}
    END

    ${has_intent}=              Run Keyword And Return Status
    ...                         Dictionary Should Contain Key                           ${raw_step}                 intent
    IF                          not ${has_intent}
        Log To Console          ⚠️                          Step is missing required "intent" field. Skipping: ${raw_step}
        RETURN                  ${NONE}
    END

    ${raw_strategies}=          Get From Dictionary         ${raw_step}                 strategies                  default=${NONE}
    ${is_risky}=                Get From Dictionary         ${raw_step}                 is_risky                    default=${False}

    ${clean_step}=              Create Dictionary
    ...                         intent=${raw_step}[intent]
    ...                         strategies=${raw_strategies}
    ...                         is_risky=${is_risky}

    RETURN                      ${clean_step}


Normalize Step List
    [Documentation]             Accepts a raw list of step objects (from architect or surgeon) and
    ...                         returns a clean list where every entry has passed through Normalize Step.
    ...                         Invalid or unrecognisable entries are dropped with a console warning.
    ...
    ...                         Use this on every assignment to ${active_steps} to guarantee the
    ...                         execution loop always receives a predictable shape.
    [Arguments]                 ${raw_steps}

    ${is_none}=                 Evaluate                    $raw_steps is None
    IF                          ${is_none}
        Log To Console          ⚠️                          Step list is None. Returning empty list.
        RETURN                  ${EMPTY LIST}
    END

    ${is_list}=                 Evaluate                    isinstance($raw_steps, list)
    IF                          not ${is_list}
        Log To Console          ⚠️                          Step list is not a list (got: ${raw_steps}). Returning empty list.
        RETURN                  ${EMPTY LIST}
    END

    ${result}=                  Create List
    FOR                         ${raw_step}                 IN                          @{raw_steps}
        ${clean_step}=          Normalize Step              ${raw_step}
        ${is_none}=             Evaluate                    $clean_step is None
        IF                      not ${is_none}
            Append To List      ${result}                   ${clean_step}
        ELSE
            Log To Console      ⚠️                          Dropped unrecognisable step from queue: ${raw_step}
        END
    END

    RETURN                      ${result}


Sanitize Kwargs
    [Documentation]             Converts boolean values in a kwargs dict to their string
    ...                         representations so Robot Framework dispatches them correctly.
    ...                         All other values are passed through completely unmodified,
    ...                         preserving casing, whitespace, and special characters.
    [Arguments]                 ${raw_kwargs}

    ${clean_kwargs}=            Create Dictionary
    FOR                         ${key}                      ${val}                      IN                          &{raw_kwargs}
        ${is_bool}=             Evaluate                    isinstance($val, bool)
        IF                      ${is_bool}
            ${str_val}=         Evaluate                    str($val)
            Set To Dictionary                               ${clean_kwargs}             ${key}                      ${str_val}
        ELSE
            Set To Dictionary                               ${clean_kwargs}             ${key}                      ${val}
        END
    END

    RETURN                      ${clean_kwargs}


    # ══════════════════════════════════════════════════════════════════════════════
    # MAIN KEYWORD
    # ══════════════════════════════════════════════════════════════════════════════

Execute Agentic JSON Steps Stable
    [Documentation]             Iterates over AI-proposed JSON steps, executes each action sequence,
    ...                         and routes failures to the AI Surgeon.
    [Arguments]                 ${json_steps}
    ...                         ${user_intent}

    @{DESTRUCTIVE_TRIGGERS}=    Create List
    ...                         save                        next                        done                        submit                      confirm                 create    finish

    FOR                         ${index}                    ${step}                     IN ENUMERATE                @{json_steps}
        ${step_intent}=         Get From Dictionary         ${step}                     intent
        ${raw_strategies}=      Get From Dictionary         ${step}                     strategies                  default=${NONE}
        ${is_risky}=            Get From Dictionary         ${step}                     is_risky                    default=${False}

        Log To Console          \n🤖 Attempting Intent: ${step_intent}

        # ── NORMALIZATION PASS ───────────────────────────────────────────────
        ${strategies}=          Normalize Strategies        ${raw_strategies}

        ${step_passed}=         Set Variable                ${False}
        ${last_error}=          Set Variable                ${EMPTY}
        ${failure_mode}=        Set Variable                HARD_KEYWORD_ERROR

        # ── THE FALLBACK LOOP ────────────────────────────────────────────────
        FOR                     ${strategy_actions}         IN                          @{strategies}
            ${strategy_passed}=                             Set Variable                ${True}
            ${temp_passed_actions}=                         Create List

            # ── THE ACTION SEQUENCE LOOP ─────────────────────────────────────
            FOR                 ${raw_action}               IN                          @{strategy_actions}

            # ── NORMALIZATION PASS (action level) ────────────────────────
                ${action}=      Normalize Action            ${raw_action}

                ${action_is_none}=                          Evaluate                    $action is None
                IF              ${action_is_none}
                    ${strategy_passed}=                     Set Variable                ${False}
                    ${failure_mode}=                        Set Variable                HARD_KEYWORD_ERROR
                    ${last_error}=                          Catenate                    SEPARATOR=\n
                    ...         ${last_error}
                    ...         [Strategy failed] Unrecognisable action object skipped: ${raw_action}
                    Log To Console                          ↳ Unrecognisable action skipped. Marking strategy as failed.
                    BREAK
                END

                # FIX: Use scalar default=${NONE} — NEVER &{EMPTY} — to avoid
                # the "cannot be converted to Mapping" ValueError.
                # Normalize Action guarantees these keys exist, so Get From
                # Dictionary here is safe with a scalar fallback.
                ${keyword}=     Get From Dictionary         ${action}                   keyword
                ${args}=        Get From Dictionary         ${action}                   args                        default=${NONE}
                ${raw_kwargs}=                              Get From Dictionary         ${action}                   kwargs                      default=${NONE}

                # Guard: if args came back None (should not happen after Normalize Action,
                # but belt-and-suspenders), replace with an empty list.
                ${args_is_none}=                            Evaluate                    $args is None
                IF              ${args_is_none}
                    ${args}=    Create List
                END

                # ── KWARGS SANITIZATION ──────────────────────────────────────
                # Guard: if kwargs came back None or non-dict, replace with empty dict.
                ${kwargs_is_none}=                          Evaluate                    $raw_kwargs is None
                IF              ${kwargs_is_none}
                    ${raw_kwargs}=                          Create Dictionary
                END
                ${kwargs_is_dict}=                          Evaluate                    isinstance($raw_kwargs, dict)
                IF              not ${kwargs_is_dict}
                    ${raw_kwargs}=                          Create Dictionary
                END

                ${clean_kwargs}=                            Create Dictionary
                FOR             ${key}                      ${val}                      IN                          &{raw_kwargs}
                    ${is_bool}=                             Evaluate                    isinstance($val, bool)
                    IF          ${is_bool}
                        ${str_val}=                         Evaluate                    str($val)
                        Set To Dictionary                   ${clean_kwargs}             ${key}                      ${str_val}
                    ELSE
                        Set To Dictionary                   ${clean_kwargs}             ${key}                      ${val}
                    END
                END

                # ── XPATH ESCAPE: re-inject \= at dispatch time ──────────────
                ${escaped_args}=                            Create List
                FOR             ${arg}                      IN                          @{args}
                    ${is_str}=                              Evaluate                    isinstance($arg, str)
                    IF          ${is_str}
                        ${arg}=                             Evaluate                    JsonSanitizer.escape_xpath_arg($arg)
                    END
                    Append To List                          ${escaped_args}             ${arg}
                END

                # ── CAPTURE STATE BEFORE ACTION ──────────────────────────────
                ${url_before}=                              GetUrl
                Set To Dictionary                           ${action}                   url_before                  ${url_before}

                Log To Console                              ↳ Executing: ${keyword}
                ${status}       ${message}=                 Run Keyword And Ignore Error
                ...             ${keyword}                  @{escaped_args}             &{clean_kwargs}

                # ── CAPTURE STATE AFTER ACTION ───────────────────────────────
                ${url_after}=                               GetUrl
                Set To Dictionary                           ${action}                   url_after                   ${url_after}

                IF              '${status}' == 'PASS'

                # ── POST-ACTION SNAG CHECK ───────────────────────────────
                    ${is_destructive}=                      Set Variable                ${False}
                    FOR         ${arg}                      IN                          @{escaped_args}
                        ${arg_lower}=                       Evaluate                    str($arg).lower().strip()
                        ${trigger_hit}=                     Run Keyword And Return Status
                        ...     Should Contain              ${DESTRUCTIVE_TRIGGERS}     ${arg_lower}
                        IF      ${trigger_hit}
                            ${is_destructive}=              Set Variable                ${True}
                            BREAK
                        END
                    END

                    IF          ${is_destructive}
                        Log To Console                      🔍 Destructive action detected. Running Post-Action Snag Check...

                        UseModal                            Off

                        ${snag_found}=                      IsText                      We hit a snag               timeout=3s
                        ${review_found}=                    IsText                      Review the following fields                             timeout=2s
                        ${field_error}=                     IsElement
                        ...     xpath=//div[contains(@class,'slds-has-error')]
                        ...     timeout=2s
                        ${toast_error}=                     IsElement
                        ...     xpath=//*[contains(@class,'slds-theme_error')]
                        ...     timeout=2s

                        ${snag_detected}=                   Evaluate
                        ...     $snag_found or $review_found or $field_error or $toast_error

                        IF      ${snag_detected}
                            UseModal                        On

                            ${snag_detail}=                 Set Variable                ${EMPTY}
                            IF                              ${snag_found}
                                ${snag_detail}=             Set Variable                'We hit a snag' banner visible
                            ELSE IF                         ${review_found}
                                ${snag_detail}=             Set Variable                'Review the following fields' banner visible
                            ELSE IF                         ${field_error}
                                ${snag_detail}=             Set Variable                slds-has-error field element detected
                            ELSE IF                         ${toast_error}
                                ${snag_detail}=             Set Variable                slds-theme_error toast element detected
                            END

                            ${strategy_passed}=             Set Variable                ${False}
                            ${failure_mode}=                Set Variable                SILENT_APP_ERROR
                            ${last_error}=                  Set Variable
                            ...                             SILENT_APP_ERROR: ${snag_detail} after ${keyword} ${escaped_args}
                            Log To Console                  ❌ Snag detected: ${last_error}
                            BREAK
                        ELSE
                            Log To Console                  ✅ Snag Check passed. No error signals detected.
                        END
                    END

                    IF          ${strategy_passed}
                        Append To List                      ${temp_passed_actions}      ${action}
                    END

                ELSE
                    ${strategy_passed}=                     Set Variable                ${False}
                    ${failure_mode}=                        Set Variable                HARD_KEYWORD_ERROR
                    ${last_error}=                          Catenate                    SEPARATOR=\n
                    ...         ${last_error}
                    ...         [Strategy failed] ${keyword} → ${message}
                    Log To Console                          ↳ Strategy failed at ${keyword}: ${message}.
                    BREAK
                END
            END

            # ── DID THE ENTIRE STRATEGY COMPLETE SUCCESSFULLY? ───────────────
            IF                  ${strategy_passed}
                FOR             ${passed_action}            IN                          @{temp_passed_actions}
                    Append To Passed History                ${passed_action}
                    Append To Golden Path                   ${passed_action}
                END
                ${step_passed}=                             Set Variable                ${True}
                BREAK
            ELSE IF             '${failure_mode}' == 'SILENT_APP_ERROR'
                Log To Console                              ⛔ SILENT_APP_ERROR confirmed. Skipping all remaining fallback strategies.
                BREAK
            END
        END

        # ── ALL STRATEGIES FAILED: ROUTE TO SURGEON ──────────────────────────
        IF                      not ${step_passed}
            Append To Failed History                        ${step}
            Log To Console      ❌ All strategies failed for: ${step_intent}. Mode: ${failure_mode}. Pausing for Agentic Re-Prompt.
            RETURN              FAIL                        ${step}                     ${last_error}               ${index}                    ${failure_mode}
        END
    END

    RETURN                      PASS                        ${NONE}                     ${EMPTY}                    -1                          NONE




Get Agent ID By Name
    [Documentation]             Resolves a Copado AI assistant ID by its visible name within
    ...                         a given workspace utilizing our active persistent session.
    [Arguments]                 ${target_name}              ${workspace_id}
    ${WSPACE}=                  String.Strip String         ${workspace_id}

    Log To Console              Discovering assistants in workspace: ${WSPACE}

    # FIX: Route through the persistent session alias; headers are handled automatically
    ${workspace_detail_res}=    GET On Session
    ...                         alias=CopadoSession
    ...                         url=/organizations/${CLEAN_ORG}/workspaces/${WSPACE}
    ...                         expected_status=200
    ...                         timeout=90

    ${workspace_data}=          Set Variable                ${workspace_detail_res.json()}
    ${assistants_list}=         Set Variable                ${workspace_data['assistants']}
    ${TARGET_ASSISTANT_ID}=     Set Variable                knowledge

    FOR                         ${assistant}                IN                          @{assistants_list}
        Log To Console          Found Agent: ${assistant['visible_name']} (ID: ${assistant['id']})
        IF                      '${target_name}' in '${assistant['visible_name']}'
            ${TARGET_ASSISTANT_ID}=                         Set Variable                ${assistant['id']}
            Log To Console      Target matched! Using Assistant ID: ${TARGET_ASSISTANT_ID}
            BREAK
        END
    END

    Log To Console              Resolved Assistant ID: ${TARGET_ASSISTANT_ID}
    RETURN                      ${TARGET_ASSISTANT_ID}


Wait Until Dialogue Is Idle
    [Documentation]             Polls the dialogue state endpoint until the thread reports it is no
    ...                         longer actively processing a message. This prevents 403 deadlocks
    ...                         caused by POSTing a new message to a thread that is still streaming
    ...                         a prior AI response.
    ...
    ...                         Polls every ${poll_interval} seconds up to ${max_attempts} times.
    ...                         Raises a clear error if the thread does not become idle in time.
    [Arguments]                 ${max_attempts}=12          ${poll_interval}=5s

    Log To Console              ⏳ Waiting for dialogue ${DIALOGUE_ID} to become idle...

    FOR                         ${attempt}                  IN RANGE                    1                           ${max_attempts} + 1
        ${dial_res}=            GET On Session
        ...                     alias=CopadoSession
        ...                     url=/organizations/${CLEAN_ORG}/dialogues/${DIALOGUE_ID}
        ...                     expected_status=any
        ...                     timeout=30

        ${dial_data}=           Set Variable                ${dial_res.json()}

        # The API exposes a 'status' or 'is_processing' field on the dialogue object.
        # We check both known field shapes defensively.
        ${status}=              Get From Dictionary         ${dial_data}                status                      default=unknown
        ${is_processing}=       Get From Dictionary         ${dial_data}                is_processing               default=${False}

        Log To Console          [Attempt ${attempt}/${max_attempts}] Dialogue status: '${status}' | is_processing: ${is_processing}

        # Treat the thread as idle if status is not an active/processing value
        # AND is_processing is not True.
        ${status_is_active}=    Run Keyword And Return Status
        ...                     Should Be True
        ...                     '${status}' in ['processing', 'active', 'streaming', 'running']

        IF                      not ${status_is_active} and not ${is_processing}
            Log To Console      ✅ Dialogue is idle. Proceeding after attempt ${attempt}.
            RETURN
        END

        Log To Console          🔄 Thread still active. Waiting ${poll_interval} before retry...
        Sleep                   ${poll_interval}
    END

    # If we exhausted all attempts, fail with a clear diagnostic message.
    Fail
    ...                         TIMEOUT: Dialogue ${DIALOGUE_ID} did not become idle after ${max_attempts} attempts.
    ...                         Last known status: '${status}' | is_processing: ${is_processing}.
    ...                         The prior AI response may still be streaming. Increase max_attempts or poll_interval.

Extract And Sanitize Robot Script
    [Documentation]             Extracts a clean, executable Robot Framework script from the AI reply.
    [Arguments]                 ${ai_final_reply}

    # ── Prong 1: Structured artifact path ────────────────────────────────────
    ${final_robot_script}=      Set Variable                ${NONE}

    ${is_list}=                 Evaluate                    isinstance($ai_final_reply, list)
    IF                          ${is_list}
        FOR                     ${item}                     IN                          @{ai_final_reply}
            ${has_artifact}=    Run Keyword And Return Status
            ...                 Dictionary Should Contain Key                           ${item}                     artifact
            IF                  ${has_artifact}
                ${artifact}=    Get From Dictionary         ${item}                     artifact
                IF              $artifact != $NONE and $artifact.get('language') == 'robot'
                    ${final_robot_script}=                  Get From Dictionary         ${item}                     text
                    Log To Console                          Prong 1 matched: structured artifact block found.
                    BREAK
                END
            END
        END

        # Prong 1 secondary: look for raw *** Settings *** marker in text values
        IF                      $final_robot_script == $NONE
            FOR                 ${item}                     IN                          @{ai_final_reply}
                ${text_val}=    Get From Dictionary         ${item}                     text
                IF              '*** Settings ***' in $text_val
                    ${final_robot_script}=                  Set Variable                ${text_val}
                    Log To Console                          Prong 1 secondary matched: Settings block found in text.
                    BREAK
                END
            END
        END
    END

    # ── Prong 2: Plain string markdown fence extraction ───────────────────────
    IF                          $final_robot_script == $NONE
        Log To Console          Prong 2 activated: attempting markdown fence extraction.
        ${cropped_left}=        Fetch From Right            ${ai_final_reply}           \`\`\`robot
        ${final_robot_script}=                              Fetch From Left             ${cropped_left}             \`\`\`
        ${final_robot_script}=                              Strip String                ${final_robot_script}
        Log To Console          Prong 2 extracted script block.
    END

    Log To Console              Raw extracted script:
    Log To Console              ${final_robot_script}

    # ── State machine sanitization loop ──────────────────────────────────────
    @{script_lines}=            Split To Lines              ${final_robot_script}
    ${cleaned_steps_list}=      Create List
    ${inside_test_cases}=       Set Variable                ${FALSE}
    ${passed_title_line}=       Set Variable                ${FALSE}

    FOR                         ${raw_line}                 IN                          @{script_lines}
        ${line}=                Strip String                ${raw_line}
        ${line}=                Replace String              ${line}                     \r                          ${EMPTY}

        # Skip empty lines and pure comments
        IF                      $line == "" or $line.startswith('#')
            CONTINUE
        END

        # Detect the Test Cases section boundary
        IF                      '*** Test Cases ***' in $line
            ${inside_test_cases}=                           Set Variable                ${TRUE}
            CONTINUE
        END

        IF                      ${inside_test_cases}
        # Skip any other structural section headers encountered inside
            IF                  $line.startswith('*')
                CONTINUE
            END

            # Skip the test case title line (first non-bracket, non-empty line)
            IF                  ${passed_title_line} == ${FALSE}
                IF              $line.startswith('[')
                    CONTINUE
                END
                ${passed_title_line}=                       Set Variable                ${TRUE}
                CONTINUE
            END

            # Skip inline test case settings (e.g. [Documentation], [Tags])
            IF                  $line.startswith('[')
                CONTINUE
            END

            # Skip suite/library/resource configuration lines
            IF                  $line.startswith('Library') or $line.startswith('Resource') or $line.startswith('Suite')
                CONTINUE
            END

            # Everything that falls through is a clean, executable step
            Append To List      ${cleaned_steps_list}       ${line}
        END
    END

    Log To Console              Sanitized steps to be executed:
    FOR                         ${step}                     IN                          @{cleaned_steps_list}
        Log To Console          -> ${step}
    END

    RETURN                      ${cleaned_steps_list}

DiscoverCopadoAIWorkspaces
    ${API_KEY}=                 String.Strip String         ${CopadoAIApi}
    ${ORG}=                     String.Strip String         ${ORG_ID}
    ${WSPACE}=                  String.Strip String         ${WORKSPACE_ID}
    Log To Console              ${API_KEY}
    ${headers}=                 Create Dictionary
    ...                         accept=application/json
    ...                         Content-Type=application/json
    ...                         X-Authorization=${API_KEY}

    ${list_res}=                RequestsLibrary.GET
    ...                         url=https://copadogpt-api.robotic.copado.com/organizations/${ORG}/workspaces
    ...                         headers=${headers}
    ...                         expected_status=200
    ...                         timeout=90

    Log To Console              workspaces available: ${list_res}









Compile Golden Path Script
    [Documentation]             Translates the JSON Golden Path into a pure Robot Framework script.
    ...                         Logs to console for Live Testing and writes to a .robot file.

    ${script_content}=          Set Variable                *** Test Cases ***\nAgentic Generated Test\n

    FOR                         ${action}                   IN                          @{GOLDEN_PATH_SCRIPT}
        ${keyword}=             Get From Dictionary         ${action}                   keyword
        ${args}=                Get From Dictionary         ${action}                   args                        default=${NONE}
        ${raw_kwargs}=          Get From Dictionary         ${action}                   kwargs                      default=${NONE}

        # FIX: Guard args — never use @{EMPTY} as a default in Get From Dictionary.
        ${args_is_none}=        Evaluate                    $args is None
        IF                      ${args_is_none}
            ${args}=            Create List
        END

        # FIX: Guard kwargs — never use &{EMPTY} as a default in Get From Dictionary.
        ${kwargs_is_none}=      Evaluate                    $raw_kwargs is None
        IF                      ${kwargs_is_none}
            ${raw_kwargs}=      Create Dictionary
        END
        ${kwargs_is_dict}=      Evaluate                    isinstance($raw_kwargs, dict)
        IF                      not ${kwargs_is_dict}
            ${raw_kwargs}=      Create Dictionary
        END

        # Add 4 spaces for Robot Framework indentation
        ${step_string}=         Set Variable                \ \ \ \ ${keyword}

        FOR                     ${arg}                      IN                          @{args}
            ${step_string}=     Catenate                    SEPARATOR=${SPACE}${SPACE}${SPACE}${SPACE}
            ...                 ${step_string}              ${arg}
        END

        FOR                     ${key}                      ${val}                      IN                          &{raw_kwargs}
            ${step_string}=     Catenate                    SEPARATOR=${SPACE}${SPACE}${SPACE}${SPACE}
            ...                 ${step_string}              ${key}=${val}
        END

        ${script_content}=      Catenate                    SEPARATOR=\n                ${script_content}           ${step_string}
    END

    Log To Console              🌟 COMPILED GOLDEN PATH SCRIPT 🌟
    Log To Console              Script: ${script_content}

    ${ts}=                      Get Time                    format=%Y%m%d_%H%M%S
    ${file_path}=               Set Variable                ${OUTPUT_DIR}/Agentic_Golden_Path_${ts}.robot
    Create File                 ${file_path}                ${script_content}
    Log To Console              💾 Backup saved to: ${file_path}

    RETURN                      ${script_content}





Extract Agent JSON Reply
    [Documentation]             Parses the architect's bare array reply from the last AI message.
    [Arguments]                 ${ai_reply}

    # ── PRE-PARSE DIAGNOSTICS ─────────────────────────────────────────────
    ${reply_type}=              Evaluate                    type($ai_reply).__name__
    Log To Console              [Extract Agent JSON Reply] input type: ${reply_type}

    ${is_list}=                 Evaluate                    isinstance($ai_reply, list)
    IF                          ${is_list}
        ${item_count}=          Evaluate                    len($ai_reply)
        Log To Console          [Extract Agent JSON Reply] content list item count: ${item_count}
        FOR                     ${idx}                      ${item}                     IN ENUMERATE                @{ai_reply}
            ${item_type}=       Evaluate                    type($item).__name__
            ${item_preview}=    Evaluate                    repr($item)[:300]
            Log To Console      [Extract Agent JSON Reply] item[${idx}] type=${item_type} | ${item_preview}
        END
    ELSE
        ${reply_preview}=       Evaluate                    repr($ai_reply)[:300]
        Log To Console          [Extract Agent JSON Reply] raw value preview: ${reply_preview}
    END
    # ── END DIAGNOSTICS ───────────────────────────────────────────────────

    ${parsed}=                  Evaluate                    AgentJsonParser.parse_architect_reply($ai_reply)

    # FIX: Pre-evaluate len() into a variable before logging.
    ${step_count}=              Evaluate                    len($parsed)
    Log To Console              [Extract Agent JSON Reply] parse succeeded | steps=${step_count}
    RETURN                      ${parsed}


Extract Surgeon JSON Reply
    [Documentation]             Parses the surgeon's dict reply from the last AI message.
    ...                         v5 FIX: ${list($parsed.keys())} inline interpolation replaced
    ...                         with a dedicated Evaluate step. RF cannot resolve built-in
    ...                         Python functions like list() inside ${...} variable syntax.
    [Arguments]                 ${ai_reply}

    # ── PRE-PARSE DIAGNOSTICS ─────────────────────────────────────────────
    ${reply_type}=              Evaluate                    type($ai_reply).__name__
    Log To Console              [Extract Surgeon JSON Reply] input type: ${reply_type}

    ${is_list}=                 Evaluate                    isinstance($ai_reply, list)
    IF                          ${is_list}
        ${item_count}=          Evaluate                    len($ai_reply)
        Log To Console          [Extract Surgeon JSON Reply] content list item count: ${item_count}
        FOR                     ${idx}                      ${item}                     IN ENUMERATE                @{ai_reply}
            ${item_type}=       Evaluate                    type($item).__name__
            ${item_preview}=    Evaluate                    repr($item)[:300]
            Log To Console      [Extract Surgeon JSON Reply] item[${idx}] type=${item_type} | ${item_preview}
        END
    ELSE
        ${reply_preview}=       Evaluate                    repr($ai_reply)[:300]
        Log To Console          [Extract Surgeon JSON Reply] raw value preview: ${reply_preview}
    END
    # ── END DIAGNOSTICS ───────────────────────────────────────────────────

    ${parsed}=                  Evaluate                    AgentJsonParser.parse_surgeon_reply($ai_reply)

    # FIX: Pre-evaluate list($parsed.keys()) into a variable before logging.
    # RF resolves ${list(...)} as a variable lookup for ${list}, not a Python call.
    ${parsed_keys}=             Evaluate                    list($parsed.keys())
    Log To Console              [Extract Surgeon JSON Reply] parse succeeded | keys=${parsed_keys}
    RETURN                      ${parsed}






    #######Step Returns#####

    # ════════════════════════════════════════════════════════════════════
    # AGENTIC STEP TRACKING - Getters, Setters, and Appenders
    # ════════════════════════════════════════════════════════════════════

Get All Proposed Steps
    [Documentation]             Returns the full list of every step the AI has suggested so far.
    RETURN                      @{ALL_PROPOSED_STEPS}

Get Execution History Passed
    [Documentation]             Returns the list of steps that executed without throwing a CRT error.
    RETURN                      @{EXECUTION_HISTORY_PASSED}

Get Execution History Failed
    [Documentation]             Returns the list of steps that threw a CRT error during execution.
    RETURN                      @{EXECUTION_HISTORY_FAILED}

Get Golden Path Script
    [Documentation]             Returns the final optimized sequence to be saved as the real test asset.
    RETURN                      @{GOLDEN_PATH_SCRIPT}

    # ── Appenders (used internally by the execution engine) ─────────────

Append To Proposed Steps
    [Documentation]             Adds a single step entry to ALL_PROPOSED_STEPS at suite scope.
    [Arguments]                 ${step}
    Append To List              ${ALL_PROPOSED_STEPS}       ${step}
    Set Suite Variable          @{ALL_PROPOSED_STEPS}       @{ALL_PROPOSED_STEPS}

Append To Passed History
    [Documentation]             Records a step that passed execution into EXECUTION_HISTORY_PASSED.
    [Arguments]                 ${step}
    Append To List              ${EXECUTION_HISTORY_PASSED}                             ${step}
    Set Suite Variable          @{EXECUTION_HISTORY_PASSED}                             @{EXECUTION_HISTORY_PASSED}

Append To Failed History
    [Documentation]             Records a step that failed execution into EXECUTION_HISTORY_FAILED.
    [Arguments]                 ${step}
    Append To List              ${EXECUTION_HISTORY_FAILED}                             ${step}
    Set Suite Variable          @{EXECUTION_HISTORY_FAILED}                             @{EXECUTION_HISTORY_FAILED}

Append To Golden Path
    [Documentation]             Adds a confirmed optimized step to the GOLDEN_PATH_SCRIPT.
    [Arguments]                 ${step}
    Append To List              ${GOLDEN_PATH_SCRIPT}       ${step}
    Set Suite Variable          @{GOLDEN_PATH_SCRIPT}       @{GOLDEN_PATH_SCRIPT}

    # ── Full list setters (for bulk replacement, e.g. after AI reply parsing) ──

Set All Proposed Steps
    [Documentation]             Replaces ALL_PROPOSED_STEPS entirely with a new list.
    [Arguments]                 @{steps}
    Set Suite Variable          @{ALL_PROPOSED_STEPS}       @{steps}

Set Golden Path Script
    [Documentation]             Replaces GOLDEN_PATH_SCRIPT entirely with a new list.
    [Arguments]                 @{steps}
    Set Suite Variable          @{GOLDEN_PATH_SCRIPT}       @{steps}

Generate Initial Test Steps Stable
    [Documentation]             Compiles system formatting rules and user intent
    ...                         and dispatches via the stable connection layout.
    [Arguments]                 ${assistant_id}             ${user_intent}

    ${system_rules}=            Generate Agentic System Prompt

    ${final_architect_prompt}=  Catenate                    SEPARATOR=\n
    ...                         ${system_rules}
    ...
    ...                         ════════════════════════════════════════════
    ...                         USER INTENT FOR THIS SCENARIO:
    ...                         ════════════════════════════════════════════
    ...                         ${user_intent}
    ...
    ...                         Generate the bare JSON array now.
    # Execute utilizing the stable transport configuration
    Send Message To Agent Stable                            ${assistant_id}             ${final_architect_prompt}
    Sleep                       10s
    ${ai_reply}=                Retrieve Agent Reply Stable
    ${parsed_steps}=            Extract Agent JSON Reply    ${ai_reply}
    Set All Proposed Steps      @{parsed_steps}
    RETURN                      ${ai_reply}


Resolve Step Failure Stable
    [Documentation]             Recovers from a failed agentic step by recycling the hot conversation thread,
    ...                         attaching a live DOM snapshot, and executing an intent-aware multimodal repair prompt.
    [Arguments]                 ${assistant_id}
    ...                         ${failed_step}
    ...                         ${error_message}
    ...                         ${remaining_steps}
    ...                         ${dom_json_path}
    ...                         ${screenshot_path}
    ...                         ${executed_history_json}
    ...                         ${user_intent}
    ...                         ${failure_mode}=HARD_KEYWORD_ERROR

    # ── STEP 1: Preserve original thread ID for tracking purposes ─────────────
    ${ORIGINAL_DIALOGUE_ID}=    Set Variable                ${DIALOGUE_ID}
    Log To Console              🔒 Reusing hot conversation thread container context: ${ORIGINAL_DIALOGUE_ID}

    # ── STEP 2: Stream the text-based DOM blueprint into the RAG engine ──────
    Log To Console              🏥 Uploading live DOM snapshot to shared dialogue stream...
    ${attached_file_name}=      Attach Document To Dialogue Stable                      ${dom_json_path}

    # ── STEP 3: Build a clean human-readable summary of the failed step ─────
    ${failed_intent}=           Get From Dictionary         ${failed_step}              intent                      default=unknown
    ${failed_strategies}=       Get From Dictionary         ${failed_step}              strategies                  default=@{EMPTY}
    ${rep_keyword}=             Set Variable                unknown
    ${rep_args_str}=            Set Variable                (none)
    ${rep_kwargs_str}=          Set Variable                (none)

    ${rep_action}=              Evaluate
    ...                         AgentJsonParser.extract_first_action_from_step($failed_step)

    ${rep_action_is_none}=      Evaluate                    $rep_action is None
    IF                          ${rep_action_is_none}
        ${rep_keyword}=         Set Variable                unknown
        ${rep_args_str}=        Set Variable                (none)
        ${rep_kwargs_str}=      Set Variable                (none)
    ELSE
        ${rep_keyword}=         Get From Dictionary         ${rep_action}               keyword
        ${rep_args}=            Get From Dictionary         ${rep_action}               args
        ${rep_kwargs}=          Get From Dictionary         ${rep_action}               kwargs
        ${rep_args_str}=        Evaluate                    ', '.join(str(a) for a in $rep_args)
        ${rep_kwargs_raw}=      Evaluate                    ', '.join(f"{k}={v}" for k, v in $rep_kwargs.items())
        IF                      '${rep_kwargs_raw}' != ''
            ${rep_kwargs_str}=                              Set Variable                ${rep_kwargs_raw}
        ELSE
            ${rep_kwargs_str}=                              Set Variable                (none)
        END
    END


    # ── STEP 4: Build a clean numbered list of remaining steps ──────────────
    @{remaining_lines}=         Create List
    ${step_num}=                Set Variable                ${1}

    FOR                         ${rem_step}                 IN                          @{remaining_steps}
        ${rem_strategies}=      Get From Dictionary         ${rem_step}                 strategies                  default=@{EMPTY}
        ${rem_has_strats}=      Evaluate                    len($rem_strategies) > 0
        IF                      ${rem_has_strats}
            ${rem_first}=       Get From List               ${rem_strategies}           0
            ${rem_has_acts}=    Evaluate                    len($rem_first) > 0
            IF                  ${rem_has_acts}
                ${rem_action}=                              Get From List               ${rem_first}                0
                ${rem_kw}=      Get From Dictionary         ${rem_action}               keyword                     default=unknown
                ${rem_args}=    Get From Dictionary         ${rem_action}               args                        default=@{EMPTY}
                ${rem_kwargs}=                              Get From Dictionary         ${rem_action}               kwargs                      default=&{EMPTY}
                ${rem_args_str}=                            Evaluate                    ', '.join(str(a) for a in $rem_args)
                ${rem_kwa_raw}=                             Evaluate                    ', '.join(f"{k}={v}" for k, v in $rem_kwargs.items())
                IF              '${rem_kwa_raw}' != ''
                    ${rem_kwa_suffix}=                      Set Variable                ${rem_kwa_raw}
                ELSE
                    ${rem_kwa_suffix}=                      Set Variable                ${EMPTY}
                END
                ${step_prefix}=                             Catenate                    SEPARATOR=.${SPACE}         ${step_num}                 ${rem_kw}
                IF              '${rem_kwa_suffix}' != '${EMPTY}'
                    ${rem_line}=                            Catenate
                    ...         SEPARATOR=${SPACE}${SPACE}${SPACE}${SPACE}
                    ...         ${step_prefix}              ${rem_args_str}             ${rem_kwa_suffix}
                ELSE
                    ${rem_line}=                            Catenate
                    ...         SEPARATOR=${SPACE}${SPACE}${SPACE}${SPACE}
                    ...         ${step_prefix}              ${rem_args_str}
                END
                Append To List                              ${remaining_lines}          ${rem_line}
            END
        END
        ${step_num}=            Evaluate                    ${step_num} + 1
    END

    ${remaining_readable}=      Catenate                    SEPARATOR=\n                @{remaining_lines}

    # ── STEP 5: Build the failure-mode context block ─────────────────────────
    ${failure_context}=         Set Variable                ${EMPTY}

    IF                          '${failure_mode}' == 'SILENT_APP_ERROR'
          ${failure_context}=     Catenate                    SEPARATOR=\n
        ...                     FAILURE MODE: SILENT_APP_ERROR
        ...                     The QWord executed without error, but a post-action snag check detected
        ...                     a Salesforce validation signal after the destructive action completed.
        ...                     The browser is still on the SAME FORM. The record was NOT saved.
        ...                     DETECTED SIGNAL: ${error_message}
    ELSE
        ${failure_context}=     Catenate                    SEPARATOR=\n
        ...                     FAILURE MODE: HARD_KEYWORD_ERROR
        ...                     A QWord threw an exception. The action did not complete.
        ...                     ERROR THROWN: ${error_message}
    END

    # ── STEP 6: Build and send the surgeon prompt ────────────────────────────
    ${surgeon_prompt}=          Catenate                    SEPARATOR=\n
    ...                         ════════════════════════════════════════════
    ...                         ORIGINAL TEST INTENT:
    ...                         ════════════════════════════════════════════
    ...                         ${user_intent}
    ...
    ...                         ════════════════════════════════════════════
    ...                         FAILURE CLASSIFICATION:
    ...                         ════════════════════════════════════════════
    ...                         ${failure_context}
    ...
    ...                         ════════════════════════════════════════════
    ...                         FAILED STEP SUMMARY:
    ...                         ════════════════════════════════════════════
    ...                         Step Intent : ${failed_intent}
    ...                         Keyword     : ${rep_keyword}
    ...                         Args        : ${rep_args_str}
    ...                         Kwargs      : ${rep_kwargs_str}
    ...                         All strategies for this step were exhausted before the surgeon was called.
    ...
    ...                         ════════════════════════════════════════════
    ...                         LIVE DOM FILE:
    ...                         ════════════════════════════════════════════
    ...                         File name: ${attached_file_name}
    ...
    ...                         ════════════════════════════════════════════
    ...                         HISTORICAL EXECUTION AUDIT TRAIL (PASSED STEPS):
    ...                         ════════════════════════════════════════════
    ...                         ${executed_history_json}
    ...
    ...                         ════════════════════════════════════════════
    ...                         REMAINING PLANNED STEPS:
    ...                         ════════════════════════════════════════════
    ...                         ${remaining_readable}
    ...
    ...                         ════════════════════════════════════════════
    ...                         YOUR MISSION:
    ...                         ════════════════════════════════════════════
    ...                         Refer to the SelfHealing workspace document for your full Surgeon rules,
    ...                         the Full Horizon Scan protocol, failure mode playbooks, output schema,
    ...                         and anti-patterns. That document is your single source of truth.
    ...
    ...                         Understand that the blue highlights on the screen ARENT indicators for you to reference. Rather, this is a live test from CRT and those steps have performed. If nothing matches the intent from what the users step was trying to accomplish, you MUST escalate
    ...
    ...                         Using the failure classification, DOM file, screenshot, audit trail,
    ...                         and remaining steps above, produce your corrected JSON output now.
    ...                         Output ONLY the raw JSON object. No markdown, no prose, no explanation.

    # ── STEP 7: Dispatch the combined instructions and screenshot image turn ──
    Send Multimodal Message To Agent Stable                 ${assistant_id}             ${surgeon_prompt}           ${screenshot_path}
    ${ai_reply}=                Retrieve Agent Reply Stable

    # ── STEP 8: Record surgeon-proposed corrections ──────────────────────────
    ${surgeon_payload}=         Extract Surgeon JSON Reply                              ${ai_reply}

    ${recovery}=                Get From Dictionary         ${surgeon_payload}          recovery_steps
    ${corrected}=               Get From Dictionary         ${surgeon_payload}          corrected_steps

    FOR                         ${step}                     IN                          @{recovery}
        Append To Proposed Steps                            ${step}
    END

    FOR                         ${step}                     IN                          @{corrected}
        Append To Proposed Steps                            ${step}
    END

    Log To Console              🏁 Multimodal Surgeon adjustments compiled successfully over connection.
    RETURN                      ${ai_reply}

Generate Agentic System Prompt
     [Documentation]             Defines the Architect phase system prompt.
    ...                         Full rules and schema are defined in the AgenticTesting workspace document.
    ${rules}=                   Catenate                    SEPARATOR=\n
    ...                         You are an AI Test Agent operating Copado Robotic Testing (CRT) via QWeb and QForce.
    ...                         Your role in this phase is the ARCHITECT.
    ...
    ...                         Refer to the AgenticTesting workspace document for your full rules, schema format,
    ...                         and anti-patterns. That document is your single source of truth for this phase.
    ...
    ...                         Key constraints to remember:
    ...                         - You have NO live DOM context. Do not invent locators or backup strategies.
    ...                         - Output ONLY a bare JSON array. No markdown, no prose, no explanation.
    ...                         - The browser is already authenticated and idle at the Salesforce home page.
    ...                         - Do NOT include login or authentication steps.
    RETURN                      ${rules}