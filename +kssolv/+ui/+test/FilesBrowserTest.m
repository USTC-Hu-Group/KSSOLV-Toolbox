classdef FilesBrowserTest < matlab.unittest.TestCase
    % Exercise native Files controls without a browser, JVM or live volume.
    properties (Access = private)
        Browser
        Tree
        MissingModels = false
    end
    methods (TestMethodSetup)
        function createFiles(testCase)
            mode = getenv('KSSOLV_ONLINE'); enabled = getenv('KSSOLV_WORKSPACE_ENABLED');
            previous = kssolv.ui.util.DataStorage.getData('FilesBrowser');
            testCase.addTeardown(@()restore(mode,enabled,previous));
            setenv('KSSOLV_ONLINE','true'); setenv('KSSOLV_WORKSPACE_ENABLED','true');
            testCase.Browser = kssolv.ui.components.databrowser.FilesBrowser( ...
                WorkspaceRequest=@(varargin)testCase.listing(varargin{:}));
            panel = testCase.Browser.Panel;
            testCase.addTeardown(@()delete(panel));
            testCase.addTeardown(@()delete(testCase.Browser));
            testCase.Tree = findall(testCase.Browser.Figure,'Type','uitree');
        end
    end
    methods (Test)
        function compactHeaderAndDirectoriesFirst(testCase)
            root = testCase.Tree.Children(1);
            testCase.verifyEqual(string(root.Text), "Online");
            testCase.verifyEqual(string({root.Children.Text}),["models","results","a.cif","z.ks"]);
            buttons = findall(testCase.Browser.Figure,'Type','uibutton');
            testCase.verifyNumElements(buttons,2);
            testCase.verifyEqual(sort(string({buttons.Tag})),["FilesActionsButton","FilesSortButton"]);
            testCase.verifyNotEmpty(root.Children(1).ContextMenu);
            testCase.verifyEqual(testCase.importMenuStates(),["off","off"]);
        end

        function sortingRetainsExpandedDirectoryAndSelectedFile(testCase)
            models = testCase.Tree.Children(1).Children(1);
            testCase.Tree.NodeExpandedFcn(testCase.Tree,struct('Node',models));
            file = models.Children(1);
            testCase.Tree.SelectedNodes = file;
            testCase.Tree.SelectionChangedFcn(testCase.Tree,[]);
            button = findall(testCase.Browser.Figure,'Tag','FilesSortButton');
            button.ButtonPushedFcn(button,[]);
            root = testCase.Tree.Children(1);
            testCase.verifyEqual(string({root.Children.Text}),["results","models","z.ks","a.cif"]);
            testCase.verifyEqual(string({root.Children(2).Children.Text}),["b.cif","a.ks"]);
            testCase.verifyEqual(testCase.Tree.SelectedNodes.NodeData.path,"models/a.ks");
            testCase.verifyEqual(button.Text,'↓');
            button.ButtonPushedFcn(button,[]);
            testCase.verifyEqual(button.Text,'↑');
            testCase.verifyEqual(testCase.Tree.SelectedNodes.NodeData.path,"models/a.ks");
        end

        function missingSelectedFolderFallsBackToExistingParent(testCase)
            models = testCase.Tree.Children(1).Children(1);
            testCase.Tree.NodeExpandedFcn(testCase.Tree,struct('Node',models));
            testCase.Tree.SelectedNodes = models.Children(1);
            testCase.Tree.SelectionChangedFcn(testCase.Tree,[]);
            testCase.MissingModels = true;
            testCase.Browser.refresh();
            testCase.verifyEqual(testCase.Tree.SelectedNodes.NodeData.path,"");
            testCase.verifyFalse(any(string({testCase.Tree.Children(1).Children.Text})=="models"));
            testCase.verifyEqual(testCase.importMenuStates(),["off","off"]);
        end

        function contextMenuUsesClickedNodeAndBlankSpaceDisablesFileActions(testCase)
            root = testCase.Tree.Children(1);
            menu = testCase.Tree.ContextMenu;
            menu.ContextMenuOpeningFcn(menu,struct('ContextObject',root.Children(4)));
            testCase.verifyEqual(testCase.Tree.SelectedNodes.NodeData.path,"z.ks");
            testCase.verifyEqual(testCase.importMenuStates(),["on","on"]);
            menu.ContextMenuOpeningFcn(menu,struct('ContextObject',root.Children(1)));
            testCase.verifyEqual(testCase.Tree.SelectedNodes.NodeData.path,"models");
            testCase.verifyEqual(testCase.importMenuStates(),["off","off"]);
            menu.ContextMenuOpeningFcn(menu,struct('ContextObject',testCase.Tree));
            testCase.verifyEmpty(testCase.Tree.SelectedNodes);
            testCase.Tree.DoubleClickedFcn(testCase.Tree, ...
                struct('InteractionInformation',struct('Node',[])));
            testCase.verifyEmpty(testCase.Tree.SelectedNodes);
        end
    end
    methods (Access = private)
        function states = importMenuStates(testCase)
            menus = findall(testCase.Browser.Figure,'Type','uimenu','Tag','FilesImportAction');
            states = string({menus.Enable});
        end

        function reply = listing(testCase,action,path,varargin)
            assert(strcmp(action,'list'));
            if string(path)==""
                names = ["z.ks","results","a.cif","models"];
                folders = [false,true,false,true];
                if testCase.MissingModels, names(end)=[]; folders(end)=[]; end
            elseif string(path)=="models" && ~testCase.MissingModels
                names = ["b.cif","a.ks"]; folders = [false,false];
            else
                names = strings(1,0); folders = false(1,0);
            end
            entries = struct('name',{},'path',{},'isDirectory',{},'bytes',{});
            for index = 1:numel(names)
                relative = names(index);
                if string(path)~="", relative = string(path)+'/'+relative; end
                entries(index) = struct('name',char(names(index)),'path',char(relative), ...
                    'isDirectory',folders(index),'bytes',1024*index);
            end
            reply = struct('entries',entries,'truncated',false);
        end
    end
end

function restore(mode,enabled,previous)
setenv('KSSOLV_ONLINE',mode); setenv('KSSOLV_WORKSPACE_ENABLED',enabled);
kssolv.ui.util.DataStorage.setData('FilesBrowser',previous);
end
