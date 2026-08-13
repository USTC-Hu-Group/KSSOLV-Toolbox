classdef SessionRegistry < handle
    %SESSIONREGISTRY Tracks open structure documents and their model sessions.

    properties (Access = private)
        Sessions containers.Map
        ActiveSessionId string = ""
        IsShuttingDown (1,1) logical = false
    end

    events
        SessionCountChanged
        ActiveSessionChanged
    end

    methods (Access = private)
        function this = SessionRegistry()
            this.Sessions = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
        end
    end

    methods (Static)
        function this = getInstance()
            this = kssolv.ui.util.DataStorage.getData( ...
                "ModelingSessionRegistry");
            if isempty(this) || ~isvalid(this)
                this = kssolv.ui.features.modeling.SessionRegistry();
                kssolv.ui.util.DataStorage.setData( ...
                    "ModelingSessionRegistry", this);
            end
        end
    end

    methods
        function sessionId = register(this, document, display)
            arguments
                this
                document matlab.ui.internal.FigureDocument
                display kssolv.ui.components.figuredocument.MoleculeDisplay
            end
            if this.IsShuttingDown
                error("KSSOLV:Modeling:RegistryShuttingDown", ...
                    "The modeling session registry is shutting down.");
            end
            sessionId = string(document.Tag);
            if sessionId == ""
                sessionId = "StructureModel(" + ...
                    string(matlab.lang.internal.uuid) + ")";
                document.Tag = char(sessionId);
            end
            key = char(sessionId);
            if isKey(this.Sessions, key)
                previous = this.Sessions(key);
                if isequal(previous.display, display)
                    return
                end
                this.deleteEntryListeners(previous);
            end
            closeListener = addlistener(document, ...
                "ObjectBeingDestroyed", ...
                @(~, ~)this.unregister(sessionId));
            selectionListener = addlistener(document, ...
                "PropertyChanged", ...
                @(~, ~)this.noteSelection(sessionId));
            this.Sessions(key) = struct( ...
                "display", display, ...
                "document", document, ...
                "closeListener", closeListener, ...
                "selectionListener", selectionListener);
            % AppContainer can transiently report both the old and newly
            % opened FigureDocument as Selected. Opening a structure is an
            % activation action; later selection events remain authoritative.
            this.setActiveSession(sessionId);
            notify(this, "SessionCountChanged");
        end

        function unregister(this, sessionId)
            if this.IsShuttingDown
                return
            end
            key = char(string(sessionId));
            if ~isKey(this.Sessions, key)
                return
            end
            entry = this.Sessions(key);
            remove(this.Sessions, key);
            this.deleteEntryListeners(entry);
            if this.ActiveSessionId == string(sessionId)
                this.ActiveSessionId = "";
                notify(this, "ActiveSessionChanged");
            end
            notify(this, "SessionCountChanged");
        end

        function display = getCurrentDisplay(this)
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay.empty;
            this.removeInvalidSessions();
            selectedKey = this.selectedSessionKey();
            if selectedKey ~= ""
                this.setActiveSession(selectedKey);
                entry = this.Sessions(char(selectedKey));
                display = entry.display;
                return
            end
            appContainer = kssolv.ui.util.DataStorage.getData("AppContainer");
            if ~isempty(appContainer) && isvalid(appContainer)
                document = appContainer.LastSelectedDocument;
                if ~isempty(document)
                    tag = "";
                    if isobject(document) && isprop(document, "Tag")
                        tag = string(document.Tag);
                    elseif isstruct(document) && isfield(document, "Tag")
                        tag = string(document.Tag);
                    end
                    if isscalar(tag) && tag ~= ""
                        key = char(tag);
                        if isKey(this.Sessions, key)
                            entry = this.Sessions(key);
                            this.setActiveSession(string(key));
                            display = entry.display;
                            return
                        end
                    end
                end
            end
            if this.ActiveSessionId ~= "" && ...
                    isKey(this.Sessions, char(this.ActiveSessionId))
                entry = this.Sessions(char(this.ActiveSessionId));
                display = entry.display;
                return
            end
            keys = this.Sessions.keys;
            if isscalar(keys)
                entry = this.Sessions(keys{1});
                this.setActiveSession(string(keys{1}));
                display = entry.display;
            end
        end

        function value = count(this)
            this.removeInvalidSessions();
            value = double(this.Sessions.Count);
        end

        function value = hasSessions(this)
            value = this.count() > 0;
        end

        function exitFullscreen(this)
            %EXITFULLSCREEN Let each viewer check and leave fullscreen.
            this.removeInvalidSessions();
            keys = this.Sessions.keys;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                entry.display.exitFullscreen();
            end
        end

        function waitForFullscreenExit(this, timeout)
            %WAITFORFULLSCREENEXIT Process viewer acknowledgements briefly.
            arguments
                this
                timeout (1,1) double {mustBeNonnegative} = 1
            end
            started = tic;
            while toc(started) < timeout
                this.removeInvalidSessions();
                pending = false;
                keys = this.Sessions.keys;
                for index = 1:numel(keys)
                    entry = this.Sessions(keys{index});
                    if entry.display.isFullscreenExitPending()
                        pending = true;
                        break
                    end
                end
                if ~pending
                    return
                end
                drawnow
                pause(0.01)
            end
        end

        function value = hasUnsavedChanges(this)
            this.removeInvalidSessions();
            value = false;
            keys = this.Sessions.keys;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                if entry.display.hasUnsavedChanges()
                    value = true;
                    return
                end
            end
        end

        function saveAllChangesToProject(this)
            %SAVEALLCHANGESTOPROJECT Commit every open structure draft.
            this.removeInvalidSessions();
            keys = this.Sessions.keys;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                entry.display.saveChangesToProject();
            end
        end

        function discardAllChanges(this, render)
            %DISCARDALLCHANGES Restore all initial copies without persistence.
            arguments
                this
                render (1,1) logical = false
            end
            this.removeInvalidSessions();
            keys = this.Sessions.keys;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                entry.display.discardChanges(render);
            end
        end

        function clear(this)
            keys = this.Sessions.keys;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                this.deleteEntryListeners(entry);
            end
            this.Sessions = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.ActiveSessionId = "";
            notify(this, "SessionCountChanged");
            notify(this, "ActiveSessionChanged");
        end

        function prepareForShutdown(this)
            %PREPAREFORSHUTDOWN Detach document callbacks without notifying UI.
            if this.IsShuttingDown
                return
            end
            this.IsShuttingDown = true;
            keys = this.Sessions.keys;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                this.deleteEntryListeners(entry);
                if ~isempty(entry.display) && isvalid(entry.display)
                    entry.display.prepareForShutdown();
                end
            end
            this.Sessions = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            this.ActiveSessionId = "";
        end

        function delete(this)
            this.prepareForShutdown();
            stored = kssolv.ui.util.DataStorage.getData( ...
                "ModelingSessionRegistry");
            if ~isempty(stored) && isequal(stored, this)
                kssolv.ui.util.DataStorage.removeData( ...
                    "ModelingSessionRegistry");
            end
        end
    end

    methods (Access = private)
        function removeInvalidSessions(this)
            if this.IsShuttingDown
                return
            end
            keys = this.Sessions.keys;
            changed = false;
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                if isempty(entry.document) || ~isvalid(entry.document) || ...
                        isempty(entry.display) || ~isvalid(entry.display)
                    this.deleteEntryListeners(entry);
                    if this.ActiveSessionId == string(keys{index})
                        this.ActiveSessionId = "";
                    end
                    remove(this.Sessions, keys{index});
                    changed = true;
                end
            end
            if changed
                notify(this, "SessionCountChanged");
            end
        end

        function noteSelection(this, sessionId)
            if this.IsShuttingDown
                return
            end
            key = char(string(sessionId));
            if ~isKey(this.Sessions, key)
                return
            end
            entry = this.Sessions(key);
            if ~isempty(entry.document) && isvalid(entry.document) && ...
                    entry.document.Selected
                selectedId = string(sessionId);
                this.setActiveSession(selectedId);
            end
        end

        function setActiveSession(this, sessionId)
            if this.IsShuttingDown
                return
            end
            sessionId = string(sessionId);
            if this.ActiveSessionId == sessionId
                return
            end
            this.ActiveSessionId = sessionId;
            notify(this, "ActiveSessionChanged");
        end

        function key = selectedSessionKey(this)
            key = "";
            keys = this.Sessions.keys;
            selected = strings(0, 1);
            for index = 1:numel(keys)
                entry = this.Sessions(keys{index});
                if ~isempty(entry.document) && isvalid(entry.document) && ...
                        entry.document.Selected
                    selected(end + 1, 1) = string(keys{index}); %#ok<AGROW>
                end
            end
            if isempty(selected)
                return
            end
            if any(selected == this.ActiveSessionId)
                key = this.ActiveSessionId;
            else
                key = selected(end);
            end
        end

        function deleteEntryListeners(~, entry)
            listenerFields = ["closeListener", "selectionListener"];
            for index = 1:numel(listenerFields)
                field = char(listenerFields(index));
                if isfield(entry, field) && ~isempty(entry.(field)) && ...
                        isvalid(entry.(field))
                    delete(entry.(field));
                end
            end
        end
    end
end
