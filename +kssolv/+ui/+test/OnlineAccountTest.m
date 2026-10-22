classdef OnlineAccountTest < matlab.unittest.TestCase
    methods (Test)
        function desktopQuickAccessRemainsUnchanged(testCase)
            cleanup = setMode('false'); %#ok<NASGU>
            bar = kssolv.ui.components.qab.QuickAccessBar();
            app = kssolv.ui.test.fixtures.QABCollector();
            bar.addToAppContainer(app);
            testCase.verifyNumElements(app.Controls, 4);
            testCase.verifyFalse(any(cellfun(@(c)strcmp(c.Tag,'QABAccountButton'),app.Controls)));
        end

        function onlineAccountUsesNativeTextAndRightmostInsertion(testCase)
            cleanup = setMode('true'); %#ok<NASGU>
            bar = kssolv.ui.components.qab.QuickAccessBar();
            app = kssolv.ui.test.fixtures.QABCollector();
            bar.addToAppContainer(app);
            testCase.verifyNumElements(app.Controls, 5);
            account = app.Controls{1};
            testCase.verifyEqual(account.Tag, 'QABAccountButton');
            testCase.verifyTrue(account.ShowText);
            bar.setOnlineAccount(struct('username','qa-alice','idleSeconds',1800)); %#ok<XCREDS> Test username only.
            testCase.verifyEqual(string(account.Text), "qa-alice");
            testCase.verifyTrue(account.Enabled);
            popup = account.DynamicPopupFcn([],[]);
            testCase.verifyEqual(popup.getChildByIndex(1).Tag, 'QABAccountSettings');
            testCase.verifyEqual(popup.getChildByIndex(2).Tag, 'QABAccountExit');
            testCase.verifyEqual(popup.getChildByIndex(3).Tag, 'QABAccountSignOut');
            bar.setOnlineAccount(struct('username','','idleSeconds',0));
            testCase.verifyEqual(string(account.Text), string(kssolv.ui.util.Localizer.message( ...
                'KSSOLV:dialogs:OnlineAccountLogin')));
        end
    end
end

function cleanup = setMode(mode)
previous = getenv('KSSOLV_ONLINE');
previousBar = kssolv.ui.util.DataStorage.getData('QuickAccessBar');
previousAccount = kssolv.ui.util.DataStorage.getData('OnlineAccount');
cleanup = onCleanup(@()restore(previous,previousBar,previousAccount));
setenv('KSSOLV_ONLINE', mode);
end

function restore(mode, bar, account)
setenv('KSSOLV_ONLINE', mode);
kssolv.ui.util.DataStorage.setData('QuickAccessBar', bar);
kssolv.ui.util.DataStorage.setData('OnlineAccount', account);
end
