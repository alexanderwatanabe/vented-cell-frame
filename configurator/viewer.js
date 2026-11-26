// SPDX-License-Identifier: CERN-OHL-S-2.0
// A 3D view of one binary STL: orbit with the mouse, Z up as printed. Driven from outside through show(). It draws
// only when something moves: the camera, the size, or a new part.

import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { STLLoader } from "three/addons/loaders/STLLoader.js";

export function createViewer(host) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(window.devicePixelRatio);
  host.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(35, 1, 0.1, 5000);
  camera.up.set(0, 0, 1);
  camera.position.set(250, -300, 220);
  // a white part: light from above, a blue fill from the plate below, kept soft so its vents still read
  scene.add(new THREE.HemisphereLight(0xffffff, 0x3a52b8, 1.7));
  const sun = new THREE.DirectionalLight(0xffffff, 2.0);
  sun.position.set(200, -150, 400);
  scene.add(sun);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;

  let mesh = null;
  const material = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.75, metalness: 0 });

  let queued = false;
  function draw() {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      if (controls.update()) draw();   // damping still settling: keep going until it stops
      renderer.render(scene, camera);
    });
  }
  controls.addEventListener("change", draw);
  function resize() {
    const { clientWidth: w, clientHeight: h } = host;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    draw();
  }
  new ResizeObserver(resize).observe(host);
  resize();

  return {
    show(buffer) {
      const geometry = new STLLoader().parse(buffer);
      geometry.computeBoundingBox();
      const box = geometry.boundingBox;
      const centre = box.getCenter(new THREE.Vector3());
      const size = box.getSize(new THREE.Vector3()).length();
      if (mesh) { scene.remove(mesh); mesh.geometry.dispose(); }
      mesh = new THREE.Mesh(geometry, material);
      scene.add(mesh);
      controls.target.copy(centre);
      const dir = new THREE.Vector3(0.6, -0.75, 0.55).normalize();
      camera.position.copy(centre).addScaledVector(dir, size * 1.6);
      camera.near = size / 100;
      camera.far = size * 20;
      camera.updateProjectionMatrix();
      draw();
    },
  };
}
