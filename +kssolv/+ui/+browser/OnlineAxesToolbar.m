classdef OnlineAxesToolbar
    %ONLINEAXESTOOLBAR Keep native axes tools with browser export actions.
    methods (Static)
        function toolbar = install(ax)
            toolbar = [];
            if ~isKSSOLVOnline() || ~isscalar(ax) || ...
                    ~isgraphics(ax) || ~isprop(ax, 'Toolbar')
                return
            end

            key = 'KSSOLVOnlineAxesToolbar';
            toolbar = ax.Toolbar;
            if isappdata(ax, key)
                installed = getappdata(ax, key);
                if isscalar(toolbar) && isvalid(toolbar) && ...
                        isequal(installed.Toolbar, toolbar) && ...
                        all(isvalid(installed.Buttons))
                    return
                end
            end

            % The automatic toolbar can be shared and its buttons are not
            % serialized. Ask MATLAB for a regular native default toolbar;
            % retain an existing explicit toolbar and its exploration modes.
            if isempty(toolbar) || ~isvalid(toolbar) || ...
                    ~strcmp(string(toolbar.Serializable), "on")
                toolbar = axtoolbar(ax, 'default');
            end

            tags = {'saveas', 'copyimage', 'copyvector'};
            actions = {'save', 'image', 'vector'};
            buttons = gobjects(0);
            for index = 1:numel(tags)
                button = findall(toolbar, 'Tag', tags{index});
                for child = reshape(button, 1, [])
                    action = actions{index};
                    child.ButtonPushedFcn = @(~, ~) ...
                        kssolv.ui.browser.OnlinePlotExport.open(ax, action);
                    if strcmp(action, 'vector')
                        child.Tooltip = 'Copy SVG (vector source)';
                    end
                    buttons(end + 1) = child; %#ok<AGROW>
                end
            end
            setappdata(ax, key, struct('Toolbar', toolbar, 'Buttons', buttons));
        end
    end
end
