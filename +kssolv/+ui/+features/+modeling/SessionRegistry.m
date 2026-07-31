classdef SessionRegistry < handle
    %SESSIONREGISTRY Tracks open structure documents and their model sessions.

    properties (Access = private)
        Sessions containers.Map
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
                delete(previous.closeListener);
            end
            closeListener = addlistener(document, ...
                "ObjectBeingDestroyed", ...
                @(~, ~)this.unregister(sessionId));
            this.Sessions(key) = struct( ...
                "display", display, ...
                "document", document, ...
                "closeListener", closeListener);
            notify(this, "SessionCountChanged");
        end

        function unregister(this, sessionId)
            key = char(string(sessionId));
            if ~isKey(this.Sessions, key)
                return
            end
            entry = this.Sessions(key);
            remove(this.Sessions, key);
            if ~isempty(entry.closeListener) && isvalid(entry.closeListener)
                delete(entry.closeListener);
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
                            display = entry.display;
                            return
                        end
                    end
                end
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
                if ~isempty(entry.closeListener) && ...
                        isvalid(entry.closeListener)
                    delete(entry.closeListener);
                end
            end
            this.Sessions = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
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
                    if ~isempty(entry.closeListener) && ...
                            isvalid(entry.closeListener)
                        delete(entry.closeListener);
                    end
                    remove(this.Sessions, keys{index});
                    changed = true;
                end
            end
            if changed
                notify(this, "SessionCountChanged");
            end
        end
    end
end
