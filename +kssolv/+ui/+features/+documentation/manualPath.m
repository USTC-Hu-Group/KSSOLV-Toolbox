function path = manualPath(locale)
%MANUALPATH Resolve the bundled PDF for the active application language.
arguments
    locale (1,1) string = string(kssolv.ui.util.Localizer.getInstance().currentLocale)
end
language = "en";
if startsWith(lower(replace(locale, '-', '_')), "zh")
    language = "zh-CN";
end
path = fullfile(KSSOLV_Toolbox.RootDirectory, 'docs', 'manuals', ...
    "KSSOLV_Toolbox_User_Manual_" + language + ".pdf");
if ~isfile(path)
    error('KSSOLV:Documentation:MissingManual', ...
        'The bundled user manual is missing: %s', path);
end
end
