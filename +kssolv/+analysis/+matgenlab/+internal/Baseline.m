classdef Baseline
    %BASELINE Immutable upstream compatibility baseline.

    properties (Constant)
        PymatgenVersion string = "2026.5.4"
        PymatgenTag string = "v2026.5.4"
        PymatgenCommit string = "8495e941504cd5123701635b6572942c78d9589c"

        PymatgenCoreTag string = "v2026.7.24"
        % The tagged source currently retains this project metadata value.
        PymatgenCoreMetadataVersion string = "2026.7.16"
        PymatgenCoreCommit string = "c71faa7a95df9bbcd20cb3d14ff112d0f72d8e39"

        MinimumMATLABRelease string = "R2024a"
    end
end
