import 'camara_config.dart';

/// Genera el HTML completo con Three.js para renderizar modelos GLB
/// Este HTML es compartido entre web (iframe) y desktop (InAppWebView)
String buildThreeJsHtml(
  String modelUrl, {
  String scenarioModelUrl = '',
  String? backgroundColorHex,
  bool renderContinuously = true,
  bool isThumbnail = false,
}) {
  final bg = backgroundColorHex ?? VisorConfig.backgroundColorHex;
  final renderContinuouslyJs = renderContinuously ? 'true' : 'false';
  final camRoll = VisorConfig.cameraDefaultRoll;
  final camPitch = VisorConfig.cameraDefaultPitch;
  final camDist = VisorConfig.cameraDefaultDistance;
  final targetX = VisorConfig.cameraTargetX;
  final targetY = VisorConfig.cameraTargetY;
  final targetZ = VisorConfig.cameraTargetZ;
  final zoomMin = VisorConfig.zoomMin;
  final zoomMax = VisorConfig.zoomMax;
  final polarMin = VisorConfig.polarAngleMin;
  final polarMax = VisorConfig.polarAngleMax;

  return '''
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; overflow: hidden; background: $bg; }
  canvas { display: block; width: 100%; height: 100%; }
  #loading {
    position: absolute; top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    color: #FFD54F; font-family: sans-serif; font-size: 14px;
    text-align: center;
  }
  @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
</style>
</head>
<body>
<div id="loading">
  <div class="spinner"></div>
</div>

<script type="importmap">
{
  "imports": {
    "three": "https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.js",
    "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/"
  }
}
</script>

<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { EXRLoader } from 'three/addons/loaders/EXRLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { clone as cloneSkeletonSafe } from 'three/addons/utils/SkeletonUtils.js';

// --- Estado global ---
let scene, camera, renderer, controls;
let pmremGenerator = null;
let envMap = null;
let loadedModels = {};  // { id: THREE.Group }
let modelLoadVersions = {}; // { id: number }
let raycastRoots = new Set();
let animMixers = [];
let positionAnimations = {};
let clock = new THREE.Clock();
let raycaster = new THREE.Raycaster();
let pointer = new THREE.Vector2();
let renderRequested = false;
let activeAnimationModelIds = new Set();
const RENDER_CONTINUOUSLY = $renderContinuouslyJs;
const SHOW_HDRI_BACKGROUND = true; // HDRI como fondo
const IS_THUMBNAIL = ${isThumbnail.toString()}; // true si es miniatura, no cargar HDRI
const AMBIENT_LIGHT_INTENSITY = 2;
const ENV_MAP_INTENSITY = 1.9;
const MARKER_POSITION_JITTER_MIN = 0.03;
const MARKER_POSITION_JITTER_MAX = 0.16;

// --- Configuración inicial de cámara ---
const DEFAULT_CAM = {
  roll: $camRoll, pitch: $camPitch, distance: $camDist,
  targetX: $targetX, targetY: $targetY, targetZ: $targetZ
};

// --- Inicialización ---
function init() {
  scene = new THREE.Scene();
  scene.background = new THREE.Color('$bg');
  scene.add(new THREE.AmbientLight(0xffffff, AMBIENT_LIGHT_INTENSITY));

  camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100000);
  applyCameraOrbit(DEFAULT_CAM.roll, DEFAULT_CAM.pitch, DEFAULT_CAM.distance);

  renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1.5, 2.0));
  renderer.setSize(window.innerWidth, window.innerHeight);
  // Configuración de color space y tone mapping para mejor renderizado PBR
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping || THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  document.body.appendChild(renderer.domElement);
  renderer.domElement.addEventListener('pointerdown', onPointerDown);
  renderer.domElement.addEventListener('contextmenu', blockContextMenu);
  document.addEventListener('contextmenu', blockContextMenu);
  window.addEventListener('contextmenu', blockContextMenu);

  // Controles orbitales
  controls = new OrbitControls(camera, renderer.domElement);
  controls.target.set(DEFAULT_CAM.targetX, DEFAULT_CAM.targetY, DEFAULT_CAM.targetZ);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;
  controls.enablePan = false;
  controls.minDistance = $zoomMin;
  controls.maxDistance = $zoomMax;
  controls.minPolarAngle = THREE.MathUtils.degToRad($polarMin);
  controls.maxPolarAngle = THREE.MathUtils.degToRad($polarMax);
  controls.addEventListener('change', requestRender);
  controls.update();

  // PMREM Generator para convertir equirectangular a cubeMap
  pmremGenerator = new THREE.PMREMGenerator(renderer);
  pmremGenerator.compileEquirectangularShader();
  // Resize
  window.addEventListener('resize', onResize);

  // Cargar HDRI para iluminación y reflejos
  loadEnvironmentMap();

  // Ocultar loading
  document.getElementById('loading').style.display = 'none';

  // Cargar escenario base y tablero inicial si se proporcionaron.
  // Se cargan en paralelo para que el tablero no espere al escenario.
  const scenarioModelUrl = '$scenarioModelUrl';
  const initialModelUrl = '$modelUrl';
  if (scenarioModelUrl && scenarioModelUrl !== '') {
    loadModel('scenario', scenarioModelUrl, 0, 0, 0);
  }
  if (initialModelUrl && initialModelUrl !== '') {
    loadModel('main', initialModelUrl, 0, 0, 0);
  }

  if (RENDER_CONTINUOUSLY) {
    animate();
  } else {
    requestRender();
  }
}

function onResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
  requestRender();
}

function animate() {
  requestAnimationFrame(animate);
  renderFrame();
}

function renderFrame() {
  const delta = clock.getDelta();
  for (const mixer of animMixers) {
    mixer.update(delta);
  }
  const hasActivePositionAnimations = updatePositionAnimations();
  controls.update();
  renderer.render(scene, camera);
  if (
    !RENDER_CONTINUOUSLY &&
    (hasActivePositionAnimations || activeAnimationModelIds.size > 0)
  ) {
    requestRender();
  }
}

function requestRender() {
  if (RENDER_CONTINUOUSLY || renderRequested) {
    return;
  }

  renderRequested = true;
  requestAnimationFrame(() => {
    renderRequested = false;
    renderFrame();
  });
}

function easeOutCubic(t) {
  return 1 - Math.pow(1 - t, 3);
}

function hashString(value) {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function seededRange(seed, min, max) {
  const hash = hashString(seed);
  return min + (hash / 0xffffffff) * (max - min);
}

function markerJitterFor(id, coord) {
  if (!id.startsWith('lot_marker_')) {
    return null;
  }

  const seed = id + ':' + coord;
  const angle = seededRange(seed + ':angle', 0, Math.PI * 2);
  const radius = seededRange(
    seed + ':radius',
    MARKER_POSITION_JITTER_MIN,
    MARKER_POSITION_JITTER_MAX
  );
  return {
    x: Math.cos(angle) * radius,
    z: Math.sin(angle) * radius,
    rotationY: seededRange(seed + ':ry', 0, Math.PI * 2),
  };
}

function updatePositionAnimations() {
  const now = performance.now();
  let hasActiveAnimations = false;
  for (const id of Object.keys(positionAnimations)) {
    const animation = positionAnimations[id];
    const model = loadedModels[id];
    if (!model) {
      delete positionAnimations[id];
      continue;
    }

    const t = Math.min(1, (now - animation.startTime) / animation.durationMs);
    model.position.lerpVectors(
      animation.from,
      animation.to,
      easeOutCubic(t)
    );
    updateModelTransform(model);

    if (t >= 1) {
      model.position.copy(animation.to);
      updateModelTransform(model);
      delete positionAnimations[id];
      sendMessage('positionAnimationDone:' + id);
    } else {
      hasActiveAnimations = true;
    }
  }
  return hasActiveAnimations;
}

// --- Conversión de coordenadas esféricas (roll/pitch/distance) a cartesianas ---
function applyCameraOrbit(rollDeg, pitchDeg, distance) {
  const roll = THREE.MathUtils.degToRad(rollDeg);
  const pitch = THREE.MathUtils.degToRad(pitchDeg);
  const target = controls ? controls.target : new THREE.Vector3(DEFAULT_CAM.targetX, DEFAULT_CAM.targetY, DEFAULT_CAM.targetZ);
  camera.position.set(
    target.x + distance * Math.sin(pitch) * Math.sin(roll),
    target.y + distance * Math.cos(pitch),
    target.z + distance * Math.sin(pitch) * Math.cos(roll)
  );
  if (controls) controls.update();
}

// --- Carga de modelos GLB ---
const dracoLoader = new DRACOLoader();
dracoLoader.setDecoderPath('https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/libs/draco/');
const gltfLoader = new GLTFLoader();
gltfLoader.setDRACOLoader(dracoLoader);
const DEFAULT_PLAYER_TINT = '#202020';
const ALWAYS_RAYCAST_IDS = new Set(['main']);
const gltfCache = new Map();
const tilePositionCache = new Map();

function freezeStaticMatrices(model) {
  if (!model) {
    return;
  }

  model.traverse((node) => {
    node.updateMatrix();
    node.matrixAutoUpdate = false;
  });
  model.updateMatrixWorld(true);
  model.userData = model.userData || {};
  model.userData.staticMatricesFrozen = true;
}

function updateModelTransform(model) {
  if (!model || model.userData?.staticMatricesFrozen !== true) {
    return;
  }

  model.updateMatrix();
  model.updateMatrixWorld(true);
}

function loadGltfCached(url) {
  if (!gltfCache.has(url)) {
    gltfCache.set(url, new Promise((resolve, reject) => {
      gltfLoader.load(url, resolve, undefined, reject);
    }));
  }
  return gltfCache.get(url);
}

function cloneMaterialForInstance(material) {
  const cloned = material.clone();
  cloned.needsUpdate = true;
  return cloned;
}

function cloneModelForInstance(source) {
  const model = cloneSkeletonSafe(source);

  model.traverse((node) => {
    if (!node.isMesh) {
      return;
    }

    node.userData = {
      ...(node.userData || {}),
      _sharesCachedGeometry: true,
    };

    if (Array.isArray(node.material)) {
      node.material = node.material.map(cloneMaterialForInstance);
    } else if (node.material) {
      node.material = cloneMaterialForInstance(node.material);
    }
  });

  return model;
}

function tintPlayerMaterial(model, colorHex) {
  if (!model) {
    return;
  }

  const tintColor = colorHex || DEFAULT_PLAYER_TINT;
  model.traverse((node) => {
    if (!node.isMesh || !node.material) {
      return;
    }

    const materials = Array.isArray(node.material) ? node.material : [node.material];
    for (const material of materials) {
      if (!material || material.name !== 'playerTint' || !material.color) {
        continue;
      }
      material.userData = material.userData || {};
      if (material.userData.playerTintColor === tintColor) {
        continue;
      }

      material.color.set(tintColor);
      material.userData.playerTintColor = tintColor;
      material.needsUpdate = true;
    }
  });
}

function disposeObject3D(object) {
  if (!object) {
    return;
  }

  object.traverse((child) => {
    if (!child.isMesh) {
      return;
    }

    if (child.geometry && child.userData?._sharesCachedGeometry !== true) {
      child.geometry.dispose();
    }
    if (Array.isArray(child.material)) {
      child.material.forEach((material) => material && material.dispose && material.dispose());
    } else if (child.material && child.material.dispose) {
      child.material.dispose();
    }
  });
}

// --- Carga de HDRI (environment map) ---
function loadEnvironmentMap() {
  // En miniaturas no cargamos el HDRI completo, pero los materiales PBR
  // necesitan un environment map para no quedarse negros.
  if (IS_THUMBNAIL) {
    const roomEnvironment = new RoomEnvironment(renderer);
    const renderTarget = pmremGenerator.fromScene(roomEnvironment, 0.04);
    envMap = renderTarget.texture;
    scene.environment = envMap;
    roomEnvironment.dispose();
    return;
  }

  const exrLoader = new EXRLoader();
  const hdriPath = '/assets/pics/fondo_2k.exr'; // Ruta del HDRI desde raiz publica
  
  exrLoader.load(
    hdriPath,
    (texture) => {
      // Convertir equirectangular a envMap usando PMREMGenerator
      const renderTarget = pmremGenerator.fromEquirectangular(texture);
      envMap = renderTarget.texture;
      
      // Asignar como environment map para iluminación global y reflejos
      scene.environment = envMap;
      scene.background = envMap;
      Object.values(loadedModels).forEach(applyEnvironmentMapToModel);
      
      // Crear esfera visual del HDRI transformable
      const hdriGeometry = new THREE.SphereGeometry(1000, 64, 64);
      const hdriMaterial = new THREE.MeshBasicMaterial({
        map: texture,
        side: THREE.BackSide, // Invertir culling para verlo desde dentro
        toneMapped: false,
      });
      const hdriSphere = new THREE.Mesh(hdriGeometry, hdriMaterial);
      hdriSphere.name = 'hdriSphere';
      
      // Aplicar transformaciones
      hdriSphere.position.y = -0.8; // Location z
      hdriSphere.rotation.y = THREE.MathUtils.degToRad(310); // Rotation y: 18º
      hdriSphere.scale.set(1, 0.7, 1.6); // Scale: y=0.9, z=1.6 (x=1 por defecto)
      
      scene.add(hdriSphere);
      
      console.log('HDRI cargado correctamente con transformaciones');
      requestRender();
    },
    undefined,
    (error) => {
      console.error('Error cargando HDRI:', error);
    }
  );
}

// --- Aplicar environment map a materiales PBR ---
function applyEnvironmentMapToModel(model) {
  if (!model || !envMap) {
    return;
  }

  model.traverse((child) => {
    if (!child.isMesh || !child.material) {
      return;
    }

    const materials = Array.isArray(child.material) ? child.material : [child.material];
    for (const material of materials) {
      if (!material) continue;
      
      // Aplicar envMapIntensity para mejorar reflejos especialmente en materiales PBR
      if (material.envMapIntensity !== undefined) {
        material.envMapIntensity = ENV_MAP_INTENSITY;
        material.needsUpdate = true;
      }
    }
  });
}

function loadModel(id, url, x, y, z, onLoaded) {
  // Si ya existe un modelo con el mismo id, lo eliminamos antes de recargar.
  removeModel(id);
  const loadVersion = (modelLoadVersions[id] || 0) + 1;
  modelLoadVersions[id] = loadVersion;

  loadGltfCached(url)
    .then((gltf) => {
      if (modelLoadVersions[id] !== loadVersion) {
        return;
      }

      const model = cloneModelForInstance(gltf.scene);
      model.position.set(x, y, z);
      model.name = id;
      tintPlayerMaterial(model, DEFAULT_PLAYER_TINT);
      
      // Aplicar environment map y ajustar envMapIntensity para PBR
      applyEnvironmentMapToModel(model);
      
      scene.add(model);
      loadedModels[id] = model;
      if (id === 'main') {
        tilePositionCache.clear();
      }

      if (id === 'main' || id === 'scenario') {
        setObjectClickState(id, false);
      } else {
        setObjectClickState(id, true);
      }

      // Animaciones
      if (gltf.animations && gltf.animations.length > 0) {
        const mixer = new THREE.AnimationMixer(model);
        animMixers.push(mixer);
        model.userData.mixer = mixer;
        model.userData.animations = gltf.animations;
      } else {
        freezeStaticMatrices(model);
      }

      sendMessage('modelLoaded:' + id);
      if (onLoaded) {
        onLoaded(model);
      }
      requestRender();
    })
    .catch((error) => {
      console.error('Error cargando modelo ' + id + ':', error);
      sendMessage('error:' + id + ':' + error.message);
      requestRender();
    });
}

function updateRaycastRoot(id, enabled) {
  const model = loadedModels[id];
  if (!model) {
    return;
  }

  if (enabled || ALWAYS_RAYCAST_IDS.has(id)) {
    raycastRoots.add(model);
  } else {
    raycastRoots.delete(model);
  }
}

function removeModel(id) {
  modelLoadVersions[id] = (modelLoadVersions[id] || 0) + 1;
  delete positionAnimations[id];
  const model = loadedModels[id];
  if (model) {
    scene.remove(model);
    if (model.userData.mixer) {
      const idx = animMixers.indexOf(model.userData.mixer);
      if (idx > -1) animMixers.splice(idx, 1);
    }
    activeAnimationModelIds.delete(id);
    disposeObject3D(model);
    raycastRoots.delete(model);
    delete loadedModels[id];
    if (id === 'main') {
      tilePositionCache.clear();
    }
    sendMessage('modelRemoved:' + id);
    requestRender();
  }
}

function setModelPosition(id, x, y, z) {
  const model = loadedModels[id];
  if (model) {
    delete positionAnimations[id];
    model.position.set(x, y, z);
    updateModelTransform(model);
    requestRender();
  }
}

function animateModelToTile(id, coord, yOffset, durationMs) {
  const model = loadedModels[id];
  const tilePosition = getTileWorldPosition(coord);
  if (!model || !tilePosition) {
    return;
  }

  const target = new THREE.Vector3(
    tilePosition.x,
    tilePosition.y + (parseFloat(yOffset) || 0),
    tilePosition.z
  );

  positionAnimations[id] = {
    from: model.position.clone(),
    to: target,
    startTime: performance.now(),
    durationMs: Math.max(1, parseFloat(durationMs) || 220),
  };
  requestRender();
}

function setModelRotation(id, rx, ry, rz) {
  const model = loadedModels[id];
  if (model) {
    if (
      model.rotation.x === rx &&
      model.rotation.y === ry &&
      model.rotation.z === rz
    ) {
      return;
    }
    model.rotation.set(rx, ry, rz);
    updateModelTransform(model);
    requestRender();
  }
}

function setModelScale(id, sx, sy, sz) {
  const model = loadedModels[id];
  if (model) {
    model.scale.set(sx, sy, sz);
    updateModelTransform(model);
    requestRender();
  }
}

function setModelVisible(id, visible) {
  const model = loadedModels[id];
  if (model) {
    if (model.visible === visible) {
      return;
    }
    model.visible = visible;
    requestRender();
  }
}

function setObjectClickState(id, clickable) {
  const model = loadedModels[id];
  if (!model) {
    return;
  }

  model.userData = model.userData || {};
  if (model.userData.clickableRootState === clickable) {
    updateRaycastRoot(id, clickable);
    return;
  }
  model.userData.clickableRootState = clickable;

  model.traverse((child) => {
    child.userData = child.userData || {};
    child.userData.clickId = id;
    child.userData.clickable = clickable;
  });
  updateRaycastRoot(id, clickable);
}

function clearBuildingStyle(id) {
  const model = loadedModels[id];
  if (!model) {
    return;
  }

  model.traverse((node) => {
    if (!node.children || node.children.length === 0) {
      return;
    }

    for (let i = node.children.length - 1; i >= 0; i--) {
      const child = node.children[i];
      if (!(child.userData && child.userData._isStyleHelper === true)) {
        continue;
      }

      node.remove(child);
      if (child.geometry) {
        child.geometry.dispose();
      }
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material.forEach((mat) => mat.dispose && mat.dispose());
        } else if (child.material.dispose) {
          child.material.dispose();
        }
      }
    }
  });
}

function applyBuildingStyle(id, outlineHex, roofHex) {
  const model = loadedModels[id];
  if (!model) {
    return;
  }

  clearBuildingStyle(id);

  tintPlayerMaterial(model, roofHex || DEFAULT_PLAYER_TINT);
  requestRender();
}

function createMarkerCube(id, x, y, z, size, colorHex) {
  removeModel(id);

  const geometry = new THREE.BoxGeometry(size, size, size);
  const material = new THREE.MeshStandardMaterial({
    color: colorHex || '#ffffff',
    roughness: 0.6,
    metalness: 0.15,
  });
  const cube = new THREE.Mesh(geometry, material);
  cube.position.set(x, y, z);
  cube.name = id;
  cube.userData = cube.userData || {};
  cube.userData.clickId = id;
  cube.userData.clickable = true;
  scene.add(cube);
  loadedModels[id] = cube;
  updateRaycastRoot(id, true);

  sendMessage('modelLoaded:' + id);
  requestRender();
}

function coordToTileName(coord) {
  const normalized = String(coord || '').trim().toUpperCase();
  return normalized;
}

function tileNameToCoord(tileName) {
  const normalized = String(tileName || '').trim();
  return normalized;
}

function getTileObjectByCoord(coord) {
  const tileName = coordToTileName(coord);
  if (!tileName) {
    return null;
  }

  const boardRoot = loadedModels['main'];
  if (!boardRoot) {
    return null;
  }

  return boardRoot.getObjectByName(tileName) || scene.getObjectByName(tileName);
}

function getTileWorldPosition(coord) {
  const normalized = String(coord || '').trim().toUpperCase();
  if (tilePositionCache.has(normalized)) {
    return tilePositionCache.get(normalized).clone();
  }

  const tileObject = getTileObjectByCoord(coord);
  if (!tileObject) {
    return null;
  }

  const position = new THREE.Vector3();
  tileObject.getWorldPosition(position);
  tilePositionCache.set(normalized, position.clone());
  return position;
}

function createMarkerCubeOnTile(id, coord, yOffset, size, colorHex) {
  const tilePosition = getTileWorldPosition(coord);
  if (!tilePosition) {
    sendMessage('error:tileNotFound:' + coord);
    return;
  }

  createMarkerCube(
    id,
    tilePosition.x,
    tilePosition.y + (parseFloat(yOffset) || 0),
    tilePosition.z,
    parseFloat(size) || 1,
    colorHex || '#ffffff'
  );
}

function loadModelOnTile(id, url, coord, yOffset) {
  const tilePosition = getTileWorldPosition(coord);
  if (!tilePosition) {
    sendMessage('error:tileNotFound:' + coord);
    return;
  }

  const markerJitter = markerJitterFor(id, coord);
  loadModel(
    id,
    url,
    tilePosition.x + (markerJitter?.x || 0),
    tilePosition.y + (parseFloat(yOffset) || 0),
    tilePosition.z + (markerJitter?.z || 0),
    markerJitter
      ? (model) => {
          model.rotation.y = markerJitter.rotationY;
          updateModelTransform(model);
        }
      : undefined
  );
}

function findClickIdInHierarchy(object) {
  let current = object;
  while (current) {
    const data = current.userData || {};
    if (typeof data.clickId === 'string' && data.clickable !== false) {
      return data.clickId;
    }

    if (typeof current.name === 'string' && /^[0-9]+_[0-9]+\$/.test(current.name)) {
      const coord = tileNameToCoord(current.name);
      if (coord) {
        return 'tile:' + coord;
      }
    }

    current = current.parent;
  }
  return null;
}

function blockContextMenu(event) {
  event.preventDefault();
}

function onPointerDown(event) {
  if (event.button !== 0) {
    return;
  }

  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

  raycaster.setFromCamera(pointer, camera);
  const intersections = raycaster.intersectObjects(Array.from(raycastRoots), true);

  for (const hit of intersections) {
    const clickedId = findClickIdInHierarchy(hit.object);
    if (clickedId) {
      sendMessage('objectClicked:' + clickedId);
      return;
    }
  }
}

// --- Mensajería Flutter ↔ Three.js ---
function sendMessage(msg) {
  // Web: postMessage al padre
  if (window.parent !== window) {
    window.parent.postMessage(msg, '*');
  }
  // Desktop (InAppWebView): handler dedicado
  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler('onThreeJsMessage', msg);
  }
}

// Escuchar comandos desde Flutter
window.addEventListener('message', handleCommand);


function handleCommand(event) {
  const data = typeof event === 'string' ? event : event.data;
  if (typeof data !== 'string') return;

  const parts = data.split(':');
  const cmd = parts[0];

  switch (cmd) {
    case 'loadModel': {
      // loadModel:id:url:x:y:z
      const [, id, url, x, y, z] = parts;
      loadModel(id, url, parseFloat(x)||0, parseFloat(y)||0, parseFloat(z)||0);
      break;
    }
    case 'removeModel': {
      removeModel(parts[1]);
      break;
    }
    case 'setModelPosition': {
      const [, id, x, y, z] = parts;
      setModelPosition(id, parseFloat(x), parseFloat(y), parseFloat(z));
      break;
    }
    case 'animateModelToTile': {
      const [, id, coord, yOffset, durationMs] = parts;
      animateModelToTile(id, coord, yOffset, durationMs);
      break;
    }
    case 'setModelRotation': {
      const [, id, rx, ry, rz] = parts;
      setModelRotation(id, parseFloat(rx), parseFloat(ry), parseFloat(rz));
      break;
    }
    case 'setModelScale': {
      const [, id, sx, sy, sz] = parts;
      setModelScale(id, parseFloat(sx), parseFloat(sy), parseFloat(sz));
      break;
    }
    case 'setModelVisible': {
      setModelVisible(parts[1], parts[2] === 'true');
      break;
    }
    case 'createMarkerCube': {
      const [, id, x, y, z, size, colorHex] = parts;
      createMarkerCube(
        id,
        parseFloat(x) || 0,
        parseFloat(y) || 0,
        parseFloat(z) || 0,
        parseFloat(size) || 1,
        colorHex || '#ffffff'
      );
      break;
    }
    case 'createMarkerCubeOnTile': {
      const [, id, coord, yOffset, size, colorHex] = parts;
      createMarkerCubeOnTile(id, coord, yOffset, size, colorHex);
      break;
    }
    case 'loadModelOnTile': {
      const [, id, url, coord, yOffset] = parts;
      loadModelOnTile(id, url, coord, yOffset);
      break;
    }
    case 'setObjectClickable': {
      const [, id, clickable] = parts;
      setObjectClickState(id, clickable === 'true');
      break;
    }
    case 'applyBuildingStyle': {
      const [, id, outlineHex, roofHex] = parts;
      applyBuildingStyle(id, outlineHex, roofHex);
      break;
    }
    case 'setCameraOrbit': {
      const [, roll, pitch, dist] = parts;
      applyCameraOrbit(parseFloat(roll), parseFloat(pitch), parseFloat(dist));
      requestRender();
      break;
    }
    case 'setCameraTarget': {
      const [, x, y, z] = parts;
      controls.target.set(parseFloat(x), parseFloat(y), parseFloat(z));
      controls.update();
      requestRender();
      break;
    }
    case 'resetCamera': {
      controls.target.set(DEFAULT_CAM.targetX, DEFAULT_CAM.targetY, DEFAULT_CAM.targetZ);
      applyCameraOrbit(DEFAULT_CAM.roll, DEFAULT_CAM.pitch, DEFAULT_CAM.distance);
      controls.update();
      requestRender();
      break;
    }
    case 'playAnimation': {
      const [, id, animName] = parts;
      const model = loadedModels[id];
      if (model && model.userData.mixer && model.userData.animations) {
        const clip = model.userData.animations.find(a => a.name === animName)
                     || model.userData.animations[0];
        if (clip) {
          model.userData.mixer.clipAction(clip).play();
          activeAnimationModelIds.add(id);
          requestRender();
        }
      }
      break;
    }
    case 'pauseAnimation': {
      const model = loadedModels[parts[1]];
      if (model && model.userData.mixer) {
        model.userData.mixer.stopAllAction();
        activeAnimationModelIds.delete(parts[1]);
        requestRender();
      }
      break;
    }
    case 'getAnimations': {
      const model = loadedModels[parts[1]];
      const anims = model?.userData?.animations?.map(a => a.name) || [];
      sendMessage('animations:' + parts[1] + ':' + JSON.stringify(anims));
      break;
    }
  }
}

// Exponer handleCommand para InAppWebView
window.handleCommand = (cmd) => handleCommand(cmd);

init();
</script>
</body>
</html>
''';
}
