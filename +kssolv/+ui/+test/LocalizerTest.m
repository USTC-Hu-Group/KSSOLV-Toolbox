function LocalizerTest()
%LOCALIZERTEST 测试本地化文件的读取

import kssolv.ui.util.Localizer.*
localizer = getInstance();
originalLocale = string(localizer.currentLocale);
cleanup = onCleanup(@()setLocale(originalLocale));

% 获取默认的本地化翻译
disp(message('KSSOLV:toolbox:WelcomeMessage'));

% 切换至另一种语言
setLocale('en_US');
disp(message('KSSOLV:toolbox:WelcomeMessage'));

% 再次切换语言
setLocale('zh_CN');
disp(message('KSSOLV:toolbox:WelcomeMessage'));
clear cleanup
end
