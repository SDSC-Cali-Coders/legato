# X-Gitlab-Token sent in header to validate recieved payloads
# Will be injected in pipeline, manually set for local terminal testing
if (-not $env:X_GITLAB_TOKEN) {
    $tokenFilePath      = "$(git rev-parse --show-toplevel)/.gitlab/scripts/token2.txt";
    $env:X_GITLAB_TOKEN = Get-Content $tokenFilePath;
}

# Attempting to define the type of data received from Gitlab requests
class WebhookUser {
    [ValidateNotNullOrEmpty()][int]$id
    [ValidateNotNullOrEmpty()][string]$name
    [ValidateNotNullOrEmpty()][string]$username
    [ValidateNotNullOrEmpty()][string]$avatar_url
    [ValidateNotNullOrEmpty()][string]$email
}
class WebhookProject {
    [ValidateNotNullOrEmpty()][int]$id
    [ValidateNotNullOrEmpty()][string]$name
    [ValidateNotNullOrEmpty()][string]$description
    [ValidateNotNullOrEmpty()][string]$web_url
    [string]$avatar_url
    [ValidateNotNullOrEmpty()][string]$git_ssh_url
    [ValidateNotNullOrEmpty()][string]$git_http_url
    [ValidateNotNullOrEmpty()][string]$namespace
    [ValidateNotNullOrEmpty()][int]$visibility_level
    [ValidateNotNullOrEmpty()][string]$path_with_namespace
    [ValidateNotNullOrEmpty()][string]$default_branch
    [ValidateNotNullOrEmpty()][string]$homepage
    [ValidateNotNullOrEmpty()][string]$url
    [ValidateNotNullOrEmpty()][string]$ssh_url
    [ValidateNotNullOrEmpty()][string]$http_url
}
class WebhookRepository {
    [ValidateNotNullOrEmpty()][string]$name
    [ValidateNotNullOrEmpty()][string]$url
    [ValidateNotNullOrEmpty()][string]$description
    [ValidateNotNullOrEmpty()][string]$homepage
}
class WebhookObjectAttributes {
    [ValidateNotNullOrEmpty()][int]$id
    [ValidateNotNullOrEmpty()][int]$iid
    [ValidateNotNullOrEmpty()][string]$target_branch
    [ValidateNotNullOrEmpty()][string]$source_branch
    [ValidateNotNullOrEmpty()][int]$source_project_id
    [ValidateNotNullOrEmpty()][int]$author_id
    [ValidateNotNullOrEmpty()][int]$assignee_id
    [ValidateNotNullOrEmpty()][string]$title
    [ValidateNotNullOrEmpty()][string]$created_at
    [ValidateNotNullOrEmpty()][string]$updated_at
    [int]$milestone_id
    [ValidateNotNullOrEmpty()][string]$state
    [ValidateNotNullOrEmpty()][bool]$blocking_discussions_resolved
    [ValidateNotNullOrEmpty()][bool]$work_in_progress
    [ValidateNotNullOrEmpty()][bool]$first_contribution
    [ValidateNotNullOrEmpty()][string]$merge_status
    [ValidateNotNullOrEmpty()][int]$target_project_id
    [string]$description
    [ValidateNotNullOrEmpty()][string]$url
    $source
    $target
    $last_commit
    $labels
    [ValidateNotNullOrEmpty()][string]$action
    $assignee
}
class GitlabWebhookEvent {
    [ValidateNotNullOrEmpty()][string]$object_kind
    [ValidateNotNullOrEmpty()][string]$event_type
    [ValidateNotNullOrEmpty()][WebhookUser]$user
    [ValidateNotNullOrEmpty()][WebhookProject]$project
    [ValidateNotNullOrEmpty()][WebhookRepository]$repository
    [ValidateNotNullOrEmpty()][WebhookObjectAttributes]$object_attributes
    $labels
    $changes
}

