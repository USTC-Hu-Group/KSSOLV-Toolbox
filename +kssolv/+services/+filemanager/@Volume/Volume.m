classdef Volume < kssolv.services.filemanager.AbstractItem
    %VOLUME Project-tree item for CHGCAR, Cube, and XSF scalar grids.

    methods
        function this = Volume(label, type)
            arguments
                label string = "Volume"
                type string = "Volume"
            end
            this = this@kssolv.services.filemanager.AbstractItem(label, type);
        end

        function showVolumeDisplay(this)
            if isempty(this.data) || ~isprop(this.data, "filePath")
                error("KSSOLV:FileManager:Volume:MissingData", ...
                    "The selected volume item has no readable source.");
            end
            kssolv.ui.components.figuredocument.VolumeDisplay( ...
                this.data.filePath, this.name).Display();
        end

        function importedFileCount = importVolumeFromFile(this)
            import kssolv.ui.util.Localizer.message
            [files, folder] = ...
                kssolv.services.fileparser.FileDialogRegistry. ...
                chooseMany( ...
                kssolv.services.fileparser.FileDialogRegistry. ...
                volumeFilters(), ...
                message("KSSOLV:dialogs:ImportVolumeFromFile"), ...
                "LastVolumeImportFolder");
            if isempty(files)
                importedFileCount = 0;
                return
            end
            importedFileCount = 0;
            failures = strings(1, 0);
            for index = 1:numel(files)
                filePath = fullfile(folder, files{index});
                [~, label, extension] = fileparts(files{index});
                if any(lower(string(extension)) == [".gz", ".bz2"])
                    [~, label] = fileparts(label);
                end
                item = kssolv.services.filemanager.Volume(label);
                try
                    item.data = ...
                        kssolv.services.fileparser.VolumeIO(filePath);
                catch exception
                    warning("KSSOLV:FileManager:Volume:ImportFailed", ...
                        "Unable to import '%s' [%s]: %s", filePath, ...
                        exception.identifier, exception.message);
                    failures(end + 1) = sprintf("%s [%s]: %s", ...
                        files{index}, exception.identifier, ...
                        exception.message); %#ok<AGROW>
                    continue
                end
                this.addChildrenItem(item);
                importedFileCount = importedFileCount + 1;
                item.showVolumeDisplay();
            end
            if ~isempty(failures)
                this.showImportFailures(failures);
            end
        end
    end

    methods (Static, Access = private)
        function showImportFailures(failures)
            import kssolv.ui.util.Localizer.message
            maximumVisible = 8;
            visible = failures(1:min(numel(failures), maximumVisible));
            if numel(failures) > maximumVisible
                visible(end + 1) = sprintf(message( ...
                    "KSSOLV:dialogs:VolumeImportMoreFailures"), ...
                    numel(failures) - maximumVisible);
            end
            detail = sprintf(message( ...
                "KSSOLV:dialogs:VolumeImportFailedMessage"), ...
                strjoin(visible, newline));
            title = message( ...
                "KSSOLV:dialogs:VolumeImportFailedTitle");
            try
                app = kssolv.ui.util.DataStorage.getData( ...
                    "AppContainer");
                uialert(app, detail, title);
            catch exception
                warning("KSSOLV:FileManager:Volume:AlertFailed", ...
                    "Unable to show the volume import alert [%s]: %s", ...
                    exception.identifier, exception.message);
            end
        end
    end
end
