/**
 * ===================================================================
 *  ROBLOX RIVALS OPTIMIZER — INTERACTIVE UNLOCK SYSTEM
 *  Created with love by Kaiser Everhart (@KaiserEverhart-Adaptation)
 * ===================================================================
 */

const SITE_CONFIG = {
  // YouTube Configuration
  creatorName: "Kaiser Everhart",
  creatorHandle: "@KaiserEverhart-Adaptation",
  channelUrl: "https://www.youtube.com/@KaiserEverhart-Adaptation",
  subscribeUrl: "https://www.youtube.com/@KaiserEverhart-Adaptation?sub_confirmation=1",
  
  // Tutorial Video (Easily updated once video goes live!)
  tutorialVideoUrl: "https://www.youtube.com/@KaiserEverhart-Adaptation/videos",
  
  // GitHub Open-Source Repository Link
  githubRepoUrl: "https://github.com/toufiqbd4200-sketch/Roblox-Rivals-Optimizer",
  
  // Download Artifact
  downloadFilename: "Kai_Optimizer.zip",
  downloadUrl: "./Kai_Optimizer.zip"
};

// State
const unlockState = {
  subscribed: false,
  liked: false
};

// DOM Elements
document.addEventListener("DOMContentLoaded", () => {
  const btnSub = document.getElementById("btn-subscribe");
  const btnLike = document.getElementById("btn-like");
  const btnDownload = document.getElementById("btn-download");
  const step1Box = document.getElementById("step-1-box");
  const step2Box = document.getElementById("step-2-box");
  const gateBox = document.getElementById("download-gate");
  const gateStatusText = document.getElementById("gate-status-text");

  // Step 1: Subscribe Action
  if (btnSub) {
    btnSub.addEventListener("click", (e) => {
      // Open YouTube Subscribe confirmation in a new tab
      window.open(SITE_CONFIG.subscribeUrl, "_blank", "noopener,noreferrer");

      // Mark Step 1 as completed after user action
      setTimeout(() => {
        markStep1Complete();
      }, 1200);
    });
  }

  // Step 2: Like Video Action
  if (btnLike) {
    btnLike.addEventListener("click", (e) => {
      // Open tutorial video in a new tab
      window.open(SITE_CONFIG.tutorialVideoUrl, "_blank", "noopener,noreferrer");

      // Mark Step 2 as completed
      setTimeout(() => {
        markStep2Complete();
      }, 1200);
    });
  }

  function markStep1Complete() {
    unlockState.subscribed = true;
    step1Box.classList.add("completed");
    const statusIcon = step1Box.querySelector(".step-status");
    if (statusIcon) statusIcon.innerHTML = "✓";
    btnSub.classList.add("btn-completed");
    btnSub.innerHTML = "<span>✓ Subscribed to Kaiser!</span>";
    checkUnlock();
  }

  function markStep2Complete() {
    unlockState.liked = true;
    step2Box.classList.add("completed");
    const statusIcon = step2Box.querySelector(".step-status");
    if (statusIcon) statusIcon.innerHTML = "✓";
    btnLike.classList.add("btn-completed");
    btnLike.innerHTML = "<span>✓ Video Liked!</span>";
    checkUnlock();
  }

  function checkUnlock() {
    if (unlockState.subscribed && unlockState.liked) {
      // UNLOCKED!
      gateBox.classList.add("unlocked");
      btnDownload.classList.remove("locked");
      btnDownload.classList.add("unlocked");
      btnDownload.removeAttribute("disabled");
      btnDownload.setAttribute("href", SITE_CONFIG.downloadUrl);
      btnDownload.setAttribute("download", SITE_CONFIG.downloadFilename);
      gateStatusText.innerHTML = "🎉 <strong>Download Unlocked! Enjoy Maximum FPS &amp; Low Ping!</strong>";
      btnDownload.innerHTML = `
        <span style="font-size: 1.4rem;">🎁</span>
        <span>Download Kai_Optimizer.zip (Direct)</span>
      `;

      // Launch Confetti Celebration!
      triggerConfetti();
    } else if (unlockState.subscribed) {
      gateStatusText.innerHTML = "⏳ <strong>Almost there!</strong> Like the tutorial video to unlock direct download.";
    } else if (unlockState.liked) {
      gateStatusText.innerHTML = "⏳ <strong>Almost there!</strong> Subscribe to Kaiser to unlock direct download.";
    }
  }

  // Confetti Animation Effect
  function triggerConfetti() {
    const canvas = document.getElementById("confetti-canvas");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const pieces = [];
    const colors = ["#FF3385", "#FF65A3", "#FFB3D9", "#FFE4EE", "#10B981", "#FFD700"];

    for (let i = 0; i < 90; i++) {
      pieces.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height - canvas.height,
        size: Math.random() * 8 + 4,
        color: colors[Math.floor(Math.random() * colors.length)],
        velY: Math.random() * 3 + 2,
        velX: Math.random() * 2 - 1,
        angle: Math.random() * 360,
        spin: Math.random() * 6 - 3
      });
    }

    let frame = 0;
    function render() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      pieces.forEach((p) => {
        p.y += p.velY;
        p.x += p.velX;
        p.angle += p.spin;
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2);
        ctx.fill();
      });

      frame++;
      if (frame < 180) {
        requestAnimationFrame(render);
      } else {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
      }
    }
    render();
  }

  // Smooth scroll
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", function (e) {
      const target = document.querySelector(this.getAttribute("href"));
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: "smooth" });
      }
    });
  });
});
