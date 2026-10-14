classdef QABUndoButton < matlab.ui.internal.toolstrip.impl.QABPushButton
    %QABUndoButton 自定义图标的 QAB 撤销按钮

    % 修改自 matlab.ui.internal.toolstrip.qab.QABUndoButton

    %   开发者：杨柳
    %   版权 2025 合肥瀚海量子科技有限公司

    properties (Access = private)
        ClassAnchor = '<a href="matlab:doc matlab.ui.internal.toolstrip.qab.QABUndoButton">QABUndoButton</a>';
    end

    methods
        %% Constructor
        function this = QABUndoButton(varargin)
            this = this@matlab.ui.internal.toolstrip.impl.QABPushButton(varargin{:});
            this.setPropertyDefaults();
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
    end

    methods (Access = private)
        function setPropertyDefaults(this)
            action = this.getAction();

            % Set Icon property
            action.Icon = matlab.ui.internal.toolstrip.Icon('undo');
            action.QuickAccessIcon = matlab.ui.internal.toolstrip.Icon('undo');

            % Set Text property
            action.Text = message('MATLAB:toolstrip:qab:undoLabel').getString;

            % Set Description property
            action.Description = message('MATLAB:toolstrip:qab:undoDescription').getString;

            % Set Enabled property
            action.Enabled = true;

            % Set Tag property
            this.Tag = 'QABUndoButton';
        end
    end

    methods (Hidden)
        function qePushed(this)
            % qePushed(this) simulates a user pressing a button in the UI.
            % Triggers the "ButtonPushed" event.
            type = 'ButtonPushed';
            if ~isempty(this.ButtonPushedFcn)
                internal.Callback.execute(this.ButtonPushedFcn, getAction(this));
            end

            this.notify(type);
        end
    end
end
