function password = keyboardInteractiveCallback(promptMessage)
%KEYBOARDINTERACTIVECALLBACK Secure SSH keyboard-interactive prompt.
%
% Bridge and Mirror activate a saved credential context before constructing
% the SSH client.  Refuse callbacks outside that context instead of opening
% an unexpected password dialog during an automated job operation.

promptMessage = string(promptMessage);
context = kssolv.services.remote.security.MfaCredentialContext.shared();
if context.isActive()
    password = char(context.response(promptMessage));
    return
end
error("KSSOLV:Remote:MfaAuthenticationNotActive", ...
    "No saved multifactor authentication context is active for the " + ...
    "SSH prompt: %s", promptMessage);
end
