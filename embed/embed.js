const postHeight = () => window.parent.postMessage({ type: "climber-embed-height", height: Math.ceil(document.body.getBoundingClientRect().height) }, "*");
window.addEventListener("load", postHeight);
window.addEventListener("resize", postHeight);
document.addEventListener("toggle", () => setTimeout(postHeight), true);
new ResizeObserver(postHeight).observe(document.body);
