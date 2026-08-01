const statusElement = document.getElementById('status');
const loadingElement = document.getElementById('loading');

let viewerPromise = null;
let viewer = null;
let queuedPayload = null;
let queuedCommand = null;
let currentPayload = null;
let currentObjectUrl = null;
let representation = 'Ribbon';
let colorMode = 'Confidence';

function postEvent(type, detail = {}) {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.molecularYou) {
    window.webkit.messageHandlers.molecularYou.postMessage({ type, ...detail });
  }
}

function setStatus(message) { statusElement.textContent = message; }

function setLoading(isLoading, message = 'Loading AlphaFold structure') {
  loadingElement.textContent = message;
  loadingElement.classList.toggle('hidden', !isLoading);
}

async function ensureViewer() {
  if (viewer) return viewer;
  if (!viewerPromise) {
    viewerPromise = molstar.Viewer.create('app', {
      layoutIsExpanded: false,
      layoutShowControls: false,
      layoutShowRemoteState: false,
      layoutShowSequence: false,
      layoutShowLog: false,
      layoutShowLeftPanel: false,
      collapseRightPanel: true,
      viewportShowControls: true,
      viewportShowSettings: true,
      viewportShowSelectionMode: false,
      viewportShowAnimation: false,
      viewportShowTrajectoryControls: false,
      viewportShowExpand: false,
      viewportShowScreenshotControls: false,
      viewportBackgroundColor: '#020617',
      illumination: false,
      pixelScale: Math.min(window.devicePixelRatio || 1, 1.35)
    }).then(createdViewer => {
      viewer = createdViewer;
      postEvent('ready');
      setStatus('Mol* viewer ready');
      if (queuedPayload) {
        const payload = queuedPayload;
        queuedPayload = null;
        loadStructure(payload);
      }
      if (queuedCommand) {
        const command = queuedCommand;
        queuedCommand = null;
        applyCommand(command);
      }
      return viewer;
    }).catch(error => {
      setLoading(false);
      const message = String(error && error.message ? error.message : error);
      setStatus(`Mol* failed to initialize: ${message}`);
      postEvent('failed', { message });
      throw error;
    });
  }
  return viewerPromise;
}

async function clearViewer() {
  if (!viewer || !viewer.plugin) return;
  if (typeof viewer.plugin.clear === 'function') {
    await viewer.plugin.clear();
  }
}

function decodeStructure(payload) {
  const binary = atob(payload.dataBase64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return new TextDecoder('utf-8').decode(bytes);
}

function makeObjectUrl(mmcif) {
  if (currentObjectUrl) URL.revokeObjectURL(currentObjectUrl);
  currentObjectUrl = URL.createObjectURL(new Blob([mmcif], { type: 'chemical/x-mmcif' }));
  return currentObjectUrl;
}

async function loadStructureFromSource(source, payload) {
  await viewer.loadStructureFromUrl(source, payload.format || 'mmcif', false, {
    label: `${payload.name || payload.accession || 'AlphaFold reference'} (${payload.accession || 'AFDB'})`
  });
}

async function loadStructureFromData(payload) {
  const label = `${payload.name || payload.accession || 'AlphaFold reference'} (${payload.accession || 'AFDB'})`;
  await viewer.loadStructureFromData(decodeStructure(payload), payload.format || 'mmcif', {
    dataLabel: label
  });
}

async function loadStructure(payload) {
  currentPayload = payload;
  if (!payload || (!payload.url && !payload.dataBase64)) {
    setLoading(false);
    setStatus('No structure file was provided');
    postEvent('failed', { message: 'No structure file was provided' });
    return;
  }

  if (!viewer) {
    queuedPayload = payload;
    await ensureViewer();
    return;
  }

  try {
    setLoading(true, `Loading ${payload.name || payload.accession || 'protein'} from AlphaFold DB`);
    setStatus('Parsing mmCIF structure');

    await clearViewer();

    try {
      if (!payload.url) throw new Error('No readable mmCIF file URL was provided');
      await loadStructureFromSource(payload.url, payload);
    } catch (fileError) {
      if (!payload.dataBase64) throw fileError;
      setStatus('Retrying from in-memory mmCIF data');
      await clearViewer();
      await loadStructureFromData(payload);
    }

    fitStructureToViewport();
    setLoading(false);
    setStatus(`${payload.name || 'Protein'} rendered from cached AlphaFold mmCIF`);
    postEvent('loaded', { name: payload.name || '', accession: payload.accession || '', source: payload.url || '' });
  } catch (error) {
    setLoading(false);
    const message = String(error && error.message ? error.message : error);
    setStatus(`Failed to render structure: ${message}`);
    postEvent('failed', { message });
  }
}

function requestCameraReset() {
  try {
    if (viewer && viewer.plugin && viewer.plugin.canvas3d && typeof viewer.plugin.canvas3d.requestCameraReset === 'function') {
      if (typeof viewer.handleResize === 'function') viewer.handleResize();
      viewer.plugin.canvas3d.requestCameraReset();
    }
  } catch (error) {
    postEvent('warning', { message: String(error && error.message ? error.message : error) });
  }
}

function fitStructureToViewport() {
  requestCameraReset();
  window.requestAnimationFrame(() => requestCameraReset());
  window.setTimeout(() => requestCameraReset(), 250);
  window.setTimeout(() => requestCameraReset(), 800);
}

async function reloadCurrentStructure() {
  if (!currentPayload) return;
  await loadStructure(currentPayload);
}

function applyCommand(command) {
  if (!viewer) {
    queuedCommand = command;
    ensureViewer();
    return;
  }

  switch (command.type) {
    case 'resetCamera':
      requestCameraReset();
      setStatus('Camera reset');
      break;
    case 'centerStructure':
      requestCameraReset();
      setStatus('Structure centered');
      break;
    case 'setRepresentation':
      representation = command.value;
      setStatus(`${representation} selected. Mol* is rendering the real AlphaFold structure; detailed style editing remains available through Mol* viewport tools.`);
      postEvent('representationChanged', { value: representation });
      break;
    case 'setColorMode':
      colorMode = command.value;
      setStatus(`${colorMode} color mode selected. AlphaFold confidence coloring is used automatically when pLDDT annotations are present.`);
      postEvent('colorModeChanged', { value: colorMode });
      break;
    case 'toggleLabels':
      setStatus(command.value ? 'Use Mol* selection tools to inspect residue labels' : 'Selection labels hidden');
      postEvent('labelsChanged', { value: !!command.value });
      break;
    case 'focusResidue':
      setStatus(`Residue focus requested for ${command.chainID}${command.sequenceNumber}`);
      postEvent('focusRequested', { chainID: command.chainID, sequenceNumber: command.sequenceNumber });
      break;
    default:
      setStatus('Unknown viewer command');
  }
}

window.MolecularYou = { loadStructure, command: applyCommand, reloadCurrentStructure };

const pendingLoads = window.MolecularYouLoadQueue || [];
window.MolecularYouLoadQueue = [];
pendingLoads.forEach(payload => loadStructure(payload));

const pendingCommands = window.MolecularYouCommandQueue || [];
window.MolecularYouCommandQueue = [];
pendingCommands.forEach(command => applyCommand(command));

window.addEventListener('resize', () => { if (viewer && typeof viewer.handleResize === 'function') viewer.handleResize(); });
window.addEventListener('beforeunload', () => { if (currentObjectUrl) URL.revokeObjectURL(currentObjectUrl); });
ensureViewer();
