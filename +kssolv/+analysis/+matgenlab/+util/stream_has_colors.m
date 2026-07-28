function tf = stream_has_colors(stream) %#ok<INUSD>
%STREAM_HAS_COLORS Whether a MATLAB output stream supports ANSI colors.
% MATLAB does not expose curses/terminfo capabilities for arbitrary streams;
% conservatively report false, matching pymatgen's non-TTY behavior.
tf = false;
end
