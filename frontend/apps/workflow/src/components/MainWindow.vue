<script setup lang="ts">
  import type { Cell } from '@antv/x6';
  import { Graph, Path } from '@antv/x6';
  import { Clipboard } from '@antv/x6-plugin-clipboard';
  import { History } from '@antv/x6-plugin-history';
  import { Keyboard } from '@antv/x6-plugin-keyboard';
  import { MiniMap } from '@antv/x6-plugin-minimap';
  import { Selection } from '@antv/x6-plugin-selection';
  import { Snapline } from '@antv/x6-plugin-snapline';
  import { getTeleport, register } from '@antv/x6-vue-shape';
  import { onMounted, onUnmounted, ref } from 'vue';

  import DagNode from './DagNode.vue';
  import dagData from '../assets/data/dag.json';

  const container = ref<HTMLElement | null>(null);
  const minimap = ref<HTMLElement | null>(null);
  const enableMiniMap = ref(false);

  // 添加响应式的宽高
  const containerSize = ref({
    width: document.documentElement.clientWidth,
    height: document.documentElement.clientHeight,
  });

  // 添加 resize 处理函数
  const handleResize = () => {
    containerSize.value = {
      width: document.documentElement.clientWidth,
      height: document.documentElement.clientHeight,
    };
    if (graph) {
      graph.resize(containerSize.value.width, containerSize.value.height);
    }
  };

  // 获取Teleport组件
  const TeleportContainer = getTeleport();

  declare const MATLAB: any;

  // 注册自定义节点
  register({
    component: DagNode,
    height: 36,
    ports: {
      groups: {
        bottom: {
          attrs: {
            circle: {
              fill: '#fff',
              magnet: true,
              r: 4,
              stroke: '#C2C8D5',
              strokeWidth: 1,
            },
          },
          position: 'bottom',
        },
        top: {
          attrs: {
            circle: {
              fill: '#fff',
              magnet: true,
              r: 4,
              stroke: '#C2C8D5',
              strokeWidth: 1,
            },
          },
          position: 'top',
        },
      },
    },
    shape: 'dag-node',
    width: 180,
  });

  // 注册自定义的 edge
  Graph.registerEdge(
    'dag-edge',
    {
      attrs: {
        line: {
          stroke: '#C2C8D5',
          strokeWidth: 1,
          targetMarker: null,
        },
      },
      inherit: 'edge',
    },
    true,
  );

  // 注册自定义的 connector
  Graph.registerConnector(
    'dag-connector',
    (s, e) => {
      const offset = 4;
      const deltaY = Math.abs(e.y - s.y);
      const control = Math.floor((deltaY / 3) * 2);

      const v1 = { x: s.x, y: s.y + offset + control };
      const v2 = { x: e.x, y: e.y - offset - control };

      return Path.normalize(
        `M ${s.x} ${s.y}
       L ${s.x} ${s.y + offset}
       C ${v1.x} ${v1.y} ${v2.x} ${v2.y} ${e.x} ${e.y - offset}
       L ${e.x} ${e.y}
      `,
      );
    },
    true,
  );

  let graph: Graph;

  onMounted(() => {
    // 添加窗口 resize 事件监听
    window.addEventListener('resize', handleResize);

    graph = new Graph({
      autoResize: true,
      connecting: {
        allowBlank: false,
        allowLoop: false,
        anchor: 'center',
        connectionPoint: 'anchor',
        connector: 'dag-connector',
        validateMagnet({ magnet }) {
          return magnet.getAttribute('port-group') !== 'top';
        },
        createEdge: function () {
          return this.addEdge({
            attrs: {
              line: {
                strokeDasharray: '5 5',
              },
            },
            shape: 'dag-edge',
            zIndex: -1,
          });
        },
        router: {
          name: 'orth',
        },
        snap: true,
      },
      container: container.value!,
      grid: {
        args: [
          {
            color: '#eee', // 主网格线颜色
            thickness: 1, // 主网格线宽度
          },
          {
            color: '#ddd', // 次网格线颜色
            factor: 4, // 次网格线宽度
            thickness: 1, // 主次网格线间隔
          },
        ],
        type: 'doubleMesh',
        visible: true,
      },
      height: containerSize.value.height,
      width: containerSize.value.width,
      highlighting: {
        magnetAdsorbed: {
          args: {
            attrs: {
              fill: '#fff',
              stroke: '#31d0c6',
              strokeWidth: 4,
            },
          },
          name: 'stroke',
        },
      },
      mousewheel: {
        enabled: true,
        factor: 1.1,
        maxScale: 2.5,
        minScale: 0.5,
      },
      panning: true,
      virtual: true,
    });

    // 启用框选功能
    graph.use(
      new Selection({
        modifiers: 'shift',
        multiple: true,
        rubberEdge: true,
        rubberNode: true,
        rubberband: true,
      }),
    );

    // 启用辅助线功能
    graph.use(
      new Snapline({
        enabled: true,
      }),
    );

    // 启用复制粘贴功能
    graph.use(
      new Clipboard({
        enabled: true,
      }),
    );

    // 启用快捷键功能
    graph.use(
      new Keyboard({
        enabled: true,
        global: true,
      }),
    );

    // 启用撤销重做功能
    graph.use(
      new History({
        enabled: true,
      }),
    );

    // 启用小地图功能
    graph.use(
      new MiniMap({
        container: minimap.value!,
        height: 160,
        padding: 10,
        width: 200,
      }),
    );

    // 绑定复制快捷键
    const graphCopy = () => {
      const cells = graph.getSelectedCells();
      if (cells.length > 0) graph.copy(cells);
    };
    graph.bindKey(['ctrl+c', 'cmd+c'], () => {
      graphCopy();
      return false;
    });

    // 绑定粘贴快捷键
    const graphPaste = () => {
      if (!graph.isClipboardEmpty()) {
        const cells = graph.paste({ offset: 32 });
        graph.cleanSelection();
        graph.select(cells);
      }
    };
    graph.bindKey(['ctrl+v', 'cmd+v'], () => {
      graphPaste();
      return false;
    });

    // 绑定撤销快捷键
    const graphUndo = () => {
      if (graph.canUndo()) graph.undo();
    };
    graph.bindKey(['ctrl+z', 'cmd+z'], () => {
      graphUndo();
      return false;
    });

    // 绑定重做快捷键
    const graphRedo = () => {
      if (graph.canRedo()) graph.redo();
    };
    graph.bindKey(['ctrl+shift+z', 'cmd+shift+z'], () => {
      graphRedo();
      return false;
    });

    // 绑定全选快捷键
    const graphSelectAll = () => {
      const cells = graph.getCells();
      if (cells.length > 0) graph.select(cells);
    };
    graph.bindKey(['ctrl+a', 'cmd+a'], () => {
      graphSelectAll();
      return false;
    });

    // 绑定开启关闭小地图快捷键
    const graphEnableMiniMap = () => {
      enableMiniMap.value = !enableMiniMap.value;
    };
    graph.bindKey(['ctrl+m', 'cmd+m'], () => {
      graphEnableMiniMap();
      return false;
    });

    // 绑定自动缩放快捷键
    const graphZoomToFit = () => {
      graph.centerContent();
      graph.zoomToFit({ maxScale: 1.2, padding: 5 });
    };
    graph.bindKey('space', () => {
      graphZoomToFit();
    });

    // 缩小画布
    const graphZoomIn = () => {
      graph.zoom(0.2);
    };

    // 放大画布
    const graphZoomOut = () => {
      graph.zoom(-0.2);
    };

    // 绑定删除快捷键
    const graphRemoveSelectedCells = () => {
      const cells = graph.getSelectedCells();
      if (cells.length > 0) graph.removeCells(cells);
    };
    graph.bindKey('backspace', () => {
      graphRemoveSelectedCells();
    });

    // 绑定增加节点顶部连接桩的快捷键
    const graphAddTopPort = () => {
      const cells = graph.getSelectedCells();
      cells.forEach((cell) => {
        if (cell.isNode()) {
          cell.addPort({
            group: 'top',
          });
        }
      });
    };
    graph.bindKey('ctrl+shift+i', () => {
      graphAddTopPort();
    });

    // 绑定减少节点顶部连接桩的快捷键
    const graphRemoveTopPort = () => {
      const cells = graph.getSelectedCells();
      cells.forEach((cell) => {
        if (cell.isNode()) {
          const ports = cell.getPorts();
          const index = ports
            .slice()
            .reverse()
            .findIndex((port) => port.group === 'top');

          if (index !== -1) {
            // 计算原数组中的实际索引位置
            const actualIndex = ports.length - 1 - index;
            cell.removePort(ports[actualIndex]);
          }
        }
      });
    };
    graph.bindKey('ctrl+shift+o', () => {
      graphRemoveTopPort();
    });

    // 绑定增加节点底部连接桩的快捷键
    const graphAddBottomPort = () => {
      const cells = graph.getSelectedCells();
      cells.forEach((cell) => {
        if (cell.isNode()) {
          cell.addPort({
            group: 'bottom',
          });
        }
      });
    };
    graph.bindKey('ctrl+shift+k', () => {
      graphAddBottomPort();
    });

    // 绑定减少节点底部连接桩的快捷键
    const graphRemoveBottomPort = () => {
      const cells = graph.getSelectedCells();
      cells.forEach((cell) => {
        if (cell.isNode()) {
          const ports = cell.getPorts();
          const index = ports
            .slice()
            .reverse()
            .findIndex((port) => port.group === 'bottom');

          if (index !== -1) {
            // 计算原数组中的实际索引位置
            const actualIndex = ports.length - 1 - index;
            cell.removePort(ports[actualIndex]);
          }
        }
      });
    };
    graph.bindKey('ctrl+shift+l', () => {
      graphRemoveBottomPort();
    });

    // 绑定增加节点的快捷键
    const graphAddNode = () => {
      let lastX, lastY;
      let needCenterContent = false;
      // 若当前存在框选的节点，获取最后一个节点的坐标
      const cells = graph.getSelectedCells();
      const node = cells
        .slice()
        .reverse()
        .find((cell) => cell.isNode());
      if (node) {
        // 若存在框选的节点
        lastX = node.position().x;
        lastY = node.position().y;
      } else {
        // 没有框选任何节点
        const nodes = graph.getNodes();
        if (nodes.length) {
          // 若画布上存在节点
          const node = nodes[nodes.length - 1];
          lastX = node.position().x;
          lastY = node.position().y;
        } else {
          // 画布上尚没有节点
          lastX = document.documentElement.clientWidth / 2;
          lastY = document.documentElement.clientHeight / 2;
          needCenterContent = true;
        }
      }
      const newNode = graph.addNode({
        shape: 'dag-node',
        data: {
          label: '新增节点',
          status: 'default',
        },
        x: lastX + 30,
        y: lastY + 30,
      });

      if (needCenterContent) {
        graph.centerContent();
      }

      // 选中新创建的节点
      graph.cleanSelection();
      graph.select(newNode);
    };
    graph.bindKey('ctrl+n', () => {
      graphAddNode();
    });

    // 导出为 JSON
    const graphExportToJSON = () => {
      let object = graph.toJSON();
      let exportedJSON = JSON.stringify(object);
      if (typeof MATLAB !== 'undefined') {
        MATLAB.sendEventToMATLAB('GraphExportToJSON', exportedJSON);
      }
    };

    // 重命名节点的 label
    const graphRenameNodeLabel = (event: any) => {
      let eventData = JSON.parse(event.Data);
      const node = graph.getCellById(eventData.nodeID);
      if (node && node.isNode()) {
        const data = node.getData();
        data.label = eventData.newLabel;

        // 使用 setData 更新数据
        node.setData({ label: eventData.newLabel, status: data.status });
        // 强制更新节点
        node.updateAttrs({
          label: {
            text: eventData.newLabel,
          },
        });
        // 触发节点更新事件
        node.notify('change:data', { current: node.getData(), previous: data });
        graphExportToJSON();
      }
    };

    // 更新节点的 status
    const graphUpdateNodeStatus = (event: any) => {
      let eventData = JSON.parse(event.Data);
      const node = graph.getCellById(eventData.nodeID);
      if (node && node.isNode()) {
        const data = node.getData();
        data.status = eventData.newStatus;

        // 使用 setData 更新数据
        node.setData({ label: data.label, status: eventData.newStatus });
        // 强制更新节点
        node.updateAttrs({
          status: eventData.newStatus,
        });
        // 触发节点更新事件
        node.notify('change:data', { current: node.getData(), previous: data });
        graphExportToJSON();
      }
    };

    // 对当前选中节点，向 MATLAB 发送打开设置窗口（Config Editor）的事件
    const graphOpenSettingsWindow = () => {
      // 选中的节点或画布上的第一个节点
      const selectedNode = graph.getSelectedCells().find((cell) => cell.isNode());
      const node = selectedNode || graph.getNodes()[0];

      if (!node) return;

      // 若之前没有选中节点，则选中该节点
      if (!selectedNode) {
        graph.select(node);
      }

      // 向 MATLAB 发送事件，决定打开节点设置窗口
      if (typeof MATLAB !== 'undefined') {
        MATLAB.sendEventToMATLAB('OpenSettingsWindow', node.id);
      }
    };
    graph.bindKey('ctrl+shift+s', () => {
      graphOpenSettingsWindow();
    });

    // 当 MATLAB 向工作流画布传递新的数据时
    const dataFromMATLABToHTML = () => {
      graph.fromJSON(JSON.parse(MATLAB.Data));
    };

    if (typeof MATLAB !== 'undefined') {
      MATLAB.addEventListener('DataChanged', dataFromMATLABToHTML);
      MATLAB.addEventListener('workflowCopy', graphCopy);
      MATLAB.addEventListener('workflowPaste', graphPaste);
      MATLAB.addEventListener('workflowUndo', graphUndo);
      MATLAB.addEventListener('workflowRedo', graphRedo);
      MATLAB.addEventListener('workflowSelectAll', graphSelectAll);
      MATLAB.addEventListener('workflowEnableMiniMap', graphEnableMiniMap);
      MATLAB.addEventListener('workflowZoomToFit', graphZoomToFit);
      MATLAB.addEventListener('workflowZoomIn', graphZoomIn);
      MATLAB.addEventListener('workflowZoomOut', graphZoomOut);
      MATLAB.addEventListener('workflowRemoveSelectedCells', graphRemoveSelectedCells);
      MATLAB.addEventListener('workflowAddTopPort', graphAddTopPort);
      MATLAB.addEventListener('workflowRemoveTopPort', graphRemoveTopPort);
      MATLAB.addEventListener('workflowAddBottomPort', graphAddBottomPort);
      MATLAB.addEventListener('workflowRemoveBottomPort', graphRemoveBottomPort);
      MATLAB.addEventListener('workflowAddNode', graphAddNode);
      MATLAB.addEventListener('workflowExportToJSON', graphExportToJSON);
      MATLAB.addEventListener('workflowRenameNodeLabel', graphRenameNodeLabel);
      MATLAB.addEventListener('workflowUpdateNodeStatus', graphUpdateNodeStatus);
      MATLAB.addEventListener('workflowOpenSettingsWindow', graphOpenSettingsWindow);
    }

    graph.on('edge:connected', ({ edge }) => {
      edge.attr({
        line: {
          strokeDasharray: '',
        },
      });
    });

    graph.on('node:change:data', ({ node }) => {
      const edges = graph.getIncomingEdges(node);
      const { status } = node.getData();

      edges?.forEach((edge) => {
        if (status === 'running') {
          edge.attr('line/strokeDasharray', 5);
          edge.attr('line/style/animation', 'running-line 30s infinite linear');
        } else {
          edge.attr('line/strokeDasharray', '');
          edge.attr('line/style/animation', '');
        }
      });
    });

    graph.on('history:change', graphExportToJSON);

    // 初始化节点/边
    const init = (data: Cell.Metadata[]) => {
      const cells: Cell[] = [];

      data.forEach((item) => {
        if (item.shape === 'dag-node') cells.push(graph.createNode(item));
        else cells.push(graph.createEdge(item));
      });
      graph.resetCells(cells);
    };

    init(dagData);
    graph.centerContent();
    graph.zoomToFit({ padding: 10, maxScale: 1.2 });

    /*
  const targetNode = graph.addNode({
    data: {
      label: '初始节点',
      status: 'default',
    },
    shape: 'dag-node',
    x: 180,
    y: 140,
  });

  targetNode.setData({ status: 'failed' });
  */

    graph.centerContent();
  });

  onUnmounted(() => {
    // 在组件卸载时移除事件监听
    window.removeEventListener('resize', handleResize);
  });
</script>

<template>
  <div class="outer-container">
    <div ref="container" class="container"></div>
    <TeleportContainer />
  </div>

  <div v-show="enableMiniMap" ref="minimap" class="minimap"></div>
</template>

<style scoped>
  .outer-container {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    width: 100%;
    height: 100%;
  }

  .container {
    width: 100%;
    height: 100%;
    background-color: white;
  }

  :deep(.x6-widget-minimap) {
    background-color: whitesmoke;
  }

  .minimap {
    position: fixed;
    bottom: 20px;
    left: 20px;
    z-index: 999;
  }
</style>
