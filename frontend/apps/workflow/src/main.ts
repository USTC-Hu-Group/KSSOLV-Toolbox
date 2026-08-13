import { createApp } from 'vue';

import { installEmbeddedBrowserZoomGuard } from '@kssolv/matlab-bridge';

import './style.css';
import App from './App.vue';

installEmbeddedBrowserZoomGuard();

// 将 MATLAB 和 setup 添加到 window 对象以使它们全局可访问
declare global {
  interface Window {
    MATLAB: any;
    setup: (htmlComponent: any) => void;
    debug: () => void;
  }
}

window.MATLAB = undefined; // 初始化为 undefined 或其他默认值

window.setup = function (htmlComponent: any): void {
  window.MATLAB = htmlComponent;
  createApp(App).mount('#app');
};

window.debug = function () {
  const matlab = {
    Data: '',
    addEventListener: function (...args: unknown[]) {
      console.log('addEventListener called with: ', ...args);
    },
    sendEventToMATLAB: function (...args: unknown[]) {
      console.log('sendEventToMATLAB called with: ', ...args);
    },
  };
  window.setup(matlab);
};
