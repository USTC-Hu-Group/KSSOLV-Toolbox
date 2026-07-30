import { createApp } from 'vue';

import { matlabBridge, type MatlabHtmlComponent } from '@kssolv/matlab-bridge';

import App from './App.vue';
import { createDebugVolume, shouldUseDebugVolume } from './state/debugVolume';
import { useVolumeStore } from './state/volumeStore';
import './style.css';

declare global {
  interface Window {
    MATLAB?: MatlabHtmlComponent;
    setup: (htmlComponent: MatlabHtmlComponent) => void;
  }
}

window.setup = (htmlComponent: MatlabHtmlComponent): void => {
  window.MATLAB = htmlComponent;
  matlabBridge.attach(htmlComponent);
  matlabBridge.emit('volume:ready', { schemaVersion: '1.0' });
};

const app = createApp(App);
app.mount('#app');

if (shouldUseDebugVolume(window.location.search, matlabBridge.connected)) {
  const { scene, buffer } = createDebugVolume();
  useVolumeStore().setScene(scene);
  useVolumeStore().setChannelBytes(scene.channels[0].transport.transferId, buffer);
}
