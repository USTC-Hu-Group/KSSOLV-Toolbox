classdef OnlineFileTransfer < handle
    %ONLINEFILETRANSFER Browser file IO over the existing uihtml connection.
    % No filesystem paths are accepted from the client. Transfers are bounded
    % and acknowledged one chunk at a time; uploads live in session temp space.
    properties (SetAccess = private)
        Done = false
        DownloadConfirmed = false
    end
    properties (Access = private)
        Modal
        HTML
        Options
        Folder = ""
        DownloadPath = ""
        Files = {}
        FileID = -1
        CurrentName = ""
        CurrentSize = 0
        TotalSize = 0
        NextChunk = 0
        ErrorMessage = ""
        SavedName = ""
        UploadComplete = false
        DestroyListener
    end
    properties (Constant, Access = private)
        MaxFileBytes = 128 * 1024 * 1024
        MaxTotalBytes = 128 * 1024 * 1024
        ChunkBytes = 128 * 1024
    end
    methods (Static)
        function [file, folder, index] = choose(mode, filters, title, varargin)
            options = struct('mode', mode, 'title', char(title), ...
                'multiple', false, 'filename', '', 'accept', '', ...
                'maxFileBytes', kssolv.ui.browser.OnlineFileTransfer.MaxFileBytes, ...
                'maxTotalBytes', kssolv.ui.browser.OnlineFileTransfer.MaxTotalBytes);
            if iscell(filters), pattern = string(filters{1});
            else, pattern = string(filters); end
            extensions = split(pattern, ';');
            extensions = erase(extensions(startsWith(extensions, '*.')), '*');
            extensions(extensions == ".*") = [];
            options.accept = char(join(extensions, ','));
            if ~isempty(varargin) && ~strcmpi(string(varargin{1}), 'MultiSelect')
                if strcmp(mode, 'save')
                    [~, base, ext] = fileparts(string(varargin{1}));
                    if ext == "" && ~isempty(extensions), ext = extensions(1); end
                    options.filename = char(base + ext);
                end
                varargin(1) = [];
            end
            for k = 1:2:numel(varargin)
                if strcmpi(string(varargin{k}), 'MultiSelect')
                    options.multiple = strcmpi(string(varargin{k+1}), 'on');
                end
            end
            if strcmp(mode, 'save')
                % Selecting an existing file in showSaveFilePicker truncates
                % it immediately. Prepare server output before asking for a
                % browser destination; download() owns the eventual picker.
                filename = string(options.filename);
                if filename == ""
                    filename = "untitled";
                    if ~isempty(extensions), filename = filename + extensions(1); end
                end
                file = char(kssolv.ui.browser.OnlineFileTransfer.validateName(filename));
                folder = char(string(tempname) + filesep);
                mkdir(folder);
                index = 1;
                return
            end
            transfer = kssolv.ui.browser.OnlineFileTransfer(options);
            cleanup = onCleanup(@() delete(transfer));
            file = 0; folder = 0; index = 0;
            if ~kssolv.ui.browser.BrowserReconnectMonitor.waitFor(transfer, 'Done', true)
                return
            end
            if transfer.ErrorMessage ~= ""
                error('KSSOLV:Online:FileTransfer', '%s', transfer.ErrorMessage);
            end
            if transfer.UploadComplete
                file = transfer.Files;
                if ~options.multiple || isscalar(file), file = file{1}; end
                folder = char(transfer.Folder + filesep);
                index = 1;
                transfer.Folder = ""; % Keep completed files for their consumers.
            end
        end

        function [completed, savedName] = download(path, waitForConfirmation, clipboardMode)
            if nargin < 2, waitForConfirmation = false; end
            if nargin < 3, clipboardMode = ""; end
            clipboardMode = string(clipboardMode);
            if ~isscalar(clipboardMode) || ~ismember(clipboardMode, ["","image","vector"])
                error('KSSOLV:Online:ClipboardMode', 'Invalid graphics clipboard mode.');
            end
            completed = true;
            info = dir(path);
            if ~isscalar(info) || info.isdir || info.bytes > kssolv.ui.browser.OnlineFileTransfer.MaxFileBytes
                error('KSSOLV:Online:DownloadSize', ...
                    'Online downloads require one file of at most 128 MiB.');
            end
            [~, name, ext] = fileparts(path);
            savedName = string(name) + string(ext);
            options = struct('mode', 'download', 'title', 'Download file', ...
                'filename', char(name + string(ext)), 'multiple', false, ...
                'accept', '', 'maxFileBytes', kssolv.ui.browser.OnlineFileTransfer.MaxFileBytes, ...
                'fileBytes', info.bytes, ...
                'requireConfirmation', logical(waitForConfirmation));
            options.clipboardMode = char(clipboardMode);
            if clipboardMode ~= "", options.title = 'Copy plot'; end
            % Publish only an isolated copy, never the parent project folder.
            folder = string(tempname); mkdir(folder);
            try
                % Connector reparses download paths; URL delimiters in an
                % actual filename can still cause Bad URI syntax. Keep the
                % storage name ASCII and let the Online proxy supply the
                % original UTF-8 name in Content-Disposition.
                copy = fullfile(folder, 'download.bin');
                copyfile(path, copy);
                % Register the copy now, but issue its one-use, short-lived
                % download authorization only when the browser requests data.
                downloadPath = matlab.ui.internal.URLUtils.getURLToUserFile(char(copy), false);
                transfer = kssolv.ui.browser.OnlineFileTransfer(options, folder, downloadPath);
            catch exception
                removeFolder(folder);
                rethrow(exception);
            end
            % HTML callbacks retain this transfer until the modal closes.
            if waitForConfirmation
                cleanup = onCleanup(@() delete(transfer));
                if ~kssolv.ui.browser.BrowserReconnectMonitor.waitFor(transfer, 'Done', true)
                    completed = false;
                    return
                end
                completed = transfer.DownloadConfirmed;
                if transfer.SavedName ~= "", savedName = transfer.SavedName; end
            end
        end

        function name = validateName(value)
            name = string(value);
            if ~isscalar(name) || strlength(name) == 0 || ...
                    strlength(name) > 255 || any(name == [".", ".."]) || ...
                    any(contains(name, ["/", "\", ":"])) || ...
                    any(double(char(name)) < 32) || any(double(char(name)) == 127)
                error('KSSOLV:Online:Filename', 'Invalid client filename.');
            end
        end

        function encoded = encodeFilename(value)
            % Encode one UTF-8 path segment without form/query conventions.
            value = kssolv.ui.browser.OnlineFileTransfer.validateName(value);
            bytes = unicode2native(char(value), 'UTF-8');
            pieces = strings(1, numel(bytes));
            for index = 1:numel(bytes)
                byte = bytes(index);
                if (byte >= 65 && byte <= 90) || ...
                        (byte >= 97 && byte <= 122) || ...
                        (byte >= 48 && byte <= 57) || ...
                        ismember(byte, uint8('-._~'))
                    pieces(index) = string(char(byte));
                else
                    pieces(index) = string(sprintf('%%%02X', byte));
                end
            end
            encoded = char(join(pieces, ''));
        end
    end
    methods
        function this = OnlineFileTransfer(options, folder, downloadPath)
            if nargin < 2, folder = ""; end
            if nargin < 3, downloadPath = ""; end
            source = kssolv.ui.browser.htmlSource( ...
                kssolv.ui.browser.resourcePath('online-files.html'));
            options.id = char(matlab.lang.internal.uuid);
            this.Options = options;
            this.Folder = string(folder);
            this.DownloadPath = string(downloadPath);
            this.Modal = kssolv.ui.browser.OnlineModal.create(options.title, true, false);
            this.Modal.Figure.Position(3:4) = [480, 208];
            this.Modal.CanCloseFcn = @(~)this.cancel();
            grid = uigridlayout(this.Modal.Figure, [1, 1], 'Padding', 0);
            this.HTML = uihtml(grid, 'HTMLSource', source, 'Tag', 'OnlineFileTransfer', ...
                'HTMLEventReceivedFcn', @(~, event)this.receive(event));
            this.DestroyListener = addlistener(this.Modal.Figure, ...
                'ObjectBeingDestroyed', @(~, ~)this.destroyed());
            this.Modal.show();
        end

        function delete(this)
            this.closeFile();
            if this.Folder ~= "" && isfolder(this.Folder)
                rmdir(this.Folder, 's');
            end
            if ~isempty(this.DestroyListener), delete(this.DestroyListener); end
            if ~isempty(this.Modal) && isvalid(this.Modal)
                kssolv.ui.browser.OnlineModal.dispose(this.Modal);
            end
        end
    end
    methods (Access = private)
        function allowed = cancel(this)
            this.Done = true;
            this.closeFile();
            allowed = true;
        end

        function destroyed(this)
            this.Modal = [];
            this.Done = true;
            this.closeFile();
            if strcmp(this.Options.mode, 'download') && ...
                    ~this.Options.requireConfirmation
                delete(this);
            end
        end

        function closeFile(this)
            if this.FileID >= 0, fclose(this.FileID); this.FileID = -1; end
        end

        function receive(this, event)
            try
                data = event.HTMLEventData;
                switch string(event.HTMLEventName)
                    case "ready"
                        this.HTML.sendEventToHTMLSource('configure', this.Options);
                    case "cancel"
                        if strcmp(this.Options.mode, 'download') && ...
                                ~this.Options.requireConfirmation
                            kssolv.ui.browser.OnlineModal.dispose(this.Modal);
                        else
                            this.cancel();
                        end
                    case "requestDownload"
                        if ~strcmp(this.Options.mode, 'download') || this.DownloadPath == ""
                            error('KSSOLV:Online:Mode', 'Download is not active.');
                        end
                        url = matlab.ui.internal.URLUtils. ...
                            applyNonceAndCSRFTokenToDownloadURL(char(this.DownloadPath));
                        url = [url, '&kssolv_filename=', this.encodeFilename(this.Options.filename)];
                        this.HTML.sendEventToHTMLSource('downloadURL', struct('url', url));
                    case "downloadConfirmed"
                        if strcmp(this.Options.mode, 'download') && ...
                                this.Options.requireConfirmation
                            this.DownloadConfirmed = true;
                            this.Done = true;
                        end
                    case "nativeDownloadComplete"
                        if strcmp(this.Options.mode, 'download')
                            if isfield(data, 'name')
                                this.SavedName = this.validateName(data.name);
                            end
                            this.DownloadConfirmed = true;
                            this.Done = true;
                            if ~this.Options.requireConfirmation
                                kssolv.ui.browser.OnlineModal.dispose(this.Modal);
                            end
                        end
                    case "upload"
                        this.upload(data);
                        this.HTML.sendEventToHTMLSource('ack', struct());
                    case "complete"
                        if this.FileID >= 0 || isempty(this.Files)
                            error('KSSOLV:Online:Incomplete', 'Incomplete upload.');
                        end
                        this.UploadComplete = true;
                        this.Done = true;
                end
            catch exception
                this.closeFile();
                this.ErrorMessage = string(exception.message);
                this.HTML.sendEventToHTMLSource('failure', char(this.ErrorMessage));
                if ~strcmp(this.Options.mode, 'download'), this.Done = true; end
            end
        end

        function upload(this, data)
            if ~strcmp(this.Options.mode, 'open')
                error('KSSOLV:Online:Mode', 'Upload is not active.');
            end
            name = this.validateName(data.name);
            index = double(data.index);
            if ~isscalar(index) || ~isfinite(index) || index ~= this.NextChunk
                error('KSSOLV:Online:Order', 'Unexpected upload chunk.');
            end
            if this.FileID < 0
                if index ~= 0 || numel(this.Files) >= 100 || ...
                        (~this.Options.multiple && ~isempty(this.Files)) || ...
                        any(strcmpi(this.Files, name))
                    error('KSSOLV:Online:Files', 'Invalid upload file sequence.');
                end
                if this.Folder == "", this.Folder = string(tempname); mkdir(this.Folder); end
                this.CurrentName = name;
                this.CurrentSize = 0;
                this.FileID = fopen(fullfile(this.Folder, name), 'wb');
                if this.FileID < 0, error('KSSOLV:Online:Write', 'Cannot create upload.'); end
            elseif name ~= this.CurrentName
                error('KSSOLV:Online:Order', 'Upload name changed during transfer.');
            end
            encoded = char(string(data.bytes));
            if numel(encoded) > 4 * ceil(this.ChunkBytes / 3)
                error('KSSOLV:Online:ChunkSize', 'Upload chunk is too large.');
            end
            bytes = matlab.net.base64decode(encoded);
            if numel(bytes) > this.ChunkBytes
                error('KSSOLV:Online:ChunkSize', 'Upload chunk is too large.');
            end
            this.CurrentSize = this.CurrentSize + numel(bytes);
            this.TotalSize = this.TotalSize + numel(bytes);
            if this.CurrentSize > this.MaxFileBytes || this.TotalSize > this.MaxTotalBytes
                error('KSSOLV:Online:Size', 'Upload exceeds the session transfer limit.');
            end
            if fwrite(this.FileID, bytes, 'uint8') ~= numel(bytes)
                error('KSSOLV:Online:Write', 'Incomplete upload write.');
            end
            this.NextChunk = this.NextChunk + 1;
            if isequal(data.final, true)
                this.closeFile();
                this.Files{end+1} = char(name);
                this.NextChunk = 0;
            end
        end

    end

end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