function Start-Listener {
    Param (
        [string[]]
        $Prefixes = 'http://localhost:5000/'
    )

    # Write callbacks to handle each endpoint
    Begin {
        # Call generic callback w/ {message='Goodbye!'} as the message
        $endCallback = {
            Param (
                [Parameter(Mandatory)]
                [System.Net.HttpListenerResponse]
                $response
            )

            $generalCallBack.Invoke($response, (@{message='Goodbye!'} | ConvertTo-Json));
        };

        # Generates and encodes a response from a JSON respBody
        $generalCallBack = {
            Param (
                [Parameter(Mandatory)]
                [System.Net.HttpListenerResponse]
                $response,

                [Parameter(Mandatory)]
                [string]
                $respBody = (@{message='Hello World'} | ConvertTo-Json),

                [int]
                $StatusCode = 200,

                [ValidateSet('application/json', 'html/text')]
                [string]
                $ContentType = 'application/json'
            )

            # Set StatusCode and ContentType to 200 (Success) and application/json respectively
            $response.StatusCode    = $StatusCode;
            $response.ContentType   = $ContentType;

            # Encode JSON response in bytes and write to output stream (w/ proper length settings etc.)
            [byte[]] $respBuffer    = [System.Text.Encoding]::UTF8.GetBytes($respBody);

            $response.ContentLength64 = $respBuffer.Length;
            $response.OutputStream.Write($respBuffer, 0, $respBuffer.Length);

            # Close the output stream afterwards
            $response.OutputStream.Close();
        };

        # Call the generic callback w/ the request header (JSON) & body as the message
        $parrotCallback = {
            Param (
                [Parameter(Mandatory)]
                [System.Net.HttpListenerResponse]
                $response,

                [Parameter(Mandatory)]
                [System.Net.HttpListenerRequest]
                $request,

                [string]
                $requestBody
            )

            $respBody = @{};
            $request.Headers.AllKeys | ForEach-Object { 
                $respBody.Add($_, $request.Headers.Get($_));
            }

            $respBody.Add('Request-Body', $requestBody);

            $generalCallBack.Invoke($response, ($respBody | ConvertTo-Json))
        }

        # Callback to handle Gitlab webhooks triggered by events
        $webhookCallback = {
            Param (
                [Parameter(Mandatory)]
                [System.Net.HttpListenerResponse]
                $response,

                [Parameter(Mandatory)]
                [System.Net.HttpListenerRequest]
                $request,

                [Parameter(Mandatory)]
                [string]
                $requestBody
            )

            # Validate payload by checking X-Gitlab-Token in the HTTP Headers
            if ($request.Headers.AllKeys -notcontains 'X-Gitlab-Token') {
                $generalCallBack.Invoke($response, (@{error='unauthorized - missing X-Gitlab-Token'} | ConvertTo-Json), 401);
                return;
            } elseif ($request.Headers.Get('X-Gitlab-Token') -ne $env:X_GITLAB_TOKEN) {
                $generalCallBack.Invoke($response, (@{error='forbidden - wrong X-Gitlab-Token'} | ConvertTo-Json), 403);
                return;
            }

            # Next, parse the payload
            try {
                $payload = ($requestBody | ConvertFrom-Json);

                # For testing: just send the payload back
                # $generalCallBack.Invoke($response, $requestBody);

                # Logic to filter out any non-approval events
                if ($payload.event_type -eq 'merge_request' -and $payload.object_attributes.action -eq 'approved') {
                    $generalCallBack.Invoke($response, (@{mesg='Approval event captured!'} | ConvertTo-Json));
                } else {
                    $generalCallBack.Invoke($response, (@{mesg='Skipping non-approval event'} | ConvertTo-Json));
                }

            }
            catch {
                $generalCallBack.Invoke($response, (@{error='bad request - failed to parse the payload from JSON form'} | ConvertTo-Json), 400);
            }
        }
    }

    Process {
        # Instantiate a listener on provided prefixes
        $httpListener = [System.Net.HttpListener]::new();

        # Process and add all provided prefixes to listener
        $Prefixes | ForEach-Object { 
            $prefix = $_;
            if ($prefix.Length -and -not $prefix.EndsWith('/')){
                $prefix += '/';
            }
            $httpListener.Prefixes.Add($prefix);
        }

        $httpListener.Start()

        while ($httpListener.IsListening) {
            # Synchronously wait for a request with BeginGetContext
            [System.Net.HttpListenerContext]$context    = $httpListener.GetContext();

            # Obtain request (to perform parsing on)
            # Construct a response (usually with logic involving parsed request)
            [System.Net.HttpListenerRequest]$request    = $context.Request;
            [System.Net.HttpListenerResponse]$response  = $context.Response;

            # Log request info + body to console
            [string]$requestBody = [System.IO.StreamReader]::new($request.InputStream).ReadToEnd();
            Write-Output ("{0} - {1}:`n{2}`n" -f
                            $request.HttpMethod,
                            $request.Url,
                            $requestBody);

            # Handle stopping the listener with an "/end" endpoint w/ regex matching
            switch -Regex ($request.Url) {
                '/end$' {
                    $endCallback.Invoke($response);
                    $httpListener.Stop();
                }
                '/webhook$' {
                    $webhookCallback.Invoke($response, $request, $requestBody);
                }
                '/parrot$' {
                    $parrotCallback.Invoke($response, $request, $requestBody);
                }
                Default {
                    $generalCallBack.Invoke($response, (@{error=('not found - unrecognized endpoint [{0}]' -f $request.Url.LocalPath)} | ConvertTo-Json), 404)
                }
            }
        }
    }
}

Export-ModuleMember -Function Start-Listener;