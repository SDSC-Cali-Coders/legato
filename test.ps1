Import-Module ./.gitlab/modules/GitLabAPI.psm1; 
Get-MergeRequests -iid $env:MERGE_IID;
Invoke-MergeAction -iid $env:MERGE_IID;