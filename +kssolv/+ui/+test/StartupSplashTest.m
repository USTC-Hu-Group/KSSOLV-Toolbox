classdef StartupSplashTest < matlab.unittest.TestCase
    methods (Test)
        function inheritedHostSignalIsIgnoredOutsideDeployment(testCase)
            testCase.assumeFalse(isdeployed);
            previousSignal = getenv('KSSOLV_STARTUP_SIGNAL');
            previousNonce = getenv('KSSOLV_STARTUP_NONCE');
            cleanup = onCleanup(@() restoreEnvironment(previousSignal, previousNonce));
            signal = string(tempname) + ".json";
            setenv('KSSOLV_STARTUP_SIGNAL', signal);
            setenv('KSSOLV_STARTUP_NONCE', 'inherited-host-signal');
            testCase.verifyFalse(kssolv.ui.util.StartupSplash.isRequested());
            kssolv.ui.util.StartupSplash.fail(MException('KSSOLV:Test', 'Source mode'));
            % An inactive adapter must not inspect the app or touch its window.
            testCase.verifyFalse(kssolv.ui.util.StartupSplash.tryShow([]));
            testCase.verifyFalse(isfile(signal));
            clear cleanup
        end
    end
end

function restoreEnvironment(signal, nonce)
setenv('KSSOLV_STARTUP_SIGNAL', signal);
setenv('KSSOLV_STARTUP_NONCE', nonce);
end
