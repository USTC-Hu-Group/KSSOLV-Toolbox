function quoted=shellQuote(value)
%SHELLQUOTE Quote one text scalar as a POSIX shell argument.

arguments
    value {mustBeTextScalar}
end

value=string(value);
singleQuote=string(char(39));
backslash=string(char(92));
escapedSingleQuote=singleQuote+backslash+singleQuote+singleQuote;
quoted=singleQuote+replace(value,singleQuote,escapedSingleQuote)+singleQuote;
end
