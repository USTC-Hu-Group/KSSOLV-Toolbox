classdef SessionRegistry < handle
    %SESSIONREGISTRY Tracks open structure documents and their model sessions.

    properties (Access = private)
        Sessions containers.Map
        ActiveSessionId string = ""
    end

    events
        SessionCountChanged
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
            this.noteSelection(sessionId);
            notify(this, "SessionCountChanged");
        end

        function unregister(this, sessionId)
            key = char(string(sessionId));
            if ~isKey(this.Sessions, key)
                return
            end
            entry = this.Sessions(key);
            remove(this.Sessions, key);
            this.deleteEntryListeners(entry);
            if this.ActiveSessionId == string(sessionId)
                this.ActiveSessionId = "";
            end
            notify(this, "SessionCountChanged");
        end

        function display = getCurrentDisplay(this)
            display = ...
                kssolv.ui.components.figuredocument.MoleculeDisplay.empty;
            this.removeInvalidSessions();
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
                            this.ActiveSessionId = string(key);
                            display = entry.display;
                            return
                        end
                    end
                end
            end
            selectedKey = this.selectedSessionKey();
            if selectedKey ~= ""
                this.ActiveSessionId = selectedKey;
                entry = this.Sessions(char(selectedKey));
                display = entry.display;
                return
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
        end

        function delete(this)
            this.clear();
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
            key = char(string(sessionId));
            if ~isKey(this.Sessions, key)
                return
            end
            entry = this.Sessions(key);
            if ~isempty(entry.document) && isvalid(entry.document) && ...
                    entry.document.Selected
                this.ActiveSessionId = string(sessionId);
            end
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
