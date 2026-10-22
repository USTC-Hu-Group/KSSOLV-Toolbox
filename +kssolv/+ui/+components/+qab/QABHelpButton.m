classdef QABHelpButton < matlab.ui.internal.toolstrip.impl.QABPushButton
    %QABHelpButton 自定义图标的 QAB 帮助按钮

    % 修改自 matlab.ui.internal.toolstrip.qab.QABHelpButton

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties
        DocName = '';
    end

    properties (Access = private)
        ClassAnchor = '<a href="matlab:doc matlab.ui.internal.toolstrip.qab.QABHelpButton">QABHelpButton</a>';
    end

    methods
        %% Constructor
        function this = QABHelpButton(varargin)
            this = this@matlab.ui.internal.toolstrip.impl.QABPushButton(varargin{:});
            this.setPropertyDefaults();
        end

        %% Get/Set Methods
        function value = get.DocName(this)
            value = this.DocName;
        end

        function set.DocName(this, value)
            if ~ischar(value) && ~isstring(value)
                throw(MException(message('MATLAB:string')));
            end

            this.DocName = value;
        end
    end

    methods (Hidden = true)
        function openHelp(this)
            if isKSSOLVOnline(), return, end
            if isempty(this.DocName)
                doc;
                return;
            end

            tlbxSplt = strsplit(this.DocName, '/');
            if numel(tlbxSplt) > 1
                productShortName = tlbxSplt{1};
                topicId = strjoin(tlbxSplt(2:end),'/');

                try
                    helpview(productShortName, topicId);
                catch err
                    if isequal(err.identifier, 'MATLAB:helpview:InvalidPathArg') || ...
                            isequal(err.identifier, 'MATLAB:helpview:TopicPathDoesNotExist')
                        doc(this.DocName);
                    else
                        rethrow(err);
                    end
                end
            else
                doc(this.DocName);
            end
        end
    end

    methods (Access = protected)
        function set_Icon(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'Icon', this.ClassAnchor)));
        end

        function set_IconOverride(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'IconOverride', this.ClassAnchor)));
        end

        function set_QuickAccessIcon(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'QuickAccessIcon', this.ClassAnchor)));
        end

        function set_Text(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'Text', this.ClassAnchor)));
        end

        function set_TextOverride(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'TextOverride', this.ClassAnchor)));
        end

        function set_Description(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'Description', this.ClassAnchor)));
        end

        function set_DescriptionOverride(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'DescriptionOverride', this.ClassAnchor)));
        end

        function set_Enabled(this, ~)
            throw(MException(message('MATLAB:class:SetProhibited', 'Enabled', this.ClassAnchor)));
        end

        function ActionPerformedCallback(this, ~, ~)
            % Overloaded method defined in @control
            if isempty(this.ButtonPushedFcn)
                this.openHelp();
            end
        end
    end

    methods (Access = private)
        function setPropertyDefaults(this)
            action = this.getAction();

            % Set Icon property
            action.Icon = matlab.ui.internal.toolstrip.Icon.HELP_16;
            action.QuickAccessIcon = matlab.ui.internal.toolstrip.Icon('help');

            % Set Text property
            action.Text = message('MATLAB:toolstrip:qab:helpLabel').getString;

            % Set Description property
            action.Description = message('MATLAB:toolstrip:qab:helpDescription').getString;

            % Set Enabled property
            action.Enabled = true;

            % Set Tag property
            this.Tag = 'QABHelpButton';
        end
    end

    methods (Hidden)
        function qePushed(this)
            % qePushed(this) simulates a user pressing a button in the UI.
            % Triggers the "ButtonPushed" event.
            type = 'ButtonPushed';
            if ~isempty(this.ButtonPushedFcn)
                internal.Callback.execute(this.ButtonPushedFcn, getAction(this));
            else
                this.openHelp();
            end

            this.notify(type);
        end
    end
end
