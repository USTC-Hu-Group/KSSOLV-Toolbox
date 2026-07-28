classdef XSFTransport
    %XSFTRANSPORT UTF-8 text transport including Monty-style compression.

    methods (Static)
        function text = read_text(filename)
            text = kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(filename);
        end

        function write_text(filename, text)
            kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                write_text(filename, text);
        end

        function text = read_stream(stream)
            if ~isnumeric(stream) || ~isscalar(stream) || stream < 0
                error("KSSOLV:Matgenlab:XSF:BinaryStream", ...
                    "XSF.parse_file requires an open binary file identifier.");
            end
            position = ftell(stream);
            if position < 0
                error("KSSOLV:Matgenlab:XSF:BinaryStream", ...
                    "XSF.parse_file requires an open binary file identifier.");
            end
            bytes = fread(stream, Inf, "*uint8");
            text = string(native2unicode(bytes.', "UTF-8"));
        end
    end
end
