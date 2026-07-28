classdef VaspDoc
    %VASPDOC Fetch and render VASP Wiki parameter documentation.

    properties
        url_template (1, 1) string = ...
            "https://www.vasp.at/wiki/index.php/%s"
    end

    methods
        function print_help(~, tag)
            fprintf("%s\n", ...
                kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                get_help(tag));
        end

        function print_jupyter_help(~, tag)
            % MATLAB Live scripts render the returned markup as text when no
            % notebook HTML display service is available.
            fprintf("%s\n", ...
                kssolv.analysis.matgenlab.io.vasp.help.VaspDoc. ...
                get_help(tag, "html"));
        end
    end

    methods (Static)
        function output = get_help(tag, fmt)
            if nargin < 2, fmt = "text"; end
            tag = upper(string(tag));
            url = "https://www.vasp.at/wiki/index.php/" + tag;
            document = fetchText(url);
            main = extractMainDocument(document);
            if strcmpi(fmt, "text")
                output = htmlToText(main);
            else
                output = main;
            end
        end

        function tags = get_incar_tags()
            url = "https://www.vasp.at/wiki/api.php?" + ...
                "action=query&list=categorymembers" + ...
                "&cmtitle=Category:INCAR_tag" + ...
                "&cmlimit=500&format=json";
            tags = strings(1, 0);
            nextUrl = url;
            while strlength(nextUrl) > 0
                response = jsondecode(fetchText(nextUrl));
                members = response.query.categorymembers;
                if ~isempty(members)
                    tags = [tags, reshape(string( ...
                        {members.title}), 1, [])]; %#ok<AGROW>
                end
                nextUrl = "";
                if isfield(response, "continue") && ...
                        isfield(response.continue, "cmcontinue")
                    token = string(response.continue.cmcontinue);
                    token = replace(token, "%", "%25");
                    token = replace(token, "|", "%7C");
                    token = replace(token, " ", "%20");
                    nextUrl = url + "&cmcontinue=" + token;
                end
            end
        end

        function set_transport(transport)
            arguments
                transport = []
            end
            transportStore("set", transport);
        end
    end
end

function text = fetchText(url)
transport = transportStore("get");
if ~isempty(transport)
    result = transport(url);
    if isstruct(result) && isfield(result, "text")
        result = result.text;
    end
    text = string(result);
    return
end
options = weboptions("Timeout", 60, "ContentType", "text");
text = string(webread(url, options));
end

function value = transportStore(action, replacement)
persistent transport
if nargin > 1 && action == "set"
    transport = replacement;
end
value = transport;
end

function main = extractMainDocument(document)
document = string(document);
startToken = regexp(document, ...
    '<(?:div|main)[^>]*id=["'']mw-content-text["''][^>]*>', ...
    "start", "once");
if isempty(startToken)
    error("KSSOLV:Matgenlab:VaspHelp:Content", ...
        "VASP Wiki response has no mw-content-text element.");
end
tail = extractAfter(document, startToken - 1);
stopToken = regexp(tail, ...
    '<div[^>]*class=["''][^"'']*printfooter|</main>', ...
    "start", "once");
if isempty(stopToken)
    main = tail;
else
    main = extractBefore(tail, stopToken);
end
end

function text = htmlToText(html)
text = regexprep(html, "(?is)<(script|style)\b[^>]*>.*?</\1>", "");
text = regexprep(text, "(?i)<br\s*/?>|</p>|</h[1-6]>|</li>|</tr>", newline);
text = regexprep(text, "(?s)<[^>]+>", "");
text = replace(text, ["&nbsp;", "&amp;", "&lt;", "&gt;", "&quot;", "&#39;"], ...
    [" ", "&", "<", ">", """", "'"]);
text = regexprep(text, "[ \t]+\n", newline);
text = regexprep(text, "\n{3,}", sprintf("\n\n"));
text = strtrim(text);
end
