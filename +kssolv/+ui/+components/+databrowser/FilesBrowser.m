classdef FilesBrowser < matlab.ui.internal.databrowser.AbstractDataBrowser
    %FILESBROWSER MATLAB-style file tree for the current Online persistent volume.
    properties (Access = private)
        Tree
        PathLabel
        Status
        SortButton
        ImportMenus = gobjects(0)
        DownloadMenus = gobjects(0)
        ContextMenu
        WorkspaceRequest function_handle
        Descending (1,1) logical = false
        ExpandedPaths (:,1) string = ""
        CurrentFolder (1,1) string = ""
    end
    methods
        function this = FilesBrowser(options)
            arguments
                options.WorkspaceRequest function_handle = @kssolv.ui.browser.OnlineWorkspace.request
            end
            this@matlab.ui.internal.databrowser.AbstractDataBrowser('OnlineFilesBrowser', text('FilesTitle'));
            this.WorkspaceRequest = options.WorkspaceRequest;
            this.Panel.Tag = 'OnlineFilesBrowser';
            this.setPreferredHeight(0.4);
            % Keep the native panel title and tree; actions belong in menus,
            % leaving the same compact name header as the desktop Files panel.
            grid = uigridlayout(this.Figure,[3 1], 'RowHeight',{26,'1x',22}, ...
                'ColumnWidth',{'1x'},'Padding',0,'RowSpacing',0);
            header = uigridlayout(grid,[1 3],'ColumnWidth',{'1x',26,26}, ...
                'Padding',[8 0 2 0],'ColumnSpacing',0,'BackgroundColor',[.94 .94 .94]);
            uilabel(header,'Text',text('FilesFilename'),'FontWeight','bold');
            this.SortButton = uibutton(header,'Text','↑','Tag','FilesSortButton', ...
                'Tooltip',text('FilesSortDescending'), ...
                'ButtonPushedFcn',@(~,~)this.run(@()this.toggleSort()));
            actions = this.createMenu();
            uibutton(header,'Text','⋮','Tag','FilesActionsButton', ...
                'Tooltip',text('FilesActions'),'ButtonPushedFcn', ...
                @(button,~)this.run(@()this.openMenu(actions,button)));
            this.ContextMenu = this.createMenu();
            this.ContextMenu.ContextMenuOpeningFcn = @(~,event)this.contextOpening(event);
            this.Tree = uitree(grid,'Multiselect','off','FontSize',13, ...
                'Tag','OnlineFilesTree', ...
                'SelectionChangedFcn',@(~,~)this.selectionChanged(), ...
                'NodeExpandedFcn',@(~,event)this.run(@()this.nodeExpanded(event.Node)), ...
                'NodeCollapsedFcn',@(~,event)this.nodeCollapsed(event.Node), ...
                'DoubleClickedFcn',@(~,event)this.run(@()this.doubleClicked(event)));
            this.Tree.ContextMenu = this.ContextMenu;
            footer = uigridlayout(grid,[1 2],'ColumnWidth',{'1x','fit'}, ...
                'Padding',[6 0 6 0],'ColumnSpacing',6);
            this.PathLabel = uilabel(footer,'Text',text('FilesRoot') + '/','FontSize',11);
            this.Status = uilabel(footer,'Text','','FontSize',11);
            kssolv.ui.util.DataStorage.setData('FilesBrowser',this);
            if kssolv.ui.browser.OnlineWorkspace.available()
                this.refresh();
            else
                this.Status.Text = text('FilesUnavailable');
                this.Tree.Enable = 'off'; this.SortButton.Enable = 'off';
                set(findall(this.Figure,'Type','uimenu'),'Enable','off');
            end
        end

        function delete(this)
            stored = kssolv.ui.util.DataStorage.getData('FilesBrowser');
            if isequal(stored,this), kssolv.ui.util.DataStorage.removeData('FilesBrowser'); end
        end

        function refresh(this, selected)
            if nargin < 2, selected = this.selectedPath(); end
            % Fetch before replacing the current tree: a failed request must
            % not discard a still-useful view or its selection.
            listing = this.WorkspaceRequest('list',"");
            expanded = this.ExpandedPaths;
            delete(this.Tree.Children);
            root = uitreenode(this.Tree,'Text',text('FilesRoot'), ...
                'NodeData',struct('path',"",'isDirectory',true,'loaded',false,'bytes',0), ...
                'Icon',fileIcon(true),'ContextMenu',this.ContextMenu);
            this.populate(root,listing);
            this.ExpandedPaths = strings(0,1);
            [~,order] = sort(strlength(expanded));
            partial = false;
            for path = expanded(order)'
                try
                    node = this.findNode(path);
                    if node.NodeData.path == path && node.NodeData.isDirectory
                        this.nodeExpanded(node); expand(node);
                    end
                catch
                    partial = true;
                end
            end
            try
                node = this.findNode(string(selected));
            catch
                node = root; partial = true;
            end
            this.Tree.SelectedNodes = node;
            this.selectionChanged();
            if partial, this.Status.Text = text('FilesRefreshPartial'); end
        end

        function completed = saveProject(this, saveAs)
            completed = false;
            project = kssolv.ui.util.DataStorage.getData('Project');
            try
                previous = string(kssolv.ui.util.DataStorage.getData('ProjectFilename'));
                relative = kssolv.ui.browser.OnlineWorkspace.relativePath(previous);
                if saveAs || relative == ""
                    [~,name,ext] = fileparts(previous);
                    if name == "", name = "untitled"; end
                    if ext ~= ".ks", ext = ".ks"; end
                    answer = kssolv.ui.util.SessionPrompt.input( ...
                        text('FilesFilename') + " (" + this.PathLabel.Text + ")", ...
                        text('FilesSaveProject'),1,{char(name+ext)});
                    if isempty(answer), return, end
                    name = kssolv.ui.browser.OnlineFileTransfer.validateName(answer{1});
                    if endsWith(lower(name),'.ks')
                        name = extractBefore(name,strlength(name)-2) + '.ks';
                    else
                        name = name + '.ks';
                    end
                    relative = this.childPath(name);
                end
                target = kssolv.ui.browser.OnlineWorkspace.resolve(relative,true);
                if isfile(target) && (saveAs || previous ~= target) && ~this.replaceFile()
                    return
                end
                registry = kssolv.ui.util.DataStorage.getData('ModelingSessionRegistry');
                if ~isempty(registry) && isvalid(registry) && registry.hasUnsavedChanges()
                    registry.saveAllChangesToProject();
                end
                staged = string(tempname(fileparts(target))) + '.ks';
                cleanup = onCleanup(@()removeStaged(staged));
                project.saveToKsFile(staged);
                [ok,message] = movefile(staged,target,'f');
                if ~ok, error('KSSOLV:Online:WorkspaceSave','%s',message); end
                clear cleanup
                kssolv.ui.util.DataStorage.setData('ProjectFilename',target);
                kssolv.KSSOLVToolbox.setAppContainerTitle();
                this.refresh(relative);
                this.Status.Text = text('FilesSaved');
                completed = true;
            catch exception
                project.isDirty = true;
                this.showError(exception);
            end
        end
    end
    methods (Access = private)
        function openMenu(~,menu,button)
            position = getpixelposition(button,true);
            open(menu,position(1),position(2));
        end

        function menu = createMenu(this)
            menu = uicontextmenu(this.Figure);
            this.ImportMenus(end+1) = uimenu(menu,'Text',text('FilesImport'), ...
                'Tag','FilesImportAction','MenuSelectedFcn',@(~,~)this.run(@()this.openSelected()));
            this.DownloadMenus(end+1) = uimenu(menu,'Text',text('FilesDownload'), ...
                'Tag','FilesDownloadAction','MenuSelectedFcn',@(~,~)this.run(@()this.download()));
            uimenu(menu,'Text',text('FilesUpload'),'Separator','on', ...
                'MenuSelectedFcn',@(~,~)this.run(@()this.upload()));
            uimenu(menu,'Text',text('FilesSaveProject'), ...
                'MenuSelectedFcn',@(~,~)this.saveProject(true));
            uimenu(menu,'Text',text('FilesNewFolder'), ...
                'MenuSelectedFcn',@(~,~)this.run(@()this.newFolder()));
            uimenu(menu,'Text',text('FilesRefresh'),'Separator','on', ...
                'MenuSelectedFcn',@(~,~)this.run(@()this.refresh()));
        end

        function toggleSort(this)
            this.Descending = ~this.Descending;
            if this.Descending
                this.SortButton.Text = '↓'; this.SortButton.Tooltip = text('FilesSortAscending');
            else
                this.SortButton.Text = '↑'; this.SortButton.Tooltip = text('FilesSortDescending');
            end
            this.refresh();
        end

        function populate(this,node,listing)
            data = node.NodeData;
            if ~isstruct(data) || ~data.isDirectory || data.loaded, return, end
            if nargin < 3
                listing = this.WorkspaceRequest('list',data.path);
            end
            delete(node.Children);
            entries = listing.entries;
            if ~isempty(entries)
                names = lower(string({entries.name}));
                if this.Descending, direction = 'descend'; else, direction = 'ascend'; end
                [~,order] = sort(names,direction);
                % Directories stay first for either name sort direction.
                folders = [entries(order).isDirectory];
                order = [order(folders),order(~folders)];
                entries = entries(order);
            end
            for index = 1:numel(entries)
                item = entries(index);
                child = uitreenode(node,'Text',item.name,'NodeData', ...
                    struct('path',string(item.path),'isDirectory',item.isDirectory, ...
                    'loaded',false,'bytes',item.bytes), ...
                    'Icon',fileIcon(item.isDirectory),'ContextMenu',this.ContextMenu);
                if item.isDirectory, uitreenode(child,'Text','…'); end
            end
            data.loaded = true; data.truncated = listing.truncated; node.NodeData = data;
        end

        function nodeExpanded(this,node)
            if ~isstruct(node.NodeData) || ~node.NodeData.isDirectory, return, end
            this.populate(node);
            this.ExpandedPaths = unique([this.ExpandedPaths;string(node.NodeData.path)],'stable');
        end

        function nodeCollapsed(this,node)
            if ~isstruct(node.NodeData), return, end
            path = string(node.NodeData.path);
            if path == ""
                this.ExpandedPaths = strings(0,1);
            else
                this.ExpandedPaths(this.ExpandedPaths == path | ...
                    startsWith(this.ExpandedPaths,path+'/')) = [];
            end
            if startsWith(this.selectedPath(),path+'/') || path == ""
                this.Tree.SelectedNodes = node; this.selectionChanged();
            end
        end

        function node = findNode(this,path)
            node = this.Tree.Children(1);
            if path == "", return, end
            parts = split(path,'/'); current = "";
            for index = 1:numel(parts)
                if current == "", current = parts(index); else, current = current+'/'+parts(index); end
                this.nodeExpanded(node); expand(node);
                found = [];
                for child = node.Children(:)'
                    if isstruct(child.NodeData) && child.NodeData.path == current
                        found = child; break
                    end
                end
                if isempty(found), return, end
                node = found;
            end
        end

        function path = selectedPath(this)
            path = this.CurrentFolder;
            selected = this.Tree.SelectedNodes;
            if ~isempty(selected) && isstruct(selected.NodeData), path = string(selected.NodeData.path); end
        end

        function contextOpening(this,event)
            % Per-node menus identify the right-click target, independent of
            % whichever file was previously selected.
            target = event.ContextObject;
            if isa(target,'matlab.ui.container.TreeNode') && isstruct(target.NodeData)
                this.Tree.SelectedNodes = target;
            else
                this.Tree.SelectedNodes = [];
            end
            this.selectionChanged();
        end

        function doubleClicked(this,event)
            node = event.InteractionInformation.Node;
            if isempty(node) || ~isstruct(node.NodeData), return, end
            this.Tree.SelectedNodes = node; this.selectionChanged();
            this.openSelected();
        end

        function selectionChanged(this)
            selected = this.Tree.SelectedNodes;
            file = ~isempty(selected) && isstruct(selected.NodeData) && ~selected.NodeData.isDirectory;
            set(this.ImportMenus,'Enable',file); set(this.DownloadMenus,'Enable',file);
            this.Status.Text = "";
            if isempty(selected) || ~isstruct(selected.NodeData), return, end
            data = selected.NodeData;
            if data.isDirectory
                this.CurrentFolder = string(data.path);
                if data.loaded
                    count = numel(selected.Children);
                    this.Status.Text = string(sprintf(text('FilesItemCount'),count));
                    if data.truncated, this.Status.Text = text('FilesTruncated'); end
                end
            else
                this.CurrentFolder = string(fileparts(data.path));
                this.Status.Text = fileSize(data.bytes);
            end
            this.PathLabel.Text = text('FilesRoot') + '/' + this.CurrentFolder;
            this.PathLabel.Tooltip = this.PathLabel.Text;
            this.Tree.Tooltip = text('FilesRoot') + '/' + string(data.path);
            this.Status.Tooltip = this.Status.Text;
        end

        function relative = childPath(this,name)
            name = kssolv.ui.browser.OnlineFileTransfer.validateName(name);
            if this.CurrentFolder == "", relative = name;
            else, relative = this.CurrentFolder + '/' + name; end
        end

        function openSelected(this)
            selected = this.Tree.SelectedNodes;
            if isempty(selected) || ~isstruct(selected.NodeData), return, end
            if selected.NodeData.isDirectory
                this.nodeExpanded(selected); expand(selected); this.selectionChanged(); return
            end
            kssolv.ui.util.DataStorage.getData('HomeTab').openWorkspaceFile(selected.NodeData.path);
        end

        function download(this)
            selected = this.Tree.SelectedNodes;
            if isempty(selected) || ~isstruct(selected.NodeData) || selected.NodeData.isDirectory, return, end
            path = kssolv.ui.browser.OnlineWorkspace.resolve(selected.NodeData.path);
            kssolv.ui.browser.OnlineFileTransfer.download(path,true);
        end

        function upload(this)
            [names,folder] = kssolv.ui.util.FileDialog.open({'*.*',text('FilesAll')}, ...
                text('FilesUpload'),'MultiSelect','on');
            if isequal(names,0), return, end
            cleanup = onCleanup(@()rmdir(folder,'s'));
            if ~iscell(names), names = {names}; end
            for index = 1:numel(names)
                relative = this.childPath(names{index});
                target = kssolv.ui.browser.OnlineWorkspace.resolve(relative,true);
                if isfile(target) && ~this.replaceFile(), continue, end
                staged = string(tempname(fileparts(target)));
                stagedCleanup = onCleanup(@()removeStaged(staged));
                [ok,message] = copyfile(fullfile(folder,names{index}),staged);
                if ~ok, error('KSSOLV:Online:WorkspaceUpload','%s',message); end
                [ok,message] = movefile(staged,target,'f');
                if ~ok, error('KSSOLV:Online:WorkspaceUpload','%s',message); end
                clear stagedCleanup
            end
            this.refresh(); clear cleanup
        end

        function newFolder(this)
            answer = kssolv.ui.util.SessionPrompt.input(text('FilesFilename'),text('FilesNewFolder'),1,{''});
            if isempty(answer), return, end
            relative = this.childPath(answer{1});
            this.WorkspaceRequest('mkdir',relative,true);
            this.refresh(relative);
        end

        function yes = replaceFile(~)
            replace = text('FilesReplace');
            choice = kssolv.ui.util.SessionPrompt.confirm([],text('FilesExists'),text('FilesTitle'), ...
                'Options',{replace,text('OnlineAccountCancel')},'DefaultOption',2,'CancelOption',2);
            yes = strcmp(choice,replace);
        end

        function run(this,action)
            try, action(); catch exception, this.showError(exception); end
        end

        function showError(~,exception)
            kssolv.ui.util.SessionPrompt.confirm([],exception.message,text('FilesTitle'), ...
                'Options',{text('OnlineAccountClose')},'Icon','error');
        end
    end
end

function value = text(key)
value = string(kssolv.ui.util.Localizer.message(['KSSOLV:dialogs:' char(key)]));
end

function removeStaged(path)
if isfile(path), delete(path); end
end

function path = fileIcon(folder)
if folder, name = 'files-folder.svg'; else, name = 'files-document.svg'; end
path = fullfile(KSSOLV_Toolbox.UIResourcesDirectory,'icons',name);
end

function value = fileSize(bytes)
units = ["B","KiB","MiB","GiB"];
index = min(4,max(1,floor(log(max(1,double(bytes)))/log(1024))+1));
if index == 1, value = string(sprintf('%d B',bytes));
else, value = string(sprintf('%.1f %s',double(bytes)/1024^(index-1),units(index))); end
end
