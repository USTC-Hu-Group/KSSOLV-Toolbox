function value=is_redox_active_intercalation(element)
%IS_REDOX_ACTIVE_INTERCALATION Whether an element is a battery redox center.
if ischar(element)||isstring(element)
    symbol=string(element);
else
    symbol=string(element.symbol);
end
value=any(symbol==["Ti","V","Cr","Mn","Fe","Co","Ni","Cu", ...
    "Nb","Mo","W","Sb","Sn","Bi"]);
end
